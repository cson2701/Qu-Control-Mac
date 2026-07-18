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
    static let relayEnabled = "relay.enabled"
    static let relayBindHost = "relay.bindHost"
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
