import SwiftUI
import BrainCore

/// 深棕近黑 + 纸张颗粒 + 中央柔光 + 暗角
struct InkBackground: View {
    var glow: Double = 1
    var tint: Color = Palette.gold

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.ink2, Palette.ink], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [tint.opacity(0.09 * glow), .clear], center: .init(x: 0.5, y: 0.38),
                           startRadius: 10, endRadius: 460)
            GrainOverlay()
            RadialGradient(colors: [.clear, .black.opacity(0.6)], center: .center, startRadius: 260, endRadius: 720)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct GrainOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 20261118)
            let count = Int(size.width * size.height / 260)
            for _ in 0..<count {
                let x = rng.double(in: 0...Double(size.width))
                let y = rng.double(in: 0...Double(size.height))
                let s = rng.double(in: 0.6...1.6)
                let o = rng.double(in: 0.015...0.06)
                let light = rng.chance(0.6)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                         with: .color((light ? Color.white : Color.black).opacity(o)))
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

/// 缓慢上浮的金色微光
struct FloatingMotes: View {
    var count: Int = 22
    var color: Color = Palette.gold

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                var rng = SeededRNG(seed: 77)
                for _ in 0..<count {
                    let baseX = rng.double(in: 0...1)
                    let speed = rng.double(in: 0.008...0.025)
                    let phase = rng.double(in: 0...1)
                    let r = rng.double(in: 0.8...2.2)
                    let wobble = rng.double(in: 6...18)
                    let p = (phase + t * speed).truncatingRemainder(dividingBy: 1)
                    let y = Double(size.height) * (1 - p)
                    let x = baseX * Double(size.width) + sin(t * 0.6 + phase * 9) * wobble
                    let alpha = sin(p * .pi) * 0.55
                    let rect = CGRect(x: x, y: y, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect.insetBy(dx: -r * 1.5, dy: -r * 1.5)), with: .color(color.opacity(alpha * 0.18)))
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 舞台聚光灯（记忆清单 / 故事）
struct SpotlightCone: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: w * 0.42, y: 0))
                p.addLine(to: CGPoint(x: w * 0.58, y: 0))
                p.addLine(to: CGPoint(x: w * 0.86, y: h))
                p.addLine(to: CGPoint(x: w * 0.14, y: h))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [Palette.goldBright.opacity(0.26), Palette.gold.opacity(0.05)],
                                 startPoint: .top, endPoint: .bottom))
            .blur(radius: 6)
        }
        .allowsHitTesting(false)
    }
}

struct StagePlatform: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [Palette.ink3, Palette.ink], startPoint: .top, endPoint: .bottom))
                .frame(height: 46)
                .offset(y: 10)
            Ellipse()
                .fill(RadialGradient(colors: [Palette.goldDeep.opacity(0.45), Palette.ink3], center: .center,
                                     startRadius: 4, endRadius: 120))
                .overlay(Ellipse().stroke(Palette.goldDeep.opacity(0.55), lineWidth: 1))
                .frame(height: 40)
        }
    }
}
