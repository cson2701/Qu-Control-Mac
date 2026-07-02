//
//  MixerControllerFactory.swift
//  Qu Controller
//

import Foundation

enum MixerControllerFactory {
    @MainActor
    static func makeMixerController() -> MixerController {
        if ProcessInfo.processInfo.environment["QU_CONTROLLER_USE_MOCK"] == "1" {
            return MockMixerController()
        }
        return QuNetworkMixerController()
    }
}
