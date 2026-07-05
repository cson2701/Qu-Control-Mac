import AppKit
import SwiftUI

struct WindowKeyPressHandler: NSViewRepresentable {
    let key: String
    let modifiers: NSEvent.ModifierFlags
    let onKeyPress: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(key: key, modifiers: modifiers, onKeyPress: onKeyPress)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.key = key
        context.coordinator.modifiers = modifiers
        context.coordinator.onKeyPress = onKeyPress
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        var key: String
        var modifiers: NSEvent.ModifierFlags
        var onKeyPress: () -> Void

        private weak var view: NSView?
        private var monitor: Any?

        init(key: String, modifiers: NSEvent.ModifierFlags, onKeyPress: @escaping () -> Void) {
            self.key = key
            self.modifiers = modifiers
            self.onKeyPress = onKeyPress
        }

        deinit {
            detach()
        }

        func attach(to view: NSView) {
            self.view = view

            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }

                guard let window = self.view?.window,
                      window.isKeyWindow,
                      event.window === window else {
                    return event
                }

                let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard eventModifiers == self.modifiers,
                      event.charactersIgnoringModifiers?.lowercased() == self.key.lowercased() else {
                    return event
                }

                self.onKeyPress()
                return nil
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
