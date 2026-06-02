//
//  ChunkyScroller.swift
//  Vimac
//
//  Created by Dexter Leng on 14/6/20.
//  Copyright © 2020 Dexter Leng. All rights reserved.
//

import Cocoa

class ChunkyScroller: Scroller {
    /// Tick rate for j/k/l/h smooth scrolling. Higher rate + smaller deltas feels less stepped.
    private static let smoothScrollTicksPerSecond: Double = 120
    /// Historical smooth-scroll rate; used to preserve pixels/second when sensitivity is unchanged.
    private static let legacySmoothScrollTicksPerSecond: Double = 50

    private enum ScrollStyle {
        case discrete(xAxis: Int32, yAxis: Int32)
        case continuous(deltaX: Double, deltaY: Double)
    }

    static func instantiate(direction: ScrollDirection, scrollAmount: Int) -> ChunkyScroller {
        var xAxis = Int32(0)
        var yAxis = Int32(0)

        switch direction {
            case .halfLeft:
                xAxis = Int32(scrollAmount)
            case .halfRight:
                xAxis = Int32(-scrollAmount)
            case .halfDown:
                yAxis = Int32(-scrollAmount)
            case .halfUp:
                yAxis = Int32(scrollAmount)
            default:
                fatalError("<direction> scroll directions should not used for SmoothScroller")
        }

        let isHorizontalScrollReversed = UserPreferences.ScrollMode.ReverseHorizontalScrollProperty.read()
        let isVerticalScrollReversed = UserPreferences.ScrollMode.ReverseVerticalScrollProperty.read()

        if isHorizontalScrollReversed {
            xAxis = -xAxis
        }

        if isVerticalScrollReversed {
            yAxis = -yAxis
        }

        let frequency = 0.25

        return ChunkyScroller(frequency: frequency, style: .discrete(xAxis: xAxis, yAxis: yAxis))
    }

    static func instantiateForSmoothScroll(direction: ScrollDirection) -> ChunkyScroller {
        let sensitivity = UserPreferences.ScrollMode.ScrollSensitivityProperty.read()

        var xAxis = Int32(0)
        var yAxis = Int32(0)

        switch direction {
            case .left:
                xAxis = Int32(sensitivity)
            case .right:
                xAxis = Int32(-sensitivity)
            case .down:
                yAxis = Int32(-sensitivity)
            case .up:
                yAxis = Int32(sensitivity)
            case .bottom:
                yAxis = Int32(Int16.min)
            case .top:
                // Some applications (VS Code) have issues using Int32.max to scroll. Instead of scrolling to the top, they scroll to the bottom.
                // Not sure what causes this.
                yAxis = Int32(Int16.max)
            default:
                fatalError("half-<direction> scroll directions should not used for smooth scrolling")
        }

        let isHorizontalScrollReversed = UserPreferences.ScrollMode.ReverseHorizontalScrollProperty.read()
        let isVerticalScrollReversed = UserPreferences.ScrollMode.ReverseVerticalScrollProperty.read()

        var frequency: Double
        if ![.bottom, .top].contains(direction) {
            if isHorizontalScrollReversed {
                xAxis = -xAxis
            }

            if isVerticalScrollReversed {
                yAxis = -yAxis
            }

            let pixelsPerSecond = Double(sensitivity) * legacySmoothScrollTicksPerSecond
            let deltaPerTick = pixelsPerSecond / smoothScrollTicksPerSecond
            frequency = 1.0 / smoothScrollTicksPerSecond
            return ChunkyScroller(
                frequency: frequency,
                style: .continuous(
                    deltaX: Double(xAxis.signum()) * deltaPerTick,
                    deltaY: Double(yAxis.signum()) * deltaPerTick
                )
            )
        }
        else {
            frequency = 0.25
            return ChunkyScroller(frequency: frequency, style: .discrete(xAxis: xAxis, yAxis: yAxis))
        }
    }

    private let frequency: TimeInterval
    private let style: ScrollStyle

    private var timer: Timer?
    private var scrollGestureActive = false
    private var remainderX: Double = 0
    private var remainderY: Double = 0

    private init(frequency: TimeInterval, style: ScrollStyle) {
        self.frequency = frequency
        self.style = style
    }

    @objc func emitScrollEvent() {
        switch style {
        case .discrete(let xAxis, let yAxis):
            postScrollEvent(wheel1: yAxis, wheel2: xAxis, usePhases: false)
        case .continuous(let deltaX, let deltaY):
            remainderX += deltaX
            remainderY += deltaY

            let wheel2 = extractPixels(from: &remainderX)
            let wheel1 = extractPixels(from: &remainderY)
            guard wheel1 != 0 || wheel2 != 0 else { return }

            let phase: CGScrollPhase = scrollGestureActive ? .changed : .began
            scrollGestureActive = true
            postScrollEvent(wheel1: wheel1, wheel2: wheel2, usePhases: true, phase: phase)
        }
    }

    func start() {
        if timer != nil {
            fatalError("Do not call start() more than once.")
        }

        emitScrollEvent()
        self.timer = Timer.scheduledTimer(timeInterval: frequency, target: self, selector: #selector(emitScrollEvent), userInfo: nil, repeats: true)
    }

    func stop() {
        timer?.invalidate()
        self.timer = nil

        if scrollGestureActive {
            postScrollEvent(wheel1: 0, wheel2: 0, usePhases: true, phase: .ended)
            scrollGestureActive = false
            remainderX = 0
            remainderY = 0
        }
    }

    private func extractPixels(from value: inout Double) -> Int32 {
        guard abs(value) >= 1 else { return 0 }
        let pixels = Int32(value)
        value -= Double(pixels)
        return pixels
    }

    private func postScrollEvent(wheel1: Int32, wheel2: Int32, usePhases: Bool, phase: CGScrollPhase = .changed) {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: wheel1, wheel2: wheel2, wheel3: 0)!
        if usePhases {
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase.rawValue))
            event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(CGMomentumScrollPhase.none.rawValue))
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        }
        event.post(tap: .cghidEventTap)
    }
}

private extension Int32 {
    func signum() -> Int {
        if self > 0 { return 1 }
        if self < 0 { return -1 }
        return 0
    }
}
