import Combine
import CoreMIDI
import Foundation
import OSLog

@MainActor
final class QuUSBMIDIMixerController: MixerController {
    private static let logger = Logger(subsystem: "QuController", category: "USBMIDI")

    let transportKind: MixerTransportKind = .usbMIDI

    @Published private var storedChannels: [MixerChannelState] = QuMidiControllerSupport.makeInitialChannels()
    @Published private var storedConnectionState = MixerConnectionState(
        phase: .disconnected,
        message: "Disconnected",
        endpoint: nil
    )
    @Published private var storedConnectionOptions: [MixerConnectionOption] = []

    var channels: [MixerChannelState] {
        storedChannels
    }

    var connectionState: MixerConnectionState {
        storedConnectionState
    }

    var connectionOptions: [MixerConnectionOption] {
        storedConnectionOptions
    }

    var channelsPublisher: AnyPublisher<[MixerChannelState], Never> {
        $storedChannels.eraseToAnyPublisher()
    }

    var connectionStatePublisher: AnyPublisher<MixerConnectionState, Never> {
        $storedConnectionState.eraseToAnyPublisher()
    }

    var connectionOptionsPublisher: AnyPublisher<[MixerConnectionOption], Never> {
        $storedConnectionOptions.eraseToAnyPublisher()
    }

    private let connectionTimeout: Duration = .seconds(5)
    private let handshakeRetryDelay: Duration = .milliseconds(400)
    private let handshakeAttemptCount = 3
    private let signalPublishInterval: Duration = .milliseconds(300)
    private var client = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private var inputPort = MIDIPortRef()
    private var destinationEndpoint = MIDIEndpointRef()
    private var sourceEndpoints: [MIDIEndpointRef] = []
    private var activeSenseTask: Task<Void, Never>?
    private var connectionTimeoutTask: Task<Void, Never>?
    private var signalPublishTask: Task<Void, Never>?
    private var midiChannel: UInt8?
    private var mixerModel: QuMixerModel?
    private var byteBuffer: [UInt8] = []
    private var nrpnState = NRPNState()
    private var isIntentionalDisconnect = false
    private var isSignalMonitoringEnabled = false
    private var pendingSignalStates: [MixerChannelID: Bool] = [:]
    private var availablePorts: [String: USBMIDIPortPair] = [:]
    private var connectedPortName: String?

    init() {
        refreshConnectionOptions()
    }

    deinit {
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }
        if outputPort != 0 {
            MIDIPortDispose(outputPort)
        }
        if client != 0 {
            MIDIClientDispose(client)
        }
    }

    func connect(to target: MixerConnectionTarget) async {
        guard case .usbMIDI(let optionID) = target else {
            storedConnectionState = MixerConnectionState(
                phase: .error,
                message: formattedErrorMessage(for: MixerTransportError.unsupportedTarget, prefix: "Connection failed"),
                endpoint: nil
            )
            return
        }

        refreshConnectionOptions()
        Self.logger.info("USB MIDI connect requested. optionID=\(String(describing: optionID), privacy: .public) availableOptions=\(self.storedConnectionOptions.count)")

        guard let optionID else {
            storedConnectionState = MixerConnectionState(
                phase: .error,
                message: formattedErrorMessage(for: MixerTransportError.missingUSBMIDIDevice, prefix: "Connection failed"),
                endpoint: nil
            )
            return
        }

        guard let portPair = availablePorts[optionID] else {
            storedConnectionState = MixerConnectionState(
                phase: .error,
                message: formattedErrorMessage(for: MixerTransportError.unavailableUSBMIDIDevice(optionID), prefix: "Connection failed"),
                endpoint: nil
            )
            return
        }

        await disconnectTransport(updateState: false, intentional: false)
        isIntentionalDisconnect = false

        storedConnectionState = MixerConnectionState(
            phase: .connecting,
            message: "Connecting to USB MIDI device \(portPair.option.displayName)",
            endpoint: nil
        )
        Self.logger.info("Connecting to USB MIDI device name=\(portPair.option.displayName, privacy: .public) destinationUID=\(portPair.destinationUID) sourceCount=\(portPair.sources.count)")
        for source in portPair.sources {
            Self.logger.debug("Selected source endpoint name=\(Self.endpointDisplayName(source), privacy: .public) uid=\(Self.endpointUniqueID(source)) entityUID=\(Self.entityUniqueID(for: source) ?? 0) deviceUID=\(Self.deviceUniqueID(for: source) ?? 0)")
        }
        startConnectionTimeout(deviceName: portPair.option.displayName)

        do {
            try ensureMIDIClient()
            try connectPorts(for: portPair)
            connectedPortName = portPair.option.displayName
            try await beginHandshake(destinationUID: portPair.destinationUID)
        } catch {
            Self.logger.error("USB MIDI connect setup failed: \(error.localizedDescription, privacy: .public)")
            await handleConnectionFailure(error, prefix: "Connection failed")
        }
    }

    func disconnect() {
        Task {
            await disconnectTransport(updateState: true, intentional: true)
        }
    }

    func shutdownMixer() async {
        guard connectionState.phase == .connected, let midiChannel else {
            storedConnectionState = MixerConnectionState(
                phase: .error,
                message: "Shutdown unavailable: Connect to a mixer first",
                endpoint: nil
            )
            return
        }

        do {
            try await sendBytes(QuMidiMessageEncoder.remoteShutdown(midiChannel: midiChannel))
            let deviceName = connectedPortName
            await disconnectTransport(updateState: false, intentional: true)
            storedConnectionState = MixerConnectionState(
                phase: .disconnected,
                message: deviceName.map { "Shutdown command sent to \($0). Mixer is powering off." } ?? "Shutdown command sent. Mixer is powering off.",
                endpoint: nil
            )
        } catch {
            await handleConnectionFailure(error, prefix: "Shutdown failed")
        }
    }

    func setLevel(for channelID: MixerChannelID, level: FaderLevel) {
        storedChannels = QuMidiControllerSupport.setLevel(storedChannels, channelID: channelID, level: level)

        guard let midiChannel else {
            return
        }

        Task {
            do {
                try await sendBytes(
                    QuMidiMessageEncoder.nrpn(
                        midiChannel: midiChannel,
                        targetChannel: channelID.midiChannelCode,
                        parameterID: 0x17,
                        value: UInt8(level.toMIDIValue()),
                        index: 0x07
                    )
                )
            } catch {
                await handleConnectionFailure(error, prefix: "Send failed")
            }
        }
    }

    func setMute(for channelID: MixerChannelID, isMuted: Bool) {
        storedChannels = QuMidiControllerSupport.setMute(storedChannels, channelID: channelID, isMuted: isMuted)

        guard let midiChannel else {
            return
        }

        Task {
            do {
                try await sendBytes(
                    QuMidiMessageEncoder.mute(
                        midiChannel: midiChannel,
                        targetChannel: channelID.midiChannelCode,
                        isMuted: isMuted
                    )
                )
            } catch {
                await handleConnectionFailure(error, prefix: "Send failed")
            }
        }
    }

    func setSignalMonitoringEnabled(_ isEnabled: Bool) {
        guard isSignalMonitoringEnabled != isEnabled else {
            return
        }

        isSignalMonitoringEnabled = isEnabled

        Task {
            do {
                try await sendMeterRequest(isEnabled: isEnabled)
                if !isEnabled {
                    clearSignalStates()
                }
            } catch {
                if isEnabled {
                    await handleConnectionFailure(error, prefix: "Signal monitoring failed")
                } else {
                    clearSignalStates()
                }
            }
        }
    }

    func refreshConnectionOptions() {
        let ports = Self.discoverPorts()
        availablePorts = Dictionary(uniqueKeysWithValues: ports.map { ($0.option.id, $0) })
        storedConnectionOptions = ports.map(\.option).sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        Self.logger.info("Discovered \(ports.count) USB MIDI destination option(s)")
        for port in ports {
            Self.logger.debug("Destination option name=\(port.option.displayName, privacy: .public) detail=\(port.option.detail ?? "", privacy: .public) destinationUID=\(port.destinationUID) matchedSourceCount=\(port.sources.count)")
        }
    }

    private func ensureMIDIClient() throws {
        guard client == 0 else {
            Self.logger.debug("Reusing existing CoreMIDI client and ports")
            return
        }

        var createdClient = MIDIClientRef()
        let clientStatus = MIDIClientCreateWithBlock("Qu Controller MIDI Client" as CFString, &createdClient) { _ in }
        guard clientStatus == noErr else {
            throw MixerTransportError.midiSetupFailed("Unable to create MIDI client (\(clientStatus))")
        }
        Self.logger.info("Created CoreMIDI client ref=\(createdClient)")

        var createdOutputPort = MIDIPortRef()
        let outputStatus = MIDIOutputPortCreate(createdClient, "Qu Controller MIDI Output" as CFString, &createdOutputPort)
        guard outputStatus == noErr else {
            MIDIClientDispose(createdClient)
            throw MixerTransportError.midiSetupFailed("Unable to create MIDI output port (\(outputStatus))")
        }
        Self.logger.info("Created CoreMIDI output port ref=\(createdOutputPort)")

        var createdInputPort = MIDIPortRef()
        let inputStatus = MIDIInputPortCreateWithBlock(createdClient, "Qu Controller MIDI Input" as CFString, &createdInputPort) { [weak self] packetList, _ in
            guard let self else {
                return
            }

            Self.forEachPacket(in: packetList.pointee) { packet in
                let bytes = withUnsafeBytes(of: packet.data) { rawBuffer in
                    Array(rawBuffer.prefix(Int(packet.length)))
                }
                Task { @MainActor in
                    self.receive(bytes: bytes)
                }
            }
        }

        guard inputStatus == noErr else {
            MIDIPortDispose(createdOutputPort)
            MIDIClientDispose(createdClient)
            throw MixerTransportError.midiSetupFailed("Unable to create MIDI input port (\(inputStatus))")
        }
        Self.logger.info("Created CoreMIDI input port ref=\(createdInputPort)")

        client = createdClient
        outputPort = createdOutputPort
        inputPort = createdInputPort
    }

    private func connectPorts(for portPair: USBMIDIPortPair) throws {
        guard !portPair.sources.isEmpty else {
            throw MixerTransportError.missingUSBMIDISource(portPair.option.displayName)
        }

        for sourceEndpoint in sourceEndpoints {
            Self.logger.debug("Disconnecting previous source uid=\(Self.endpointUniqueID(sourceEndpoint))")
            MIDIPortDisconnectSource(inputPort, sourceEndpoint)
        }

        for sourceEndpoint in portPair.sources {
            let status = MIDIPortConnectSource(inputPort, sourceEndpoint, nil)
            guard status == noErr else {
                throw MixerTransportError.midiSetupFailed("Unable to open MIDI source (\(status))")
            }
            Self.logger.info("Connected input port to source name=\(Self.endpointDisplayName(sourceEndpoint), privacy: .public) uid=\(Self.endpointUniqueID(sourceEndpoint))")
        }

        sourceEndpoints = portPair.sources
        destinationEndpoint = portPair.destination
        Self.logger.info("Using destination name=\(Self.endpointDisplayName(portPair.destination), privacy: .public) uid=\(portPair.destinationUID)")
    }

    private func startActiveSensing() {
        activeSenseTask?.cancel()
        activeSenseTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                do {
                    try await self.sendBytes([0xFE])
                } catch {
                    await self.handleConnectionFailure(error, prefix: "Connection lost")
                    return
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func beginHandshake(destinationUID: MIDIUniqueID) async throws {
        for attempt in 1 ... handshakeAttemptCount {
            guard connectionState.phase == .connecting else {
                Self.logger.debug("Stopping handshake retries because connection phase changed to \(String(describing: self.connectionState.phase), privacy: .public)")
                return
            }

            Self.logger.info("Sending Qu USB MIDI system state request attempt=\(attempt) destinationUID=\(destinationUID)")
            try await sendBytes(QuMidiMessageEncoder.systemStateRequest())

            guard attempt < handshakeAttemptCount else {
                continue
            }

            try? await Task.sleep(for: handshakeRetryDelay)
        }
    }

    private func requestChannelNames() async throws {
        guard let midiChannel else {
            return
        }

        for channelID in MixerChannelID.selectableChannels {
            try await sendBytes(QuMidiMessageEncoder.channelNameRequest(midiChannel: midiChannel, channelID: channelID))
        }
    }

    private func sendMeterRequest(isEnabled: Bool) async throws {
        guard destinationEndpoint != 0 else {
            if !isEnabled {
                clearSignalStates()
                return
            }
            throw MixerTransportError.notConnected
        }

        let requestChannel = midiChannel ?? 0x7F
        try await sendBytes(QuMidiMessageEncoder.meterRequest(requestChannel: requestChannel, isEnabled: isEnabled))
    }

    private func sendBytes(_ bytes: [UInt8]) async throws {
        guard outputPort != 0, destinationEndpoint != 0 else {
            throw MixerTransportError.notConnected
        }

        if bytes.first == 0xF0, bytes.last == 0xF7 {
            try await sendSysExBytes(bytes)
            return
        }

        Self.logger.debug("Sending MIDI bytes count=\(bytes.count) destinationUID=\(Self.endpointUniqueID(self.destinationEndpoint)) payload=\(Self.hexString(for: bytes), privacy: .public)")

        let bufferSize = MemoryLayout<MIDIPacketList>.size + max(bytes.count, 256)
        let packetListPointer = UnsafeMutableRawPointer.allocate(
            byteCount: bufferSize,
            alignment: MemoryLayout<MIDIPacketList>.alignment
        )
        defer { packetListPointer.deallocate() }

        let packetList = packetListPointer.bindMemory(to: MIDIPacketList.self, capacity: 1)
        var packet = MIDIPacketListInit(packetList)

        let status = bytes.withUnsafeBufferPointer { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else {
                return noErr
            }

            packet = MIDIPacketListAdd(packetList, bufferSize, packet, 0, buffer.count, baseAddress)
            guard packet != nil else {
                return OSStatus(paramErr)
            }

            return MIDISend(outputPort, destinationEndpoint, packetList)
        }

        guard status == noErr else {
            throw MixerTransportError.midiSetupFailed("Unable to send MIDI data (\(status))")
        }
    }

    private func sendSysExBytes(_ bytes: [UInt8]) async throws {
        Self.logger.debug("Sending SysEx bytes count=\(bytes.count) destinationUID=\(Self.endpointUniqueID(self.destinationEndpoint)) payload=\(Self.hexString(for: bytes), privacy: .public)")

        let box = USBMIDISysExRequestBox(
            destination: destinationEndpoint,
            payload: bytes
        ) { result in
            switch result {
            case .success:
                Self.logger.debug("SysEx send completion succeeded payload=\(Self.hexString(for: bytes), privacy: .public)")
            case .failure(let error):
                Self.logger.error("SysEx send completion failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        try await box.send()
    }

    private func receive(bytes: [UInt8]) {
        guard !bytes.isEmpty else {
            return
        }

        Self.logger.debug("Received MIDI bytes count=\(bytes.count) payload=\(Self.hexString(for: bytes), privacy: .public)")
        byteBuffer.append(contentsOf: bytes)
        processBufferedMessages()
    }

    private func processBufferedMessages() {
        while let firstByte = byteBuffer.first {
            switch firstByte {
            case 0xFE:
                byteBuffer.removeFirst()
            case 0xF0:
                guard let endIndex = byteBuffer.firstIndex(of: 0xF7) else {
                    Self.logger.debug("Buffered partial SysEx count=\(self.byteBuffer.count)")
                    return
                }
                let sysex = Array(byteBuffer[...endIndex])
                byteBuffer.removeSubrange(...endIndex)
                handleSysEx(sysex)
            case 0xB0 ... 0xBF:
                guard byteBuffer.count >= 3 else {
                    return
                }
                let status = byteBuffer[0]
                let controller = byteBuffer[1]
                let value = byteBuffer[2]
                byteBuffer.removeFirst(3)
                handleControlChange(status: status, controller: controller, value: value)
            case 0x80 ... 0x9F:
                guard byteBuffer.count >= 3 else {
                    return
                }
                let status = byteBuffer[0]
                let note = byteBuffer[1]
                let velocity = byteBuffer[2]
                byteBuffer.removeFirst(3)
                handleNoteMessage(status: status, note: note, velocity: velocity)
            default:
                Self.logger.debug("Dropping unexpected MIDI byte=\(String(format: "%02X", firstByte), privacy: .public)")
                byteBuffer.removeFirst()
            }
        }
    }

    private func handleSysEx(_ bytes: [UInt8]) {
        guard bytes.count >= 10 else {
            Self.logger.debug("Ignoring short SysEx payload=\(Self.hexString(for: bytes), privacy: .public)")
            return
        }

        let isQuHeader =
            bytes[0] == 0xF0 &&
            bytes[1] == 0x00 &&
            bytes[2] == 0x00 &&
            bytes[3] == 0x1A &&
            bytes[4] == 0x50 &&
            bytes[5] == 0x11

        guard isQuHeader else {
            Self.logger.debug("Ignoring non-Qu SysEx payload=\(Self.hexString(for: bytes), privacy: .public)")
            return
        }

        let receivedMIDIChannel = bytes[8] & 0x0F
        let command = bytes[9] & 0x7F
        Self.logger.info("Received Qu SysEx command=\(command) midiChannel=\(receivedMIDIChannel + 1) payload=\(Self.hexString(for: bytes), privacy: .public)")

        switch command {
        case 0x02:
            guard bytes.count >= 12,
                  let channelID = MixerChannelID(midiChannelCode: bytes[10]) else {
                return
            }

            let nameBytes = Array(bytes[11..<(bytes.count - 1)])
            let decodedName = QuMidiControllerSupport.sanitizedChannelName(from: nameBytes)
            storedChannels = QuMidiControllerSupport.setCustomName(storedChannels, channelID: channelID, customName: decodedName)
        case 0x11:
            connectionTimeoutTask?.cancel()
            connectionTimeoutTask = nil
            midiChannel = receivedMIDIChannel
            mixerModel = QuMixerModel(boxID: bytes[10])
            let deviceName = connectedPortName ?? "USB MIDI device"
            Self.logger.info("USB MIDI handshake succeeded. device=\(deviceName, privacy: .public) mixerModelBoxID=\(bytes[10]) negotiatedChannel=\(receivedMIDIChannel + 1)")
            startActiveSensing()
            storedConnectionState = MixerConnectionState(
                phase: .connected,
                message: "Connected to \(deviceName) on MIDI channel \(Int(receivedMIDIChannel) + 1)",
                endpoint: nil
            )

            Task {
                try? await requestChannelNames()
                if self.isSignalMonitoringEnabled {
                    try? await self.sendMeterRequest(isEnabled: true)
                }
            }
        case 0x13:
            Self.logger.debug("Received Qu meter payload length=\(bytes.count)")
            let payload = Array(bytes[10..<(bytes.count - 1)])
            handleMeterDataPayload(payload)
        default:
            Self.logger.debug("Unhandled Qu SysEx command=\(command) payload=\(Self.hexString(for: bytes), privacy: .public)")
            return
        }
    }

    private func startConnectionTimeout(deviceName: String) {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: self?.connectionTimeout ?? .seconds(5))

            guard let self, !Task.isCancelled else {
                return
            }

            guard self.connectionState.phase == .connecting else {
                return
            }

            Self.logger.error("USB MIDI connection timed out. device=\(deviceName, privacy: .public) destinationUID=\(Self.endpointUniqueID(self.destinationEndpoint)) sourceCount=\(self.sourceEndpoints.count)")
            await self.handleConnectionFailure(
                MixerTransportError.connectionTimedOut(seconds: Int(connectionTimeout.components.seconds)),
                prefix: "Connection to \(deviceName) timed out"
            )
        }
    }

    private func handleControlChange(status: UInt8, controller: UInt8, value: UInt8) {
        let statusChannel = status & 0x0F
        if let midiChannel, statusChannel != midiChannel {
            return
        }

        switch controller {
        case 0x63:
            nrpnState.channel = value
        case 0x62:
            nrpnState.parameterID = value
        case 0x06:
            nrpnState.dataMSB = value
        case 0x26:
            if let targetChannel = nrpnState.channel,
               let channelID = MixerChannelID(midiChannelCode: targetChannel),
               nrpnState.parameterID == 0x17,
               value == 0x07,
               let dataMSB = nrpnState.dataMSB
            {
                let level = FaderLevel(normalized: Double(dataMSB) / 127)
                storedChannels = QuMidiControllerSupport.setLevel(storedChannels, channelID: channelID, level: level)
            }
            nrpnState.clear()
        default:
            break
        }
    }

    private func handleNoteMessage(status: UInt8, note: UInt8, velocity: UInt8) {
        let statusType = status & 0xF0
        let statusChannel = status & 0x0F

        guard let midiChannel, statusChannel == midiChannel else {
            return
        }

        guard statusType == 0x90,
              velocity > 0,
              let channelID = MixerChannelID(midiChannelCode: note) else {
            return
        }

        let isMuted = velocity >= 0x40
        storedChannels = QuMidiControllerSupport.setMute(storedChannels, channelID: channelID, isMuted: isMuted)
    }

    private func handleMeterDataPayload(_ payload: [UInt8]) {
        guard isSignalMonitoringEnabled,
              let signalLevels = QuSignalActivityDecoder.decodeSignalLevels(from7BitPayload: payload, mixerModel: mixerModel) else {
            return
        }

        var resolvedStates: [MixerChannelID: Bool] = [:]
        for channel in storedChannels {
            let decibels = signalLevels[channel.id] ?? QuSignalActivityDecoder.silenceFloor
            resolvedStates[channel.id] = resolvedSignalState(currentState: channel.hasSignal, decibels: decibels)
        }

        pendingSignalStates = resolvedStates
        scheduleSignalPublishIfNeeded()
    }

    private func resolvedSignalState(currentState: Bool, decibels: Double) -> Bool {
        let turnOnThreshold = -60.0
        let turnOffThreshold = -72.0

        if currentState {
            return decibels >= turnOffThreshold
        }

        return decibels >= turnOnThreshold
    }

    private func scheduleSignalPublishIfNeeded() {
        guard signalPublishTask == nil else {
            return
        }

        signalPublishTask = Task { [weak self] in
            guard let self else {
                return
            }

            try? await Task.sleep(for: self.signalPublishInterval)
            guard !Task.isCancelled else {
                return
            }

            self.applyPendingSignalStates()
            self.signalPublishTask = nil
        }
    }

    private func applyPendingSignalStates() {
        guard isSignalMonitoringEnabled else {
            return
        }

        let signalStates = pendingSignalStates
        guard !signalStates.isEmpty else {
            return
        }

        storedChannels = QuMidiControllerSupport.applySignalStates(storedChannels, signalStates: signalStates)
    }

    private func clearSignalStates() {
        pendingSignalStates.removeAll(keepingCapacity: false)
        signalPublishTask?.cancel()
        signalPublishTask = nil
        storedChannels = QuMidiControllerSupport.applySignalStates(storedChannels, signalStates: [:])
    }

    private func disconnectTransport(updateState: Bool, intentional: Bool) async {
        Self.logger.info("Disconnecting USB MIDI transport intentional=\(intentional) updateState=\(updateState)")
        isIntentionalDisconnect = intentional
        activeSenseTask?.cancel()
        activeSenseTask = nil
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        signalPublishTask?.cancel()
        signalPublishTask = nil
        if inputPort != 0 {
            for sourceEndpoint in sourceEndpoints {
                Self.logger.debug("Disconnecting source uid=\(Self.endpointUniqueID(sourceEndpoint))")
                MIDIPortDisconnectSource(inputPort, sourceEndpoint)
            }
        }
        sourceEndpoints.removeAll(keepingCapacity: false)
        destinationEndpoint = MIDIEndpointRef()
        connectedPortName = nil
        midiChannel = nil
        mixerModel = nil
        byteBuffer.removeAll(keepingCapacity: false)
        nrpnState.clear()
        pendingSignalStates.removeAll(keepingCapacity: false)
        storedChannels = QuMidiControllerSupport.clearTransientState(storedChannels)

        if updateState {
            storedConnectionState = MixerConnectionState(
                phase: .disconnected,
                message: "Disconnected",
                endpoint: nil
            )
        }
    }

    private func handleConnectionFailure(_ error: Error, prefix: String) async {
        if isIntentionalDisconnect {
            Self.logger.debug("Ignoring connection failure after intentional disconnect: \(error.localizedDescription, privacy: .public)")
            return
        }

        Self.logger.error("USB MIDI failure prefix=\(prefix, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        await disconnectTransport(updateState: false, intentional: true)
        storedConnectionState = MixerConnectionState(
            phase: .error,
            message: formattedErrorMessage(for: error, prefix: prefix),
            endpoint: nil
        )
    }

    private func formattedErrorMessage(for error: Error, prefix: String) -> String {
        "\(prefix): \(error.localizedDescription)"
    }

    private static func discoverPorts() -> [USBMIDIPortPair] {
        var sourcesByEntityID: [MIDIUniqueID: [MIDIEndpointRef]] = [:]
        var sourcesByDeviceID: [MIDIUniqueID: [MIDIEndpointRef]] = [:]
        var allSources: [MIDIEndpointRef] = []

        for sourceIndex in 0 ..< MIDIGetNumberOfSources() {
            let source = MIDIGetSource(sourceIndex)
            guard source != 0 else {
                continue
            }

            allSources.append(source)

            if let entityID = entityUniqueID(for: source) {
                sourcesByEntityID[entityID, default: []].append(source)
            }

            if let deviceID = deviceUniqueID(for: source) {
                sourcesByDeviceID[deviceID, default: []].append(source)
            }
        }

        var ports: [USBMIDIPortPair] = []
        for destinationIndex in 0 ..< MIDIGetNumberOfDestinations() {
            let destination = MIDIGetDestination(destinationIndex)
            guard destination != 0 else {
                continue
            }

            let name = displayName(for: destination) ?? "USB MIDI Device \(destinationIndex + 1)"
            let detail = manufacturerName(for: destination)
            let destinationID = uniqueID(for: destination)
            let entityID = entityUniqueID(for: destination)
            let deviceID = deviceUniqueID(for: destination)
            let matchedSources: [MIDIEndpointRef] = if let entityID, let entitySources = sourcesByEntityID[entityID], !entitySources.isEmpty {
                entitySources
            } else if let deviceID, let deviceSources = sourcesByDeviceID[deviceID] {
                deviceSources
            } else {
                []
            }
            let sources = matchedSources.isEmpty ? allSources : matchedSources
            let id = destinationID.map(String.init) ?? name
            let option = MixerConnectionOption(id: id, displayName: name, detail: detail)
            ports.append(USBMIDIPortPair(option: option, destination: destination, sources: sources))
        }

        return ports
    }

    private static func endpointDisplayName(_ endpoint: MIDIEndpointRef) -> String {
        displayName(for: endpoint) ?? "<unknown>"
    }

    private static func endpointUniqueID(_ endpoint: MIDIEndpointRef) -> MIDIUniqueID {
        uniqueID(for: endpoint) ?? 0
    }

    private static func hexString(for bytes: [UInt8], limit: Int = 24) -> String {
        let prefixBytes = bytes.prefix(limit).map { String(format: "%02X", $0) }.joined(separator: " ")
        if bytes.count > limit {
            return "\(prefixBytes) ... (\(bytes.count) bytes)"
        }

        return prefixBytes
    }

    private static func uniqueID(for object: MIDIObjectRef) -> MIDIUniqueID? {
        var value = MIDIUniqueID()
        let status = MIDIObjectGetIntegerProperty(object, kMIDIPropertyUniqueID, &value)
        return status == noErr ? value : nil
    }

    private static func deviceUniqueID(for endpoint: MIDIEndpointRef) -> MIDIUniqueID? {
        var entity = MIDIEntityRef()
        guard MIDIEndpointGetEntity(endpoint, &entity) == noErr, entity != 0 else {
            return nil
        }

        var device = MIDIDeviceRef()
        guard MIDIEntityGetDevice(entity, &device) == noErr, device != 0 else {
            return nil
        }

        return uniqueID(for: device)
    }

    private static func entityUniqueID(for endpoint: MIDIEndpointRef) -> MIDIUniqueID? {
        var entity = MIDIEntityRef()
        guard MIDIEndpointGetEntity(endpoint, &entity) == noErr, entity != 0 else {
            return nil
        }

        return uniqueID(for: entity)
    }

    private static func displayName(for object: MIDIObjectRef) -> String? {
        stringProperty(kMIDIPropertyDisplayName, for: object) ?? stringProperty(kMIDIPropertyName, for: object)
    }

    private static func manufacturerName(for endpoint: MIDIEndpointRef) -> String? {
        var entity = MIDIEntityRef()
        guard MIDIEndpointGetEntity(endpoint, &entity) == noErr, entity != 0 else {
            return nil
        }

        var device = MIDIDeviceRef()
        guard MIDIEntityGetDevice(entity, &device) == noErr, device != 0 else {
            return nil
        }

        return stringProperty(kMIDIPropertyManufacturer, for: device)
    }

    private static func stringProperty(_ property: CFString, for object: MIDIObjectRef) -> String? {
        var unmanaged: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(object, property, &unmanaged)
        guard status == noErr, let unmanaged else {
            return nil
        }

        return unmanaged.takeRetainedValue() as String
    }

    private static func forEachPacket(in packetList: MIDIPacketList, _ body: (MIDIPacket) -> Void) {
        var packet = packetList.packet
        for _ in 0 ..< packetList.numPackets {
            body(packet)
            packet = MIDIPacketNext(&packet).pointee
        }
    }
}

private struct USBMIDIPortPair {
    let option: MixerConnectionOption
    let destination: MIDIEndpointRef
    let sources: [MIDIEndpointRef]

    var destinationUID: MIDIUniqueID {
        var value = MIDIUniqueID()
        return MIDIObjectGetIntegerProperty(destination, kMIDIPropertyUniqueID, &value) == noErr ? value : 0
    }
}

private struct NRPNState {
    var channel: UInt8?
    var parameterID: UInt8?
    var dataMSB: UInt8?

    mutating func clear() {
        channel = nil
        parameterID = nil
        dataMSB = nil
    }
}

private final class USBMIDISysExRequestBox {
    private let payloadCount: Int
    private let payloadPointer: UnsafeMutablePointer<UInt8>
    private let onCompletion: (Result<Void, Error>) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var request: MIDISysexSendRequest

    init(
        destination: MIDIEndpointRef,
        payload: [UInt8],
        onCompletion: @escaping (Result<Void, Error>) -> Void
    ) {
        self.payloadCount = payload.count
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: payload.count)
        _ = pointer.initialize(from: payload, count: payload.count)
        self.payloadPointer = pointer
        self.onCompletion = onCompletion
        self.request = MIDISysexSendRequest(
            destination: destination,
            data: UnsafePointer(pointer),
            bytesToSend: UInt32(payload.count),
            complete: false,
            reserved: (0, 0, 0),
            completionProc: usbMIDISysExCompletion,
            completionRefCon: nil
        )
    }

    deinit {
        payloadPointer.deinitialize(count: payloadCount)
        payloadPointer.deallocate()
    }

    func send() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            request.completionRefCon = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
            let status = MIDISendSysex(&request)
            if status != noErr {
                let error = MixerTransportError.midiSetupFailed("Unable to send SysEx data (\(status))")
                self.continuation = nil
                request.completionRefCon.map { Unmanaged<USBMIDISysExRequestBox>.fromOpaque($0).release() }
                request.completionRefCon = nil
                onCompletion(.failure(error))
                continuation.resume(throwing: error)
            }
        }
    }

    fileprivate func finish() {
        onCompletion(.success(()))
        continuation?.resume(returning: ())
        continuation = nil
    }
}

private func usbMIDISysExCompletion(_ request: UnsafeMutablePointer<MIDISysexSendRequest>) -> Void {
    guard let refCon = request.pointee.completionRefCon else {
        return
    }

    let box = Unmanaged<USBMIDISysExRequestBox>.fromOpaque(refCon).takeRetainedValue()
    box.finish()
}
