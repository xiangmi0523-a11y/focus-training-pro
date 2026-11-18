import Foundation

public enum Outcome: String, Codable, Sendable {
    case excellent, pass, fail

    public var title: String {
        switch self {
        case .excellent: return "出色"
        case .pass: return "过关"
        case .fail: return "再练一次"
        }
    }
}

/// 自适应难度：做得好升级，做不好降级
public enum LevelSystem {
    public static let maxLevel = 30

    public static func next(_ level: Int, _ outcome: Outcome) -> Int {
        switch outcome {
        case .excellent: return clamp(level + 2, 1, maxLevel)
        case .pass: return clamp(level + 1, 1, maxLevel)
        case .fail: return clamp(level - 1, 1, maxLevel)
        }
    }

    public static func rank(for level: Int) -> String {
        switch level {
        case ..<5: return "初识"
        case 5..<10: return "入门"
        case 10..<15: return "熟练"
        case 15..<20: return "精通"
        case 20..<26: return "大师"
        default: return "宗师"
        }
    }

    /// 0...1
    public static func fraction(_ level: Int) -> Double {
        Double(clamp(level, 1, maxLevel) - 1) / Double(maxLevel - 1)
    }
}

public struct SessionRecord: Codable, Identifiable, Sendable, Hashable {
    public var id: UUID
    public var date: Date
    public var mode: ModeID
    public var level: Int
    public var newLevel: Int
    public var score: Int
    public var outcome: Outcome
    public var accuracy: Double
    public var meanRT: Double?
    public var duration: Double
    public var daily: Bool

    public init(id: UUID = UUID(), date: Date = Date(), mode: ModeID, level: Int, newLevel: Int,
                score: Int, outcome: Outcome, accuracy: Double, meanRT: Double?, duration: Double, daily: Bool) {
        self.id = id
        self.date = date
        self.mode = mode
        self.level = level
        self.newLevel = newLevel
        self.score = score
        self.outcome = outcome
        self.accuracy = accuracy
        self.meanRT = meanRT
        self.duration = duration
        self.daily = daily
    }

    public var kind: TrainingKind { mode.kind }
}

/// 上次「串成故事」记下的清单，用于延迟回忆
public struct PendingStory: Codable, Sendable, Hashable {
    public var itemIDs: [String]
    public var created: Date
    public var level: Int

    public init(itemIDs: [String], created: Date, level: Int) {
        self.itemIDs = itemIDs
        self.created = created
        self.level = level
    }

    /// 至少隔 20 分钟、最多 7 天内可做延迟回忆
    public func isReady(now: Date = Date()) -> Bool {
        let gap = now.timeIntervalSince(created)
        return gap >= 20 * 60 && gap <= 7 * 24 * 3600
    }
}

public struct ProgressData: Codable, Sendable {
    public var levels: [String: Int] = [:]
    public var bestScores: [String: Int] = [:]
    public var sessions: [SessionRecord] = []
    /// "2026-11-18" -> 当天完成的每日任务 mode id
    public var dailyDone: [String: [String]] = [:]
    public var pendingStory: PendingStory?
    public var totalSeconds: Double = 0

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case levels, bestScores, sessions, dailyDone, pendingStory, totalSeconds
    }

    /// 字段缺失时用默认值，升级版本不丢数据
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        levels = (try? c.decodeIfPresent([String: Int].self, forKey: .levels)) ?? [:]
        bestScores = (try? c.decodeIfPresent([String: Int].self, forKey: .bestScores)) ?? [:]
        sessions = (try? c.decodeIfPresent([LossyRecord].self, forKey: .sessions))?.compactMap(\.value) ?? []
        dailyDone = (try? c.decodeIfPresent([String: [String]].self, forKey: .dailyDone)) ?? [:]
        pendingStory = try? c.decodeIfPresent(PendingStory.self, forKey: .pendingStory)
        totalSeconds = (try? c.decodeIfPresent(Double.self, forKey: .totalSeconds)) ?? 0
    }

    /// 单条记录解析失败时跳过，不影响其他记录
    private struct LossyRecord: Decodable {
        let value: SessionRecord?
        init(from decoder: Decoder) throws {
            value = try? SessionRecord(from: decoder)
        }
    }

    public func level(for mode: ModeID) -> Int {
        clamp(levels[mode.rawValue] ?? 1, 1, LevelSystem.maxLevel)
    }

    public func best(for mode: ModeID) -> Int? { bestScores[mode.rawValue] }

    /// 训练熟练度 = 各玩法最高等级
    public func mastery(_ kind: TrainingKind) -> Int {
        kind.modes.filter { $0 != .storyDelayed }.map { level(for: $0) }.max() ?? 1
    }

    public func isUnlocked(_ mode: ModeID) -> Bool {
        mastery(mode.kind) >= mode.unlockMastery
    }

    public func unlockedModes(_ kind: TrainingKind) -> [ModeID] {
        kind.modes.filter { isUnlocked($0) && $0 != .storyDelayed }
    }

    public func sessions(of kind: TrainingKind) -> [SessionRecord] {
        sessions.filter { $0.kind == kind }
    }

    /// 记录一局，返回新的等级
    @discardableResult
    public mutating func apply(_ record: SessionRecord) -> Int {
        if record.mode != .storyDelayed {
            levels[record.mode.rawValue] = record.newLevel
        }
        let key = record.mode.rawValue
        bestScores[key] = max(bestScores[key] ?? 0, record.score)
        sessions.append(record)
        if sessions.count > 2000 { sessions.removeFirst(sessions.count - 2000) }
        totalSeconds += record.duration
        if record.daily {
            let day = DayKey.string(record.date)
            var done = dailyDone[day] ?? []
            if !done.contains(key) { done.append(key) }
            dailyDone[day] = done
        }
        return record.newLevel
    }

    /// 连续训练天数（今天或昨天起算）
    public func streak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(sessions.map { DayKey.string($0.date, calendar: calendar) })
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(DayKey.string(cursor, calendar: calendar)) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(DayKey.string(y, calendar: calendar)) else { return 0 }
            cursor = y
        }
        var count = 0
        while days.contains(DayKey.string(cursor, calendar: calendar)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    public func trainedDays(calendar: Calendar = .current) -> Set<String> {
        Set(sessions.map { DayKey.string($0.date, calendar: calendar) })
    }

    /// 各维度 0...100
    public func dimensionScore(_ kind: TrainingKind) -> Int {
        let base = LevelSystem.fraction(mastery(kind)) * 85
        let recent = sessions(of: kind).suffix(5)
        let recentAvg = recent.isEmpty ? 0 : Double(recent.map(\.score).reduce(0, +)) / Double(recent.count)
        return Int((base + recentAvg * 0.15).rounded())
    }

    /// 脑力指数：七个维度平均 × 10
    public var brainIndex: Int {
        let all = TrainingKind.allCases.map { dimensionScore($0) }
        return Int((Double(all.reduce(0, +)) / Double(all.count) * 10).rounded())
    }
}

public enum DayKey {
    public static func string(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// 每日训练：每天固定 3 个不同训练
public enum DailyPlanner {
    public static func plan(for date: Date, progress: ProgressData, calendar: Calendar = .current) -> [ModeID] {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let seed = UInt64((c.year ?? 2026) * 10_000 + (c.month ?? 1) * 100 + (c.day ?? 1))
        var rng = SeededRNG(seed: seed &* 2_654_435_761)
        let kinds = Array(TrainingKind.allCases.shuffled(using: &rng).prefix(3))
        return kinds.map { kind in
            let modes = progress.unlockedModes(kind).filter { $0.isDailyEligible }
            return modes.randomElement(using: &rng) ?? kind.modes[0]
        }
    }
}
