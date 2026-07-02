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

                Text(viewModel.connectionState.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text(channel.id.displayName)
                    .font(.subheadline.weight(.semibold))

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
