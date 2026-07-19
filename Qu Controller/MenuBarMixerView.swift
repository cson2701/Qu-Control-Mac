//
//  MenuBarMixerView.swift
//  Qu Controller
//

import AppKit
import SwiftUI

struct MenuBarMixerView: View {
    @ObservedObject var viewModel: MixerScreenViewModel
    let showMainWindow: () -> Void
    let closePopover: () -> Void
    let registerOpenMainWindow: (@escaping () -> Void) -> Void
    @Environment(\.openSettings) private var openSettings
    @State private var isShowingShutdownConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Text("Qu Controller")
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(0)

                Spacer(minLength: 0)

                ConnectionStatusPill(connectionState: viewModel.connectionState)
                    .scaleEffect(0.9, anchor: .trailing)
                    .layoutPriority(1)

                Menu {
                    Button("Show Mixer") {
                        showMainWindow()
                    }

                    Button("Settings") {
                        closePopover()
                        openSettings()
                    }
                    .keyboardShortcut(",", modifiers: .command)

                    Divider()

                    Button(viewModel.buttonTitle) {
                        viewModel.toggleConnection()
                    }
                    
                    Button("Shut Down Mixer", role: .destructive) {
                        if viewModel.confirmBeforeShutdown {
                            isShowingShutdownConfirmation = true
                        } else {
                            closePopover()
                            viewModel.shutdownMixer()
                        }
                    }
                    .disabled(!viewModel.isShutdownAvailable)

                    Divider()

                    Button("Quit") {
                        closePopover()
                        NSApp.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: .command)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .accessibilityLabel("Menu")
                }
                .menuStyle(.borderlessButton)
            }

            Group {
                if viewModel.connectionState.phase == .connected {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.menuBarChannels) { channel in
                            HorizontalFaderRow(
                                channel: channel,
                                isEnabled: viewModel.isFaderInteractive,
                                showsSignalIndicator: viewModel.showSignalIndicators
                            ) { level in
                                viewModel.setLevel(level, for: channel.id)
                            } onMuteToggle: { isMuted in
                                viewModel.setMute(isMuted, for: channel.id)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect to a Qu mixer to use menu bar controls.")
                            .font(.subheadline)

                        DiscoveryStatusView(
                            message: viewModel.statusMessage,
                            isScanning: viewModel.isScanningForMixer,
                            font: .caption
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .topLeading)
        .background(
            OpenMainWindowRegistrar { reopen in
                registerOpenMainWindow(reopen)
            }
        )
        .background(
            WindowKeyPressHandler(key: "m", modifiers: []) {
                viewModel.toggleMainLRMute()
            }
        )
        .confirmationDialog(
            "Shut Down Mixer",
            isPresented: $isShowingShutdownConfirmation,
            titleVisibility: .visible
        ) {
            Button("Shut Down Mixer", role: .destructive) {
                closePopover()
                viewModel.shutdownMixer()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will power off the connected Qu mixer. You will need a hard power reset to turn it back on.")
        }
    }
}

private struct HorizontalFaderRow: View {
    let channel: MixerChannelState
    let isEnabled: Bool
    let showsSignalIndicator: Bool
    let onLevelChange: (FaderLevel) -> Void
    let onMuteToggle: (Bool) -> Void

    private var levelLabel: String {
        isEnabled ? "\(channel.level.percentage)%" : "--"
    }

    private var levelBinding: Binding<Double> {
        Binding(
            get: { channel.level.normalized },
            set: { onLevelChange(FaderLevel(normalized: $0)) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(spacing: 6) {
                    if showsSignalIndicator {
                        Circle()
                            .fill(isEnabled && channel.hasSignal ? Color.green : Color.gray.opacity(0.6))
                            .frame(width: 7, height: 7)
                    }

                    Text(channel.primaryDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if let secondaryDisplayName = channel.secondaryDisplayName {
                        Text(secondaryDisplayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Text(levelLabel)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: 48, alignment: .trailing)

                MuteToggleButton(
                    isMuted: channel.isMuted,
                    label: "Mute"
                ) {
                    onMuteToggle(!channel.isMuted)
                }
                .disabled(!isEnabled)
            }

            Slider(value: levelBinding, in: 0 ... 1)
                .disabled(!isEnabled)
        }
        .padding(.vertical, 2)
    }
}
