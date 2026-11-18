import SwiftUI
import BrainCore

struct SortingGameView: View {
    let mode: ModeID
    let level: Int
    let onFinish: (GameResult) -> Void

    @State private var config: SortConfig
    @State private var rng: SeededRNG
    @State private var trials: [SortTrial]
    @State private var engine: HiddenRuleEngine
    @State private var current = 0
    @State private var ready = false
    @State private var finished = false
    @State private var trialStart = Date()
    @State private var start = Date()
    @State private var correctCount = 0
    @State private var rts: [Double] = []
    @State private var timeouts = 0
    @State private var switchErrors = 0
    @State private var bucketCounts = [0, 0, 0]
    @State private var feedback: Bool?
    @State private var flyTo: Int?
    @State private var drag: CGSize = .zero
    @State private var banner: String?
    @State private var timeoutTask: Task<Void, Never>?

    init(mode: ModeID, level: Int, onFinish: @escaping (GameResult) -> Void) {
        self.mode = mode
        self.level = level
        self.onFinish = onFinish
        var r = SeededRNG.random()
        let c = SortConfig(mode: mode, level: level)
        _config = State(initialValue: c)
        _trials = State(initialValue: SortGenerator.trials(config: c, rng: &r))
        _engine = State(initialValue: HiddenRuleEngine(runLength: c.hiddenRun, rng: &r))
        _rng = State(initialValue: r)
    }

    private var trial: SortTrial? { current < trials.count ? trials[current] : nil }
    private var isHidden: Bool { mode == .sortHidden }
    private var rule: SortRule { trial?.rule ?? .category }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                topBar
                Spacer(minLength: 0)
                itemStage
                Spacer(minLength: 0)
                buckets
                Caption(footer, size: 13, weight: .regular, base: Palette.muted)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 14)

            if let banner {
                Text(banner)
                    .font(.song(24, .bold))
                    .foregroundStyle(Palette.goldGradient)
                    .padding(.horizontal, 28).padding(.vertical, 16)
                    .background(Capsule().fill(Palette.ink.opacity(0.92)))
                    .overlay(Capsule().stroke(Palette.gold, lineWidth: 1.2))
                    .shadow(color: Palette.gold.opacity(0.5), radius: 16)
                    .transition(.scale.combined(with: .opacity))
            }
            if !ready {
                ReadyOverlay(subtitle: readyText) { begin() }
            }
        }
        .onDisappear { timeoutTask?.cancel() }
    }

    private var readyText: String {
        switch mode {
        case .sortSwitch: return "看清顶上的[规则]，规则一变马上切换"
        case .sortHidden: return "规则[不告诉你]，靠对错去猜——猜中后它还会偷偷换"
        default: return "看到东西，马上放进[对的桶]里"
        }
    }

    private var footer: String {
        if isHidden { return "已猜中规则 [\(engine.categoriesDone)] 次" }
        return "点桶或把卡片[拖进去]都可以"
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                if isHidden {
                    RuleChip(text: "规则：？")
                } else {
                    ForEach(config.rules, id: \.self) { r in
                        RuleChip(text: "规则：\(r.title)", active: r == rule)
                    }
                }
                Spacer()
                Text("\(min(current + 1, trials.count))/\(trials.count)").font(.digits(14, .bold)).foregroundColor(Palette.muted)
            }
            TimelineView(.periodic(from: .now, by: 0.05)) { ctx in
                let f = ready && !finished ? 1 - ctx.date.timeIntervalSince(trialStart) / config.itemTime : 1
                GoldBar(fraction: f, height: 3)
            }
        }
        .padding(.top, 6)
    }

    private var itemStage: some View {
        ZStack {
            if let t = trial, ready {
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Palette.cardHi).frame(width: 150, height: 150)
                        Circle().stroke(feedbackColor, lineWidth: 1.6).frame(width: 150, height: 150)
                            .shadow(color: feedbackColor.opacity(0.6), radius: 10)
                        SymbolIcon(name: t.item.symbol, color: Palette.tint(t.tint), size: 64)
                        Text("¥\(t.price)")
                            .font(.digits(14, .bold))
                            .foregroundColor(Palette.ink)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Palette.goldGradient))
                            .offset(x: 52, y: -56)
                    }
                    Text(t.item.name).font(.song(24, .bold)).foregroundColor(Palette.cream)
                }
                .id(current)
                .offset(cardOffset)
                .scaleEffect(flyTo != nil ? 0.4 : 1)
                .opacity(flyTo != nil ? 0 : 1)
                .gesture(
                    DragGesture()
                        .onChanged { v in drag = v.translation }
                        .onEnded { v in
                            if v.translation.height > 90 {
                                let dx = v.translation.width
                                let idx = dx < -55 ? 0 : (dx > 55 ? 2 : 1)
                                choose(idx)
                            }
                            withAnimation(.spring(response: 0.3)) { drag = .zero }
                        }
                )
                .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(height: 260)
    }

    private var cardOffset: CGSize {
        if let to = flyTo {
            return CGSize(width: CGFloat(to - 1) * 120, height: 260)
        }
        return drag
    }

    private var feedbackColor: Color {
        guard let f = feedback else { return Palette.gold }
        return f ? Palette.gold : Palette.red
    }

    private var buckets: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { i in
                Button { choose(i) } label: { bucket(i) }
                    .buttonStyle(PressStyle())
                    .disabled(!ready || finished)
            }
        }
    }

    private func bucket(_ i: Int) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .top) {
                BucketShape()
                    .fill(LinearGradient(colors: [bucketColor(i).opacity(0.95), bucketColor(i).opacity(0.7)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(BucketShape().stroke(Color.white.opacity(0.12), lineWidth: 1))
                // 桶口露出的东西
                HStack(spacing: -6) {
                    ForEach(0..<min(bucketCounts[i], 4), id: \.self) { k in
                        Circle().fill(Palette.cream.opacity(0.25 + 0.1 * Double(k))).frame(width: 12, height: 12)
                    }
                }
                .offset(y: 2)
                VStack(spacing: 2) {
                    if isHidden {
                        ForEach(SortRule.allCases, id: \.self) { r in
                            Text(r.buckets[i]).font(.song(12, .bold)).foregroundColor(Palette.cream)
                        }
                    } else {
                        Text(rule.buckets[i]).font(.song(17, .bold)).foregroundColor(Palette.cream)
                            .id("\(rule.rawValue)-\(i)")
                            .transition(.opacity)
                    }
                }
                .padding(.top, isHidden ? 18 : 30)
            }
            .frame(height: isHidden ? 104 : 96)
        }
        .frame(maxWidth: .infinity)
    }

    private func bucketColor(_ i: Int) -> Color {
        if isHidden { return [Palette.goldDark, Color(hex: 0x6B5638), Color(hex: 0x584630)][i] }
        if rule == .color { return [Palette.red, Palette.blue, Palette.green][i] }
        return Palette.bucket(i)
    }

    // MARK: 流程

    private func begin() {
        withAnimation { ready = true }
        start = Date()
        trialStart = Date()
        scheduleTimeout()
    }

    private func choose(_ idx: Int) {
        guard ready, !finished, flyTo == nil, let t = trial else { return }
        timeoutTask?.cancel()
        let rt = Date().timeIntervalSince(trialStart)
        let ok: Bool
        if isHidden {
            // 规则猜中后会偷偷换，不提示
            ok = engine.respond(bucket: idx, trial: t, rng: &rng)
        } else {
            ok = idx == t.answer(for: t.rule)
            if !ok && t.ruleChanged { switchErrors += 1 }
        }
        if ok {
            correctCount += 1
            rts.append(rt)
            Haptic.tap()
            SFX.tick()
        } else {
            Haptic.error()
        }
        feedback = ok
        bucketCounts[idx] += 1
        withAnimation(.easeIn(duration: 0.22)) { flyTo = idx }
        DispatchQueue.main.asyncAfter(deadline: .now() + (isHidden ? 0.45 : 0.25)) { advance() }
    }

    private func advance() {
        flyTo = nil
        feedback = nil
        drag = .zero
        current += 1
        guard current < trials.count else { finish(); return }
        let t = trials[current]
        if t.ruleChanged && !isHidden {
            Haptic.heavy()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { banner = "规则切换：\(t.rule.title)" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation { banner = nil }
                trialStart = Date()
                scheduleTimeout()
            }
        } else {
            trialStart = Date()
            scheduleTimeout()
        }
    }

    private func scheduleTimeout() {
        timeoutTask?.cancel()
        let index = current
        let wait = UInt64(config.itemTime * 1_000_000_000)
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: wait)
            guard !Task.isCancelled, !finished, current == index, flyTo == nil else { return }
            timeouts += 1
            if isHidden, let t = trial { _ = engine.respond(bucket: nil, trial: t, rng: &rng) }
            Haptic.soft()
            feedback = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { advance() }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        timeoutTask?.cancel()
        let total = max(trials.count, 1)
        let acc = Double(correctCount) / Double(total)
        let meanRT = rts.isEmpty ? nil : rts.reduce(0, +) / Double(rts.count)
        let speed = meanRT.map { max(0, 1 - $0 / config.itemTime) } ?? 0
        var score: Int
        var outcome: Outcome
        var stats: [StatLine]
        if isHidden {
            let maxCats = total / config.hiddenRun
            let catScore = Double(engine.categoriesDone) / Double(max(maxCats, 1))
            score = Int((catScore * 60 + acc * 30 + speed * 10).rounded())
            outcome = engine.categoriesDone >= maxCats - 1 && engine.perseverativeErrors <= 3 ? .excellent :
                (engine.categoriesDone >= max(2, maxCats / 2) ? .pass : .fail)
            stats = [StatLine(label: "猜中规则", value: "\(engine.categoriesDone) 次"),
                     StatLine(label: "正确率", value: Fmt.percent(acc)),
                     StatLine(label: "坚持旧规则的错误", value: "\(engine.perseverativeErrors) 次"),
                     StatLine(label: "平均反应", value: Fmt.ms(meanRT))]
        } else {
            score = Int((acc * 75 + speed * 25 * acc).rounded())
            outcome = acc >= 0.96 && speed > 0.4 ? .excellent : (acc >= 0.85 ? .pass : .fail)
            stats = [StatLine(label: "正确率", value: Fmt.percent(acc)),
                     StatLine(label: "平均反应", value: Fmt.ms(meanRT)),
                     StatLine(label: "超时", value: "\(timeouts) 题"),
                     StatLine(label: "每题限时", value: Fmt.seconds(config.itemTime))]
            if mode == .sortSwitch {
                stats.insert(StatLine(label: "切换后出错", value: "\(switchErrors) 次"), at: 2)
            }
        }
        score = clamp(score, 0, 100)
        let headline: String
        switch outcome {
        case .excellent: headline = isHidden ? "规则怎么变，你都[跟得上]" : "规则一变，也能[马上切换]"
        case .pass: headline = "分得又快又对，再[快一点]"
        case .fail: headline = isHidden ? "错了就[换个角度]试：类别、价格、颜色" : "先看[规则]，再看东西"
        }
        onFinish(GameResult(score: score, outcome: outcome, accuracy: acc, meanRT: meanRT,
                            duration: Date().timeIntervalSince(start), headline: headline, stats: stats))
    }
}
