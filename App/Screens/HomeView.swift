import SwiftUI
import BrainCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false

    var body: some View {
        ZStack {
            InkBackground()
            FloatingMotes(count: 14)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    brainHero
                    dailyCard
                    VStack(spacing: 12) {
                        SectionHeader(title: "七个训练", trailing: "挑一个开始就好")
                        ForEach(TrainingKind.allCases) { kind in
                            NavigationLink(value: kind) {
                                TrainingRow(kind: kind, mastery: model.progress.mastery(kind),
                                            sessions: model.progress.sessions(of: kind).count,
                                            pending: kind == .story && (model.progress.pendingStory?.isReady() ?? false))
                            }
                            .buttonStyle(PressStyle())
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)
                            .animation(.easeOut(duration: 0.45).delay(0.05 * Double(kind.number)), value: appeared)
                        }
                    }
                    Caption("大脑会因为你的[练习]而改变", size: 14, weight: .regular, base: Palette.faint)
                        .padding(.vertical, 18)
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { appeared = true }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("晓米脑力")
                    .font(.song(30, .bold))
                    .foregroundStyle(Palette.goldGradient)
                Text(Self.dateText(Date()))
                    .font(.song(12))
                    .foregroundColor(Palette.muted)
            }
            Spacer()
            HStack(spacing: 14) {
                statPill(icon: "flame.fill", value: "\(model.progress.streak())", unit: "天")
                statPill(icon: "sparkles", value: String(model.progress.brainIndex), unit: "脑力")
            }
        }
        .padding(.top, 8)
    }

    private func statPill(icon: String, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(Palette.gold)
                Text(verbatim: value).font(.digits(17, .bold)).foregroundColor(Palette.cream)
            }
            Text(unit).font(.song(10)).foregroundColor(Palette.muted)
        }
    }

    private var brainHero: some View {
        VStack(spacing: 6) {
            BrainView(levels: model.masteries) { i in
                Haptic.tap()
                model.start([model.progress.unlockedModes(TrainingKind.allCases[i]).first ?? TrainingKind.allCases[i].modes[0]])
            }
            .frame(height: 230)
            .padding(.horizontal, 10)
            Caption("点亮节点，直接开练 · 越练越[亮]", size: 12, weight: .regular, base: Palette.faint)
        }
    }

    private var dailyCard: some View {
        let plan = model.todayPlan
        let remaining = model.todayRemaining
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日训练").font(.song(18, .bold)).foregroundColor(Palette.cream)
                    Text(remaining.isEmpty ? "今天的三项都完成了" : "三项组合 · 约 5 分钟")
                        .font(.song(12)).foregroundColor(Palette.muted)
                }
                Spacer()
                Text("\(plan.count - remaining.count)/\(plan.count)")
                    .font(.digits(22, .bold))
                    .foregroundColor(remaining.isEmpty ? Palette.gold : Palette.cream)
            }
            HStack(spacing: 10) {
                ForEach(plan, id: \.self) { mode in
                    let done = model.isDailyDone(mode)
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(done ? Palette.gold.opacity(0.22) : Palette.ink.opacity(0.6))
                            Circle().stroke(done ? Palette.gold : Palette.line, lineWidth: 1)
                            Image(systemName: done ? "checkmark" : mode.kind.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(done ? Palette.gold : Palette.muted)
                        }
                        .frame(width: 42, height: 42)
                        Text(mode.kind.title).font(.song(11, .bold)).foregroundColor(Palette.cream).lineLimit(1)
                        Text(mode.title).font(.song(10)).foregroundColor(Palette.muted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Button {
                Haptic.tap()
                model.start(remaining.isEmpty ? plan : remaining, daily: !remaining.isEmpty)
            } label: {
                Text(remaining.isEmpty ? "再练一轮" : "开始今日训练")
            }
            .buttonStyle(GoldButtonStyle())
        }
        .goldCard(padding: 18, highlight: !remaining.isEmpty)
    }

    static func dateText(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day, .weekday], from: date)
        let week = ["日", "一", "二", "三", "四", "五", "六"][((c.weekday ?? 1) - 1) % 7]
        return "\(c.month ?? 1)月\(c.day ?? 1)日 · 星期\(week)"
    }
}

struct TrainingRow: View {
    let kind: TrainingKind
    let mastery: Int
    let sessions: Int
    var pending = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Palette.ink.opacity(0.7))
                Circle().stroke(Palette.goldDeep.opacity(0.7), lineWidth: 1)
                Text("\(kind.number)").font(.song(20, .bold)).foregroundStyle(Palette.goldGradient)
            }
            .frame(width: 46, height: 46)
            .shadow(color: Palette.gold.opacity(0.2 + 0.4 * LevelSystem.fraction(mastery)), radius: 8)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(kind.title).font(.song(17, .bold)).foregroundColor(Palette.cream)
                    if pending {
                        Text("待回忆").font(.song(10, .bold)).foregroundColor(Palette.ink)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Palette.orange))
                    }
                }
                Text(kind.tagline).font(.song(12)).foregroundColor(Palette.muted).lineLimit(1)
                HStack(spacing: 8) {
                    GoldBar(fraction: LevelSystem.fraction(mastery), height: 3)
                        .frame(width: 90)
                    Text("Lv.\(mastery) · \(LevelSystem.rank(for: mastery))")
                        .font(.song(10)).foregroundColor(Palette.goldDeep)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Palette.faint)
        }
        .goldCard(padding: 14)
    }
}
