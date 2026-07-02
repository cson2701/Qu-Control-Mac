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
    @StateObject private var viewModel: MixerScreenViewModel

    init() {
        _viewModel = StateObject(
            wrappedValue: MixerScreenViewModel(
                controller: MixerControllerFactory.makeMixerController()
            )
        )
    }

    var body: some Scene {
        Window("Qu Controller", id: AppWindowID.main) {
            ContentView(viewModel: viewModel)
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
    }

    private var menuBarImage: NSImage {
        let image = NSImage(named: "MenuBarIcon") ?? NSImage()
        image.isTemplate = true
        image.size = menuBarIconSize
        return image
    }
}
