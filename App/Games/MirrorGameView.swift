import SwiftUI
import BrainCore

struct MirrorGameView: View {
    let mode: ModeID
    let level: Int
    let onFinish: (GameResult) -> Void

    @State private var config: MirrorConfig
    @State private var rng: SeededRNG
    @State private var ready = false
    @State private var round = 0
    @State private var leftKind: ShapeKind = .circle
    @State private var rightKind: ShapeKind = .circle
    @State private var left: TraceTracker
    @State private var right: TraceTracker
    @State private var leftStrokes: [[Vec2]] = []
    @State private var rightStrokes: [[Vec2]] = []
    @State private var leftSamples: [(t: Double, p: Double)] = []
    @State private var rightSamples: [(t: Double, p: Double)] = []
    @State private var activeLeft = 0
    @State private var activeRight = 0
    @State private var roundStart: TimeInterval?
    @State private var roundStartDate: Date?
    @State private var roundScores: [Int] = []
    @State private var syncs: [Double] = []
    @State private var accL: [Double] = []
    @State private var accR: [Double] = []
    @State private var showRoundScore: Int?
    @State private var padSize: CGSize = .zero
    @State private var ended = false
    @State private var start = Date()

    private let inset: CGFloat = 10

    init(mode: ModeID, level: Int, onFinish: @escaping (GameResult) -> Void) {
        self.mode = mode
        self.level = level
        self.onFinish = onFinish
        let c = MirrorConfig(mode: mode, level: level)
        _config = State(initialValue: c)
        _rng = State(initialValue: SeededRNG.random())
        _left = State(initialValue: TraceTracker(target: [], tolerance: c.tolerance))
        _right = State(initialValue: TraceTracker(target: [], tolerance: c.tolerance))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                header
                Spacer(minLength: 0)
                canvas
                Spacer(minLength: 0)
                Caption(footerText, size: 14, weight: .regular, base: Palette.muted)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 12)

            if let s = showRoundScore {
                VStack(spacing: 8) {
                    Text("\(s)").font(.digits(60, .bold)).foregroundStyle(Palette.goldGradient)
                    Text(s >= config.passScore ? "协调得不错" : "再稳一点").font(.song(15)).foregroundColor(Palette.cream)
                }
                .padding(30)
                .background(RoundedRectangle(cornerRadius: 20).fill(Palette.ink.opacity(0.85)))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.goldDeep, lineWidth: 1))
                .transition(.scale.combined(with: .opacity))
            }
            if !ready {
                ReadyOverlay(subtitle: readyText) {
                    withAnimation { ready = true }
                    start = Date()
                    setupRound()
                }
            }
        }
    }

    private var readyText: String {
        switch mode {
        case .mirrorParallel: return "两根手指[方向相同]，同时画"
        case .mirrorDifferent: return "左手和右手画[不同的图形]，同时画"
        default: return "两根手指[方向相反]，同时画，像照镜子"
        }
    }

    private var footerText: String {
        if roundStart == nil { return "两根手指各放在[金色起点]上，一起开始" }
        return "左右脑一起[协作]"
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("第 \(min(round + 1, config.rounds))/\(config.rounds) 幅").font(.song(14, .bold)).foregroundColor(Palette.cream)
                HStack(spacing: 6) {
                    RuleChip(text: "左 · \(leftKind.name)")
                    RuleChip(text: "右 · \(rightKind.name)\(mode == .mirrorSymmetric ? "（镜像）" : "")")
                }
                HStack(spacing: 10) {
                    coverageBar("左", left.coverage)
                    coverageBar("右", right.coverage)
                }
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                let elapsed = roundStartDate.map { ctx.date.timeIntervalSince($0) } ?? 0
                let remaining = max(0, config.timeLimit - elapsed)
                RingTimer(fraction: remaining / config.timeLimit, label: String(format: "%.0f", remaining.rounded(.up)), size: 66)
                    .onChange(of: remaining <= 0) { _, over in
                        if over && roundStartDate != nil && !ended { endRound() }
                    }
            }
        }
    }

    private func coverageBar(_ label: String, _ v: Double) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.song(10)).foregroundColor(Palette.muted)
            GoldBar(fraction: v, height: 3).frame(width: 60)
        }
    }

    private var canvas: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Canvas { g, sz in
                    draw(&g, size: sz)
                }
                MultiTouchPad { event in handle(event) }
                    .disabled(!ready || ended || showRoundScore != nil)
            }
            .onAppear { padSize = size }
            .onChange(of: size) { _, s in padSize = s }
        }
        .frame(height: 260)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 0.8))
    }

    private func rect(for side: PadSide, in size: CGSize) -> CGRect {
        let half = size.width / 2
        let s = min(half - inset * 2, size.height - inset * 2)
        let y = (size.height - s) / 2
        let x = side == .left ? (half - s) / 2 : half + (half - s) / 2
        return CGRect(x: x, y: y, width: s, height: s)
    }

    private func toView(_ v: Vec2, _ r: CGRect) -> CGPoint {
        CGPoint(x: r.minX + CGFloat(v.x) * r.width, y: r.minY + CGFloat(v.y) * r.height)
    }

    private func draw(_ g: inout GraphicsContext, size: CGSize) {
        // 中线
        var mid = Path()
        mid.move(to: CGPoint(x: size.width / 2, y: 12))
        mid.addLine(to: CGPoint(x: size.width / 2, y: size.height - 12))
        g.stroke(mid, with: .color(Palette.goldDeep.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        for side in [PadSide.left, PadSide.right] {
            let r = rect(for: side, in: size)
            let tracker = side == .left ? left : right
            let strokes = side == .left ? leftStrokes : rightStrokes
            // 目标轮廓（覆盖到的部分变亮）
            if !tracker.target.isEmpty {
                var path = Path()
                path.move(to: toView(tracker.target[0], r))
                for p in tracker.target.dropFirst() { path.addLine(to: toView(p, r)) }
                g.stroke(path, with: .color(Palette.gold.opacity(0.22)),
                         style: StrokeStyle(lineWidth: CGFloat(config.tolerance) * r.width * 1.2, lineCap: .round, lineJoin: .round))
                g.stroke(path, with: .color(Palette.goldDeep.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                // 起点
                let s = toView(tracker.target[0], r)
                g.fill(Path(ellipseIn: CGRect(x: s.x - 7, y: s.y - 7, width: 14, height: 14)), with: .color(Palette.goldBright))
                g.stroke(Path(ellipseIn: CGRect(x: s.x - 12, y: s.y - 12, width: 24, height: 24)),
                         with: .color(Palette.gold.opacity(0.5)), lineWidth: 1)
                // 方向箭头
                if tracker.target.count > 8 {
                    let a = toView(tracker.target[4], r), b = toView(tracker.target[8], r)
                    let ang = atan2(b.y - a.y, b.x - a.x)
                    var arrow = Path()
                    arrow.move(to: CGPoint(x: b.x + cos(ang) * 6, y: b.y + sin(ang) * 6))
                    arrow.addLine(to: CGPoint(x: b.x + cos(ang + 2.5) * 7, y: b.y + sin(ang + 2.5) * 7))
                    arrow.addLine(to: CGPoint(x: b.x + cos(ang - 2.5) * 7, y: b.y + sin(ang - 2.5) * 7))
                    arrow.closeSubpath()
                    g.fill(arrow, with: .color(Palette.gold.opacity(0.8)))
                }
            }
            // 用户的笔迹
            for stroke in strokes where stroke.count > 1 {
                var path = Path()
                path.move(to: toView(stroke[0], r))
                for p in stroke.dropFirst() { path.addLine(to: toView(p, r)) }
                var glow = g
                glow.addFilter(.blur(radius: 4))
                glow.stroke(path, with: .color(Palette.gold.opacity(0.6)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                g.stroke(path, with: .color(side == .left ? Color(hex: 0xFFE9B8) : Color(hex: 0xFFE9B8)),
                         style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func normalized(_ p: CGPoint, side: PadSide) -> Vec2 {
        let r = rect(for: side, in: padSize)
        return Vec2(Double((p.x - r.minX) / max(r.width, 1)), Double((p.y - r.minY) / max(r.height, 1)))
    }

    private func handle(_ e: PadEvent) {
        guard ready, !ended, showRoundScore == nil else { return }
        switch e {
        case let .began(side, p, t):
            if roundStart == nil { roundStart = t; roundStartDate = Date() }
            let v = normalized(p, side: side)
            if side == .left {
                activeLeft += 1
                leftStrokes.append([v])
                left.add(v)
                leftSamples.append((t - (roundStart ?? t), left.coverage))
            } else {
                activeRight += 1
                rightStrokes.append([v])
                right.add(v)
                rightSamples.append((t - (roundStart ?? t), right.coverage))
            }
        case let .moved(side, p, t):
            let v = normalized(p, side: side)
            let rel = t - (roundStart ?? t)
            if side == .left {
                if leftStrokes.isEmpty { leftStrokes.append([]) }
                leftStrokes[leftStrokes.count - 1].append(v)
                left.add(v)
                leftSamples.append((rel, left.coverage))
            } else {
                if rightStrokes.isEmpty { rightStrokes.append([]) }
                rightStrokes[rightStrokes.count - 1].append(v)
                right.add(v)
                rightSamples.append((rel, right.coverage))
            }
        case let .ended(side, _):
            if side == .left { activeLeft = max(0, activeLeft - 1) } else { activeRight = max(0, activeRight - 1) }
            let r = round
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                guard r == round, !ended, showRoundScore == nil, activeLeft == 0, activeRight == 0 else { return }
                let enough = left.drawn.count > 12 && right.drawn.count > 12
                let complete = left.coverage > 0.75 && right.coverage > 0.75
                if enough && (complete || left.coverage + right.coverage > 1.0) { endRound() }
            }
        }
    }

    private func setupRound() {
        let t = config.targets(rng: &rng)
        leftKind = t.left
        rightKind = t.right
        left = TraceTracker(target: t.leftPoints, tolerance: config.tolerance)
        right = TraceTracker(target: t.rightPoints, tolerance: config.tolerance)
        leftStrokes = []
        rightStrokes = []
        leftSamples = []
        rightSamples = []
        activeLeft = 0
        activeRight = 0
        roundStart = nil
        roundStartDate = nil
    }

    private func endRound() {
        guard showRoundScore == nil else { return }
        let sync = MirrorScorer.synchrony(left: leftSamples, right: rightSamples)
        let score = MirrorScorer.roundScore(left: left, right: right, synchrony: sync)
        roundScores.append(score)
        syncs.append(sync)
        accL.append(left.accuracy)
        accR.append(right.accuracy)
        roundStartDate = nil
        if score >= config.passScore { Haptic.success(); SFX.correct() } else { Haptic.error() }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showRoundScore = score }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation { showRoundScore = nil }
            if round + 1 >= config.rounds {
                ended = true
                finish()
            } else {
                round += 1
                setupRound()
            }
        }
    }

    private func finish() {
        let avg = roundScores.isEmpty ? 0 : Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        let outcome = MirrorScorer.outcome(average: avg, config: config)
        func mean(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }
        let headline: String
        switch outcome {
        case .excellent: headline = "两只手像一个人在画，[左右脑]配合默契"
        case .pass: headline = "先画圆，再画心，熟练了画[复杂图案]"
        case .fail: headline = "慢一点没关系，先让两只手[同步]"
        }
        onFinish(GameResult(score: Int(avg.rounded()), outcome: outcome, accuracy: (mean(accL) + mean(accR)) / 2,
                            meanRT: nil, duration: Date().timeIntervalSince(start), headline: headline,
                            stats: [StatLine(label: "三幅得分", value: roundScores.map(String.init).joined(separator: " · ")),
                                    StatLine(label: "左手精度", value: Fmt.percent(mean(accL))),
                                    StatLine(label: "右手精度", value: Fmt.percent(mean(accR))),
                                    StatLine(label: "同步度", value: Fmt.percent(mean(syncs))),
                                    StatLine(label: "容差", value: Fmt.percent(config.tolerance))]))
    }
}
