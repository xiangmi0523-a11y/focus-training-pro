import SwiftUI
import Observation
import BrainCore

struct AppSettings: Codable, Equatable {
    var sound = true
    var haptics = true
    var voiceAnswer = false
    var speechRate: Double = 0.5
    var showHints = true
}

/// 一次训练会话（可能是每日训练的多项）
struct SessionPlan: Identifiable, Equatable {
    let id = UUID()
    var modes: [ModeID]
    var isDaily: Bool
}

struct StatLine: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: String
}

/// 一局结束后各游戏交回的结果
struct GameResult {
    var score: Int
    var outcome: Outcome
    var accuracy: Double
    var meanRT: Double?
    var duration: Double
    var headline: String
    var stats: [StatLine]
}

enum DemoScreen: String {
    case home, detail, game, result, daily, stats, settings
}

@Observable
final class AppModel {
    var progress: ProgressData
    var settings: AppSettings
    var activeSession: SessionPlan?

    /// 截图演示参数（CI 用）
    let demoScreen: DemoScreen?
    let demoMode: ModeID?
    let demoKind: TrainingKind?
    private let ephemeral: Bool

    init() {
        let args = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        demoScreen = value(after: "-demo").flatMap(DemoScreen.init(rawValue:))
        demoMode = value(after: "-demoMode").flatMap(ModeID.init(rawValue:))
        demoKind = value(after: "-demoKind").flatMap(TrainingKind.init(rawValue:))
        ephemeral = args.contains("-demoData")

        if ephemeral {
            progress = AppModel.sampleProgress()
        } else {
            progress = AppModel.loadProgress() ?? ProgressData()
        }
        if let data = UserDefaults.standard.data(forKey: "settings"),
           let s = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = s
        } else {
            settings = AppSettings()
        }
        Haptic.enabled = settings.haptics
        SFX.enabled = settings.sound
    }

    var masteries: [Int] { TrainingKind.allCases.map { progress.mastery($0) } }

    func start(_ modes: [ModeID], daily: Bool = false) {
        guard !modes.isEmpty else { return }
        activeSession = SessionPlan(modes: modes, isDaily: daily)
    }

    /// 记一局，返回记录
    @discardableResult
    func record(_ result: GameResult, mode: ModeID, daily: Bool) -> SessionRecord {
        let level = progress.level(for: mode)
        let newLevel = mode == .storyDelayed ? level : LevelSystem.next(level, result.outcome)
        let rec = SessionRecord(mode: mode, level: level, newLevel: newLevel, score: result.score,
                                outcome: result.outcome, accuracy: result.accuracy, meanRT: result.meanRT,
                                duration: result.duration, daily: daily)
        progress.apply(rec)
        if mode == .storyDelayed { progress.pendingStory = nil }
        saveProgress()
        return rec
    }

    func setPendingStory(_ items: [ObjectItem], level: Int) {
        progress.pendingStory = PendingStory(itemIDs: items.map(\.id), created: Date(), level: level)
        saveProgress()
    }

    func resetAll() {
        progress = ProgressData()
        saveProgress()
    }

    // MARK: 每日训练

    var todayPlan: [ModeID] { DailyPlanner.plan(for: Date(), progress: progress) }

    func isDailyDone(_ mode: ModeID, on date: Date = Date()) -> Bool {
        let done = progress.dailyDone[DayKey.string(date)] ?? []
        return done.contains { ModeID(rawValue: $0)?.kind == mode.kind }
    }

    var todayRemaining: [ModeID] { todayPlan.filter { !isDailyDone($0) } }

    // MARK: 存储

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress.json")
    }

    private static func loadProgress() -> ProgressData? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ProgressData.self, from: data)
    }

    func saveProgress() {
        guard !ephemeral else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(progress) {
            try? data.write(to: AppModel.fileURL, options: .atomic)
        }
    }

    func settingsChanged() {
        Haptic.enabled = settings.haptics
        SFX.enabled = settings.sound
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "settings")
        }
    }

    /// 截图用的示例数据
    static func sampleProgress() -> ProgressData {
        var p = ProgressData()
        var rng = SeededRNG(seed: 99)
        let levels: [ModeID: Int] = [.schulteClassic: 12, .schulteReverse: 9, .schulteLetters: 7, .schultePoem: 5,
                                     .stroopColor: 9, .stroopCount: 6, .stroopSwitch: 4,
                                     .memoryOrdered: 8, .memoryReverse: 5, .memoryProbe: 3,
                                     .digitsForward: 10, .digitsBackward: 6, .digitsCocktail: 3,
                                     .mirrorSymmetric: 6, .mirrorRhythm: 4,
                                     .sortSingle: 7, .sortSwitch: 5,
                                     .storyChain: 6, .storyCue: 3]
        let now = Date()
        for back in stride(from: 20, through: 0, by: -1) {
            guard back % 4 != 3 else { continue }
            let day = Calendar.current.date(byAdding: .day, value: -back, to: now) ?? now
            for _ in 0..<2 {
                let mode = Array(levels.keys).sorted { $0.rawValue < $1.rawValue }.randomElement(using: &rng)!
                let target = levels[mode] ?? 1
                let lv = max(1, target - back / 4)
                let score = rng.int(in: 55...96)
                p.apply(SessionRecord(date: day, mode: mode, level: lv, newLevel: lv, score: score,
                                      outcome: score > 85 ? .excellent : (score > 68 ? .pass : .fail),
                                      accuracy: Double(score) / 100, meanRT: rng.double(in: 0.5...1.1),
                                      duration: rng.double(in: 40...120), daily: back == 0))
            }
        }
        for (m, l) in levels { p.levels[m.rawValue] = l }
        return p
    }
}
