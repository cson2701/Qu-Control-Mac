//
//  AppVisibilityController.swift
//  Qu Controller
//

import AppKit
import SwiftUI

enum AppWindowID {
    static let main = "main-window"
}

@MainActor
final class AppVisibilityController: NSObject, NSApplicationDelegate {
    weak var mainWindow: NSWindow?

    private var observedWindow: NSWindow?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func attachMainWindow(_ window: NSWindow?) {
        guard observedWindow !== window else {
            return
        }

        detachObservedWindow()

        observedWindow = window
        mainWindow = window

        if let window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleMainWindowWillClose),
                name: NSWindow.willCloseNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleMainWindowDidBecomeKey),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            NSApp.setActivationPolicy(.regular)
        }
    }

    func showMainWindow(openWindow: OpenWindowAction) {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: AppWindowID.main)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleMainWindowWillClose(_ notification: Notification) {
        mainWindow = nil
        observedWindow = nil
        NSApp.setActivationPolicy(AppSettings.loadShowMenuBarIcon() ? .accessory : .regular)
    }

    @objc private func handleMainWindowDidBecomeKey(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    private func detachObservedWindow() {
        if let observedWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: observedWindow)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: observedWindow)
        }

        mainWindow = nil
        observedWindow = nil
    }
}

struct MainWindowObserver: NSViewRepresentable {
    let onWindowChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onWindowChange(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onWindowChange(nsView.window)
        }
    }
}
