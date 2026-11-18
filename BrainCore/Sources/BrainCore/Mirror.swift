import Foundation

public struct Vec2: Codable, Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public func distance(to o: Vec2) -> Double {
        let dx = x - o.x, dy = y - o.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

public enum ShapeKind: String, CaseIterable, Codable, Sendable, Hashable {
    case line, circle, square, triangle, heart, wave, star, infinity, zigzag, spiral, flower

    public var name: String {
        switch self {
        case .line: return "直线"
        case .circle: return "圆"
        case .square: return "方"
        case .triangle: return "三角"
        case .heart: return "心"
        case .wave: return "波浪"
        case .star: return "星"
        case .infinity: return "无限"
        case .zigzag: return "闪电"
        case .spiral: return "螺旋"
        case .flower: return "花"
        }
    }

    public static func pool(level: Int) -> [ShapeKind] {
        switch level {
        case ..<4: return [.line, .circle, .square]
        case 4..<9: return [.circle, .square, .triangle, .heart, .wave]
        case 9..<16: return [.triangle, .heart, .wave, .star, .infinity, .zigzag]
        default: return [.star, .infinity, .zigzag, .spiral, .flower, .heart]
        }
    }
}

/// 图形在单位方格 [0,1]×[0,1] 中的点（y 向下）
public enum ShapeLibrary {
    public static func points(_ kind: ShapeKind, samples: Int = 160) -> [Vec2] {
        let n = max(16, samples)
        func ts() -> [Double] { (0..<n).map { Double($0) / Double(n - 1) } }
        switch kind {
        case .line:
            return ts().map { Vec2(0.5, 0.12 + 0.76 * $0) }
        case .circle:
            return ts().map { t in
                let a = -Double.pi / 2 + 2 * .pi * t
                return Vec2(0.5 + 0.38 * cos(a), 0.5 + 0.38 * sin(a))
            }
        case .square:
            return polyline([Vec2(0.15, 0.15), Vec2(0.85, 0.15), Vec2(0.85, 0.85), Vec2(0.15, 0.85), Vec2(0.15, 0.15)], samples: n)
        case .triangle:
            return polyline([Vec2(0.5, 0.12), Vec2(0.88, 0.84), Vec2(0.12, 0.84), Vec2(0.5, 0.12)], samples: n)
        case .heart:
            return ts().map { t in
                let a = 2 * .pi * t
                let x = 16 * pow(sin(a), 3)
                let y = 13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a)
                return Vec2(0.5 + x / 40, 0.47 - y / 40)
            }
        case .wave:
            return ts().map { t in Vec2(0.5 + 0.18 * sin(t * 4 * .pi), 0.1 + 0.8 * t) }
        case .star:
            var vs: [Vec2] = []
            for i in 0...10 {
                let a = -Double.pi / 2 + Double(i) * .pi / 5
                let r = i % 2 == 0 ? 0.4 : 0.17
                vs.append(Vec2(0.5 + r * cos(a), 0.53 + r * sin(a)))
            }
            return polyline(vs, samples: n)
        case .infinity:
            return ts().map { t in
                let a = 2 * .pi * t
                let d = 1 + sin(a) * sin(a)
                return Vec2(0.5 + 0.36 * sin(a) * cos(a) / d * 1.4, 0.5 + 0.4 * cos(a) / d)
            }
        case .zigzag:
            return polyline([Vec2(0.3, 0.1), Vec2(0.7, 0.3), Vec2(0.3, 0.5), Vec2(0.7, 0.7), Vec2(0.3, 0.9)], samples: n)
        case .spiral:
            return ts().map { t in
                let a = 3 * 2 * .pi * t
                let r = 0.04 + 0.36 * t
                return Vec2(0.5 + r * cos(a), 0.5 + r * sin(a))
            }
        case .flower:
            return ts().map { t in
                let a = 2 * .pi * t
                let r = 0.12 + 0.28 * abs(cos(2.5 * a))
                return Vec2(0.5 + r * cos(a - .pi / 2), 0.5 + r * sin(a - .pi / 2))
            }
        }
    }

    public static func polyline(_ vs: [Vec2], samples: Int) -> [Vec2] {
        guard vs.count >= 2 else { return vs }
        var lengths: [Double] = [0]
        for i in 1..<vs.count { lengths.append(lengths[i - 1] + vs[i].distance(to: vs[i - 1])) }
        let total = lengths.last ?? 1
        var out: [Vec2] = []
        var seg = 1
        for k in 0..<samples {
            let d = total * Double(k) / Double(samples - 1)
            while seg < vs.count - 1 && lengths[seg] < d { seg += 1 }
            let segLen = max(lengths[seg] - lengths[seg - 1], 1e-9)
            let u = clamp((d - lengths[seg - 1]) / segLen, 0, 1)
            let a = vs[seg - 1], b = vs[seg]
            out.append(Vec2(a.x + (b.x - a.x) * u, a.y + (b.y - a.y) * u))
        }
        return out
    }

    public static func mirrored(_ pts: [Vec2]) -> [Vec2] { pts.map { Vec2(1 - $0.x, $0.y) } }
}

public struct MirrorConfig: Sendable {
    public let mode: ModeID
    public let level: Int
    public let rounds: Int
    /// 容差（占画布边长的比例）
    public let tolerance: Double
    public let timeLimit: Double
    public let passScore: Int

    public init(mode: ModeID, level: Int) {
        let lv = clamp(level, 1, LevelSystem.maxLevel)
        self.mode = mode
        self.level = lv
        self.rounds = 3
        self.tolerance = max(0.045, 0.11 - 0.0022 * Double(lv))
        self.timeLimit = max(5, 14 - 0.3 * Double(lv))
        self.passScore = 70
    }

    /// 生成一轮的左右目标图形
    public func targets(rng: inout SeededRNG) -> (left: ShapeKind, right: ShapeKind, leftPoints: [Vec2], rightPoints: [Vec2]) {
        let pool = ShapeKind.pool(level: level)
        let a = pool.randomElement(using: &rng) ?? .circle
        switch mode {
        case .mirrorParallel:
            let p = ShapeLibrary.points(a)
            return (a, a, p, p)
        case .mirrorDifferent:
            var b = pool.randomElement(using: &rng) ?? .square
            var guardCount = 0
            while b == a && guardCount < 10 { b = pool.randomElement(using: &rng) ?? .square; guardCount += 1 }
            if b == a { b = a == .circle ? .square : .circle }
            return (a, b, ShapeLibrary.points(a), ShapeLibrary.points(b))
        default:
            let p = ShapeLibrary.points(a)
            return (a, a, p, ShapeLibrary.mirrored(p))
        }
    }
}

/// 一侧的描线追踪：实时记录覆盖进度
public struct TraceTracker: Sendable {
    public let target: [Vec2]
    public let tolerance: Double
    public private(set) var drawn: [Vec2] = []
    public private(set) var covered: [Bool]
    public private(set) var coveredCount = 0

    public init(target: [Vec2], tolerance: Double) {
        self.target = target
        self.tolerance = tolerance
        self.covered = Array(repeating: false, count: target.count)
    }

    public var coverage: Double { target.isEmpty ? 0 : Double(coveredCount) / Double(target.count) }

    public mutating func add(_ p: Vec2) {
        drawn.append(p)
        for i in target.indices where !covered[i] && target[i].distance(to: p) <= tolerance {
            covered[i] = true
            coveredCount += 1
        }
    }

    /// 画出来的点有多少落在容差内
    public var precision: Double {
        guard !drawn.isEmpty else { return 0 }
        var good = 0
        for p in drawn {
            var best = Double.greatestFiniteMagnitude
            for t in target {
                let d = t.distance(to: p)
                if d < best { best = d }
                if best <= tolerance { break }
            }
            if best <= tolerance * 1.25 { good += 1 }
        }
        return Double(good) / Double(drawn.count)
    }

    public var accuracy: Double { 0.55 * coverage + 0.45 * precision }
}

public enum MirrorScorer {
    /// 同步度：两侧覆盖进度随时间的差异
    public static func synchrony(left: [(t: Double, p: Double)], right: [(t: Double, p: Double)]) -> Double {
        let start = min(left.first?.t ?? Double.infinity, right.first?.t ?? Double.infinity)
        guard start.isFinite else { return 0 }
        let end = max(left.last?.t ?? start, right.last?.t ?? start)
        guard end > start else { return 0 }
        func value(_ s: [(t: Double, p: Double)], at t: Double) -> Double {
            var v = 0.0
            for e in s { if e.t <= t { v = e.p } else { break } }
            return v
        }
        var sum = 0.0
        var n = 0
        var t = start
        let step = max((end - start) / 40, 0.02)
        while t <= end {
            sum += abs(value(left, at: t) - value(right, at: t))
            n += 1
            t += step
        }
        return clamp(1 - sum / Double(max(n, 1)) * 1.6, 0, 1)
    }

    public static func roundScore(left: TraceTracker, right: TraceTracker, synchrony: Double) -> Int {
        let acc = (left.accuracy + right.accuracy) / 2
        let balance = 1 - abs(left.coverage - right.coverage)
        return Int(clamp((acc * 0.72 + synchrony * 0.18 + balance * 0.10) * 100, 0, 100).rounded())
    }

    public static func outcome(average: Double, config: MirrorConfig) -> Outcome {
        if average >= 86 { return .excellent }
        if average >= Double(config.passScore) { return .pass }
        return .fail
    }
}

// MARK: - 复合节奏

public struct RhythmConfig: Sendable {
    public let level: Int
    public let leftBeats: Int
    public let rightBeats: Int
    public let cycle: Double
    public let cycles: Int
    /// 前几轮有引导
    public let guidedCycles: Int
    /// 是否在测试轮隐藏视觉引导
    public let hideGuide: Bool

    public init(level: Int) {
        let lv = clamp(level, 1, LevelSystem.maxLevel)
        self.level = lv
        let pair: (Int, Int)
        switch lv {
        case ..<4: pair = (1, 2)
        case 4..<10: pair = (2, 3)
        case 10..<17: pair = (3, 4)
        case 17..<24: pair = (3, 5)
        default: pair = (4, 5)
        }
        self.leftBeats = pair.0
        self.rightBeats = pair.1
        self.cycle = max(1.6, 3.0 - 0.05 * Double(lv))
        self.cycles = 6
        self.guidedCycles = 2
        self.hideGuide = lv >= 6
    }

    public func expectedTimes(beats: Int, from start: Double, cycles range: Range<Int>) -> [Double] {
        var out: [Double] = []
        for c in range {
            for b in 0..<beats {
                out.append(start + Double(c) * cycle + Double(b) * cycle / Double(beats))
            }
        }
        return out
    }
}

public enum RhythmScorer {
    /// 返回 (命中率, 平均误差秒)
    public static func match(taps: [Double], expected: [Double], window: Double) -> (hitRate: Double, meanError: Double, extra: Int) {
        guard !expected.isEmpty else { return (0, 0, taps.count) }
        var used = Array(repeating: false, count: taps.count)
        var errors: [Double] = []
        for e in expected {
            var best = -1
            var bestD = Double.greatestFiniteMagnitude
            for (i, t) in taps.enumerated() where !used[i] {
                let d = abs(t - e)
                if d < bestD { bestD = d; best = i }
            }
            if best >= 0 && bestD <= window {
                used[best] = true
                errors.append(bestD)
            }
        }
        let extra = used.filter { !$0 }.count
        let mean = errors.isEmpty ? window : errors.reduce(0, +) / Double(errors.count)
        return (Double(errors.count) / Double(expected.count), mean, extra)
    }

    public static func score(hitRate: Double, meanError: Double, window: Double, extra: Int, expectedCount: Int) -> Int {
        let timing = clamp(1 - meanError / window, 0, 1)
        let penalty = Double(extra) / Double(max(expectedCount, 1)) * 0.5
        return Int(clamp((hitRate * 0.65 + timing * 0.35 - penalty) * 100, 0, 100).rounded())
    }
}
