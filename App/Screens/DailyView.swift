import SwiftUI
import BrainCore

struct DailyView: View {
    @Environment(AppModel.self) private var model
    @State private var month = Date()

    var body: some View {
        ZStack {
            InkBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Caption("每日[训练]", size: 26)
                        Text(HomeView.dateText(Date())).font(.song(12)).foregroundColor(Palette.muted)
                    }
                    .padding(.top, 10)
                    streakCard
                    planCard
                    calendarCard
                    Caption("七个训练，[挑一个]开始就好", size: 13, weight: .regular, base: Palette.faint)
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var streakCard: some View {
        HStack(spacing: 0) {
            metric(value: "\(model.progress.streak())", unit: "天", label: "连续训练", icon: "flame.fill")
            divider
            metric(value: "\(model.progress.trainedDays().count)", unit: "天", label: "累计训练", icon: "calendar")
            divider
            metric(value: "\(Int(model.progress.totalSeconds / 60))", unit: "分钟", label: "总时长", icon: "clock")
        }
        .goldCard(padding: 16)
    }

    private var divider: some View {
        Rectangle().fill(Palette.line).frame(width: 0.8, height: 44)
    }

    private func metric(value: String, unit: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Palette.gold)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.digits(24, .bold)).foregroundColor(Palette.cream)
                Text(unit).font(.song(11)).foregroundColor(Palette.muted)
            }
            Text(label).font(.song(11)).foregroundColor(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var planCard: some View {
        let plan = model.todayPlan
        let remaining = model.todayRemaining
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "今天的三项", trailing: remaining.isEmpty ? "已完成" : "还剩 \(remaining.count) 项")
            ForEach(Array(plan.enumerated()), id: \.offset) { i, mode in
                let done = model.isDailyDone(mode)
                HStack(spacing: 14) {
                    Text("\(i + 1)").font(.song(18, .bold)).foregroundStyle(Palette.goldGradient).frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(mode.kind.title) · \(mode.title)").font(.song(15, .bold)).foregroundColor(Palette.cream)
                        Text(mode.detail).font(.song(12)).foregroundColor(Palette.muted).lineLimit(1)
                    }
                    Spacer()
                    if done {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundColor(Palette.gold)
                    } else {
                        LevelChip(level: model.progress.level(for: mode), showRank: false)
                    }
                }
                .padding(.vertical, 4)
            }
            Button(remaining.isEmpty ? "今天完成啦 · 再练一轮" : "开始今日训练") {
                Haptic.tap()
                model.start(remaining.isEmpty ? plan : remaining, daily: !remaining.isEmpty)
            }
            .buttonStyle(GoldButtonStyle())
        }
        .goldCard(padding: 18, highlight: !remaining.isEmpty)
    }

    private var calendarCard: some View {
        let cal = Calendar.current
        let days = model.progress.trainedDays()
        let comps = cal.dateComponents([.year, .month], from: month)
        let first = cal.date(from: comps) ?? month
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = (cal.component(.weekday, from: first) + 5) % 7 // 周一为第一列
        let todayKey = DayKey.string(Date())
        return VStack(spacing: 12) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(verbatim: "\(comps.year ?? 0)年\(comps.month ?? 1)月").font(.song(16, .bold)).foregroundColor(Palette.cream)
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
            }
            .foregroundColor(Palette.gold)
            let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                    Text(w).font(.song(11)).foregroundColor(Palette.faint)
                }
                ForEach(0..<(lead + count), id: \.self) { i in
                    if i < lead {
                        Color.clear.frame(height: 34)
                    } else {
                        let day = i - lead + 1
                        let date = cal.date(byAdding: .day, value: day - 1, to: first) ?? first
                        let key = DayKey.string(date)
                        let trained = days.contains(key)
                        let daily = (model.progress.dailyDone[key]?.count ?? 0) >= 3
                        ZStack {
                            if trained {
                                Circle().fill(daily ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Palette.gold.opacity(0.22)))
                            }
                            if key == todayKey {
                                Circle().stroke(Palette.gold, lineWidth: 1.2)
                            }
                            Text("\(day)").font(.digits(13, trained ? .bold : .regular))
                                .foregroundColor(daily ? Palette.ink : (trained ? Palette.cream : Palette.faint))
                        }
                        .frame(width: 34, height: 34)
                    }
                }
            }
            HStack(spacing: 14) {
                legend(AnyShapeStyle(Palette.goldGradient), "完成每日三项")
                legend(AnyShapeStyle(Palette.gold.opacity(0.22)), "有训练")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .goldCard(padding: 16)
    }

    private func legend(_ style: AnyShapeStyle, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(style).frame(width: 10, height: 10)
            Text(text).font(.song(11)).foregroundColor(Palette.muted)
        }
    }

    private func shift(_ delta: Int) {
        Haptic.soft()
        withAnimation { month = Calendar.current.date(byAdding: .month, value: delta, to: month) ?? month }
    }
}
