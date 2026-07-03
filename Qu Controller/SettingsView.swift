import SwiftUI

struct SettingsView: View {
    private enum Tab: Hashable {
        case connection
        case safety
        case mainWindow
        case menuBar
    }

    @ObservedObject var viewModel: MixerScreenViewModel
    @State private var selectedTab: Tab = .connection

    private var windowSize: CGSize {
        switch selectedTab {
        case .connection:
            CGSize(width: 540, height: 250)
        case .safety:
            CGSize(width: 520, height: 220)
        case .mainWindow, .menuBar:
            CGSize(width: 520, height: 500)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SettingsPane(title: "Connection", subtitle: "Connection and discovery behavior.") {
                Form {
                    Toggle(
                        "Automatically connect after mixer is found",
                        isOn: Binding(
                            get: { viewModel.autoConnectAfterDiscovery },
                            set: viewModel.setAutoConnectAfterDiscovery(_:)
                        )
                    )

                    Text("Discovery tries the last successfully connected IP first, then falls back to subnet scanning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .formStyle(.grouped)
            }
            .tag(Tab.connection)
            .tabItem {
                Label("Connection", systemImage: "network")
            }

            SettingsPane(title: "Safety", subtitle: "Actions that affect live mixer behavior.") {
                Form {
                    Toggle(
                        "Confirm before shutting down",
                        isOn: Binding(
                            get: { viewModel.confirmBeforeShutdown },
                            set: viewModel.setConfirmBeforeShutdown(_:)
                        )
                    )
                }
                .formStyle(.grouped)
            }
            .tag(Tab.safety)
            .tabItem {
                Label("Safety", systemImage: "exclamationmark.shield")
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
