import SwiftUI
import BrainCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    var body: some View {
        @Bindable var model = model
        ZStack {
            InkBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        BrainView(levels: model.masteries, showSynapses: true)
                            .frame(height: 120)
                        Text("晓米脑力").font(.song(24, .bold)).foregroundStyle(Palette.goldGradient)
                        Text("脑力指数 \(model.progress.brainIndex) · 已练 \(model.progress.sessions.count) 局")
                            .font(.song(12)).foregroundColor(Palette.muted)
                    }
                    .padding(.top, 14)

                    VStack(spacing: 0) {
                        toggleRow("音效", icon: "speaker.wave.2.fill", isOn: $model.settings.sound)
                        line
                        toggleRow("震动反馈", icon: "iphone.radiowaves.left.and.right", isOn: $model.settings.haptics)
                        line
                        toggleRow("斯特鲁普语音作答", icon: "mic.fill", isOn: $model.settings.voiceAnswer,
                                  note: "说出颜色代替点按钮（需要麦克风和语音识别权限）")
                        line
                        toggleRow("低等级示范故事", icon: "text.book.closed.fill", isOn: $model.settings.showHints,
                                  note: "串成故事前几级自动给出示范")
                        line
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "waveform").foregroundColor(Palette.gold).frame(width: 22)
                                Text("听数字语速").font(.song(15)).foregroundColor(Palette.cream)
                                Spacer()
                                Text(speedText).font(.song(12)).foregroundColor(Palette.muted)
                            }
                            Slider(value: $model.settings.speechRate, in: 0.4...0.6, step: 0.02)
                                .tint(Palette.gold)
                        }
                        .padding(.vertical, 12)
                    }
                    .goldCard(padding: 16)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "背后的研究")
                        ForEach(TrainingKind.allCases) { k in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(k.number)").font(.song(16, .bold)).foregroundStyle(Palette.goldGradient).frame(width: 18)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(k.title).font(.song(14, .bold)).foregroundColor(Palette.cream)
                                    Text(k.citation).font(.song(11)).foregroundColor(Palette.muted)
                                    Caption(k.benefit, size: 12, weight: .regular, base: Palette.faint,
                                            highlight: Palette.goldDeep, alignment: .leading)
                                }
                            }
                        }
                    }
                    .goldCard(padding: 16)

                    Button("清空全部训练记录", role: .destructive) { confirmReset = true }
                        .buttonStyle(GhostButtonStyle())
                    Text("所有数据只保存在这台手机上 · v\(Bundle.main.appVersion)")
                        .font(.song(11)).foregroundColor(Palette.faint)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 18)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: model.settings) { _, _ in model.settingsChanged() }
        .alert("清空全部记录？", isPresented: $confirmReset) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { model.resetAll() }
        } message: {
            Text("等级、成绩和打卡都会归零，不能恢复")
        }
    }

    private var speedText: String {
        let r = model.settings.speechRate
        if r < 0.46 { return "慢" }
        if r > 0.54 { return "快" }
        return "标准"
    }

    private var line: some View { Rectangle().fill(Palette.line).frame(height: 0.6) }

    private func toggleRow(_ title: String, icon: String, isOn: Binding<Bool>, note: String? = nil) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundColor(Palette.gold).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.song(15)).foregroundColor(Palette.cream)
                    if let note { Text(note).font(.song(11)).foregroundColor(Palette.muted) }
                }
            }
        }
        .tint(Palette.gold)
        .padding(.vertical, 12)
    }
}

extension Bundle {
    var appVersion: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
