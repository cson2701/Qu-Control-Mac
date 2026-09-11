import Foundation
import ServiceManagement

enum AppSettingsKey {
    static let layoutPreferences = "mixer.layoutPreferences"
    static let lastSuccessfulHost = "mixer.lastSuccessfulHost"
    static let confirmBeforeShutdown = "settings.confirmBeforeShutdown"
    static let autoConnectAfterDiscovery = "settings.autoConnectAfterDiscovery"
    static let startHiddenInMenuBar = "settings.startHiddenInMenuBar"
    static let showMenuBarIcon = "settings.showMenuBarIcon"
    static let showSignalIndicators = "settings.showSignalIndicators"
    static let faderWaveCycles = "settings.faderWave.cycles"
    static let faderWaveSpeed = "settings.faderWave.speed"
    static let relayEnabled = "relay.enabled"
    static let startRelayAtLaunch = "relay.startAtLaunch"
    static let relayPort = "relay.port"
}

enum AppSettings {
    static func loadShowMenuBarIcon(from userDefaults: UserDefaults = .standard) -> Bool {
        guard userDefaults.object(forKey: AppSettingsKey.showMenuBarIcon) != nil else {
            return true
        }

        return userDefaults.bool(forKey: AppSettingsKey.showMenuBarIcon)
    }

    static func loadStartHiddenInMenuBar(from userDefaults: UserDefaults = .standard) -> Bool {
        guard userDefaults.object(forKey: AppSettingsKey.startHiddenInMenuBar) != nil else {
            return false
        }

        return userDefaults.bool(forKey: AppSettingsKey.startHiddenInMenuBar)
    }

    static func loadFaderWaveConfiguration(
        from userDefaults: UserDefaults = .standard
    ) -> FaderWaveConfiguration {
        let cycles = userDefaults.object(forKey: AppSettingsKey.faderWaveCycles) == nil
            ? FaderWaveConfiguration.defaultCycles
            : userDefaults.double(forKey: AppSettingsKey.faderWaveCycles)
        let speed = userDefaults.object(forKey: AppSettingsKey.faderWaveSpeed) == nil
            ? FaderWaveConfiguration.defaultSpeed
            : userDefaults.double(forKey: AppSettingsKey.faderWaveSpeed)

        return FaderWaveConfiguration(cycles: cycles, speed: speed)
    }
}

enum LoginItemSettings {
    static var isStartAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setStartAtLoginEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
