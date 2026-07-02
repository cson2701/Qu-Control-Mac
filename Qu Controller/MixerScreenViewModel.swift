//
//  MixerScreenViewModel.swift
//  Qu Controller
//

import Combine
import Foundation

@MainActor
final class MixerScreenViewModel: ObservableObject {
    private enum StorageKey {
        static let layoutPreferences = "mixer.layoutPreferences"
    }

    @Published var host: String
    @Published private(set) var channels: [MixerChannelState]
    @Published private(set) var connectionState: MixerConnectionState
    @Published private(set) var layoutPreferences: MixerLayoutPreferences

    private let controller: MixerController
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(
        controller: MixerController,
        defaultEndpoint: MixerEndpoint = MixerEndpoint(host: "192.168.4.198"),
        userDefaults: UserDefaults = .standard
    ) {
        self.controller = controller
        self.userDefaults = userDefaults
        host = defaultEndpoint.host
        channels = controller.channels
        connectionState = controller.connectionState
        layoutPreferences = Self.loadLayoutPreferences(from: userDefaults)

        controller.channelsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$channels)

        controller.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
    }

    var visibleMainScreenChannels: [MixerChannelState] {
        visibleChannels(for: .mainScreen)
    }

    var menuBarChannels: [MixerChannelState] {
        visibleChannels(for: .menuBar)
    }

    var selectableChannels: [MixerChannelState] {
        displayChannels
    }

    private var displayChannels: [MixerChannelState] {
        guard connectionState.phase == .connected else {
            return channels.map { channel in
                MixerChannelState(
                    id: channel.id,
                    level: FaderLevel(normalized: 0),
                    customName: channel.customName
                )
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

    func isChannelVisible(_ channelID: MixerChannelID, on surface: MixerLayoutSurface) -> Bool {
        layoutPreferences.channelIDs(for: surface).contains(channelID)
    }

    func setChannelVisibility(_ isVisible: Bool, for channelID: MixerChannelID, on surface: MixerLayoutSurface) {
        layoutPreferences.setChannelVisibility(isVisible, for: channelID, surface: surface)
        persistLayoutPreferences()
        objectWillChange.send()
    }

    func shutdownMixer() {
        Task {
            await controller.shutdownMixer()
        }
    }

    private func visibleChannels(for surface: MixerLayoutSurface) -> [MixerChannelState] {
        let visibleIDs = layoutPreferences.channelIDs(for: surface)
        return displayChannels.filter { visibleIDs.contains($0.id) }
            .sorted { lhs, rhs in
                visibleIDs.firstIndex(of: lhs.id) ?? 0 < visibleIDs.firstIndex(of: rhs.id) ?? 0
            }
    }

    private func persistLayoutPreferences() {
        guard let data = try? JSONEncoder().encode(layoutPreferences) else {
            return
        }

        userDefaults.set(data, forKey: StorageKey.layoutPreferences)
    }

    private static func loadLayoutPreferences(from userDefaults: UserDefaults) -> MixerLayoutPreferences {
        guard let data = userDefaults.data(forKey: StorageKey.layoutPreferences),
              let preferences = try? JSONDecoder().decode(MixerLayoutPreferences.self, from: data) else {
            return .default
        }

        return preferences
    }
}
