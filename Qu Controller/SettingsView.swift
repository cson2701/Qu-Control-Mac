import AppKit
import SwiftUI

struct SettingsView: View {
    private enum Tab: Hashable {
        case connection
        case relay
        case appBehavior
        case mainWindow
        case menuBar
    }

    @ObservedObject var viewModel: MixerScreenViewModel
    let onSetShowMenuBarIcon: (Bool) -> Void
    @State private var selectedTab: Tab = .connection
    @State private var isShowingRelayPortResetConfirmation = false

    private var windowSize: CGSize {
        switch selectedTab {
        case .connection:
            CGSize(width: 500, height: 240)
        case .relay:
            CGSize(width: 500, height: 520)
        case .appBehavior:
            CGSize(width: 500, height: 580)
        case .mainWindow, .menuBar:
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

            SettingsPane(title: "Main Window", subtitle: "Channels visible in the main mixer window.") {
                ChannelSettingsList(surface: .mainScreen, viewModel: viewModel)
            }
            .tag(Tab.mainWindow)
            .tabItem {
                Label("Main Window", systemImage: "macwindow")
            }

            SettingsPane(title: "Menu Bar", subtitle: "Channels visible in the menu bar window.") {
                ChannelSettingsList(surface: .menuBar, viewModel: viewModel)
            }
            .tag(Tab.menuBar)
            .tabItem {
                Label("Menu Bar", systemImage: "menubar.rectangle")
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
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

    private var channelsTitle: String {
        switch surface {
        case .mainScreen:
            "Choose which channels are visible in the main window."
        case .menuBar:
            "Choose which channels are visible in the menu bar window."
        }
    }

    var body: some View {
        Form {
            Text(channelsTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(viewModel.selectableChannels) { channel in
                Toggle(
                    channel.displayName,
                    isOn: Binding(
                        get: { viewModel.isChannelVisible(channel.id, on: surface) },
                        set: { viewModel.setChannelVisibility($0, for: channel.id, on: surface) }
                    )
                )
            }
        }
        .formStyle(.grouped)
    }
}
