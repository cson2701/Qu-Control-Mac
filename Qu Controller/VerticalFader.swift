//
//  VerticalFader.swift
//  Qu Controller
//

import AppKit
import SwiftUI

struct VerticalFader: View {
    let channel: MixerChannelState
    let isEnabled: Bool
    let showsSignalIndicator: Bool
    let onLevelChange: (FaderLevel) -> Void

    private let minimumSliderHeight: CGFloat = 160
    private var levelLabel: String {
        isEnabled ? "\(channel.level.percentage)%" : "--"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                if showsSignalIndicator {
                    SignalDot(isActive: isEnabled && channel.hasSignal)
                }

                Text(channel.displayName)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80)

            Text(levelLabel)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 64)

            NativeVerticalSlider(value: channel.level.normalized, isEnabled: isEnabled) { normalized in
                onLevelChange(FaderLevel(normalized: normalized))
            }
            .allowsHitTesting(isEnabled)
            .grayscale(isEnabled ? 0 : 1)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .frame(minWidth: 56, maxWidth: 56, minHeight: minimumSliderHeight, maxHeight: .infinity)
            .layoutPriority(1)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SignalDot: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.gray.opacity(0.6))
            .frame(width: 8, height: 8)
            .animation(.easeInOut(duration: 0.2), value: isActive)
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
