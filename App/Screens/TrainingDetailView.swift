import SwiftUI
import BrainCore

struct TrainingDetailView: View {
    let kind: TrainingKind
    @Environment(AppModel.self) private var model
    @State private var selected: ModeID?
    @State private var shownRules = 0

    private var mode: ModeID {
        if let s = selected, model.progress.isUnlocked(s) { return s }
        if let recent = model.progress.sessions(of: kind).last(where: { $0.mode != .storyDelayed })?.mode,
           model.progress.isUnlocked(recent) { return recent }
        return kind.modes[0]
    }

    var body: some View {
        ZStack {
            InkBackground()
            FloatingMotes(count: 10)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    hero
                    TrainingArt(kind: kind)
                        .frame(height: 170)
                        .frame(maxWidth: .infinity)
                    rules
                    if kind == .story, let pending = model.progress.pendingStory {
                        delayedCard(pending)
                    }
                    modes
                    Caption(kind.benefit, size: 15, weight: .regular, base: Palette.muted)
                        .padding(.top, 4)
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            VStack {
                Spacer()
                startBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                CitationTag(text: kind.citation)
            }
        }
        .task {
            shownRules = 0
            for i in 1...kind.rules.count {
                try? await Task.sleep(nanoseconds: 260_000_000)
                withAnimation(.easeOut(duration: 0.4)) { shownRules = i }
            }
        }
    }

    private var hero: some View {
        let mastery = model.progress.mastery(kind)
        return VStack(spacing: 10) {
            Caption("\(kind.ordinal)：[\(kind.title)]", size: 26)
            HStack(spacing: 10) {
                LevelChip(level: mastery)
                Text(kind.dimension).font(.song(12)).foregroundColor(Palette.muted)
                Text("·").foregroundColor(Palette.faint)
                Text("已练 \(model.progress.sessions(of: kind).count) 次").font(.song(12)).foregroundColor(Palette.muted)
            }
            GoldBar(fraction: LevelSystem.fraction(mastery), height: 3)
                .frame(width: 180)
        }
    }

    private var rules: some View {
        VStack(spacing: 12) {
            ForEach(Array(kind.rules.enumerated()), id: \.offset) { i, line in
                Caption(line, size: 16)
                    .opacity(i < shownRules ? 1 : 0)
                    .offset(y: i < shownRules ? 0 : 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func delayedCard(_ pending: PendingStory) -> some View {
        let ready = pending.isReady()
        let minutes = Int(Date().timeIntervalSince(pending.created) / 60)
        return HStack(spacing: 14) {
            Image(systemName: "hourglass").font(.system(size: 22)).foregroundColor(ready ? Palette.orange : Palette.faint)
            VStack(alignment: .leading, spacing: 4) {
                Text("延迟回忆").font(.song(16, .bold)).foregroundColor(Palette.cream)
                Text(ready ? "\(Self.ago(minutes))编的 \(pending.itemIDs.count) 样东西，还记得顺序吗？"
                           : "上次的故事要隔 20 分钟以后才能考，再等等")
                    .font(.song(12)).foregroundColor(Palette.muted)
            }
            Spacer()
            if ready {
                Button("回忆") { model.start([.storyDelayed]) }
                    .buttonStyle(GoldButtonStyle(compact: true))
            }
        }
        .goldCard(padding: 14, highlight: ready)
    }

    static func ago(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟前" }
        if minutes < 60 * 24 { return "\(minutes / 60) 小时前" }
        return "\(minutes / 60 / 24) 天前"
    }

    private var modes: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "玩法", trailing: "熟练度越高，解锁越多")
            ForEach(kind.modes.filter { $0 != .storyDelayed }) { m in
                let unlocked = model.progress.isUnlocked(m)
                let isSel = unlocked && m == mode
                Button {
                    guard unlocked else { Haptic.error(); return }
                    Haptic.tap()
                    withAnimation(.easeOut(duration: 0.2)) { selected = m }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(isSel ? Palette.gold : Palette.line, lineWidth: 1.2)
                            if isSel { Circle().fill(Palette.gold).padding(5) }
                        }
                        .frame(width: 20, height: 20)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(m.title).font(.song(16, .bold)).foregroundColor(unlocked ? Palette.cream : Palette.faint)
                            Text(m.detail).font(.song(12)).foregroundColor(unlocked ? Palette.muted : Palette.faint)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        if unlocked {
                            VStack(alignment: .trailing, spacing: 3) {
                                LevelChip(level: model.progress.level(for: m), showRank: false)
                                if let best = model.progress.best(for: m) {
                                    Text("最佳 \(best)").font(.song(10)).foregroundColor(Palette.muted)
                                }
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill").font(.system(size: 11))
                                Text("熟练度 \(m.unlockMastery)").font(.song(11))
                            }
                            .foregroundColor(Palette.faint)
                        }
                    }
                    .goldCard(padding: 14, highlight: isSel)
                }
                .buttonStyle(PressStyle())
            }
        }
    }

    private var startBar: some View {
        let lv = model.progress.level(for: mode)
        return Button {
            Haptic.tap()
            model.start([mode])
        } label: {
            HStack(spacing: 8) {
                Text("开始训练")
                Text("· \(mode.title) Lv.\(lv)").font(.song(14))
            }
        }
        .buttonStyle(GoldButtonStyle())
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [Palette.ink.opacity(0), Palette.ink.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .offset(y: 20)
                .allowsHitTesting(false)
        )
    }
}

/// 每个训练的小插图（视频风格）
struct TrainingArt: View {
    let kind: TrainingKind

    var body: some View {
        switch kind {
        case .schulte: SchulteArt()
        case .stroop: StroopArt()
        case .memory: MemoryArt()
        case .digits: DigitsArt()
        case .mirror: MirrorArt()
        case .sorting: SortingArt()
        case .story: StoryArt()
        }
    }
}

private struct SchulteArt: View {
    let numbers = [19, 6, 15, 24, 3, 17, 2, 12, 13, 22, 8, 14, 5, 16, 20, 11, 18, 4, 21, 9, 1, 25, 7, 10, 23]

    var body: some View {
        let cols = Array(repeating: GridItem(.fixed(30), spacing: 4), count: 5)
        LazyVGrid(columns: cols, spacing: 4) {
            ForEach(Array(numbers.enumerated()), id: \.offset) { i, n in
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(n <= 3 ? Palette.gold.opacity(0.22) : Palette.card)
                    RoundedRectangle(cornerRadius: 4).stroke(Palette.line, lineWidth: 0.8)
                    if i == 12 {
                        Image(systemName: "eye").font(.system(size: 12)).foregroundColor(Palette.gold)
                    } else {
                        Text("\(n)").font(.digits(12)).foregroundColor(Palette.cream)
                    }
                }
                .frame(width: 30, height: 30)
            }
        }
        .frame(width: 170)
    }
}

private struct StroopArt: View {
    let items: [(InkColor, InkColor)] = [(.red, .yellow), (.green, .red), (.yellow, .blue), (.blue, .green),
                                         (.purple, .yellow), (.red, .blue), (.green, .purple), (.yellow, .red)]

    var body: some View {
        let cols = Array(repeating: GridItem(.fixed(48), spacing: 8), count: 4)
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, pair in
                Text(pair.0.name)
                    .font(.song(26, .bold))
                    .foregroundColor(Palette.inkColor(pair.1))
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.card))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(i == 0 ? Palette.gold : Palette.line, lineWidth: i == 0 ? 1.6 : 0.8))
            }
        }
        .frame(width: 230)
    }
}

private struct MemoryArt: View {
    var body: some View {
        ZStack {
            SpotlightCone().frame(width: 220, height: 150).offset(y: -10)
            VStack(spacing: 0) {
                Spacer()
                SymbolIcon(name: "car.fill", color: Palette.gray, size: 52)
                StagePlatform().frame(width: 160).offset(y: -6)
                Text("轿车").font(.song(13, .bold)).foregroundColor(Palette.goldDeep)
            }
        }
    }
}

private struct DigitsArt: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 3) {
                ForEach(0..<46, id: \.self) { i in
                    let tall = [6, 13, 20, 27, 34, 41].contains(i)
                    Capsule().fill(tall ? Palette.goldBright : Palette.goldDeep.opacity(0.5))
                        .frame(width: 1.6, height: tall ? 26 : CGFloat(6 + (i * 7) % 12))
                }
            }
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: "person.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Palette.ink3)
                        .offset(x: CGFloat(i - 2) * 46, y: 8)
                }
                Image(systemName: "headphones").font(.system(size: 40)).foregroundStyle(Palette.goldGradient)
            }
        }
    }
}

private struct MirrorArt: View {
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Path(ellipseIn: CGRect(x: 20, y: 20, width: 100, height: 100))
                    .stroke(Palette.goldBright, lineWidth: 2.5)
                    .shadow(color: Palette.gold, radius: 6)
                Image(systemName: "hand.point.up.left.fill").font(.system(size: 30)).foregroundColor(Palette.purple)
                    .offset(x: -28, y: 44)
            }
            .frame(width: 140, height: 140)
            Rectangle().fill(Palette.goldDeep).frame(width: 1, height: 130)
                .overlay(Rectangle().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundColor(Palette.goldDeep))
            ZStack {
                Path(ellipseIn: CGRect(x: 20, y: 20, width: 100, height: 100))
                    .stroke(Palette.goldBright, lineWidth: 2.5)
                    .shadow(color: Palette.gold, radius: 6)
                Image(systemName: "hand.point.up.left.fill").font(.system(size: 30)).foregroundColor(Palette.blue)
                    .scaleEffect(x: -1, y: 1)
                    .offset(x: 28, y: 44)
            }
            .frame(width: 140, height: 140)
        }
    }
}

private struct SortingArt: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(Palette.gold, lineWidth: 1.4).frame(width: 62, height: 62)
                SymbolIcon(name: "birthday.cake.fill", color: Palette.pink, size: 28)
            }
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { i in
                    BucketShape()
                        .fill(Palette.bucket(i))
                        .overlay(Text(SortCategory(rawValue: i)!.name).font(.song(12, .bold)).foregroundColor(Palette.cream))
                        .frame(width: 66, height: 58)
                }
            }
        }
    }
}

private struct StoryArt: View {
    let items = ["umbrella.fill", "tram.fill", "takeoutbag.and.cup.and.straw.fill", "guitars.fill", "cloud.fill"]
    let names = ["雨伞", "火车", "面包", "吉他", "棉花糖"]
    let colors = [Palette.gray, Palette.green, Palette.brown, Palette.orange, Palette.pink]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    VStack(spacing: 4) {
                        SymbolIcon(name: items[i], color: colors[i], size: 22)
                            .frame(width: 50, height: 50)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.card))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 0.8))
                        Text(names[i]).font(.song(10)).foregroundColor(Palette.muted)
                    }
                }
            }
            Path { p in
                p.move(to: CGPoint(x: 10, y: 8))
                p.addCurve(to: CGPoint(x: 270, y: 8), control1: CGPoint(x: 90, y: 22), control2: CGPoint(x: 190, y: -6))
            }
            .stroke(Palette.goldDeep, lineWidth: 1)
            .frame(width: 280, height: 16)
            Caption("灰色雨伞，雨中的站台……", size: 13, weight: .regular, base: Palette.muted)
        }
    }
}

/// 视频里的分类桶：上宽下窄的杯形
struct BucketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * 0.12
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + 6))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 6), control: CGPoint(x: rect.midX, y: rect.minY + 14))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - 6))
        p.addQuadCurve(to: CGPoint(x: rect.minX + inset, y: rect.maxY - 6), control: CGPoint(x: rect.midX, y: rect.maxY + 4))
        p.closeSubpath()
        return p
    }
}
