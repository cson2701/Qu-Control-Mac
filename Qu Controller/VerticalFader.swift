//
//  VerticalFader.swift
//  Qu Controller
//

import AppKit
import SwiftUI

struct VerticalFader: View {
    let channel: MixerChannelState
    let isEnabled: Bool
    let onLevelChange: (FaderLevel) -> Void

    private let minimumSliderHeight: CGFloat = 280

    var body: some View {
        VStack(spacing: 14) {
            Text(channel.id.displayName)
                .font(.title3.weight(.semibold))

            Text("\(channel.level.percentage)%")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 72)

            NativeVerticalSlider(value: channel.level.normalized, isEnabled: isEnabled) { normalized in
                onLevelChange(FaderLevel(normalized: normalized))
            }
            .allowsHitTesting(isEnabled)
            .grayscale(isEnabled ? 0 : 1)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .frame(minWidth: 56, maxWidth: 56, minHeight: minimumSliderHeight, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct NativeVerticalSlider: NSViewRepresentable {
    let value: Double
    let isEnabled: Bool
    let onValueChange: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onValueChange: onValueChange, isEnabled: isEnabled)
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = GuardedVerticalSlider(
            value: value,
            minValue: 0,
            maxValue: 1,
            target: context.coordinator,
            action: #selector(Coordinator.valueChanged(_:))
        )
        slider.sliderType = .linear
        slider.isVertical = true
        slider.isEnabled = isEnabled
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        slider.controlSize = .regular
        slider.isContinuous = true
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        context.coordinator.onValueChange = onValueChange
        context.coordinator.isEnabled = isEnabled
        nsView.isEnabled = isEnabled
        if abs(nsView.doubleValue - value) > 0.0001 {
            nsView.doubleValue = value
        }
    }

    final class Coordinator: NSObject {
        var onValueChange: (Double) -> Void
        var isEnabled: Bool

        init(onValueChange: @escaping (Double) -> Void, isEnabled: Bool) {
            self.onValueChange = onValueChange
            self.isEnabled = isEnabled
        }

        @objc func valueChanged(_ sender: NSSlider) {
            guard isEnabled else {
                return
            }
            onValueChange(sender.doubleValue)
        }
    }
}

private final class GuardedVerticalSlider: NSSlider {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled else {
            return nil
        }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        super.mouseDragged(with: event)
    }
}
