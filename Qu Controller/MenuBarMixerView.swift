//
//  MenuBarMixerView.swift
//  Qu Controller
//

import SwiftUI

struct MenuBarMixerView: View {
    @ObservedObject var viewModel: MixerScreenViewModel
    let showMainWindow: (OpenWindowAction) -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Text("Qu Controller")
                    .font(.headline)

                Spacer(minLength: 0)

                ConnectionStatusPill(connectionState: viewModel.connectionState)
                    .scaleEffect(0.9, anchor: .trailing)
            }

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

            Divider()

            HStack(spacing: 10) {
                Button("Show Mixer") {
                    showMainWindow(openWindow)
                }
                .buttonStyle(.bordered)

                Button(viewModel.buttonTitle) {
                    viewModel.toggleConnection()
                }
                .buttonStyle(.borderedProminent)

                DiscoveryStatusView(
                    message: viewModel.statusMessage,
                    isScanning: viewModel.isScanningForMixer,
                    font: .caption
                )
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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

struct ChannelVisibilityPicker: View {
    @ObservedObject var viewModel: MixerScreenViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Visible Channels")
                    .font(.headline)

                Spacer(minLength: 0)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Choose which channels are visible on the main screen and in the menu bar popup.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 20) {
                ScrollView {
                    ChannelVisibilitySection(
                        title: "Main Screen",
                        surface: .mainScreen,
                        viewModel: viewModel
                    )
                }
                .frame(width: 220, height: 360)

                ScrollView {
                    ChannelVisibilitySection(
                        title: "Menu Bar Popup",
                        surface: .menuBar,
                        viewModel: viewModel
                    )
                }
                .frame(width: 220, height: 360)
            }
        }
    }
}

private struct ChannelVisibilitySection: View {
    let title: String
    let surface: MixerLayoutSurface
    @ObservedObject var viewModel: MixerScreenViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            ForEach(viewModel.selectableChannels) { channel in
                Toggle(
                    channel.displayName,
                    isOn: Binding(
                        get: { viewModel.isChannelVisible(channel.id, on: surface) },
                        set: { viewModel.setChannelVisibility($0, for: channel.id, on: surface) }
                    )
                )
                .toggleStyle(.checkbox)
            }
        }
    }
}
