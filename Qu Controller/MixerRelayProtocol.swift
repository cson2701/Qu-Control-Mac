import Foundation

struct MixerRelayClientCommand: Decodable {
    let type: String
    let channel: MixerChannelID?
    let level: Double?
    let isMuted: Bool?
}

struct MixerRelayServerMessage: Encodable {
    let type: String
    let connection: MixerRelayConnectionSnapshot?
    let channels: [MixerRelayChannelSnapshot]?
    let message: String?

    @MainActor
    static func snapshot(
        connectionState: MixerConnectionState,
        channels: [MixerChannelState]
    ) -> MixerRelayServerMessage {
        MixerRelayServerMessage(
            type: "snapshot",
            connection: MixerRelayConnectionSnapshot(connectionState),
            channels: channels.map(MixerRelayChannelSnapshot.init),
            message: nil
        )
    }

    static func error(_ message: String) -> MixerRelayServerMessage {
        MixerRelayServerMessage(
            type: "error",
            connection: nil,
            channels: nil,
            message: message
        )
    }
}

struct MixerRelayConnectionSnapshot: Encodable {
    let phase: String
    let message: String
    let endpoint: MixerRelayEndpointSnapshot?

    @MainActor
    init(_ state: MixerConnectionState) {
        phase = switch state.phase {
        case .disconnected: "disconnected"
        case .connecting: "connecting"
        case .connected: "connected"
        case .error: "error"
        }
        message = state.message
        endpoint = state.endpoint.map(MixerRelayEndpointSnapshot.init)
    }
}

struct MixerRelayEndpointSnapshot: Encodable {
    let host: String
    let port: Int

    @MainActor
    init(_ endpoint: MixerEndpoint) {
        host = endpoint.host
        port = endpoint.port
    }
}

struct MixerRelayChannelSnapshot: Encodable {
    let id: MixerChannelID
    let level: Double
    let isMuted: Bool
    let hasSignal: Bool
    let name: String

    @MainActor
    init(_ channel: MixerChannelState) {
        id = channel.id
        level = channel.level.normalized
        isMuted = channel.isMuted
        hasSignal = channel.hasSignal
        name = channel.displayName
    }
}
