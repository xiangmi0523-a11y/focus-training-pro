import SwiftUI
import BrainCore

struct MemoryGameView: View {
    let mode: ModeID
    let level: Int
    let onFinish: (GameResult) -> Void

    @State private var config: MemoryConfig
    @State private var rng: SeededRNG
    @State private var study: [ObjectItem] = []
    @State private var candidates: [ObjectItem] = []
    @State private var probes: [MemoryProbe] = []
    @State private var phase: Phase = .ready
    @State private var shown = -1
    @State private var probeIndex = 0
    @State private var probeCorrect = 0
    @State private var interferenceScore = 0
    @State private var start = Date()

    // 找变化
    @State private var round: ChangeRound?
    @State private var roundIndex = 0
    @State private var roundCorrect = 0
    @State private var selection: Set<Int> = []
    @State private var changePhase: ChangePhase = .study
    @State private var roundResult: Bool?

    enum Phase { case ready, study, interference, recall, probe, change }
    enum ChangePhase { case study, mask, answer }

    init(mode: ModeID, level: Int, onFinish: @escaping (GameResult) -> Void) {
        self.mode = mode
        self.level = level
        self.onFinish = onFinish
        _config = State(initialValue: MemoryConfig(mode: mode, level: level))
        _rng = State(initialValue: SeededRNG.random())
    }

    var body: some View {
        ZStack {
            switch phase {
            case .ready:
                Color.clear
            case .study:
                studyStage
            case .interference:
                ArithmeticInterlude(level: level, count: 3) { c in
                    interferenceScore = c
                    withAnimation { phase = .recall }
                }
                .transition(.opacity)
            case .recall:
                OrderedRecallBoard(expected: mode == .memoryReverse ? Array(study.reversed()) : study,
                                   candidates: candidates,
                                   title: mode == .memoryReverse ? "[倒着]顺序，从最后一个找起" : "按[顺序]找回来") { picked in
                    finishOrdered(picked)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity)
            case .probe:
                probeStage
            case .change:
                changeStage
            }
            if phase == .ready {
                ReadyOverlay(subtitle: readyText) { begin() }
            }
        }
    }

    private var readyText: String {
        switch mode {
        case .memoryReverse: return "记住 [\(config.count)] 样东西，之后[倒着]找回"
        case .memoryProbe: return "记住 [\(config.count)] 样东西的位置，之后会被提问"
        case .memoryChange: return "整排东西看一眼，之后找出[哪里变了]"
        default: return "记住 [\(config.count)] 样东西和[顺序]，只记类别就好"
        }
    }

    // MARK: 逐个展示（聚光灯舞台）

    private var studyStage: some View {
        VStack(spacing: 18) {
            SlotRow(count: study.count, items: study.indices.map { $0 <= shown ? study[$0] : nil }, highlight: shown)
                .padding(.top, 10)
            Spacer(minLength: 0)
            ZStack {
                SpotlightCone().frame(width: 300, height: 300).offset(y: -40)
                VStack(spacing: 0) {
                    Spacer()
                    if shown >= 0 && shown < study.count {
                        let item = study[shown]
                        SymbolIcon(name: item.symbol, color: Palette.hue(item.hue), size: 86)
                            .shadow(color: Palette.hue(item.hue).opacity(0.4), radius: 16)
                            .id(item.id)
                            .transition(.asymmetric(insertion: .scale(scale: 0.7).combined(with: .opacity),
                                                    removal: .opacity))
                        StagePlatform().frame(width: 220).offset(y: -4)
                        Text(item.name)
                            .font(.song(20, .bold))
                            .foregroundColor(Palette.goldDeep)
                            .id("n" + item.id)
                    }
                }
                .frame(height: 260)
            }
            Spacer(minLength: 0)
            Caption("不用记细节，只记[类别]和[顺序]", size: 14, weight: .regular, base: Palette.muted)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
    }

    private func begin() {
        start = Date()
        if mode == .memoryChange {
            nextChangeRound()
            withAnimation { phase = .change }
            return
        }
        study = MemoryGenerator.study(config: config, rng: &rng)
        candidates = MemoryGenerator.candidates(study: study, config: config, rng: &rng)
        if mode == .memoryProbe {
            probes = MemoryGenerator.probes(study: study, count: config.probeQuestions, rng: &rng)
        }
        withAnimation { phase = .study }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            for i in study.indices {
                withAnimation(.easeOut(duration: 0.25)) { shown = i }
                SFX.tock()
                try? await Task.sleep(nanoseconds: UInt64(config.showTime * 1_000_000_000))
            }
            withAnimation { shown = study.count }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                if mode == .memoryProbe { phase = .probe } else { phase = config.interference ? .interference : .recall }
            }
        }
    }

    private func finishOrdered(_ picked: [ObjectItem]) {
        let expected = mode == .memoryReverse ? Array(study.reversed()) : study
        let acc = MemoryGenerator.orderedAccuracy(expected: expected, picked: picked)
        let outcome = MemoryGenerator.outcome(accuracy: acc)
        let correct = Int((acc * Double(expected.count)).rounded())
        var stats = [
            StatLine(label: "顺序全对", value: "\(correct) / \(expected.count)"),
            StatLine(label: "每样展示", value: Fmt.seconds(config.showTime)),
            StatLine(label: "干扰项", value: "\(config.distractorCount) 个\(config.sameCategoryDistractors ? "（同类）" : "")")
        ]
        if config.interference { stats.append(StatLine(label: "干扰算术", value: "\(interferenceScore) / 3")) }
        let headline: String
        switch outcome {
        case .excellent: headline = "一个不落，清单就在[脑子里]"
        case .pass: headline = "记住了大部分，再加[一样]试试"
        case .fail: headline = "先抓[类别]，再串顺序，会轻松很多"
        }
        onFinish(GameResult(score: Int((acc * 100).rounded()), outcome: outcome, accuracy: acc, meanRT: nil,
                            duration: Date().timeIntervalSince(start), headline: headline, stats: stats))
    }

    // MARK: 定位提问

    private var probeStage: some View {
        VStack(spacing: 18) {
            HStack {
                Text("提问 \(min(probeIndex + 1, probes.count))/\(probes.count)").font(.song(13)).foregroundColor(Palette.muted)
                Spacer()
                Text("答对 \(probeCorrect)").font(.song(13, .bold)).foregroundColor(Palette.gold)
            }
            SlotRow(count: study.count, items: study.map { Optional($0) }, highlight: currentProbePosition, hidden: true)
            Spacer(minLength: 0)
            if probeIndex < probes.count {
                let p = probes[probeIndex]
                ChoiceQuestion(prompt: prompt(for: p), options: options(for: p), answer: p.answer) { ok in
                    if ok { probeCorrect += 1 }
                    if probeIndex + 1 >= probes.count {
                        finishProbe()
                    } else {
                        withAnimation { probeIndex += 1 }
                    }
                }
                .id(probeIndex)
                .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
    }

    private var currentProbePosition: Int? {
        guard probeIndex < probes.count, case let .whatAt(pos) = probes[probeIndex].kind else { return nil }
        return pos
    }

    private func prompt(for p: MemoryProbe) -> String {
        switch p.kind {
        case let .whatAt(pos): return "第 [\(pos + 1)] 个是什么？"
        case let .whereIs(id): return "[\(ItemCatalog.item(id)?.name ?? "")] 排第几？"
        }
    }

    private func options(for p: MemoryProbe) -> [ChoiceQuestion.ChoiceOption] {
        switch p.kind {
        case .whatAt:
            return p.options.map { ChoiceQuestion.ChoiceOption(item: ItemCatalog.item($0), text: nil) }
        case .whereIs:
            return p.options.map { ChoiceQuestion.ChoiceOption(item: nil, text: $0) }
        }
    }

    private func finishProbe() {
        let acc = Double(probeCorrect) / Double(max(probes.count, 1))
        let outcome: Outcome = acc >= 0.999 ? .excellent : (acc >= 0.66 ? .pass : .fail)
        onFinish(GameResult(score: Int((acc * 100).rounded()), outcome: outcome, accuracy: acc, meanRT: nil,
                            duration: Date().timeIntervalSince(start),
                            headline: outcome == .fail ? "试着把每样东西和[位置]绑在一起记" : "顺序和位置都在[脑子里]",
                            stats: [StatLine(label: "答对", value: "\(probeCorrect) / \(probes.count)"),
                                    StatLine(label: "清单长度", value: "\(study.count) 样"),
                                    StatLine(label: "每样展示", value: Fmt.seconds(config.showTime))]))
    }

    // MARK: 找变化

    private var changeStage: some View {
        VStack(spacing: 18) {
            HStack {
                Text("第 \(roundIndex + 1)/\(config.changeRounds) 轮").font(.song(13)).foregroundColor(Palette.muted)
                Spacer()
                Text("答对 \(roundCorrect)").font(.song(13, .bold)).foregroundColor(Palette.gold)
            }
            Spacer(minLength: 0)
            Caption(changeCaption, size: 17)
            if let round {
                let items = changePhase == .study ? round.before : round.after
                let cols = Array(repeating: GridItem(.fixed(70), spacing: 10), count: min(4, items.count))
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        Button {
                            guard changePhase == .answer, roundResult == nil else { return }
                            Haptic.tap()
                            if selection.contains(i) { selection.remove(i) } else { selection.insert(i) }
                        } label: {
                            ZStack {
                                if changePhase == .mask {
                                    RoundedRectangle(cornerRadius: 10).fill(Palette.cardHi)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 0.8))
                                        .overlay(Text("?").font(.song(22, .bold)).foregroundColor(Palette.goldDeep))
                                        .frame(width: 66, height: 66)
                                } else {
                                    ItemTile(item: item, size: 66, showName: false, index: i + 1, state: tileState(i))
                                }
                            }
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: changePhase)
            }
            Spacer(minLength: 0)
            if changePhase == .answer {
                Button(roundResult == nil ? "确认" : (roundResult! ? "答对了" : "看看答案")) { confirmChange() }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(selection.isEmpty || roundResult != nil)
                    .opacity(selection.isEmpty ? 0.5 : 1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
    }

    private var changeCaption: String {
        switch changePhase {
        case .study: return "记住每个[位置]上是什么"
        case .mask: return "……"
        case .answer: return "有东西被[调换]或[替换]了，点出变了的位置"
        }
    }

    private func tileState(_ i: Int) -> ItemTile.TileState {
        guard let round else { return .normal }
        if let r = roundResult {
            if round.changed.contains(i) { return .correct }
            if selection.contains(i) { return .wrong }
            return r ? .normal : .dimmed
        }
        return selection.contains(i) ? .selected : .normal
    }

    private func nextChangeRound() {
        selection = []
        roundResult = nil
        round = MemoryGenerator.changeRound(config: config, rng: &rng)
        changePhase = .study
        let wait = config.changeStudyTime
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            withAnimation { changePhase = .mask }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation { changePhase = .answer }
        }
    }

    private func confirmChange() {
        guard let round else { return }
        let ok = selection == round.changed
        roundResult = ok
        if ok { roundCorrect += 1; Haptic.success(); SFX.correct() } else { Haptic.error() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if roundIndex + 1 >= config.changeRounds {
                let acc = Double(roundCorrect) / Double(config.changeRounds)
                let outcome: Outcome = acc >= 0.999 ? .excellent : (acc >= 0.6 ? .pass : .fail)
                onFinish(GameResult(score: Int((acc * 100).rounded()), outcome: outcome, accuracy: acc, meanRT: nil,
                                    duration: Date().timeIntervalSince(start),
                                    headline: outcome == .fail ? "整排一起看，先记[开头和结尾]" : "一眼就看出[哪里变了]",
                                    stats: [StatLine(label: "答对轮数", value: "\(roundCorrect) / \(config.changeRounds)"),
                                            StatLine(label: "每排", value: "\(config.count) 样"),
                                            StatLine(label: "观察时间", value: Fmt.seconds(config.changeStudyTime))]))
            } else {
                roundIndex += 1
                nextChangeRound()
            }
        }
    }
}
