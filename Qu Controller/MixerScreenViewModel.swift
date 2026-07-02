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
        static let lastSuccessfulHost = "mixer.lastSuccessfulHost"
    }

    enum DiscoveryState: Equatable {
        case idle
        case scanning
        case found(String)
        case unavailable
    }

    @Published var host: String
    @Published private(set) var channels: [MixerChannelState]
    @Published private(set) var connectionState: MixerConnectionState
    @Published private(set) var layoutPreferences: MixerLayoutPreferences
    @Published private(set) var discoveryState: DiscoveryState = .idle

    private let controller: MixerController
    private let defaultHost: String
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var discoveryTask: Task<Void, Never>?

    init(
        controller: MixerController,
        defaultEndpoint: MixerEndpoint = MixerEndpoint(host: "192.168.4.120"),
        userDefaults: UserDefaults = .standard
    ) {
        self.controller = controller
        self.defaultHost = defaultEndpoint.host
        self.userDefaults = userDefaults
        host = Self.loadLastSuccessfulHost(from: userDefaults) ?? defaultEndpoint.host
        channels = controller.channels
        connectionState = controller.connectionState
        layoutPreferences = Self.loadLayoutPreferences(from: userDefaults)

        controller.channelsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$channels)

        controller.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        controller.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleConnectionStateChange(state)
            }
            .store(in: &cancellables)

        startAutoDiscoveryIfNeeded()
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

    var statusMessage: String {
        switch discoveryState {
        case .scanning where connectionState.phase == .disconnected:
            "Scanning local network for a Qu mixer..."
        case .found(let discoveredHost) where connectionState.phase == .disconnected:
            "Discovered mixer at \(discoveredHost)"
        case .unavailable where connectionState.phase == .disconnected:
            "No mixer discovered automatically. Enter an IP or connect manually."
        default:
            connectionState.message
        }
    }

    var isScanningForMixer: Bool {
        discoveryState == .scanning && connectionState.phase == .disconnected
    }

    var isAutoScanAvailable: Bool {
        controller is QuNetworkMixerController && connectionState.phase == .disconnected && !isScanningForMixer
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

    func scanForMixer() {
        guard controller is QuNetworkMixerController, !isScanningForMixer else {
            return
        }

        startDiscovery()
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

    private static func loadLastSuccessfulHost(from userDefaults: UserDefaults) -> String? {
        guard let host = userDefaults.string(forKey: StorageKey.lastSuccessfulHost),
              !host.isEmpty else {
            return nil
        }

        return host
    }

    private func startAutoDiscoveryIfNeeded() {
        guard controller is QuNetworkMixerController else {
            return
        }

        startDiscovery()
    }

    private func startDiscovery() {
        discoveryTask?.cancel()
        discoveryState = .scanning

        discoveryTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let discovery = QuMixerDiscovery()
            if let discoveredHost = await discovery.discoverMixer() {
                if self.host == self.defaultHost {
                    self.host = discoveredHost
                }
                self.discoveryState = .found(discoveredHost)
            } else {
                self.discoveryState = .unavailable
            }
        }
    }

    private func handleConnectionStateChange(_ state: MixerConnectionState) {
        guard state.phase == .connected else {
            return
        }

        discoveryTask?.cancel()
        discoveryTask = nil
        discoveryState = .idle

        guard let successfulHost = state.endpoint?.host,
              !successfulHost.isEmpty else {
            return
        }

        if host != successfulHost {
            host = successfulHost
        }

        userDefaults.set(successfulHost, forKey: StorageKey.lastSuccessfulHost)
    }
}
