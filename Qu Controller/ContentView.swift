import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: MixerScreenViewModel
    @State private var isShowingShutdownConfirmation = false
    @State private var isShowingMainChannelPicker = false

    var body: some View {
        HStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Qu Controller")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))

                    Spacer(minLength: 0)

                    Button(role: .destructive) {
                        isShowingShutdownConfirmation = true
                    } label: {
                        Image(systemName: "power")
                            .font(.headline)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(
                                        viewModel.isShutdownAvailable
                                            ? Color.red.opacity(0.12)
                                            : Color.secondary.opacity(0.12)
                                    )
                            )
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(viewModel.isShutdownAvailable ? Color.red : Color.secondary)
                    .disabled(!viewModel.isShutdownAvailable)
                    .help("Shut down the connected mixer")
                }

                Text("Choose which mixer channels appear here and in the menu bar popup.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                ConnectionStatusPill(connectionState: viewModel.connectionState)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Qu mixer IP")
                        .font(.headline)

                    TextField("192.168.4.198", text: $viewModel.host)
                        .textFieldStyle(.roundedBorder)

                    Text("Port 51325")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(viewModel.buttonTitle) {
                    viewModel.toggleConnection()
                }
                .buttonStyle(.borderedProminent)

                Button("Choose Visible Channels") {
                    isShowingMainChannelPicker = true
                }
                .buttonStyle(.bordered)

                DiscoveryStatusView(
                    message: viewModel.statusMessage,
                    isScanning: viewModel.isScanningForMixer,
                    font: nil
                )

                Spacer(minLength: 0)
            }
            .frame(minWidth: 280, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .sheet(isPresented: $isShowingMainChannelPicker) {
                ChannelVisibilityPicker(viewModel: viewModel)
                .padding(24)
            }

            Group {
                if viewModel.visibleMainScreenChannels.isEmpty {
                    Text("No channels selected")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 18) {
                            ForEach(viewModel.visibleMainScreenChannels) { channel in
                                VerticalFader(channel: channel, isEnabled: viewModel.isFaderInteractive) { level in
                                    viewModel.setLevel(level, for: channel.id)
                                }
                                .frame(width: 104)
                                .frame(maxHeight: .infinity)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: MixerScreenViewModel(controller: MockMixerController()))
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
