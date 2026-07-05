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
    var reopenMainWindow: (() -> Void)?

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

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.orderFrontRegardless()
        } else {
            reopenMainWindow?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettingsWindow() {
        let settingsSelector = Selector(("showSettingsWindow:"))
        let preferencesSelector = Selector(("showPreferencesWindow:"))

        if NSApp.sendAction(settingsSelector, to: nil, from: nil) {
            return
        }

        _ = NSApp.sendAction(preferencesSelector, to: nil, from: nil)
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

struct OpenMainWindowRegistrar: View {
    let onRegister: (@escaping () -> Void) -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                onRegister {
                    openWindow(id: AppWindowID.main)
                }
            }
    }
}
