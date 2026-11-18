import SwiftUI
import UIKit

enum PadSide { case left, right }

enum PadEvent {
    case began(PadSide, CGPoint, TimeInterval)
    case moved(PadSide, CGPoint, TimeInterval)
    case ended(PadSide, TimeInterval)
}

/// 支持双指同时操作的触控层：每根手指按起点归属左/右半边
struct MultiTouchPad: UIViewRepresentable {
    let onEvent: (PadEvent) -> Void

    func makeUIView(context: Context) -> TouchPadView {
        let v = TouchPadView()
        v.onEvent = onEvent
        return v
    }

    func updateUIView(_ uiView: TouchPadView, context: Context) {
        uiView.onEvent = onEvent
    }
}

final class TouchPadView: UIView {
    var onEvent: ((PadEvent) -> Void)?
    private var owners: [ObjectIdentifier: PadSide] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 统一用开机以来的时间
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self)
            let side: PadSide = p.x < bounds.midX ? .left : .right
            owners[ObjectIdentifier(t)] = side
            onEvent?(.began(side, p, t.timestamp))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let side = owners[ObjectIdentifier(t)] else { continue }
            let coalesced = event?.coalescedTouches(for: t) ?? [t]
            for c in coalesced {
                onEvent?(.moved(side, c.location(in: self), c.timestamp))
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        for t in touches {
            if let side = owners.removeValue(forKey: ObjectIdentifier(t)) {
                onEvent?(.ended(side, t.timestamp))
            }
        }
    }
}
