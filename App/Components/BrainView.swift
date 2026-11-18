import SwiftUI
import BrainCore

/// 贯穿全片的金色大脑：7 个编号节点连线，练得越多越亮
struct BrainView: View {
    /// 七个训练的熟练度 1...30
    var levels: [Int] = Array(repeating: 1, count: 7)
    /// 0...1 启动动画：节点依次亮起
    var reveal: Double = 1
    var highlight: Int?
    var showSynapses = true
    var onTapNode: ((Int) -> Void)?

    static let canvas = CGSize(width: 300, height: 232)
    static let nodes: [CGPoint] = [
        CGPoint(x: 66, y: 98), CGPoint(x: 112, y: 46), CGPoint(x: 176, y: 40),
        CGPoint(x: 236, y: 76), CGPoint(x: 252, y: 132), CGPoint(x: 182, y: 112),
        CGPoint(x: 118, y: 138)
    ]

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Self.canvas.width, geo.size.height / Self.canvas.height)
            let ox = (geo.size.width - Self.canvas.width * scale) / 2
            let oy = (geo.size.height - Self.canvas.height * scale) / 2
            ZStack(alignment: .topLeading) {
                brainBody
                    .frame(width: Self.canvas.width, height: Self.canvas.height)
                    .scaleEffect(scale, anchor: .topLeading)
                    .offset(x: ox, y: oy)
                ForEach(0..<7, id: \.self) { i in
                    let p = Self.nodes[i]
                    nodeView(i)
                        .position(x: ox + p.x * scale, y: oy + p.y * scale)
                }
            }
        }
        .aspectRatio(Self.canvas.width / Self.canvas.height, contentMode: .fit)
    }

    private var brainBody: some View {
        ZStack {
            // 外光晕
            BrainSilhouette()
                .fill(Palette.gold.opacity(0.35 * reveal))
                .blur(radius: 26)
            BrainStem()
                .fill(LinearGradient(colors: [Palette.goldDeep, Palette.goldDark], startPoint: .top, endPoint: .bottom))
            BrainSilhouette()
                .fill(LinearGradient(colors: [Palette.goldBright, Palette.gold, Color(hex: 0xA7854F)],
                                     startPoint: UnitPoint(x: 0.2, y: 0.05), endPoint: UnitPoint(x: 0.85, y: 1)))
                .overlay(
                    BrainSilhouette()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.35), .clear],
                                             center: UnitPoint(x: 0.35, y: 0.25), startRadius: 2, endRadius: 120))
                )
                .opacity(0.35 + 0.65 * reveal)
            BrainFolds()
                .stroke(Color(hex: 0x8A6A3C).opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .opacity(0.4 + 0.6 * reveal)
            ConstellationLines(reveal: reveal, brightness: levels.map { brightness(for: $0) })
                .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            if showSynapses {
                Synapses(levels: levels, reveal: reveal)
                    .stroke(Palette.goldBright.opacity(0.75), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
        .compositingGroup()
        .shadow(color: Palette.gold.opacity(0.35 * reveal), radius: 22)
    }

    private func brightness(for level: Int) -> Double {
        0.35 + 0.65 * LevelSystem.fraction(level)
    }

    @ViewBuilder
    private func nodeView(_ i: Int) -> some View {
        let lit = reveal * 7 >= Double(i) + 0.5
        let b = brightness(for: i < levels.count ? levels[i] : 1)
        let isHi = highlight == i
        let node = ZStack {
            Circle()
                .fill(Palette.goldBright.opacity(lit ? 0.45 * b : 0))
                .frame(width: 30, height: 30)
                .blur(radius: 7)
            Circle()
                .fill(lit ? Color(hex: 0xFFF6E2) : Palette.goldDark)
                .frame(width: isHi ? 21 : 17, height: isHi ? 21 : 17)
                .overlay(Circle().stroke(Palette.goldDark.opacity(0.8), lineWidth: 1))
            Text("\(i + 1)")
                .font(.digits(9, .bold))
                .foregroundColor(Palette.goldDark)
        }
        .scaleEffect(lit ? 1 : 0.6)
        .opacity(lit ? 1 : 0.4)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: lit)

        if let onTapNode {
            Button { onTapNode(i) } label: { node.frame(width: 44, height: 44).contentShape(Rectangle()) }
                .buttonStyle(PressStyle())
        } else {
            node
        }
    }
}

struct BrainSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / BrainView.canvas.width
        let sy = rect.height / BrainView.canvas.height
        func e(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
            CGRect(x: (cx - rx) * sx, y: (cy - ry) * sy, width: rx * 2 * sx, height: ry * 2 * sy)
        }
        var p = Path()
        p.addEllipse(in: e(150, 106, 118, 72))
        p.addEllipse(in: e(74, 100, 58, 56))
        p.addEllipse(in: e(116, 60, 50, 42))
        p.addEllipse(in: e(178, 54, 54, 42))
        p.addEllipse(in: e(232, 84, 46, 44))
        p.addEllipse(in: e(246, 128, 38, 34))
        p.addEllipse(in: e(138, 146, 82, 36))
        p.addEllipse(in: e(212, 160, 40, 24))
        return p
    }
}

struct BrainStem: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / BrainView.canvas.width
        let sy = rect.height / BrainView.canvas.height
        var p = Path()
        p.move(to: CGPoint(x: 176 * sx, y: 160 * sy))
        p.addCurve(to: CGPoint(x: 186 * sx, y: 222 * sy), control1: CGPoint(x: 186 * sx, y: 182 * sy),
                   control2: CGPoint(x: 178 * sx, y: 206 * sy))
        p.addQuadCurve(to: CGPoint(x: 202 * sx, y: 220 * sy), control: CGPoint(x: 194 * sx, y: 230 * sy))
        p.addCurve(to: CGPoint(x: 200 * sx, y: 160 * sy), control1: CGPoint(x: 198 * sx, y: 200 * sy),
                   control2: CGPoint(x: 206 * sx, y: 180 * sy))
        p.closeSubpath()
        return p
    }
}

struct BrainFolds: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / BrainView.canvas.width
        let sy = rect.height / BrainView.canvas.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
        var p = Path()
        // 外侧裂（像视频里的「皱眉」线）
        p.move(to: pt(58, 132))
        p.addCurve(to: pt(214, 120), control1: pt(110, 112), control2: pt(160, 140))
        // 中央沟
        p.move(to: pt(160, 26))
        p.addCurve(to: pt(146, 104), control1: pt(150, 52), control2: pt(166, 80))
        // 额叶回
        p.move(to: pt(50, 88))
        p.addCurve(to: pt(108, 84), control1: pt(66, 70), control2: pt(92, 98))
        p.move(to: pt(88, 46))
        p.addQuadCurve(to: pt(120, 74), control: pt(118, 48))
        // 顶叶回
        p.move(to: pt(196, 34))
        p.addCurve(to: pt(232, 66), control1: pt(214, 42), control2: pt(206, 62))
        p.move(to: pt(186, 82))
        p.addQuadCurve(to: pt(252, 104), control: pt(230, 74))
        // 颞叶
        p.move(to: pt(92, 156))
        p.addQuadCurve(to: pt(166, 158), control: pt(128, 170))
        // 小脑纹
        p.move(to: pt(192, 162))
        p.addQuadCurve(to: pt(236, 160), control: pt(214, 172))
        p.move(to: pt(196, 152))
        p.addQuadCurve(to: pt(240, 150), control: pt(220, 160))
        return p
    }
}

struct ConstellationLines: Shape {
    var reveal: Double
    var brightness: [Double]

    var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / BrainView.canvas.width
        let sy = rect.height / BrainView.canvas.height
        let pts = BrainView.nodes.map { CGPoint(x: $0.x * sx, y: $0.y * sy) }
        var p = Path()
        let segments = 6.0 * reveal
        for i in 0..<6 {
            let amount = segments - Double(i)
            guard amount > 0 else { break }
            let a = pts[i], b = pts[i + 1]
            let u = CGFloat(min(1, amount))
            p.move(to: a)
            p.addLine(to: CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u))
        }
        return p
    }
}

/// 高熟练度节点长出的「突触」
struct Synapses: Shape {
    var levels: [Int]
    var reveal: Double

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / BrainView.canvas.width
        let sy = rect.height / BrainView.canvas.height
        let center = CGPoint(x: 160, y: 104)
        var p = Path()
        guard reveal >= 0.99 else { return p }
        for (i, node) in BrainView.nodes.enumerated() {
            let lv = i < levels.count ? levels[i] : 1
            let sprouts = min(3, lv / 7)
            guard sprouts > 0 else { continue }
            let base = atan2(node.y - center.y, node.x - center.x)
            for s in 0..<sprouts {
                let ang = base + (CGFloat(s) - CGFloat(sprouts - 1) / 2) * 0.45
                let len: CGFloat = 16 + CGFloat(s % 2) * 6
                let start = CGPoint(x: (node.x + cos(ang) * 9) * sx, y: (node.y + sin(ang) * 9) * sy)
                let end = CGPoint(x: (node.x + cos(ang) * (9 + len)) * sx, y: (node.y + sin(ang) * (9 + len)) * sy)
                p.move(to: start)
                p.addLine(to: end)
                p.addEllipse(in: CGRect(x: end.x - 1.6, y: end.y - 1.6, width: 3.2, height: 3.2))
            }
        }
        return p
    }
}
