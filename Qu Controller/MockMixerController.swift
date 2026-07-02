//
//  MockMixerController.swift
//  Qu Controller
//

import Combine
import Foundation

@MainActor
final class MockMixerController: MixerController {
    @Published private var storedChannels: [MixerChannelState] = [
        MixerChannelState(id: .mainLr, level: FaderLevel(normalized: 0.72))
    ]
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

    var channelsPublisher: AnyPublisher<[MixerChannelState], Never> {
        $storedChannels.eraseToAnyPublisher()
    }

    var connectionStatePublisher: AnyPublisher<MixerConnectionState, Never> {
        $storedConnectionState.eraseToAnyPublisher()
    }

    func connect(to endpoint: MixerEndpoint) async {
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
            return MixerChannelState(id: channel.id, level: level)
        }
    }
}
