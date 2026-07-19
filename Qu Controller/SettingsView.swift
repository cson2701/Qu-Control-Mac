import AppKit
import SwiftUI

struct SettingsView: View {
    private enum Tab: Hashable {
        case connection
        case relay
        case appBehavior
        case channels
    }

    @ObservedObject var viewModel: MixerScreenViewModel
    let onSetShowMenuBarIcon: (Bool) -> Void
    @State private var selectedTab: Tab = .connection
    @State private var selectedChannelSurface: MixerLayoutSurface = .mainScreen
    @State private var isShowingRelayPortResetConfirmation = false

    private var windowSize: CGSize {
        switch selectedTab {
        case .connection:
            CGSize(width: 500, height: 240)
        case .relay:
            CGSize(width: 500, height: 520)
        case .appBehavior:
            CGSize(width: 500, height: 580)
        case .channels:
            CGSize(width: 500, height: 600)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SettingsPane(title: "Connection", subtitle: "Connection and discovery behavior.") {
                Form {
                    Section {
                        Toggle(
                            "Automatically connect after mixer is found",
                            isOn: Binding(
                                get: { viewModel.autoConnectAfterDiscovery },
                                set: viewModel.setAutoConnectAfterDiscovery(_:)
                            )
                        )
                    } footer: {
                        Text("Discovery tries the last successfully connected IP first, then falls back to subnet scanning.")
                    }
                }
                .formStyle(.grouped)
            }
            .tag(Tab.connection)
            .tabItem {
                Label("Connection", systemImage: "network")
            }

            SettingsPane(title: "Relay", subtitle: "Share this app's mixer connection with LAN clients.") {
                Form {
                    Section {
                        Toggle(
                            "Enable relay",
                            isOn: Binding(
                                get: { viewModel.relayEnabled },
                                set: viewModel.setRelayEnabled(_:)
                            )
                        )

                        Toggle(
                            "Start relay automatically at launch",
                            isOn: Binding(
                                get: { viewModel.startRelayAtLaunch },
                                set: viewModel.setStartRelayAtLaunch(_:)
                            )
                        )
                        .disabled(!viewModel.relayEnabled)
                    }

                    Section {
                        LabeledContent("Port") {
                            TextField(
                                "",
                                value: Binding(
                                    get: { viewModel.relayPort },
                                    set: viewModel.setRelayPort(_:)
                                ),
                                format: .number.grouping(.never)
                            )
                            .accessibilityLabel("Relay port")
                            .frame(width: 100)
                        }
                    } header: {
                        Text("Listener")
                    } footer: {
                        if viewModel.relayPort != MixerScreenViewModel.defaultRelayPort {
                            HStack {
                                Spacer()

                                Button("Reset to Default") {
                                    isShowingRelayPortResetConfirmation = true
                                }
                                .foregroundStyle(.red)
                            }
                        }
                    }
                    .disabled(viewModel.relayEnabled)
                    .alert("Reset Relay Port?", isPresented: $isShowingRelayPortResetConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) {
                            viewModel.resetRelayPort()
                        }
                    } message: {
                        Text(
                            "This will reset the relay port to \(MixerScreenViewModel.defaultRelayPort). "
                                + "Update the port setting on other devices that connect to this relay."
                        )
                    }

                    Section {
                        LabeledContent("Relay status", value: viewModel.relayStatusMessage)

                        LabeledContent(
                            "Connected clients",
                            value: String(viewModel.relayConnectedClientCount)
                        )

                        if viewModel.relayNetworkAddresses.isEmpty {
                            LabeledContent("Wi-Fi", value: "Unavailable")
                        } else {
                            ForEach(viewModel.relayNetworkAddresses) { address in
                                let host = address.host

                                LabeledContent(address.interfaceLabel) {
                                    HStack(spacing: 8) {
                                        Text(host)
                                            .monospaced()
                                            .textSelection(.enabled)

                                        Button {
                                            copyToPasteboard(host)
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Copy relay endpoint")
                                        .accessibilityLabel("Copy \(address.interfaceLabel) relay endpoint")
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Status")
                    } footer: {
                        VStack(alignment: .leading, spacing: 6) {
                            if !viewModel.relayNetworkAddresses.isEmpty {
                                Text(
                                    viewModel.relayNetworkAddresses.count == 1
                                        ? "Use this Mac's LAN address on the client device."
                                        : "Use one of this Mac's LAN addresses on the client device."
                                )
                            }

                            Text("The relay accepts connections on all network interfaces and uses newline-delimited JSON without authentication or encryption.")
                        }
                    }
                }
                .formStyle(.grouped)
            }
            .tag(Tab.relay)
            .tabItem {
                Label("Relay", systemImage: "point.3.connected.trianglepath.dotted")
            }

            SettingsPane(title: "App Behavior", subtitle: "Launch and window behavior.") {
                Form {
                    Section("Launch") {
                        Toggle(
                            "Start on login",
                            isOn: Binding(
                                get: { viewModel.startAtLogin },
                                set: viewModel.setStartAtLogin(_:)
                            )
                        )
                    }

                    Section {
                        Toggle(
                            "Show menu bar icon",
                            isOn: Binding(
                                get: { viewModel.showMenuBarIcon },
                                set: onSetShowMenuBarIcon
                            )
                        )

                        if viewModel.showMenuBarIcon {
                            Toggle(
                                "Start hidden in the menu bar",
                                isOn: Binding(
                                    get: { viewModel.startHiddenInMenuBar },
                                    set: viewModel.setStartHiddenInMenuBar(_:)
                                )
                            )
                        }
                    } header: {
                        Text("Menu Bar")
                    } footer: {
                        Text("When the menu bar icon is hidden, Qu Controller stays available from the main app window and Settings.")
                    }

                    Section {
                        Toggle(
                            "Show signal indicators",
                            isOn: Binding(
                                get: { viewModel.showSignalIndicators },
                                set: viewModel.setShowSignalIndicators(_:)
                            )
                        )
                    } header: {
                        Text("Signal Indicators")
                    } footer: {
                        Text("Show green dots when channels are active.")
                    }

                    Section("Safety") {
                        Toggle(
                            "Confirm before shutting down",
                            isOn: Binding(
                                get: { viewModel.confirmBeforeShutdown },
                                set: viewModel.setConfirmBeforeShutdown(_:)
                            )
                        )
                    }
                }
                .formStyle(.grouped)
            }
            .tag(Tab.appBehavior)
            .tabItem {
                Label("App", systemImage: "app.badge")
            }

            if viewModel.connectionState.phase == .connected {
                SettingsPane(title: "Channels", subtitle: "Visibility and ordering for each mixer surface.") {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Surface", selection: $selectedChannelSurface) {
                            Text("Main Window")
                                .tag(MixerLayoutSurface.mainScreen)
                            Text("Menu Bar")
                                .tag(MixerLayoutSurface.menuBar)
                        }
                        .pickerStyle(.segmented)

                        ChannelSettingsList(surface: selectedChannelSurface, viewModel: viewModel)
                            .id(selectedChannelSurface)
                    }
                }
                .tag(Tab.channels)
                .tabItem {
                    Label("Channels", systemImage: "slider.horizontal.3")
                }
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .onChange(of: viewModel.connectionState.phase) { _, newPhase in
            if newPhase != .connected, selectedTab == .channels {
                selectedTab = .connection
            }
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private struct SettingsPane<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ChannelSettingsList: View {
    let surface: MixerLayoutSurface
    @ObservedObject var viewModel: MixerScreenViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Drag channels to change their order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                if viewModel.hasCustomChannelOrder(on: surface) {
                    Button("Reset Order") {
                        viewModel.resetChannelOrder(on: surface)
                    }
                    .controlSize(.small)
                }
            }

            List {
                ForEach(viewModel.movableSelectableChannels(for: surface)) { channel in
                    ChannelSettingsRow(
                        channel: channel,
                        surface: surface,
                        viewModel: viewModel
                    )
                }
                .onMove { offsets, destination in
                    viewModel.moveChannels(fromOffsets: offsets, toOffset: destination, on: surface)
                }

                if let mainLRChannel = viewModel.mainLRSelectableChannel(for: surface) {
                    ChannelSettingsRow(
                        channel: mainLRChannel,
                        surface: surface,
                        viewModel: viewModel
                    )
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            )
        }
    }
}

private struct ChannelSettingsRow: View {
    let channel: MixerChannelState
    let surface: MixerLayoutSurface
    @ObservedObject var viewModel: MixerScreenViewModel

    private var isMainLR: Bool {
        channel.id == .mainLr
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(channel.primaryDisplayName)
                    .lineLimit(1)

                if let secondaryDisplayName = channel.secondaryDisplayName {
                    Text(secondaryDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.isChannelVisible(channel.id, on: surface) },
                    set: { viewModel.setChannelVisibility($0, for: channel.id, on: surface) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(isMainLR)
        }
        .frame(minHeight: 36)
    }
}
