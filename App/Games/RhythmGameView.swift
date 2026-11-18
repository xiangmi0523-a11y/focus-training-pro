import SwiftUI
import BrainCore

/// 镜像画 · 复合节奏：左手和右手按不同拍子同时敲
struct RhythmGameView: View {
    let level: Int
    let onFinish: (GameResult) -> Void

    @State private var config: RhythmConfig
    @State private var ready = false
    @State private var startUptime: TimeInterval?
    @State private var leftTaps: [Double] = []
    @State private var rightTaps: [Double] = []
    @State private var leftFlash = false
    @State private var rightFlash = false
    @State private var finished = false
    @State private var metronome: Task<Void, Never>?
    @State private var start = Date()

    /// 第 0 轮只听不敲
    private let leadIn = 1

    init(level: Int, onFinish: @escaping (GameResult) -> Void) {
        self.level = level
        self.onFinish = onFinish
        _config = State(initialValue: RhythmConfig(level: level))
    }

    private var totalCycles: Int { leadIn + config.cycles }
    private var window: Double { min(0.18, 0.4 * config.cycle / Double(max(config.leftBeats, config.rightBeats))) }

    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                TimelineView(.animation(minimumInterval: 1 / 60)) { ctx in
                    let now = ProcessInfo.processInfo.systemUptime
                    let elapsed = startUptime.map { now - $0 } ?? 0
                    let cycleIndex = Int(elapsed / config.cycle)
                    let phase = (elapsed / config.cycle).truncatingRemainder(dividingBy: 1)
                    let guided = cycleIndex < leadIn + config.guidedCycles || !config.hideGuide
                    VStack(spacing: 14) {
                        statusLine(cycleIndex: cycleIndex)
                        sequencer(phase: startUptime == nil ? 0 : phase, visible: guided)
                    }
                    .onChange(of: cycleIndex >= totalCycles) { _, over in
                        if over && startUptime != nil && !finished { finish() }
                    }
                }
                .frame(height: 190)

                HStack(spacing: 0) {
                    padLabel(side: .left, beats: config.leftBeats, flash: leftFlash, color: Palette.purple)
                    Rectangle().fill(Palette.goldDeep.opacity(0.5)).frame(width: 1)
                    padLabel(side: .right, beats: config.rightBeats, flash: rightFlash, color: Palette.blue)
                }
                .overlay(MultiTouchPad { e in handle(e) }.disabled(!ready || finished))
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card.opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line, lineWidth: 0.8))

                Caption("左手 [\(config.leftBeats)] 下，右手 [\(config.rightBeats)] 下，同一个周期里均匀敲",
                        size: 13, weight: .regular, base: Palette.muted)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 14)

            if !ready {
                ReadyOverlay(subtitle: "先听一轮节拍，再跟着敲 · 后面会[撤掉提示]") { begin() }
            }
        }
        .onDisappear { metronome?.cancel() }
    }

    private func statusLine(cycleIndex: Int) -> some View {
        HStack {
            if startUptime == nil {
                Text("准备").font(.song(14, .bold)).foregroundColor(Palette.cream)
            } else if cycleIndex < leadIn {
                Text("先听节拍……").font(.song(14, .bold)).foregroundColor(Palette.gold)
            } else if cycleIndex < leadIn + config.guidedCycles {
                Text("跟着敲 · 有提示").font(.song(14, .bold)).foregroundColor(Palette.cream)
            } else {
                Text(config.hideGuide ? "提示撤掉了，保持节奏" : "保持节奏").font(.song(14, .bold)).foregroundColor(Palette.gold)
            }
            Spacer()
            Text("\(max(0, min(cycleIndex - leadIn + 1, config.cycles)))/\(config.cycles) 轮")
                .font(.digits(13, .bold)).foregroundColor(Palette.muted)
        }
    }

    /// 两行拍点 + 扫过的播放头
    private func sequencer(phase: Double, visible: Bool) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                VStack(spacing: 34) {
                    beatRow(beats: config.leftBeats, phase: phase, width: w, color: Palette.purple, label: "左")
                    beatRow(beats: config.rightBeats, phase: phase, width: w, color: Palette.blue, label: "右")
                }
                .padding(.top, 24)
                Rectangle()
                    .fill(Palette.goldBright)
                    .frame(width: 2, height: 120)
                    .shadow(color: Palette.gold, radius: 6)
                    .offset(x: 26 + (w - 40) * phase, y: 8)
                    .opacity(visible ? 1 : 0)
            }
        }
        .opacity(visible ? 1 : 0.18)
        .animation(.easeInOut(duration: 0.4), value: visible)
    }

    private func beatRow(beats: Int, phase: Double, width: CGFloat, color: Color, label: String) -> some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 26)
            Text(label).font(.song(12, .bold)).foregroundColor(color)
            ForEach(0..<beats, id: \.self) { b in
                let pos = Double(b) / Double(beats)
                let near = abs(phase - pos) < 0.04 || (b == 0 && phase > 0.96)
                Circle()
                    .fill(near ? color : color.opacity(0.35))
                    .frame(width: near ? 22 : 14, height: near ? 22 : 14)
                    .shadow(color: color.opacity(near ? 0.8 : 0), radius: 8)
                    .offset(x: 26 + (width - 40) * pos - (near ? 11 : 7))
            }
        }
        .frame(height: 24)
    }

    private func padLabel(side: PadSide, beats: Int, flash: Bool, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(flash ? 0.55 : 0.16)).frame(width: 120, height: 120)
                Circle().stroke(color.opacity(0.8), lineWidth: 1.5).frame(width: 120, height: 120)
                Image(systemName: side == .left ? "hand.point.up.left.fill" : "hand.point.up.left.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Palette.cream)
                    .scaleEffect(x: side == .left ? 1 : -1, y: 1)
            }
            .scaleEffect(flash ? 0.94 : 1)
            Text(side == .left ? "左手 · \(beats) 拍" : "右手 · \(beats) 拍").font(.song(15, .bold)).foregroundColor(Palette.cream)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func begin() {
        withAnimation { ready = true }
        start = Date()
        let s = ProcessInfo.processInfo.systemUptime + 0.3
        startUptime = s
        let cfg = config
        let lead = leadIn
        metronome = Task { @MainActor in
            // 合并左右拍点事件
            var events: [(Double, Bool)] = []
            for c in 0..<(lead + cfg.guidedCycles) {
                for b in 0..<cfg.leftBeats { events.append((Double(c) * cfg.cycle + Double(b) * cfg.cycle / Double(cfg.leftBeats), true)) }
                for b in 0..<cfg.rightBeats { events.append((Double(c) * cfg.cycle + Double(b) * cfg.cycle / Double(cfg.rightBeats), false)) }
            }
            events.sort { $0.0 < $1.0 }
            for (t, isLeft) in events {
                let wait = s + t - ProcessInfo.processInfo.systemUptime
                if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
                if Task.isCancelled { return }
                if isLeft { SFX.tick() } else { SFX.tock() }
            }
        }
    }

    private func handle(_ e: PadEvent) {
        guard case let .began(side, _, t) = e, let s = startUptime, !finished else { return }
        let rel = t - s
        Haptic.tap()
        if side == .left {
            leftTaps.append(rel)
            leftFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { leftFlash = false }
        } else {
            rightTaps.append(rel)
            rightFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { rightFlash = false }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        metronome?.cancel()
        let scored = (leadIn + config.guidedCycles)..<totalCycles
        let window = self.window
        let firstScored = Double(scored.lowerBound) * config.cycle - window
        let lExp = config.expectedTimes(beats: config.leftBeats, from: 0, cycles: scored)
        let rExp = config.expectedTimes(beats: config.rightBeats, from: 0, cycles: scored)
        let lTaps = leftTaps.filter { $0 >= firstScored }
        let rTaps = rightTaps.filter { $0 >= firstScored }
        let l = RhythmScorer.match(taps: lTaps, expected: lExp, window: window)
        let r = RhythmScorer.match(taps: rTaps, expected: rExp, window: window)
        let hit = (l.hitRate * Double(lExp.count) + r.hitRate * Double(rExp.count)) / Double(max(lExp.count + rExp.count, 1))
        let err = (l.meanError + r.meanError) / 2
        let score = RhythmScorer.score(hitRate: hit, meanError: err, window: window, extra: l.extra + r.extra,
                                       expectedCount: lExp.count + rExp.count)
        let outcome: Outcome = score >= 85 ? .excellent : (score >= 68 ? .pass : .fail)
        let headline: String
        switch outcome {
        case .excellent: headline = "两只手各走各的拍，[一点不乱]"
        case .pass: headline = "节奏基本稳住了，下次[撤掉提示]也能行"
        case .fail: headline = "先只看一只手，再慢慢[合起来]"
        }
        onFinish(GameResult(score: score, outcome: outcome, accuracy: hit, meanRT: err,
                            duration: Date().timeIntervalSince(start), headline: headline,
                            stats: [StatLine(label: "节奏", value: "\(config.leftBeats) : \(config.rightBeats)"),
                                    StatLine(label: "左手命中", value: Fmt.percent(l.hitRate)),
                                    StatLine(label: "右手命中", value: Fmt.percent(r.hitRate)),
                                    StatLine(label: "平均偏差", value: Fmt.ms(err)),
                                    StatLine(label: "多敲", value: "\(l.extra + r.extra) 下"),
                                    StatLine(label: "周期", value: Fmt.seconds(config.cycle))]))
    }
}
