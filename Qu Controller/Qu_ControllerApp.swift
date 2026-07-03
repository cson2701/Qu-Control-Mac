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

    init() {
        let initialControllerMode = MixerControllerFactory.currentControllerMode()
        _controllerMode = State(initialValue: initialControllerMode)
        _viewModel = State(
            initialValue: MixerScreenViewModel(
                controller: MixerControllerFactory.makeMixerController(mode: initialControllerMode)
            )
        )
    }

    var body: some Scene {
        Window("Qu Controller", id: AppWindowID.main) {
            ContentView(
                viewModel: viewModel,
                isUsingMockConnection: controllerMode.usesMockConnection,
                onSetUseMockConnection: updateMockConnectionUsage(_:)
            )
                .background(
                    MainWindowObserver { window in
                        appVisibilityController.attachMainWindow(window)
                    }
                )
        }

        MenuBarExtra {
            MenuBarMixerView(
                viewModel: viewModel,
                showMainWindow: {
                    appVisibilityController.showMainWindow(openWindow: $0)
                }
            )
        } label: {
            Image(nsImage: menuBarImage)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
    }

    private var menuBarImage: NSImage {
        let image = NSImage(named: "MenuBarIcon") ?? NSImage()
        image.isTemplate = true
        image.size = menuBarIconSize
        return image
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
    }
}
