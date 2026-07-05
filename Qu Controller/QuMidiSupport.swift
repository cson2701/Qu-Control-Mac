import Foundation

enum MixerTransportError: LocalizedError {
    case invalidPort(Int)
    case cancelledBeforeReady
    case notConnected
    case connectionClosed
    case connectionTimedOut(seconds: Int)
    case unsupportedTarget
    case missingUSBMIDIDevice
    case unavailableUSBMIDIDevice(String)
    case missingUSBMIDISource(String)
    case midiSetupFailed(String)

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
        case .unsupportedTarget:
            "Unsupported connection target"
        case .missingUSBMIDIDevice:
            "Choose a USB MIDI device first"
        case .unavailableUSBMIDIDevice(let name):
            "USB MIDI device “\(name)” is no longer available"
        case .missingUSBMIDISource(let name):
            "USB MIDI device “\(name)” does not expose an input source"
        case .midiSetupFailed(let detail):
            detail
        }
    }
}

enum QuMidiControllerSupport {
    static func makeInitialChannels() -> [MixerChannelState] {
        MixerChannelID.selectableChannels.map { channelID in
            MixerChannelState(
                id: channelID,
                level: FaderLevel(normalized: channelID == .mainLr ? 0.72 : 0),
                isMuted: false,
                hasSignal: false,
                customName: nil
            )
        }
    }

    static func setLevel(
        _ channels: [MixerChannelState],
        channelID: MixerChannelID,
        level: FaderLevel
    ) -> [MixerChannelState] {
        channels.map { channel in
            guard channel.id == channelID else {
                return channel
            }

            return MixerChannelState(
                id: channel.id,
                level: level,
                isMuted: channel.isMuted,
                hasSignal: channel.hasSignal,
                customName: channel.customName
            )
        }
    }

    static func setMute(
        _ channels: [MixerChannelState],
        channelID: MixerChannelID,
        isMuted: Bool
    ) -> [MixerChannelState] {
        channels.map { channel in
            guard channel.id == channelID else {
                return channel
            }

            return MixerChannelState(
                id: channel.id,
                level: channel.level,
                isMuted: isMuted,
                hasSignal: channel.hasSignal,
                customName: channel.customName
            )
        }
    }

    static func setCustomName(
        _ channels: [MixerChannelState],
        channelID: MixerChannelID,
        customName: String?
    ) -> [MixerChannelState] {
        channels.map { channel in
            guard channel.id == channelID else {
                return channel
            }

            return MixerChannelState(
                id: channel.id,
                level: channel.level,
                isMuted: channel.isMuted,
                hasSignal: channel.hasSignal,
                customName: customName
            )
        }
    }

    static func clearTransientState(_ channels: [MixerChannelState]) -> [MixerChannelState] {
        channels.map { channel in
            MixerChannelState(
                id: channel.id,
                level: channel.level,
                isMuted: false,
                hasSignal: false,
                customName: channel.customName
            )
        }
    }

    static func applySignalStates(
        _ channels: [MixerChannelState],
        signalStates: [MixerChannelID: Bool]
    ) -> [MixerChannelState] {
        channels.map { channel in
            MixerChannelState(
                id: channel.id,
                level: channel.level,
                isMuted: channel.isMuted,
                hasSignal: signalStates[channel.id] ?? false,
                customName: channel.customName
            )
        }
    }

    static func sanitizedChannelName(from nameBytes: [UInt8]) -> String? {
        let filteredBytes = nameBytes.filter { byte in
            byte != 0x00 && byte >= 0x20 && byte <= 0x7E
        }

        guard let decodedName = String(bytes: filteredBytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !decodedName.isEmpty else {
            return nil
        }

        return decodedName
    }
}

enum QuMidiMessageEncoder {
    static func systemStateRequest() -> [UInt8] {
        [0xF0, 0x00, 0x00, 0x1A, 0x50, 0x11, 0x01, 0x00, 0x7F, 0x10, 0x01, 0xF7]
    }

    static func channelNameRequest(midiChannel: UInt8, channelID: MixerChannelID) -> [UInt8] {
        [0xF0, 0x00, 0x00, 0x1A, 0x50, 0x11, 0x01, 0x00, midiChannel, 0x01, channelID.midiChannelCode, 0xF7]
    }

    static func meterRequest(requestChannel: UInt8, isEnabled: Bool) -> [UInt8] {
        [0xF0, 0x00, 0x00, 0x1A, 0x50, 0x11, 0x01, 0x00, requestChannel, 0x12, isEnabled ? 0x01 : 0x00, 0xF7]
    }

    static func nrpn(
        midiChannel: UInt8,
        targetChannel: UInt8,
        parameterID: UInt8,
        value: UInt8,
        index: UInt8
    ) -> [UInt8] {
        let status = 0xB0 | midiChannel
        return [
            status, 0x63, targetChannel,
            status, 0x62, parameterID,
            status, 0x06, value,
            status, 0x26, index
        ]
    }

    static func mute(midiChannel: UInt8, targetChannel: UInt8, isMuted: Bool) -> [UInt8] {
        let status = 0x90 | midiChannel
        return [
            status, targetChannel, isMuted ? 0x7F : 0x3F,
            status, targetChannel, 0x00
        ]
    }

    static func remoteShutdown(midiChannel: UInt8) -> [UInt8] {
        let status = 0xB0 | midiChannel
        return [
            status, 0x63, 0x00,
            status, 0x62, 0x5F,
            status, 0x06, 0x00,
            status, 0x26, 0x00
        ]
    }
}

extension FaderLevel {
    func toMIDIValue() -> Int {
        let clampedValue = min(max(normalized, 0), 1)
        return Int((clampedValue * 127).rounded(.towardZero))
    }
}

enum QuMixerModel {
    case qu16
    case qu24
    case qu32Family

    init?(boxID: UInt8) {
        switch boxID {
        case 1:
            self = .qu16
        case 2:
            self = .qu24
        case 3, 4, 5:
            self = .qu32Family
        default:
            return nil
        }
    }
}

enum QuSignalActivityDecoder {
    static let silenceFloor = -128.0

    fileprivate static let monoInputBlockSize = 10
    fileprivate static let stereoInputBlockSize = 20
    fileprivate static let monoMixBlockSize = 10
    fileprivate static let stereoMixBlockSize = 20
    fileprivate static let stereoMonitorBlockSize = 78
    private static let monoInputSignalOffsets = [0, 1, 2, 3, 6]
    private static let lrStereoMixSignalOffsets = [5, 15]
    private static let mainMonitorSignalOffsets = [5, 6, 7, 8, 11, 12]

    static func decodeSignalLevels(
        from7BitPayload payload: [UInt8],
        mixerModel: QuMixerModel?
    ) -> [MixerChannelID: Double]? {
        let bytes = unpack7Bitized(payload)
        guard !bytes.isEmpty else {
            return nil
        }

        let meterValues = decodeMeterValues(from: bytes)
        guard let layout = resolveLayout(for: meterValues.count, mixerModel: mixerModel) else {
            return nil
        }

        var result: [MixerChannelID: Double] = [:]

        for channelIndex in 0 ..< 16 {
            let blockStart = channelIndex * monoInputBlockSize
            let blockEnd = blockStart + monoInputBlockSize
            guard blockEnd <= meterValues.count else {
                break
            }

            let channelID = MixerChannelID.selectableChannels[channelIndex]
            result[channelID] = monoInputSignalOffsets
                .compactMap { offset in
                    let meterIndex = blockStart + offset
                    return meterIndex < blockEnd ? meterValues[meterIndex] : nil
                }
                .max() ?? silenceFloor
        }

        let mainLRCandidates =
            mainMonitorSignalOffsets.compactMap { offset -> Double? in
                let meterIndex = layout.monitorBlockStartOffset + offset
                guard meterIndex < meterValues.count else {
                    return nil
                }
                return meterValues[meterIndex]
            } +
            lrStereoMixSignalOffsets.compactMap { offset -> Double? in
                let meterIndex = layout.lrStereoMixBlockStartOffset + offset
                guard meterIndex < meterValues.count else {
                    return nil
                }
                return meterValues[meterIndex]
            }

        result[.mainLr] = mainLRCandidates.max() ?? silenceFloor
        return result
    }

    private static func unpack7Bitized(_ payload: [UInt8]) -> [UInt8] {
        var unpacked: [UInt8] = []
        var index = 0

        while index < payload.count {
            let header = payload[index]
            index += 1

            let remaining = payload.count - index
            let chunkSize = min(7, remaining)
            guard chunkSize > 0 else {
                break
            }

            for bitIndex in 0 ..< chunkSize {
                let lowBits = payload[index + bitIndex] & 0x7F
                let highBit = ((header >> (6 - bitIndex)) & 0x01) << 7
                unpacked.append(lowBits | highBit)
            }

            index += chunkSize
        }

        return unpacked
    }

    private static func decodeMeterValues(from bytes: [UInt8]) -> [Double] {
        var values: [Double] = []
        values.reserveCapacity(bytes.count / 2)

        var index = 0
        while index + 1 < bytes.count {
            let rawValue = UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
            let signedValue = Int16(bitPattern: rawValue &- 0x8000)
            values.append(Double(signedValue) / 256.0)
            index += 2
        }

        return values
    }

    private static func resolveLayout(for meterCount: Int, mixerModel: QuMixerModel?) -> QuSignalLayout? {
        if let mixerModel {
            let preferredLayout = QuSignalLayout(for: mixerModel)
            if meterCount >= preferredLayout.minimumMeterCount {
                return preferredLayout
            }
        }

        let layouts = [
            QuSignalLayout(for: .qu16),
            QuSignalLayout(for: .qu24),
            QuSignalLayout(for: .qu32Family)
        ]

        return layouts
            .filter { meterCount >= $0.minimumMeterCount }
            .min { abs($0.minimumMeterCount - meterCount) < abs($1.minimumMeterCount - meterCount) }
    }
}

private struct QuSignalLayout {
    let minimumMeterCount: Int
    let lrStereoMixBlockStartOffset: Int
    let monitorBlockStartOffset: Int

    init(for mixerModel: QuMixerModel) {
        switch mixerModel {
        case .qu16:
            lrStereoMixBlockStartOffset = (16 * QuSignalActivityDecoder.monoInputBlockSize) + 80 + (3 * QuSignalActivityDecoder.stereoInputBlockSize) + 20 + (4 * QuSignalActivityDecoder.monoMixBlockSize) + (3 * QuSignalActivityDecoder.stereoMixBlockSize)
            minimumMeterCount = (16 * QuSignalActivityDecoder.monoInputBlockSize) + 80 + (3 * QuSignalActivityDecoder.stereoInputBlockSize) + 20 + (4 * QuSignalActivityDecoder.monoMixBlockSize) + (4 * QuSignalActivityDecoder.stereoMixBlockSize) + QuSignalActivityDecoder.stereoMonitorBlockSize + (4 * 18)
            monitorBlockStartOffset = (16 * QuSignalActivityDecoder.monoInputBlockSize) + 80 + (3 * QuSignalActivityDecoder.stereoInputBlockSize) + 20 + (4 * QuSignalActivityDecoder.monoMixBlockSize) + (4 * QuSignalActivityDecoder.stereoMixBlockSize)
        case .qu24:
            lrStereoMixBlockStartOffset = (24 * QuSignalActivityDecoder.monoInputBlockSize) + (3 * QuSignalActivityDecoder.stereoInputBlockSize) + 180 + (4 * QuSignalActivityDecoder.monoMixBlockSize) + (3 * QuSignalActivityDecoder.stereoMixBlockSize)
            minimumMeterCount = (24 * QuSignalActivityDecoder.monoInputBlockSize) + (3 * QuSignalActivityDecoder.stereoInputBlockSize) + 180 + (4 * QuSignalActivityDecoder.monoMixBlockSize) + (4 * QuSignalActivityDecoder.stereoMixBlockSize) + (2 * QuSignalActivityDecoder.stereoMixBlockSize) + (2 * QuSignalActivityDecoder.stereoMixBlockSize) + QuSignalActivityDecoder.stereoMonitorBlockSize + (4 * 18)
            monitorBlockStartOffset = (24 * QuSignalActivityDecoder.monoInputBlockSize) + (3 * QuSignalActivityDecoder.stereoInputBlockSize) + 180 + (4 * QuSignalActivityDecoder.monoMixBlockSize) + (4 * QuSignalActivityDecoder.stereoMixBlockSize) + (2 * QuSignalActivityDecoder.stereoMixBlockSize) + (2 * QuSignalActivityDecoder.stereoMixBlockSize)
        case .qu32Family:
            lrStereoMixBlockStartOffset = (24 * QuSignalActivityDecoder.monoInputBlockSize) + (3 * QuSignalActivityDecoder.stereoInputBlockSize) + 20 + (8 * QuSignalActivityDecoder.monoInputBlockSize) + (4 * QuSignalActivityDecoder.monoMixBlockSize) + (3 * QuSignalActivityDecoder.stereoMixBlockSize)
            minimumMeterCount = (24 * QuSignalActivityDecoder.monoInputBlockSize) + (3 * QuSignalActivityDecoder.stereoInputBlockSize) + 20 + (8 * QuSignalActivityDecoder.monoInputBlockSize) + (4 * QuSignalActivityDecoder.monoMixBlockSize) + (4 * QuSignalActivityDecoder.stereoMixBlockSize) + (4 * QuSignalActivityDecoder.stereoMixBlockSize) + (2 * QuSignalActivityDecoder.stereoMixBlockSize) + QuSignalActivityDecoder.stereoMonitorBlockSize + (4 * 18)
            monitorBlockStartOffset = (24 * QuSignalActivityDecoder.monoInputBlockSize) + (3 * QuSignalActivityDecoder.stereoInputBlockSize) + 20 + (8 * QuSignalActivityDecoder.monoInputBlockSize) + (4 * QuSignalActivityDecoder.monoMixBlockSize) + (4 * QuSignalActivityDecoder.stereoMixBlockSize) + (4 * QuSignalActivityDecoder.stereoMixBlockSize) + (2 * QuSignalActivityDecoder.stereoMixBlockSize)
        }
    }
}
