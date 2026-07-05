//
//  MockMixerController.swift
//  Qu Controller
//

import Combine
import Foundation

@MainActor
final class MockMixerController: MixerController {
    let transportKind: MixerTransportKind = .network

    @Published private var storedChannels: [MixerChannelState] = MixerChannelID.selectableChannels.enumerated().map { index, channelID in
        let normalized = min(0.18 + (Double(index) * 0.04), 0.88)
        let customName: String? = switch channelID {
        case .ch1: "Kick"
        case .ch2: "Snare"
        case .ch3: "Bass"
        case .ch4: "Guitar"
        case .mainLr: "Main LR"
        default: nil
        }

        return MixerChannelState(
            id: channelID,
            level: FaderLevel(normalized: normalized),
            isMuted: false,
            hasSignal: channelID == .ch1 || channelID == .ch2 || channelID == .mainLr,
            customName: customName
        )
    }
    @Published private var storedConnectionState = MixerConnectionState(
        phase: .disconnected,
        message: "Mock controller disconnected",
        endpoint: nil
    )

    var channels: [MixerChannelState] {
        storedChannels
    }

    var connectionState: MixerConnectionState {
        storedConnectionState
    }

    var connectionOptions: [MixerConnectionOption] {
        []
    }

    var channelsPublisher: AnyPublisher<[MixerChannelState], Never> {
        $storedChannels.eraseToAnyPublisher()
    }

    var connectionStatePublisher: AnyPublisher<MixerConnectionState, Never> {
        $storedConnectionState.eraseToAnyPublisher()
    }

    var connectionOptionsPublisher: AnyPublisher<[MixerConnectionOption], Never> {
        Empty(completeImmediately: false).eraseToAnyPublisher()
    }

    func connect(to target: MixerConnectionTarget) async {
        let endpoint: MixerEndpoint
        switch target {
        case .network(let resolvedEndpoint):
            endpoint = resolvedEndpoint
        case .usbMIDI:
            endpoint = MixerEndpoint(host: "USB MIDI")
        }

        storedConnectionState = MixerConnectionState(
            phase: .connecting,
            message: "Connecting to \(endpoint.host):\(endpoint.port)",
            endpoint: endpoint
        )

        try? await Task.sleep(for: .milliseconds(250))

        storedConnectionState = MixerConnectionState(
            phase: .connected,
            message: "Mock controller connected",
            endpoint: endpoint
        )
    }

    func disconnect() {
        storedConnectionState = MixerConnectionState(
            phase: .disconnected,
            message: "Mock controller disconnected",
            endpoint: nil
        )
    }

    func shutdownMixer() async {
        storedConnectionState = MixerConnectionState(
            phase: .disconnected,
            message: "Mock shutdown complete",
            endpoint: nil
        )
    }

    func setLevel(for channelID: MixerChannelID, level: FaderLevel) {
        storedChannels = storedChannels.map { channel in
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

    func setMute(for channelID: MixerChannelID, isMuted: Bool) {
        storedChannels = storedChannels.map { channel in
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

    func setSignalMonitoringEnabled(_ isEnabled: Bool) {
        guard !isEnabled else {
            return
        }

        storedChannels = storedChannels.map { channel in
            MixerChannelState(
                id: channel.id,
                level: channel.level,
                isMuted: channel.isMuted,
                hasSignal: false,
                customName: channel.customName
            )
        }
    }

    func refreshConnectionOptions() {}
}
