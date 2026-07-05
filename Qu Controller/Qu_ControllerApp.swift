//
//  Qu_ControllerApp.swift
//  Qu Controller
//
//  Created by Gavin Song on 2/7/2026.
//

import AppKit
import SwiftUI

@main
struct Qu_ControllerApp: App {
    private let menuBarIconSize = NSSize(width: 18, height: 18)
    @NSApplicationDelegateAdaptor(AppVisibilityController.self) private var appVisibilityController
    @State private var controllerMode: MixerControllerFactory.ControllerMode
    @State private var viewModel: MixerScreenViewModel
    @State private var showMenuBarIcon: Bool
    private let menuBarStatusItemController: MenuBarStatusItemController

    init() {
        let initialControllerMode = MixerControllerFactory.currentControllerMode()
        let showsMenuBarIcon = AppSettings.loadShowMenuBarIcon()
        let startsHiddenInMenuBar = AppSettings.loadStartHiddenInMenuBar()
        let menuBarImage = NSImage(named: "MenuBarIcon") ?? NSImage()
        menuBarImage.isTemplate = true
        menuBarImage.size = NSSize(width: 18, height: 18)

        _controllerMode = State(initialValue: initialControllerMode)
        _showMenuBarIcon = State(initialValue: showsMenuBarIcon)
        _viewModel = State(
            initialValue: MixerScreenViewModel(
                controller: MixerControllerFactory.makeMixerController(mode: initialControllerMode)
            )
        )
        menuBarStatusItemController = MenuBarStatusItemController(image: menuBarImage)

        if showsMenuBarIcon && startsHiddenInMenuBar {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    var body: some Scene {
        let _ = syncMenuBarStatusItem()

        Window("Qu Controller", id: AppWindowID.main) {
            ContentView(
                viewModel: viewModel,
                isUsingMockConnection: controllerMode.usesMockConnection,
                onSetUseMockConnection: updateMockConnectionUsage(_:)
            )
                .background(
                    OpenMainWindowRegistrar { reopen in
                        appVisibilityController.reopenMainWindow = reopen
                    }
                )
                .background(
                    MainWindowObserver { window in
                        appVisibilityController.attachMainWindow(window)
                    }
                )
        }
        .defaultLaunchBehavior(shouldSuppressMainWindowOnLaunch ? .suppressed : .automatic)

        Settings {
            SettingsView(
                viewModel: viewModel,
                onSetShowMenuBarIcon: setShowMenuBarIcon(_:)
            )
        }
        .windowResizability(.contentSize)
        .commands {
            AppSettingsCommands {
                menuBarStatusItemController.closePopover()
            }
        }
    }

    private var shouldSuppressMainWindowOnLaunch: Bool {
        viewModel.showMenuBarIcon && viewModel.startHiddenInMenuBar
    }

    @MainActor
    private func updateMockConnectionUsage(_ usesMockConnection: Bool) {
        let nextMode: MixerControllerFactory.ControllerMode = usesMockConnection ? .mock : .network
        guard nextMode != controllerMode else {
            return
        }

        if usesMockConnection {
            viewModel.stopScanningForMixer()
        }

        controllerMode = nextMode
        MixerControllerFactory.setDebugControllerMode(nextMode)
        viewModel = MixerScreenViewModel(
            controller: MixerControllerFactory.makeMixerController(mode: nextMode)
        )
        showMenuBarIcon = viewModel.showMenuBarIcon
        syncMenuBarStatusItem()
    }

    @MainActor
    private func setShowMenuBarIcon(_ isVisible: Bool) {
        viewModel.setShowMenuBarIcon(isVisible)
        showMenuBarIcon = viewModel.showMenuBarIcon
        syncMenuBarStatusItem()
        if showMenuBarIcon, appVisibilityController.mainWindow == nil {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }

    @MainActor
    private func syncMenuBarStatusItem() {
        menuBarStatusItemController.update(
            isVisible: showMenuBarIcon,
            rootView: AnyView(
                MenuBarMixerView(
                    viewModel: viewModel,
                    showMainWindow: {
                        menuBarStatusItemController.closePopover()
                        appVisibilityController.showMainWindow()
                    },
                    closePopover: {
                        menuBarStatusItemController.closePopover()
                    },
                    registerOpenMainWindow: { reopen in
                        appVisibilityController.reopenMainWindow = reopen
                    }
                )
            )
        )
    }
}

private struct AppSettingsCommands: Commands {
    let prepareToOpenSettings: () -> Void
    @Environment(\.openSettings) private var openSettings

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                prepareToOpenSettings()
                openSettings()

                DispatchQueue.main.async {
                    for window in NSApp.windows where window.identifier?.rawValue == "com.apple.SwiftUI.Settings" {
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()
                    }
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
