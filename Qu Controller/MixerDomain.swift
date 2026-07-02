//
//  MixerDomain.swift
//  Qu Controller
//

import Foundation

struct FaderLevel: Equatable {
    let normalized: Double

    init(normalized: Double) {
        self.normalized = normalized.clamped(to: 0 ... 1)
    }

    var percentage: Int {
        Int((normalized * 100).rounded())
    }
}

enum MixerChannelID: String, CaseIterable, Identifiable {
    case mainLr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mainLr:
            "Main LR"
        }
    }
}

struct MixerChannelState: Equatable, Identifiable {
    let id: MixerChannelID
    var level: FaderLevel
}

struct MixerEndpoint: Equatable {
    var host: String
    var port: Int = 51_325
}

enum MixerConnectionPhase: Equatable {
    case disconnected
    case connecting
    case connected
    case error
}

struct MixerConnectionState: Equatable {
    var phase: MixerConnectionPhase
    var message: String
    var endpoint: MixerEndpoint?
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
