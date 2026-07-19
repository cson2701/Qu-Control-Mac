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

enum MixerChannelID: String, CaseIterable, Identifiable, Codable {
    case ch1
    case ch2
    case ch3
    case ch4
    case ch5
    case ch6
    case ch7
    case ch8
    case ch9
    case ch10
    case ch11
    case ch12
    case ch13
    case ch14
    case ch15
    case ch16
    case mainLr

    static let selectableChannels: [MixerChannelID] = [
        .ch1, .ch2, .ch3, .ch4, .ch5, .ch6, .ch7, .ch8,
        .ch9, .ch10, .ch11, .ch12, .ch13, .ch14, .ch15, .ch16,
        .mainLr
    ]

    var id: String { rawValue }

    var defaultDisplayName: String {
        switch self {
        case .ch1: "CH 1"
        case .ch2: "CH 2"
        case .ch3: "CH 3"
        case .ch4: "CH 4"
        case .ch5: "CH 5"
        case .ch6: "CH 6"
        case .ch7: "CH 7"
        case .ch8: "CH 8"
        case .ch9: "CH 9"
        case .ch10: "CH 10"
        case .ch11: "CH 11"
        case .ch12: "CH 12"
        case .ch13: "CH 13"
        case .ch14: "CH 14"
        case .ch15: "CH 15"
        case .ch16: "CH 16"
        case .mainLr:
            "Main LR"
        }
    }

    var midiChannelCode: UInt8 {
        switch self {
        case .ch1: 0x20
        case .ch2: 0x21
        case .ch3: 0x22
        case .ch4: 0x23
        case .ch5: 0x24
        case .ch6: 0x25
        case .ch7: 0x26
        case .ch8: 0x27
        case .ch9: 0x28
        case .ch10: 0x29
        case .ch11: 0x2A
        case .ch12: 0x2B
        case .ch13: 0x2C
        case .ch14: 0x2D
        case .ch15: 0x2E
        case .ch16: 0x2F
        case .mainLr: 0x67
        }
    }

    init?(midiChannelCode: UInt8) {
        switch midiChannelCode {
        case 0x20: self = .ch1
        case 0x21: self = .ch2
        case 0x22: self = .ch3
        case 0x23: self = .ch4
        case 0x24: self = .ch5
        case 0x25: self = .ch6
        case 0x26: self = .ch7
        case 0x27: self = .ch8
        case 0x28: self = .ch9
        case 0x29: self = .ch10
        case 0x2A: self = .ch11
        case 0x2B: self = .ch12
        case 0x2C: self = .ch13
        case 0x2D: self = .ch14
        case 0x2E: self = .ch15
        case 0x2F: self = .ch16
        case 0x67: self = .mainLr
        default: return nil
        }
    }
}

struct MixerChannelState: Equatable, Identifiable {
    let id: MixerChannelID
    var level: FaderLevel
    var isMuted: Bool
    var hasSignal: Bool
    var customName: String?

    var hasCustomDisplayName: Bool {
        guard let customName else {
            return false
        }

        return !customName.isEmpty
    }

    var channelNumberLabel: String? {
        guard id != .mainLr else {
            return nil
        }

        return id.defaultDisplayName
    }

    var primaryDisplayName: String {
        hasCustomDisplayName ? customName ?? id.defaultDisplayName : id.defaultDisplayName
    }

    var secondaryDisplayName: String? {
        hasCustomDisplayName ? channelNumberLabel : nil
    }

    var displayName: String {
        primaryDisplayName
    }
}

enum MixerLayoutSurface: String, Codable {
    case mainScreen
    case menuBar
}

struct MixerLayoutPreferences: Equatable, Codable {
    var mainScreenOrderedChannelIDs: [MixerChannelID]
    var menuBarOrderedChannelIDs: [MixerChannelID]
    var mainScreenVisibleChannelIDs: [MixerChannelID]
    var menuBarVisibleChannelIDs: [MixerChannelID]

    private static let defaultOrderedChannelIDs = MixerChannelID.selectableChannels
    private static let defaultMainScreenVisibleChannelIDs: [MixerChannelID] = [.ch1, .ch2, .ch3, .ch4, .mainLr]
    private static let defaultMenuBarVisibleChannelIDs: [MixerChannelID] = [.ch1, .ch2, .mainLr]

    static let `default` = MixerLayoutPreferences(
        mainScreenOrderedChannelIDs: defaultOrderedChannelIDs,
        menuBarOrderedChannelIDs: defaultOrderedChannelIDs,
        mainScreenVisibleChannelIDs: defaultMainScreenVisibleChannelIDs,
        menuBarVisibleChannelIDs: defaultMenuBarVisibleChannelIDs
    )

    private enum CodingKeys: String, CodingKey {
        case mainScreenOrderedChannelIDs
        case menuBarOrderedChannelIDs
        case mainScreenVisibleChannelIDs
        case menuBarVisibleChannelIDs
        case mainScreenChannelIDs
        case menuBarChannelIDs
        case orderedChannelIDs
    }

    init(
        mainScreenOrderedChannelIDs: [MixerChannelID],
        menuBarOrderedChannelIDs: [MixerChannelID],
        mainScreenVisibleChannelIDs: [MixerChannelID],
        menuBarVisibleChannelIDs: [MixerChannelID]
    ) {
        self.mainScreenOrderedChannelIDs = Self.normalizedOrder(
            from: mainScreenOrderedChannelIDs,
            fallback: Self.defaultOrderedChannelIDs
        )
        self.menuBarOrderedChannelIDs = Self.normalizedOrder(
            from: menuBarOrderedChannelIDs,
            fallback: Self.defaultOrderedChannelIDs
        )
        self.mainScreenVisibleChannelIDs = Self.normalizedVisibleChannelIDs(
            visibleChannelIDs: mainScreenVisibleChannelIDs,
            order: self.mainScreenOrderedChannelIDs,
            fallback: Self.defaultMainScreenVisibleChannelIDs
        )
        self.menuBarVisibleChannelIDs = Self.normalizedVisibleChannelIDs(
            visibleChannelIDs: menuBarVisibleChannelIDs,
            order: self.menuBarOrderedChannelIDs,
            fallback: Self.defaultMenuBarVisibleChannelIDs
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let mainScreenOrderedChannelIDs = try container.decodeIfPresent([MixerChannelID].self, forKey: .mainScreenOrderedChannelIDs),
           let menuBarOrderedChannelIDs = try container.decodeIfPresent([MixerChannelID].self, forKey: .menuBarOrderedChannelIDs) {
            self.init(
                mainScreenOrderedChannelIDs: mainScreenOrderedChannelIDs,
                menuBarOrderedChannelIDs: menuBarOrderedChannelIDs,
                mainScreenVisibleChannelIDs: try container.decodeIfPresent([MixerChannelID].self, forKey: .mainScreenVisibleChannelIDs)
                    ?? Self.defaultMainScreenVisibleChannelIDs,
                menuBarVisibleChannelIDs: try container.decodeIfPresent([MixerChannelID].self, forKey: .menuBarVisibleChannelIDs)
                    ?? Self.defaultMenuBarVisibleChannelIDs
            )
            return
        }

        if let mainScreenChannelIDs = try container.decodeIfPresent([MixerChannelID].self, forKey: .mainScreenChannelIDs),
           let menuBarChannelIDs = try container.decodeIfPresent([MixerChannelID].self, forKey: .menuBarChannelIDs) {
            self.init(
                mainScreenOrderedChannelIDs: mainScreenChannelIDs,
                menuBarOrderedChannelIDs: menuBarChannelIDs,
                mainScreenVisibleChannelIDs: mainScreenChannelIDs,
                menuBarVisibleChannelIDs: menuBarChannelIDs
            )
            return
        }

        if let orderedChannelIDs = try container.decodeIfPresent([MixerChannelID].self, forKey: .orderedChannelIDs) {
            let mainScreenVisibleChannelIDs = try container.decodeIfPresent([MixerChannelID].self, forKey: .mainScreenVisibleChannelIDs)
                ?? Self.defaultMainScreenVisibleChannelIDs
            let menuBarVisibleChannelIDs = try container.decodeIfPresent([MixerChannelID].self, forKey: .menuBarVisibleChannelIDs)
                ?? Self.defaultMenuBarVisibleChannelIDs

            self.init(
                mainScreenOrderedChannelIDs: Self.migratedSurfaceOrder(
                    visibleChannelIDs: mainScreenVisibleChannelIDs,
                    orderedChannelIDs: orderedChannelIDs
                ),
                menuBarOrderedChannelIDs: Self.migratedSurfaceOrder(
                    visibleChannelIDs: menuBarVisibleChannelIDs,
                    orderedChannelIDs: orderedChannelIDs
                ),
                mainScreenVisibleChannelIDs: mainScreenVisibleChannelIDs,
                menuBarVisibleChannelIDs: menuBarVisibleChannelIDs
            )
            return
        }

        self = .default
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mainScreenOrderedChannelIDs, forKey: .mainScreenOrderedChannelIDs)
        try container.encode(menuBarOrderedChannelIDs, forKey: .menuBarOrderedChannelIDs)
        try container.encode(mainScreenVisibleChannelIDs, forKey: .mainScreenVisibleChannelIDs)
        try container.encode(menuBarVisibleChannelIDs, forKey: .menuBarVisibleChannelIDs)
    }

    func orderedChannelIDs(for surface: MixerLayoutSurface) -> [MixerChannelID] {
        switch surface {
        case .mainScreen:
            Self.normalizedOrder(from: mainScreenOrderedChannelIDs, fallback: Self.defaultOrderedChannelIDs)
        case .menuBar:
            Self.normalizedOrder(from: menuBarOrderedChannelIDs, fallback: Self.defaultOrderedChannelIDs)
        }
    }

    func hasCustomOrder(for surface: MixerLayoutSurface) -> Bool {
        orderedChannelIDs(for: surface) != Self.defaultOrderedChannelIDs
    }

    func channelIDs(for surface: MixerLayoutSurface) -> [MixerChannelID] {
        switch surface {
        case .mainScreen:
            Self.normalizedVisibleChannelIDs(
                visibleChannelIDs: mainScreenVisibleChannelIDs,
                order: orderedChannelIDs(for: .mainScreen),
                fallback: Self.defaultMainScreenVisibleChannelIDs
            )
        case .menuBar:
            Self.normalizedVisibleChannelIDs(
                visibleChannelIDs: menuBarVisibleChannelIDs,
                order: orderedChannelIDs(for: .menuBar),
                fallback: Self.defaultMenuBarVisibleChannelIDs
            )
        }
    }

    mutating func setChannelVisibility(
        _ isVisible: Bool,
        for channelID: MixerChannelID,
        surface: MixerLayoutSurface
    ) {
        let currentVisibleChannelIDs = channelIDs(for: surface)
        let updatedVisibleChannelIDs = if isVisible {
            Self.appendVisible(channelID, to: currentVisibleChannelIDs, order: orderedChannelIDs(for: surface))
        } else {
            currentVisibleChannelIDs.filter { $0 != channelID || $0 == .mainLr }
        }

        switch surface {
        case .mainScreen:
            mainScreenVisibleChannelIDs = Self.normalizedVisibleChannelIDs(
                visibleChannelIDs: updatedVisibleChannelIDs,
                order: orderedChannelIDs(for: .mainScreen),
                fallback: Self.defaultMainScreenVisibleChannelIDs
            )
        case .menuBar:
            menuBarVisibleChannelIDs = Self.normalizedVisibleChannelIDs(
                visibleChannelIDs: updatedVisibleChannelIDs,
                order: orderedChannelIDs(for: .menuBar),
                fallback: Self.defaultMenuBarVisibleChannelIDs
            )
        }
    }

    mutating func moveChannel(from source: Int, to destination: Int, surface: MixerLayoutSurface) {
        var movableChannels = orderedChannelIDs(for: surface).filter { $0 != .mainLr }
        guard movableChannels.indices.contains(source) else {
            return
        }

        let channel = movableChannels.remove(at: source)
        let targetIndex = max(0, min(destination, movableChannels.count))
        movableChannels.insert(channel, at: targetIndex)
        let movedChannelIDs = Self.normalizedOrder(
            from: movableChannels + [.mainLr],
            fallback: orderedChannelIDs(for: surface)
        )

        switch surface {
        case .mainScreen:
            mainScreenOrderedChannelIDs = movedChannelIDs
        case .menuBar:
            menuBarOrderedChannelIDs = movedChannelIDs
        }
    }

    mutating func resetOrder(for surface: MixerLayoutSurface) {
        switch surface {
        case .mainScreen:
            mainScreenOrderedChannelIDs = Self.defaultOrderedChannelIDs
        case .menuBar:
            menuBarOrderedChannelIDs = Self.defaultOrderedChannelIDs
        }
    }

    private static func appendVisible(
        _ channelID: MixerChannelID,
        to visibleChannelIDs: [MixerChannelID],
        order: [MixerChannelID]
    ) -> [MixerChannelID] {
        normalizedVisibleChannelIDs(
            visibleChannelIDs: visibleChannelIDs + [channelID],
            order: order,
            fallback: []
        )
    }

    private static func normalizedOrder(from channelIDs: [MixerChannelID], fallback: [MixerChannelID]) -> [MixerChannelID] {
        var seen = Set<MixerChannelID>()
        var ordered = channelIDs.compactMap { channelID -> MixerChannelID? in
            guard channelID != .mainLr,
                  MixerChannelID.selectableChannels.contains(channelID),
                  seen.insert(channelID).inserted else {
                return nil
            }

            return channelID
        }

        for channelID in MixerChannelID.selectableChannels where channelID != .mainLr && seen.insert(channelID).inserted {
            ordered.append(channelID)
        }

        ordered.append(.mainLr)
        return ordered.isEmpty ? normalizedOrder(from: fallback, fallback: Self.defaultOrderedChannelIDs) : ordered
    }

    private static func normalizedVisibleChannelIDs(
        visibleChannelIDs: [MixerChannelID],
        order: [MixerChannelID],
        fallback: [MixerChannelID]
    ) -> [MixerChannelID] {
        let requestedVisibleChannels = Set(visibleChannelIDs + [.mainLr])
        let filteredVisibleChannelIDs = normalizedOrder(from: order, fallback: Self.defaultOrderedChannelIDs)
            .filter { requestedVisibleChannels.contains($0) }

        guard !filteredVisibleChannelIDs.isEmpty else {
            return normalizedVisibleChannelIDs(
                visibleChannelIDs: fallback,
                order: order,
                fallback: []
            )
        }

        return filteredVisibleChannelIDs
    }

    private static func migratedSurfaceOrder(
        visibleChannelIDs: [MixerChannelID],
        orderedChannelIDs: [MixerChannelID]
    ) -> [MixerChannelID] {
        let requestedVisibleChannels = Set(visibleChannelIDs + [.mainLr])
        return normalizedOrder(
            from: orderedChannelIDs.filter { requestedVisibleChannels.contains($0) } + MixerChannelID.selectableChannels,
            fallback: Self.defaultOrderedChannelIDs
        )
    }
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
