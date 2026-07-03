import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: MixerScreenViewModel
    let isUsingMockConnection: Bool
    let onSetUseMockConnection: (Bool) -> Void
    @Environment(\.openSettings) private var openSettings
    @State private var isShowingShutdownConfirmation = false

    var body: some View {
        Group {
            if viewModel.connectionState.phase == .connected {
                connectedContent
            } else {
                disconnectedContent
            }
        }
        .padding(24)
        .frame(minWidth: 900, minHeight: 520)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .underPageBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .confirmationDialog(
            "Shut Down Mixer",
            isPresented: $isShowingShutdownConfirmation,
            titleVisibility: .visible
        ) {
            Button("Shut Down Mixer", role: .destructive) {
                viewModel.shutdownMixer()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will power off the connected Qu mixer. You will need a hard power reset to turn it back on.")
        }
    }

    private var connectedContent: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                connectedHeader

                if viewModel.visibleMainScreenChannels.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("No channels selected")
                            .font(.title3.weight(.semibold))

                        Button("Open Settings") {
                            openSettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                    .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Control Surface")
                                .font(.headline)

                            Spacer(minLength: 0)

                            Text("\(viewModel.visibleMainScreenChannels.count) channels")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 14) {
                                ForEach(viewModel.visibleMainScreenChannels) { channel in
                                    VerticalFader(channel: channel, isEnabled: viewModel.isFaderInteractive) { level in
                                        viewModel.setLevel(level, for: channel.id)
                                    }
                                    .frame(width: 96)
                                    .frame(maxHeight: .infinity)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                        }
                        .scrollIndicators(.visible)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var disconnectedContent: some View {
        VStack {
            controlSidebar(subtitle: "Connect to a Qu mixer to open the live control surface.")
            .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func controlSidebar(subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Text("Qu Controller")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))

                Spacer(minLength: 0)
            }

            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            ConnectionStatusPill(connectionState: viewModel.connectionState)

            VStack(alignment: .leading, spacing: 8) {
                Text("Qu mixer IP")
                    .font(.headline)

                TextField("192.168.4.198", text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if viewModel.connectionState.phase == .disconnected || viewModel.connectionState.phase == .error {
                            viewModel.toggleConnection()
                        }
                    }

                Text("Port 51325")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(viewModel.buttonTitle) {
                    viewModel.toggleConnection()
                }
                .buttonStyle(.borderedProminent)

                Button(viewModel.scanButtonTitle) {
                    if viewModel.isScanningForMixer {
                        viewModel.stopScanningForMixer()
                    } else {
                        viewModel.scanForMixer()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isScanningForMixer && !viewModel.isAutoScanAvailable)

                Button("Settings") {
                    openSettings()
                }
                .buttonStyle(.bordered)
            }

            DiscoveryStatusView(
                message: viewModel.statusMessage,
                isScanning: viewModel.isScanningForMixer,
                font: nil
            )

#if DEBUG
            Toggle(
                "Use Mock Connection",
                isOn: Binding(
                    get: { isUsingMockConnection },
                    set: onSetUseMockConnection
                )
            )
            .toggleStyle(.switch)
#endif

            Spacer(minLength: 0)
        }
        .frame(minWidth: 280, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var connectedHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Qu Controller")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))

                    ConnectionStatusPill(connectionState: viewModel.connectionState)
                }

                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.headline)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(CircularIconButtonStyle(fillColor: Color.secondary.opacity(0.12)))
                .foregroundStyle(Color.primary)
                .help("Open settings")

                Button("Disconnect") {
                    viewModel.toggleConnection()
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    if viewModel.confirmBeforeShutdown {
                        isShowingShutdownConfirmation = true
                    } else {
                        viewModel.shutdownMixer()
                    }
                } label: {
                    Image(systemName: "power")
                        .font(.headline)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(CircularIconButtonStyle(fillColor: Color.red.opacity(0.12)))
                .foregroundStyle(Color.red)
                .help("Shut down the connected mixer")
            }
        }
        .padding(.horizontal, 4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            viewModel: MixerScreenViewModel(controller: MockMixerController()),
            isUsingMockConnection: true,
            onSetUseMockConnection: { _ in }
        )
    }
}

struct DiscoveryStatusView: View {
    let message: String
    let isScanning: Bool
    let font: Font?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if isScanning {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Scanning for mixer")
            }

            Text(message)
                .font(font)
                .foregroundStyle(.secondary)
        }
    }
}

struct ConnectionStatusPill: View {
    let connectionState: MixerConnectionState

    private var style: (label: String, dotColor: Color, backgroundColor: Color) {
        switch connectionState.phase {
        case .connected:
            ("Connected", Color(red: 0.11, green: 0.54, blue: 0.24), Color(red: 0.9, green: 0.96, blue: 0.91))
        case .connecting:
            ("Connecting", Color(red: 0.76, green: 0.48, blue: 0), Color(red: 1, green: 0.95, blue: 0.84))
        case .error:
            ("Error", Color(red: 0.78, green: 0.16, blue: 0.16), Color(red: 0.99, green: 0.88, blue: 0.88))
        case .disconnected:
            ("Disconnected", Color(red: 0.4, green: 0.44, blue: 0.5), Color(red: 0.92, green: 0.94, blue: 0.96))
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(style.dotColor)
                .frame(width: 10, height: 10)

            Text(style.label)
                .font(.headline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(style.backgroundColor)
        .clipShape(Capsule())
    }
}

private struct CircularIconButtonStyle: ButtonStyle {
    let fillColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(configuration.isPressed ? fillColor.opacity(1.9) : fillColor)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
