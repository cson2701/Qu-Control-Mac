//
//  VerticalFader.swift
//  Qu Controller
//

import AppKit
import SwiftUI

struct VerticalFader: View {
    let channel: MixerChannelState
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

            NativeVerticalSlider(value: channel.level.normalized) { normalized in
                onLevelChange(FaderLevel(normalized: normalized))
            }
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
    let onValueChange: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onValueChange: onValueChange)
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: 0, maxValue: 1, target: context.coordinator, action: #selector(Coordinator.valueChanged(_:)))
        slider.sliderType = .linear
        slider.isVertical = true
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        slider.controlSize = .regular
        slider.isContinuous = true
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        context.coordinator.onValueChange = onValueChange
        if abs(nsView.doubleValue - value) > 0.0001 {
            nsView.doubleValue = value
        }
    }

    final class Coordinator: NSObject {
        var onValueChange: (Double) -> Void

        init(onValueChange: @escaping (Double) -> Void) {
            self.onValueChange = onValueChange
        }

        @objc func valueChanged(_ sender: NSSlider) {
            onValueChange(sender.doubleValue)
        }
    }
}
