//
//  MenuBarMixerView.swift
//  Qu Controller
//

import SwiftUI

struct MenuBarMixerView: View {
    @ObservedObject var viewModel: MixerScreenViewModel
    let showMainWindow: (OpenWindowAction) -> Void
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

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
                        showMainWindow(openWindow)
                    }

                    Button("Settings") {
                        openSettings()
                    }

                    Divider()

                    Button(viewModel.buttonTitle) {
                        viewModel.toggleConnection()
                    }
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
                                isEnabled: viewModel.isFaderInteractive
                            ) { level in
                                viewModel.setLevel(level, for: channel.id)
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
    }
}

private struct HorizontalFaderRow: View {
    let channel: MixerChannelState
    let isEnabled: Bool
    let onLevelChange: (FaderLevel) -> Void

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
                Text(channel.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(levelLabel)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: 48, alignment: .trailing)
            }

            Slider(value: levelBinding, in: 0 ... 1)
                .disabled(!isEnabled)
        }
        .padding(.vertical, 2)
    }
}
