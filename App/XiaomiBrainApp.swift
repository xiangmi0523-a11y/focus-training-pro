import SwiftUI
import UIKit
import BrainCore

@main
struct XiaomiBrainApp: App {
    @State private var model = AppModel()

    init() {
        AppFont.register()
        Self.styleNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Palette.gold)
        }
    }

    private static func styleNavigationBars() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        let titleFont = AppFont.bold.flatMap { UIFont(name: $0, size: 17) } ?? UIFont.systemFont(ofSize: 17, weight: .semibold)
        nav.titleTextAttributes = [.foregroundColor: UIColor(Palette.cream), .font: titleFont]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(Palette.gold)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showLaunch = true
    @State private var tab = 0
    @State private var homePath: [TrainingKind] = []

    var body: some View {
        @Bindable var model = model
        ZStack {
            TabView(selection: $tab) {
                NavigationStack(path: $homePath) {
                    HomeView()
                        .navigationDestination(for: TrainingKind.self) { kind in
                            TrainingDetailView(kind: kind)
                        }
                }
                .tabItem { Label("训练", systemImage: "brain.head.profile") }
                .tag(0)

                NavigationStack { DailyView() }
                    .tabItem { Label("每日", systemImage: "calendar") }
                    .tag(1)

                NavigationStack { StatsView() }
                    .tabItem { Label("数据", systemImage: "chart.xyaxis.line") }
                    .tag(2)

                NavigationStack { SettingsView() }
                    .tabItem { Label("我的", systemImage: "person.crop.circle") }
                    .tag(3)
            }
            .tint(Palette.gold)

            if showLaunch {
                LaunchView { withAnimation(.easeInOut(duration: 0.5)) { showLaunch = false } }
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .fullScreenCover(item: $model.activeSession) { plan in
            GameContainer(plan: plan)
                .environment(model)
        }
        .onAppear(perform: applyDemo)
    }

    private func applyDemo() {
        guard let demo = model.demoScreen else { return }
        showLaunch = false
        switch demo {
        case .home: tab = 0
        case .detail:
            tab = 0
            homePath = [model.demoKind ?? model.demoMode?.kind ?? .schulte]
        case .game, .result:
            tab = 0
            if let m = model.demoMode { model.start([m]) }
        case .daily: tab = 1
        case .stats: tab = 2
        case .settings: tab = 3
        }
    }
}

/// 启动动画：大脑亮起，7 个节点依次点亮
struct LaunchView: View {
    let onFinish: () -> Void
    @State private var reveal: Double = 0
    @State private var showTitle = false
    @State private var showCaption = false

    var body: some View {
        ZStack {
            InkBackground(glow: 1.4)
            FloatingMotes(count: 16)
            VStack(spacing: 28) {
                Spacer()
                BrainView(levels: Array(repeating: 12, count: 7), reveal: reveal, showSynapses: false)
                    .frame(maxWidth: 300)
                    .padding(.horizontal, 40)
                VStack(spacing: 10) {
                    Text("晓米脑力")
                        .font(.song(40, .bold))
                        .foregroundStyle(Palette.goldGradient)
                        .shadow(color: Palette.gold.opacity(0.45), radius: 14)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 8)
                    Rectangle().fill(Palette.goldDeep).frame(width: showTitle ? 120 : 0, height: 0.8)
                    Caption("7个脑训练 · 越练，越[好用]", size: 15, weight: .regular, base: Palette.muted)
                        .opacity(showCaption ? 1 : 0)
                }
                Spacer()
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onFinish() }
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            for i in 1...7 {
                withAnimation(.easeOut(duration: 0.22)) { reveal = Double(i) / 7 }
                Haptic.soft()
                try? await Task.sleep(nanoseconds: 170_000_000)
            }
            withAnimation(.easeOut(duration: 0.7)) { showTitle = true }
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.easeOut(duration: 0.6)) { showCaption = true }
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            onFinish()
        }
    }
}
