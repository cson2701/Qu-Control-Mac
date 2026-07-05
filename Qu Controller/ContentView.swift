import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: MixerScreenViewModel
    let onSetTransportKind: (MixerTransportKind) -> Void
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
        .background(Color(nsColor: .windowBackgroundColor))
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
        .background(
            WindowKeyPressHandler(key: "m", modifiers: []) {
                viewModel.toggleMainLRMute()
            }
        )
    }

    private var connectedContent: some View {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                    GeometryReader { geometry in
                        let channels = viewModel.visibleMainScreenChannels
                        let faderWidth = mainScreenFaderWidth(
                            channelCount: channels.count,
                            availableWidth: geometry.size.width
                        )

                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: Self.mainScreenFaderSpacing) {
                                ForEach(channels) { channel in
                                    VerticalFader(
                                        channel: channel,
                                        isEnabled: viewModel.isFaderInteractive,
                                        showsSignalIndicator: viewModel.showSignalIndicators
                                    ) { level in
                                        viewModel.setLevel(level, for: channel.id)
                                    } onMuteToggle: { isMuted in
                                        viewModel.setMute(isMuted, for: channel.id)
                                    }
                                    .frame(width: faderWidth)
                                    .frame(maxHeight: .infinity)
                                }
                            }
                            .padding(.horizontal, Self.mainScreenFaderPadding)
                            .padding(.vertical, 4)
                            .frame(minWidth: geometry.size.width, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .scrollIndicators(.visible)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

            Picker(
                "Transport",
                selection: Binding(
                    get: { viewModel.transportKind },
                    set: onSetTransportKind
                )
            ) {
                ForEach(MixerTransportKind.allCases) { transportKind in
                    Text(transportKind.displayName).tag(transportKind)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.transportKind == .network {
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
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("USB MIDI device")
                        .font(.headline)

                    Picker(
                        "USB MIDI Device",
                        selection: Binding(
                            get: { viewModel.selectedUSBMIDIDeviceID ?? "" },
                            set: viewModel.setSelectedUSBMIDIDeviceID(_:)
                        )
                    ) {
                        if viewModel.connectionOptions.isEmpty {
                            Text("No USB MIDI devices found").tag("")
                        } else {
                            ForEach(viewModel.connectionOptions) { option in
                                Text(option.displayName).tag(option.id)
                            }
                        }
                    }

                    Text("Connect directly to the mixer over USB MIDI.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button(viewModel.buttonTitle) {
                    viewModel.toggleConnection()
                }
                .buttonStyle(.borderedProminent)

                if viewModel.transportKind == .network {
                    Button(viewModel.scanButtonTitle) {
                        if viewModel.isScanningForMixer {
                            viewModel.stopScanningForMixer()
                        } else {
                            viewModel.scanForMixer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isScanningForMixer && !viewModel.isAutoScanAvailable)
                } else {
                    Button("Refresh Devices") {
                        viewModel.refreshConnectionOptions()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canRefreshUSBDevices)
                }

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

    private static let mainScreenFaderSpacing: CGFloat = 14
    private static let mainScreenFaderPadding: CGFloat = 4

    private func mainScreenFaderWidth(channelCount: Int, availableWidth: CGFloat) -> CGFloat {
        guard channelCount > 0 else {
            return 96
        }

        let spacing = Self.mainScreenFaderSpacing * CGFloat(max(channelCount - 1, 0))
        let padding = Self.mainScreenFaderPadding * 2
        let fittedWidth = (availableWidth - spacing - padding) / CGFloat(channelCount)

        return min(max(fittedWidth, 96), 140)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            viewModel: MixerScreenViewModel(controller: MockMixerController()),
            onSetTransportKind: { _ in },
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
    @Environment(\.colorScheme) private var colorScheme

    private var style: (label: String, dotColor: Color, backgroundColor: Color, textColor: Color) {
        let isDarkMode = colorScheme == .dark

        switch connectionState.phase {
        case .connected:
            if isDarkMode {
                return ("Connected", Color(red: 0.35, green: 0.9, blue: 0.48), Color(red: 0.06, green: 0.22, blue: 0.11), Color(red: 0.78, green: 1, blue: 0.82))
            } else {
                return ("Connected", Color(red: 0.07, green: 0.48, blue: 0.19), Color(red: 0.78, green: 0.91, blue: 0.8), Color(red: 0.03, green: 0.24, blue: 0.1))
            }
        case .connecting:
            if isDarkMode {
                return ("Connecting", Color(red: 1, green: 0.72, blue: 0.24), Color(red: 0.28, green: 0.17, blue: 0.03), Color(red: 1, green: 0.86, blue: 0.52))
            } else {
                return ("Connecting", Color(red: 0.78, green: 0.43, blue: 0), Color(red: 0.98, green: 0.84, blue: 0.55), Color(red: 0.36, green: 0.2, blue: 0))
            }
        case .error:
            if isDarkMode {
                return ("Error", Color(red: 1, green: 0.36, blue: 0.36), Color(red: 0.32, green: 0.06, blue: 0.06), Color(red: 1, green: 0.74, blue: 0.74))
            } else {
                return ("Error", Color(red: 0.78, green: 0.16, blue: 0.16), Color(red: 0.99, green: 0.88, blue: 0.88), Color(red: 0.46, green: 0.07, blue: 0.07))
            }
        case .disconnected:
            if isDarkMode {
                return ("Disconnected", Color(red: 0.7, green: 0.75, blue: 0.82), Color(red: 0.15, green: 0.17, blue: 0.2), Color(red: 0.86, green: 0.89, blue: 0.94))
            } else {
                return ("Disconnected", Color(red: 0.32, green: 0.45, blue: 0.63), Color(red: 0.82, green: 0.88, blue: 0.96), Color(red: 0.12, green: 0.2, blue: 0.32))
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(style.dotColor)
                .frame(width: 10, height: 10)

            Text(style.label)
                .font(.headline)
                .foregroundStyle(style.textColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(style.backgroundColor)
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
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
