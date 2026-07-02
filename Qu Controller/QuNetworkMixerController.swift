//
//  QuNetworkMixerController.swift
//  Qu Controller
//

import Combine
import Foundation
import Network

// Protocol reference:
// docs/IMPLEMENTATION_REFERENCES.md
@MainActor
final class QuNetworkMixerController: MixerController {
    @Published private var storedChannels: [MixerChannelState] = [
        MixerChannelState(id: .mainLr, level: FaderLevel(normalized: 0.72))
    ]
    @Published private var storedConnectionState = MixerConnectionState(
        phase: .disconnected,
        message: "Disconnected",
        endpoint: nil
    )

    var channels: [MixerChannelState] {
        storedChannels
    }

    var connectionState: MixerConnectionState {
        storedConnectionState
    }

    var channelsPublisher: AnyPublisher<[MixerChannelState], Never> {
        $storedChannels.eraseToAnyPublisher()
    }

    var connectionStatePublisher: AnyPublisher<MixerConnectionState, Never> {
        $storedConnectionState.eraseToAnyPublisher()
    }

    private let connectionQueue = DispatchQueue(label: "com.scrapps.qucontroller.network")
    private let connectionTimeout: Duration = .seconds(5)
    private var connection: NWConnection?
    private var activeSenseTask: Task<Void, Never>?
    private var connectionTimeoutTask: Task<Void, Never>?
    private var midiChannel: UInt8?
    private var byteBuffer: [UInt8] = []
    private var nrpnState = NRPNState()
    private var isIntentionalDisconnect = false

    func connect(to endpoint: MixerEndpoint) async {
        await disconnectTransport(updateState: false, intentional: false)
        isIntentionalDisconnect = false

        storedConnectionState = MixerConnectionState(
            phase: .connecting,
            message: "Connecting to \(endpoint.host):\(endpoint.port)",
            endpoint: endpoint
        )
        startConnectionTimeout(for: endpoint)

        do {
            let nwConnection = try await makeConnection(for: endpoint)
            connection = nwConnection
            startReceiving(on: nwConnection, endpoint: endpoint)
            startActiveSensing()
            try await sendSystemStateRequest()
        } catch {
            await handleConnectionFailure(error, endpoint: endpoint, prefix: "Connection failed")
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
                endpoint: storedConnectionState.endpoint
            )
            return
        }

        do {
            try await sendRemoteShutdown(midiChannel: midiChannel)
            let endpoint = storedConnectionState.endpoint
            await disconnectTransport(updateState: false, intentional: true)
            storedConnectionState = MixerConnectionState(
                phase: .disconnected,
                message: "Shutdown command sent. Mixer is powering off.",
                endpoint: endpoint
            )
        } catch {
            await handleConnectionFailure(error, endpoint: storedConnectionState.endpoint, prefix: "Shutdown failed")
        }
    }

    func setLevel(for channelID: MixerChannelID, level: FaderLevel) {
        storedChannels = storedChannels.map { channel in
            guard channel.id == channelID else {
                return channel
            }
            return MixerChannelState(id: channel.id, level: level)
        }

        guard channelID == .mainLr, let midiChannel else {
            return
        }

        Task {
            do {
                try await sendNRPN(
                    midiChannel: midiChannel,
                    targetChannel: 0x67,
                    parameterID: 0x17,
                    value: UInt8(level.toMIDIValue()),
                    index: 0x07
                )
            } catch {
                await handleConnectionFailure(
                    error,
                    endpoint: storedConnectionState.endpoint,
                    prefix: "Send failed"
                )
            }
        }
    }

    private func makeConnection(for endpoint: MixerEndpoint) async throws -> NWConnection {
        guard let port = NWEndpoint.Port(rawValue: UInt16(endpoint.port)) else {
            throw MixerTransportError.invalidPort(endpoint.port)
        }

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        let nwConnection = NWConnection(host: NWEndpoint.Host(endpoint.host), port: port, using: parameters)

        return try await withCheckedThrowingContinuation { continuation in
            let startState = ConnectionStartState()

            nwConnection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if startState.markResumed() {
                        continuation.resume(returning: nwConnection)
                    }
                case .failed(let error):
                    Task { @MainActor in
                        guard let self else { return }
                        if startState.markResumed() {
                            continuation.resume(throwing: error)
                        } else {
                            await self.handleConnectionFailure(error, endpoint: endpoint, prefix: "Connection lost")
                        }
                    }
                case .cancelled:
                    if startState.markResumed() {
                        continuation.resume(throwing: MixerTransportError.cancelledBeforeReady)
                    }
                default:
                    break
                }
            }

            nwConnection.start(queue: connectionQueue)
        }
    }

    private func startReceiving(on nwConnection: NWConnection, endpoint: MixerEndpoint) {
        nwConnection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            Task { @MainActor in
                if let error {
                    await self.handleConnectionFailure(error, endpoint: endpoint, prefix: "Connection lost")
                    return
                }

                if let data, !data.isEmpty {
                    self.byteBuffer.append(contentsOf: data)
                    self.processBufferedMessages(endpoint: endpoint)
                }

                if isComplete {
                    await self.handleConnectionFailure(
                        MixerTransportError.connectionClosed,
                        endpoint: endpoint,
                        prefix: "Connection lost"
                    )
                    return
                }

                if self.connection === nwConnection {
                    self.startReceiving(on: nwConnection, endpoint: endpoint)
                }
            }
        }
    }

    private func processBufferedMessages(endpoint: MixerEndpoint) {
        while let firstByte = byteBuffer.first {
            switch firstByte {
            case 0xFE:
                byteBuffer.removeFirst()
            case 0xF0:
                guard let endIndex = byteBuffer.firstIndex(of: 0xF7) else {
                    return
                }
                let sysex = Array(byteBuffer[...endIndex])
                byteBuffer.removeSubrange(...endIndex)
                handleSysEx(sysex, endpoint: endpoint)
            case 0xB0 ... 0xBF:
                guard byteBuffer.count >= 3 else {
                    return
                }
                let status = byteBuffer[0]
                let controller = byteBuffer[1]
                let value = byteBuffer[2]
                byteBuffer.removeFirst(3)
                handleControlChange(status: status, controller: controller, value: value)
            default:
                byteBuffer.removeFirst()
            }
        }
    }

    private func startActiveSensing() {
        activeSenseTask?.cancel()
        activeSenseTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                do {
                    try await self.sendBytes([0xFE])
                } catch {
                    await self.handleConnectionFailure(
                        error,
                        endpoint: self.storedConnectionState.endpoint,
                        prefix: "Connection lost"
                    )
                    return
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func sendSystemStateRequest() async throws {
        try await sendBytes([0xF0, 0x00, 0x00, 0x1A, 0x50, 0x11, 0x01, 0x00, 0x7F, 0x10, 0x01, 0xF7])
    }

    private func sendNRPN(
        midiChannel: UInt8,
        targetChannel: UInt8,
        parameterID: UInt8,
        value: UInt8,
        index: UInt8
    ) async throws {
        let status = 0xB0 | midiChannel
        try await sendBytes([
            status, 0x63, targetChannel,
            status, 0x62, parameterID,
            status, 0x06, value,
            status, 0x26, index
        ])
    }

    private func sendRemoteShutdown(midiChannel: UInt8) async throws {
        let status = 0xB0 | midiChannel
        try await sendBytes([
            status, 0x63, 0x00,
            status, 0x62, 0x5F,
            status, 0x06, 0x00,
            status, 0x26, 0x00
        ])
    }

    private func sendBytes(_ bytes: [UInt8]) async throws {
        guard let connection else {
            throw MixerTransportError.notConnected
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: Data(bytes), completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func handleSysEx(_ bytes: [UInt8], endpoint: MixerEndpoint) {
        guard bytes.count >= 10 else {
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
            return
        }

        let receivedMIDIChannel = bytes[8] & 0x0F
        let command = bytes[9] & 0x7F

        guard command == 0x11 else {
            return
        }

        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        midiChannel = receivedMIDIChannel
        storedConnectionState = MixerConnectionState(
            phase: .connected,
            message: "Connected to \(endpoint.host):\(endpoint.port) on MIDI channel \(Int(receivedMIDIChannel) + 1)",
            endpoint: endpoint
        )
    }

    private func startConnectionTimeout(for endpoint: MixerEndpoint) {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: connectionTimeout)

            guard let self, !Task.isCancelled else {
                return
            }

            guard self.connectionState.phase == .connecting else {
                return
            }

            await self.handleConnectionFailure(
                MixerTransportError.connectionTimedOut(seconds: Int(connectionTimeout.components.seconds)),
                endpoint: endpoint,
                prefix: "Connection timed out"
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
            if nrpnState.channel == 0x67,
               nrpnState.parameterID == 0x17,
               value == 0x07,
               let dataMSB = nrpnState.dataMSB
            {
                let level = FaderLevel(normalized: Double(dataMSB) / 127)
                storedChannels = storedChannels.map { channel in
                    guard channel.id == .mainLr else {
                        return channel
                    }
                    return MixerChannelState(id: channel.id, level: level)
                }
            }
            nrpnState.clear()
        default:
            break
        }
    }

    private func disconnectTransport(updateState: Bool, intentional: Bool) async {
        isIntentionalDisconnect = intentional
        activeSenseTask?.cancel()
        activeSenseTask = nil
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        midiChannel = nil
        byteBuffer.removeAll(keepingCapacity: false)
        nrpnState.clear()

        if updateState {
            storedConnectionState = MixerConnectionState(
                phase: .disconnected,
                message: "Disconnected",
                endpoint: nil
            )
        }
    }

    private func handleConnectionFailure(
        _ error: Error,
        endpoint: MixerEndpoint?,
        prefix: String
    ) async {
        if isIntentionalDisconnect {
            return
        }

        await disconnectTransport(updateState: false, intentional: true)
        storedConnectionState = MixerConnectionState(
            phase: .error,
            message: formattedErrorMessage(for: error, prefix: prefix),
            endpoint: endpoint
        )
    }

    private func formattedErrorMessage(for error: Error, prefix: String) -> String {
        let rawMessage = error.localizedDescription
        let loweredMessage = rawMessage.lowercased()

        if loweredMessage.contains("connection reset by peer") {
            return "\(prefix): \(rawMessage)\nAnother client may already be connected to the mixer."
        }

        return "\(prefix): \(rawMessage)"
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

private final class ConnectionStartState: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    nonisolated func markResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !resumed else {
            return false
        }

        resumed = true
        return true
    }
}

private enum MixerTransportError: LocalizedError {
    case invalidPort(Int)
    case cancelledBeforeReady
    case notConnected
    case connectionClosed
    case connectionTimedOut(seconds: Int)

    var errorDescription: String? {
        switch self {
        case .invalidPort(let port):
            "Invalid mixer port \(port)"
        case .cancelledBeforeReady:
            "Connection cancelled before ready"
        case .notConnected:
            "Not connected"
        case .connectionClosed:
            "Connection closed by mixer"
        case .connectionTimedOut(let seconds):
            "No response within \(seconds) seconds"
        }
    }
}

private extension FaderLevel {
    func toMIDIValue() -> Int {
        let clampedValue = min(max(normalized, 0), 1)
        return Int((clampedValue * 127).rounded(.towardZero))
    }
}
