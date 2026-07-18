import Combine
import Foundation
import Network

@MainActor
final class MixerRelayService: ObservableObject {
    enum Phase: Equatable {
        case disabled
        case starting
        case listening
        case failed
    }

    struct Status: Equatable {
        let phase: Phase
        let message: String
    }

    @Published private(set) var status = Status(phase: .disabled, message: "Relay disabled")
    @Published private(set) var connectedClientCount = 0

    private struct Client {
        let connection: NWConnection
        var receiveBuffer = Data()
    }

    private let controller: MixerController
    private let networkQueue = DispatchQueue(label: "com.scrapps.qucontroller.relay")
    private let maximumBufferedBytes = 64 * 1024
    private var listener: NWListener?
    private var clients: [UUID: Client] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(controller: MixerController) {
        self.controller = controller

        controller.channelsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.broadcastSnapshot()
            }
            .store(in: &cancellables)

        controller.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.broadcastSnapshot()
            }
            .store(in: &cancellables)
    }

    func configure(isEnabled: Bool, bindHost: String, port: Int) {
        stop()

        guard isEnabled else {
            status = Status(phase: .disabled, message: "Relay disabled")
            return
        }

        guard let rawPort = UInt16(exactly: port), rawPort > 0,
              let networkPort = NWEndpoint.Port(rawValue: rawPort) else {
            status = Status(phase: .failed, message: "Relay port must be between 1 and 65535")
            return
        }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            let normalizedHost = bindHost.trimmingCharacters(in: .whitespacesAndNewlines)
            let usesWildcardHost = normalizedHost.isEmpty ||
                normalizedHost == "0.0.0.0" ||
                normalizedHost == "::" ||
                normalizedHost == "*"

            let listener: NWListener
            if usesWildcardHost {
                listener = try NWListener(using: parameters, on: networkPort)
            } else {
                parameters.requiredLocalEndpoint = .hostPort(
                    host: NWEndpoint.Host(normalizedHost),
                    port: networkPort
                )
                listener = try NWListener(using: parameters)
            }

            self.listener = listener
            status = Status(phase: .starting, message: "Starting relay on \(displayHost(bindHost)):\(port)")

            listener.stateUpdateHandler = { [weak self, weak listener] state in
                Task { @MainActor [weak self, weak listener] in
                    guard let self, let listener, self.listener === listener else { return }
                    self.handleListenerState(state, bindHost: bindHost, port: port)
                }
            }
            listener.newConnectionHandler = { [weak self, weak listener] connection in
                Task { @MainActor [weak self, weak listener] in
                    guard let self, let listener, self.listener === listener else {
                        connection.cancel()
                        return
                    }
                    self.accept(connection)
                }
            }
            listener.start(queue: networkQueue)
        } catch {
            listener = nil
            status = Status(phase: .failed, message: "Relay failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil

        for client in clients.values {
            client.connection.stateUpdateHandler = nil
            client.connection.cancel()
        }
        clients.removeAll()
        connectedClientCount = 0
    }

    private func handleListenerState(_ state: NWListener.State, bindHost: String, port: Int) {
        switch state {
        case .ready:
            status = Status(
                phase: .listening,
                message: "Listening on \(displayHost(bindHost)):\(port)"
            )
        case .failed(let error):
            stop()
            status = Status(phase: .failed, message: "Relay failed: \(error.localizedDescription)")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        let clientID = UUID()
        clients[clientID] = Client(connection: connection)
        connectedClientCount = clients.count

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor [weak self, weak connection] in
                guard let self, let connection,
                      self.clients[clientID]?.connection === connection else { return }

                switch state {
                case .ready:
                    self.sendSnapshot(to: clientID)
                    self.receiveNextMessage(from: clientID)
                case .failed, .cancelled:
                    self.removeClient(clientID)
                default:
                    break
                }
            }
        }
        connection.start(queue: networkQueue)
    }

    private func receiveNextMessage(from clientID: UUID) {
        guard let connection = clients[clientID]?.connection else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self, weak connection] data, _, isComplete, error in
            Task { @MainActor [weak self, weak connection] in
                guard let self, let connection,
                      self.clients[clientID]?.connection === connection else { return }

                if let error {
                    self.sendError("Receive failed: \(error.localizedDescription)", to: clientID)
                    self.removeClient(clientID)
                    return
                }

                if let data, !data.isEmpty {
                    self.process(data, from: clientID)
                }

                if isComplete {
                    self.removeClient(clientID)
                } else if self.clients[clientID] != nil {
                    self.receiveNextMessage(from: clientID)
                }
            }
        }
    }

    private func process(_ data: Data, from clientID: UUID) {
        guard var client = clients[clientID] else { return }
        client.receiveBuffer.append(data)

        guard client.receiveBuffer.count <= maximumBufferedBytes else {
            clients[clientID] = client
            sendError("Message exceeds maximum size", to: clientID)
            removeClient(clientID)
            return
        }

        while let newlineIndex = client.receiveBuffer.firstIndex(of: 0x0A) {
            let line = Data(client.receiveBuffer[..<newlineIndex])
            client.receiveBuffer.removeSubrange(...newlineIndex)

            if !line.isEmpty {
                handleCommand(line, from: clientID)
            }
        }

        clients[clientID] = client
    }

    private func handleCommand(_ data: Data, from clientID: UUID) {
        do {
            let command = try JSONDecoder().decode(MixerRelayClientCommand.self, from: data)
            switch command.type {
            case "setLevel":
                guard let channel = command.channel, let level = command.level,
                      level.isFinite, (0 ... 1).contains(level) else {
                    sendError("setLevel requires channel and level between 0 and 1", to: clientID)
                    return
                }
                controller.setLevel(for: channel, level: FaderLevel(normalized: level))
            case "setMute":
                guard let channel = command.channel, let isMuted = command.isMuted else {
                    sendError("setMute requires channel and isMuted", to: clientID)
                    return
                }
                controller.setMute(for: channel, isMuted: isMuted)
            default:
                sendError("Unsupported command type: \(command.type)", to: clientID)
            }
        } catch {
            sendError("Invalid command: \(error.localizedDescription)", to: clientID)
        }
    }

    private func broadcastSnapshot() {
        guard status.phase == .listening, !clients.isEmpty else { return }
        guard let data = encodedLine(
            .snapshot(connectionState: controller.connectionState, channels: controller.channels)
        ) else { return }

        for clientID in clients.keys {
            send(data, to: clientID)
        }
    }

    private func sendSnapshot(to clientID: UUID) {
        guard let data = encodedLine(
            .snapshot(connectionState: controller.connectionState, channels: controller.channels)
        ) else { return }
        send(data, to: clientID)
    }

    private func sendError(_ message: String, to clientID: UUID) {
        guard let data = encodedLine(.error(message)) else { return }
        send(data, to: clientID)
    }

    private func encodedLine(_ message: MixerRelayServerMessage) -> Data? {
        guard var data = try? JSONEncoder().encode(message) else { return nil }
        data.append(0x0A)
        return data
    }

    private func send(_ data: Data, to clientID: UUID) {
        guard let connection = clients[clientID]?.connection else { return }
        connection.send(content: data, completion: .contentProcessed { [weak self, weak connection] error in
            guard error != nil else { return }
            Task { @MainActor [weak self, weak connection] in
                guard let self, let connection,
                      self.clients[clientID]?.connection === connection else { return }
                self.removeClient(clientID)
            }
        })
    }

    private func removeClient(_ clientID: UUID) {
        guard let client = clients.removeValue(forKey: clientID) else { return }
        client.connection.stateUpdateHandler = nil
        client.connection.cancel()
        connectedClientCount = clients.count
    }

    private func displayHost(_ bindHost: String) -> String {
        let trimmedHost = bindHost.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedHost.isEmpty || trimmedHost == "*" ? "0.0.0.0" : trimmedHost
    }
}
