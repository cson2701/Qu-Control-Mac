//
//  MixerScreenViewModel.swift
//  Qu Controller
//

import Combine
import Foundation

@MainActor
final class MixerScreenViewModel: ObservableObject {
    @Published var host: String
    @Published private(set) var channels: [MixerChannelState]
    @Published private(set) var connectionState: MixerConnectionState

    private let controller: MixerController
    private var cancellables = Set<AnyCancellable>()

    init(
        controller: MixerController,
        defaultEndpoint: MixerEndpoint = MixerEndpoint(host: "192.168.4.198")
    ) {
        self.controller = controller
        host = defaultEndpoint.host
        channels = controller.channels
        connectionState = controller.connectionState

        controller.channelsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$channels)

        controller.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
    }

    var mainLrChannel: MixerChannelState? {
        displayChannels.first(where: { $0.id == .mainLr })
    }

    var menuBarChannels: [MixerChannelState] {
        displayChannels
    }

    private var displayChannels: [MixerChannelState] {
        guard connectionState.phase == .connected else {
            return channels.map { channel in
                MixerChannelState(id: channel.id, level: FaderLevel(normalized: 0))
            }
        }

        return channels
    }

    var buttonTitle: String {
        switch connectionState.phase {
        case .connected, .connecting:
            "Disconnect"
        case .disconnected, .error:
            "Connect"
        }
    }

    var isFaderInteractive: Bool {
        connectionState.phase == .connected
    }

    var isShutdownAvailable: Bool {
        connectionState.phase == .connected
    }

    func toggleConnection() {
        switch connectionState.phase {
        case .connected, .connecting:
            controller.disconnect()
        case .disconnected, .error:
            Task {
                await controller.connect(to: MixerEndpoint(host: host))
            }
        }
    }

    func setLevel(_ level: FaderLevel, for channelID: MixerChannelID) {
        controller.setLevel(for: channelID, level: level)
    }

    func shutdownMixer() {
        Task {
            await controller.shutdownMixer()
        }
    }
}
