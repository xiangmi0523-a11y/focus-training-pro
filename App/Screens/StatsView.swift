import SwiftUI
import Charts
import BrainCore

struct StatsView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: TrainingKind = .schulte

    var body: some View {
        ZStack {
            InkBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Caption("脑力[数据]", size: 26)
                        Text("七个维度，越练越圆").font(.song(12)).foregroundColor(Palette.muted)
                    }
                    .padding(.top, 10)
                    radarCard
                    trendCard
                    recentCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var radarCard: some View {
        let values = TrainingKind.allCases.map { Double(model.progress.dimensionScore($0)) / 100 }
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("脑力指数").font(.song(15, .bold)).foregroundColor(Palette.cream)
                Spacer()
                Text(verbatim: "\(model.progress.brainIndex)").font(.digits(30, .bold)).foregroundStyle(Palette.goldGradient)
                Text("/ 1000").font(.song(11)).foregroundColor(Palette.muted)
            }
            RadarChart(values: values, labels: TrainingKind.allCases.map(\.dimension))
                .frame(height: 260)
        }
        .goldCard(padding: 16)
    }

    private var trendCard: some View {
        let sessions = Array(model.progress.sessions(of: selected).suffix(24))
        return VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TrainingKind.allCases) { k in
                        Button {
                            Haptic.soft()
                            withAnimation(.easeInOut(duration: 0.25)) { selected = k }
                        } label: {
                            RuleChip(text: k.title, active: k == selected)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
            HStack {
                Text("最近得分").font(.song(14, .bold)).foregroundColor(Palette.cream)
                Spacer()
                LevelChip(level: model.progress.mastery(selected))
            }
            if sessions.count < 2 {
                Text("练满两次后，这里会出现曲线")
                    .font(.song(13)).foregroundColor(Palette.muted)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { i, s in
                        AreaMark(x: .value("次", i + 1), y: .value("得分", s.score))
                            .foregroundStyle(LinearGradient(colors: [Palette.gold.opacity(0.35), Palette.gold.opacity(0.0)],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("次", i + 1), y: .value("得分", s.score))
                            .foregroundStyle(Palette.gold)
                            .lineStyle(StrokeStyle(lineWidth: 2.2))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("次", i + 1), y: .value("得分", s.score))
                            .foregroundStyle(s.outcome == .fail ? Palette.red : Palette.goldBright)
                            .symbolSize(22)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine().foregroundStyle(Palette.line)
                        AxisValueLabel().foregroundStyle(Palette.muted)
                    }
                }
                .frame(height: 170)
            }
            let modes = selected.modes.filter { model.progress.isUnlocked($0) && $0 != .storyDelayed }
            VStack(spacing: 8) {
                ForEach(modes) { m in
                    HStack {
                        Text(m.title).font(.song(13)).foregroundColor(Palette.cream)
                        Spacer()
                        Text("最佳 \(model.progress.best(for: m).map(String.init) ?? "—")").font(.song(12)).foregroundColor(Palette.muted)
                        LevelChip(level: model.progress.level(for: m), showRank: false)
                    }
                }
            }
        }
        .goldCard(padding: 16)
    }

    private var recentCard: some View {
        let recent = Array(model.progress.sessions.suffix(8).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "最近训练")
            if recent.isEmpty {
                Text("还没有记录，去练一个吧").font(.song(13)).foregroundColor(Palette.muted).padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            }
            ForEach(recent) { s in
                HStack(spacing: 12) {
                    Image(systemName: s.kind.symbol).font(.system(size: 15)).foregroundColor(Palette.gold).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(s.kind.title) · \(s.mode.title)").font(.song(14, .bold)).foregroundColor(Palette.cream)
                        Text(Self.when(s.date)).font(.song(11)).foregroundColor(Palette.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(s.score)").font(.digits(18, .bold)).foregroundColor(s.outcome == .fail ? Palette.muted : Palette.gold)
                        Text(s.newLevel > s.level ? "Lv.\(s.level)→\(s.newLevel)" : "Lv.\(s.newLevel)")
                            .font(.song(10)).foregroundColor(Palette.faint)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .goldCard(padding: 16)
    }

    static func when(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: date)
        return String(format: "%d月%d日 %02d:%02d", c.month ?? 1, c.day ?? 1, c.hour ?? 0, c.minute ?? 0)
    }
}

/// 七边形雷达图，七个顶点对应七个训练
struct RadarChart: View {
    let values: [Double]
    let labels: [String]
    @State private var grow: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 34
            let n = max(values.count, 3)
            ZStack {
                ForEach(1...4, id: \.self) { ring in
                    polygon(n: n, center: center, radius: radius * CGFloat(ring) / 4, values: nil)
                        .stroke(Palette.line, lineWidth: 0.8)
                }
                ForEach(0..<n, id: \.self) { i in
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: point(i, n: n, center: center, radius: radius))
                    }
                    .stroke(Palette.line.opacity(0.7), lineWidth: 0.6)
                }
                polygon(n: n, center: center, radius: radius, values: values.map { max(0.06, $0) * grow })
                    .fill(Palette.gold.opacity(0.22))
                polygon(n: n, center: center, radius: radius, values: values.map { max(0.06, $0) * grow })
                    .stroke(Palette.gold, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                    .shadow(color: Palette.gold.opacity(0.6), radius: 6)
                ForEach(0..<n, id: \.self) { i in
                    let v = i < values.count ? values[i] : 0
                    Circle().fill(Palette.goldBright).frame(width: 6, height: 6)
                        .position(point(i, n: n, center: center, radius: radius * CGFloat(max(0.06, v) * grow)))
                    VStack(spacing: 1) {
                        Text("\(i + 1)").font(.digits(9, .bold)).foregroundColor(Palette.goldDeep)
                        Text(i < labels.count ? labels[i] : "").font(.song(11)).foregroundColor(Palette.cream)
                        Text("\(Int((v * 100).rounded()))").font(.digits(10)).foregroundColor(Palette.muted)
                    }
                    .position(point(i, n: n, center: center, radius: radius + 22))
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { grow = 1 } }
    }

    private func point(_ i: Int, n: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let a = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(n)
        return CGPoint(x: center.x + CGFloat(cos(a)) * radius, y: center.y + CGFloat(sin(a)) * radius)
    }

    private func polygon(n: Int, center: CGPoint, radius: CGFloat, values: [Double]?) -> Path {
        Path { p in
            for i in 0..<n {
                let r = radius * CGFloat(values.map { i < $0.count ? $0[i] : 0 } ?? 1)
                let pt = point(i, n: n, center: center, radius: r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }
}
