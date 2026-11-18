import SwiftUI
import BrainCore

/// 顶部的编号格子：记忆时逐个填入，回忆时显示已选
struct SlotRow: View {
    let count: Int
    var items: [ObjectItem?]
    var marks: [Bool?] = []
    var highlight: Int?
    var hidden = false

    var body: some View {
        let perRow = min(count, 7)
        let cols = Array(repeating: GridItem(.fixed(42), spacing: 6), count: max(perRow, 1))
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                let item = i < items.count ? items[i] : nil
                let mark = i < marks.count ? marks[i] : nil
                ZStack {
                    DashedSlot(size: 42, index: i + 1, filled: item != nil)
                    if hidden && item != nil {
                        Text("?").font(.song(18, .bold)).foregroundColor(Palette.gold)
                    } else if let item {
                        SymbolIcon(name: item.symbol, color: Palette.hue(item.hue), size: 18)
                    }
                    if let mark {
                        Image(systemName: mark ? "checkmark" : "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(mark ? Palette.gold : Palette.red)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(3)
                    }
                }
                .frame(width: 42, height: 42)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(highlight == i ? Palette.gold : .clear, lineWidth: 1.5)
                )
            }
        }
    }
}

/// 按顺序从候选里找回
struct OrderedRecallBoard: View {
    let expected: [ObjectItem]
    let candidates: [ObjectItem]
    let title: String
    let onDone: ([ObjectItem]) -> Void

    @State private var picked: [ObjectItem] = []
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 14) {
            Caption(title, size: 16)
            SlotRow(count: expected.count, items: slotItems, marks: revealed ? marks : [])
                .animation(.easeOut(duration: 0.2), value: picked.count)
            if revealed {
                VStack(spacing: 6) {
                    Text("正确顺序").font(.song(12)).foregroundColor(Palette.muted)
                    SlotRow(count: expected.count, items: expected.map { Optional($0) })
                }
                .transition(.opacity)
            }
            ScrollView(showsIndicators: false) {
                let cols = [GridItem(.adaptive(minimum: 66), spacing: 10)]
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(candidates) { item in
                        let used = picked.contains(item)
                        Button {
                            pick(item)
                        } label: {
                            ItemTile(item: item, size: 62, state: used ? .dimmed : .normal)
                        }
                        .buttonStyle(PressStyle())
                        .disabled(used || revealed)
                    }
                }
                .padding(.vertical, 4)
            }
            HStack(spacing: 12) {
                Button {
                    Haptic.soft()
                    if !picked.isEmpty { _ = withAnimation { picked.removeLast() } }
                } label: { Label("撤销", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(picked.isEmpty || revealed)
                Button("确认") { confirm() }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(picked.count < expected.count || revealed)
                    .opacity(picked.count < expected.count ? 0.5 : 1)
            }
        }
    }

    private var slotItems: [ObjectItem?] {
        (0..<expected.count).map { $0 < picked.count ? picked[$0] : nil }
    }

    private var marks: [Bool?] {
        expected.indices.map { i in i < picked.count ? picked[i].id == expected[i].id : false }
    }

    private func pick(_ item: ObjectItem) {
        guard picked.count < expected.count else { return }
        Haptic.tap()
        withAnimation(.easeOut(duration: 0.15)) { picked.append(item) }
        if picked.count == expected.count && expected.count <= 6 {
            // 少量时自动确认
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { if !revealed { confirm() } }
        }
    }

    private func confirm() {
        guard !revealed else { return }
        let acc = MemoryGenerator.orderedAccuracy(expected: expected, picked: picked)
        if acc >= 0.999 { Haptic.success(); SFX.correct() } else { Haptic.error() }
        withAnimation(.easeOut(duration: 0.3)) { revealed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { onDone(picked) }
    }
}

/// 记完后插入的干扰题，防止靠「默念」硬撑
struct ArithmeticInterlude: View {
    let level: Int
    let count: Int
    let onDone: (Int) -> Void

    @State private var tasks: [ArithmeticTask] = []
    @State private var index = 0
    @State private var correct = 0
    @State private var picked: Int?

    var body: some View {
        VStack(spacing: 24) {
            Caption("先别回想——[算一算]", size: 18)
            Text("干扰题 \(min(index + 1, count))/\(count)").font(.song(12)).foregroundColor(Palette.muted)
            if index < tasks.count {
                let t = tasks[index]
                Text("\(t.text) = ?")
                    .font(.digits(44, .bold))
                    .foregroundColor(Palette.cream)
                    .id(index)
                    .transition(.opacity)
                HStack(spacing: 12) {
                    ForEach(Array(t.options.enumerated()), id: \.offset) { i, v in
                        Button {
                            choose(i)
                        } label: {
                            Text("\(v)")
                                .font(.digits(24, .bold))
                                .foregroundColor(picked == i ? Palette.ink : Palette.cream)
                                .frame(maxWidth: .infinity).frame(height: 60)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(picked == i ? (i == t.answer ? Palette.gold : Palette.red) : Palette.cardHi))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.lineHi, lineWidth: 0.8))
                        }
                        .buttonStyle(PressStyle())
                        .disabled(picked != nil)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            var rng = SeededRNG.random()
            tasks = (0..<count).map { _ in ArithmeticTask.make(rng: &rng, level: level) }
        }
    }

    private func choose(_ i: Int) {
        guard index < tasks.count else { return }
        picked = i
        if i == tasks[index].answer { correct += 1; Haptic.tap() } else { Haptic.error() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            picked = nil
            if index + 1 >= count {
                onDone(correct)
            } else {
                withAnimation { index += 1 }
            }
        }
    }
}

/// 四选一题目
struct ChoiceQuestion: View {
    let prompt: String
    let options: [ChoiceOption]
    let answer: Int
    let onAnswer: (Bool) -> Void

    @State private var picked: Int?

    struct ChoiceOption: Identifiable {
        let id = UUID()
        var item: ObjectItem?
        var text: String?
    }

    var body: some View {
        VStack(spacing: 22) {
            Caption(prompt, size: 20)
            let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.element.id) { i, opt in
                    Button {
                        guard picked == nil else { return }
                        picked = i
                        let ok = i == answer
                        if ok { Haptic.tap(); SFX.tick() } else { Haptic.error() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { onAnswer(ok) }
                    } label: {
                        VStack(spacing: 6) {
                            if let item = opt.item {
                                SymbolIcon(name: item.symbol, color: Palette.hue(item.hue), size: 30)
                                Text(item.name).font(.song(13)).foregroundColor(Palette.muted)
                            } else if let text = opt.text {
                                Text(text).font(.digits(30, .bold)).foregroundColor(Palette.cream)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 96)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cardHi))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor(i), lineWidth: picked == nil ? 0.8 : 1.8))
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
    }

    private func borderColor(_ i: Int) -> Color {
        guard let p = picked else { return Palette.lineHi }
        if i == answer { return Palette.gold }
        return i == p ? Palette.red : Palette.lineHi
    }
}
