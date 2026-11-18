import XCTest
@testable import BrainCore

final class LevelAndProgressTests: XCTestCase {
    func testLevelStaircase() {
        XCTAssertEqual(LevelSystem.next(1, .fail), 1)
        XCTAssertEqual(LevelSystem.next(5, .pass), 6)
        XCTAssertEqual(LevelSystem.next(5, .excellent), 7)
        XCTAssertEqual(LevelSystem.next(30, .excellent), 30)
        XCTAssertEqual(LevelSystem.rank(for: 1), "初识")
        XCTAssertEqual(LevelSystem.rank(for: 30), "宗师")
    }

    func testEveryKindHasModesAndFirstModeUnlocked() {
        for kind in TrainingKind.allCases {
            XCTAssertFalse(kind.modes.isEmpty, "\(kind)")
            XCTAssertEqual(kind.modes.first?.unlockMastery, 1, "\(kind)")
            XCTAssertEqual(kind.rules.count, 4)
        }
        XCTAssertEqual(TrainingKind.allCases.count, 7)
    }

    func testApplyRecordUpdatesLevelBestAndDaily() {
        var p = ProgressData()
        let rec = SessionRecord(mode: .schulteClassic, level: 1, newLevel: 3, score: 88, outcome: .excellent,
                                accuracy: 1, meanRT: nil, duration: 20, daily: true)
        p.apply(rec)
        XCTAssertEqual(p.level(for: .schulteClassic), 3)
        XCTAssertEqual(p.best(for: .schulteClassic), 88)
        XCTAssertEqual(p.mastery(.schulte), 3)
        XCTAssertTrue(p.isUnlocked(.schulteReverse))
        XCTAssertFalse(p.isUnlocked(.schulteLetters))
        XCTAssertEqual(p.dailyDone[DayKey.string(rec.date)], ["schulteClassic"])
        XCTAssertEqual(p.streak(), 1)
    }

    func testProgressCodableRoundTrip() throws {
        var p = ProgressData()
        p.apply(SessionRecord(mode: .stroopColor, level: 2, newLevel: 3, score: 70, outcome: .pass,
                              accuracy: 0.9, meanRT: 0.8, duration: 40, daily: false))
        p.pendingStory = PendingStory(itemIDs: ["car", "cat"], created: Date(), level: 2)
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(ProgressData.self, from: data)
        XCTAssertEqual(back.level(for: .stroopColor), 3)
        XCTAssertEqual(back.pendingStory?.itemIDs, ["car", "cat"])
    }

    func testStreakCountsConsecutiveDays() {
        var p = ProgressData()
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        for back in [0, 1, 2, 4] {
            let d = cal.date(byAdding: .day, value: -back, to: now)!
            p.apply(SessionRecord(date: d, mode: .memoryOrdered, level: 1, newLevel: 1, score: 50, outcome: .fail,
                                  accuracy: 0.5, meanRT: nil, duration: 10, daily: false))
        }
        XCTAssertEqual(p.streak(now: now, calendar: cal), 3)
    }

    func testDailyPlanIsStableAndDistinct() {
        let p = ProgressData()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let a = DailyPlanner.plan(for: date, progress: p)
        let b = DailyPlanner.plan(for: date, progress: p)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(Set(a.map(\.kind)).count, 3)
        XCTAssertFalse(a.contains(.storyDelayed))
    }

    func testPendingStoryWindow() {
        let s = PendingStory(itemIDs: ["a"], created: Date(timeIntervalSince1970: 0), level: 1)
        XCTAssertFalse(s.isReady(now: Date(timeIntervalSince1970: 60)))
        XCTAssertTrue(s.isReady(now: Date(timeIntervalSince1970: 3600)))
        XCTAssertFalse(s.isReady(now: Date(timeIntervalSince1970: 8 * 86400)))
    }
}

final class SchulteTests: XCTestCase {
    func testSizesGrowWithLevel() {
        XCTAssertEqual(SchulteConfig(mode: .schulteClassic, level: 1).size, 4)
        XCTAssertEqual(SchulteConfig(mode: .schulteClassic, level: 5).size, 5)
        XCTAssertEqual(SchulteConfig(mode: .schulteClassic, level: 30).size, 7)
        XCTAssertEqual(SchulteConfig(mode: .schulteLetters, level: 30).size, 5)
        XCTAssertLessThan(SchulteConfig(mode: .schulteClassic, level: 8).targetTime / 25,
                          SchulteConfig(mode: .schulteClassic, level: 4).targetTime / 25)
    }

    func solve(_ mode: ModeID, level: Int) -> SchulteBoard {
        var rng = SeededRNG(seed: 42)
        let config = SchulteConfig(mode: mode, level: level)
        var board = SchulteBoard(config: config, rng: &rng)
        XCTAssertEqual(board.cells.count, config.size * config.size)
        var guardCount = 0
        while let target = board.nextTarget, guardCount < 500 {
            guardCount += 1
            let idx = board.cells.firstIndex { !$0.found && !$0.isDecoy && $0.label == target.label && $0.tint == target.tint }
            XCTAssertNotNil(idx, "\(mode) missing \(target)")
            XCTAssertTrue(board.tap(idx!))
            if config.shuffleOnTap { board.reshuffle(rng: &rng) }
        }
        XCTAssertTrue(board.isComplete)
        XCTAssertEqual(board.errors, 0)
        return board
    }

    func testAllModesSolvable() {
        for mode in TrainingKind.schulte.modes {
            for level in [1, 6, 12, 20, 30] { _ = solve(mode, level: level) }
        }
    }

    func testWrongTapCountsError() {
        var rng = SeededRNG(seed: 1)
        var board = SchulteBoard(config: SchulteConfig(mode: .schulteClassic, level: 1), rng: &rng)
        let wrong = board.cells.firstIndex { $0.label == "5" }!
        XCTAssertFalse(board.tap(wrong))
        XCTAssertEqual(board.errors, 1)
        XCTAssertEqual(board.progress, 0)
    }

    func testGorbovAlternates() {
        var rng = SeededRNG(seed: 3)
        let board = SchulteBoard(config: SchulteConfig(mode: .schulteGorbov, level: 20), rng: &rng)
        XCTAssertEqual(board.sequence.first, SchulteTarget(label: "1", tint: .gold))
        XCTAssertEqual(board.sequence[1].tint, .red)
        XCTAssertEqual(board.sequence.count, board.cells.count)
    }

    func testPoemHasDecoys() {
        var rng = SeededRNG(seed: 9)
        let board = SchulteBoard(config: SchulteConfig(mode: .schultePoem, level: 8), rng: &rng)
        XCTAssertNotNil(board.poem)
        XCTAssertEqual(board.cells.filter(\.isDecoy).count, 5)
        XCTAssertEqual(board.sequence.count, 20)
    }

    func testEvaluate() {
        let c = SchulteConfig(mode: .schulteClassic, level: 5)
        XCTAssertEqual(SchulteBoard.evaluate(elapsed: c.targetTime * 0.5, errors: 0, completed: true, config: c).outcome, .excellent)
        XCTAssertEqual(SchulteBoard.evaluate(elapsed: c.targetTime * 0.95, errors: 0, completed: true, config: c).outcome, .pass)
        XCTAssertEqual(SchulteBoard.evaluate(elapsed: c.targetTime * 1.5, errors: 0, completed: true, config: c).outcome, .fail)
        XCTAssertEqual(SchulteBoard.evaluate(elapsed: 3, errors: 0, completed: false, config: c).outcome, .fail)
    }
}

final class StroopTests: XCTestCase {
    func testTrialsAreValid() {
        for mode in TrainingKind.stroop.modes {
            for level in [1, 10, 30] {
                var rng = SeededRNG(seed: UInt64(level))
                let config = StroopConfig(mode: mode, level: level)
                let trials = StroopGenerator.trials(config: config, rng: &rng)
                XCTAssertEqual(trials.count, config.total)
                for t in trials {
                    XCTAssertTrue((0..<config.buttonCount).contains(t.answer), "\(mode) \(t)")
                    switch t.stimulus {
                    case let .colorWord(word, ink, cue):
                        XCTAssertEqual(t.congruent, word == ink)
                        let expect = cue == .color ? ink : word
                        XCTAssertEqual(config.colors[t.answer], expect)
                        if mode == .stroopColor { XCTAssertEqual(cue, .color) }
                    case let .count(digit, count):
                        XCTAssertEqual(t.answer, count - 1)
                        XCTAssertEqual(t.congruent, digit == count)
                    case let .direction(word, pos):
                        XCTAssertEqual(t.answer, pos.rawValue)
                        XCTAssertEqual(t.congruent, word == pos)
                    }
                }
            }
        }
    }

    func testMostlyIncongruentAtHighLevel() {
        var rng = SeededRNG(seed: 77)
        let config = StroopConfig(mode: .stroopColor, level: 30)
        let trials = StroopGenerator.trials(config: config, rng: &rng)
        XCTAssertLessThan(trials.filter(\.congruent).count, trials.count / 3)
    }

    func testScorer() {
        let config = StroopConfig(mode: .stroopColor, level: 5)
        var rng = SeededRNG(seed: 5)
        let trials = StroopGenerator.trials(config: config, rng: &rng)
        let perfect = trials.map { StroopResponse(trial: $0, correct: true, rt: 0.4) }
        XCTAssertEqual(StroopScorer.evaluate(perfect, config: config).outcome, .excellent)
        let bad = trials.enumerated().map { StroopResponse(trial: $0.element, correct: $0.offset % 2 == 0, rt: 1.0) }
        XCTAssertEqual(StroopScorer.evaluate(bad, config: config).outcome, .fail)
    }

    func testSoundAlikes() {
        XCTAssertEqual(InkColor.match("兰", among: InkColor.allCases), .blue)
        XCTAssertEqual(InkColor.match("红", among: InkColor.allCases), .red)
        XCTAssertNil(InkColor.match("橙", among: [.red, .green]))
    }
}

final class MemoryAndStoryTests: XCTestCase {
    func testCatalogIDsUnique() {
        XCTAssertEqual(Set(ItemCatalog.all.map(\.id)).count, ItemCatalog.all.count)
        XCTAssertGreaterThan(ItemCatalog.all.count, 45)
    }

    func testStudyAndCandidates() {
        var rng = SeededRNG(seed: 11)
        for level in [1, 10, 30] {
            let config = MemoryConfig(mode: .memoryOrdered, level: level)
            let study = MemoryGenerator.study(config: config, rng: &rng)
            XCTAssertEqual(study.count, config.count)
            XCTAssertEqual(Set(study.map(\.id)).count, study.count)
            let cands = MemoryGenerator.candidates(study: study, config: config, rng: &rng)
            XCTAssertEqual(cands.count, config.count + config.distractorCount)
            XCTAssertTrue(Set(study.map(\.id)).isSubset(of: Set(cands.map(\.id))))
        }
    }

    func testProbes() {
        var rng = SeededRNG(seed: 12)
        let config = MemoryConfig(mode: .memoryProbe, level: 10)
        let study = MemoryGenerator.study(config: config, rng: &rng)
        let probes = MemoryGenerator.probes(study: study, count: 6, rng: &rng)
        XCTAssertEqual(probes.count, 6)
        for p in probes {
            switch p.kind {
            case let .whatAt(pos): XCTAssertEqual(p.options[p.answer], study[pos].id)
            case let .whereIs(id):
                let pos = study.firstIndex { $0.id == id }!
                XCTAssertEqual(p.options[p.answer], "\(pos + 1)")
            }
            XCTAssertEqual(Set(p.options).count, p.options.count)
        }
    }

    func testChangeRound() {
        var rng = SeededRNG(seed: 13)
        let config = MemoryConfig(mode: .memoryChange, level: 12)
        for _ in 0..<20 {
            let r = MemoryGenerator.changeRound(config: config, rng: &rng)
            XCTAssertEqual(r.before.count, r.after.count)
            let diff = Set(r.before.indices.filter { r.before[$0].id != r.after[$0].id })
            XCTAssertEqual(diff, r.changed)
            XCTAssertFalse(r.changed.isEmpty)
        }
    }

    func testOrderedAccuracy() {
        let items = Array(ItemCatalog.all.prefix(4))
        XCTAssertEqual(MemoryGenerator.orderedAccuracy(expected: items, picked: items), 1)
        XCTAssertEqual(MemoryGenerator.orderedAccuracy(expected: items, picked: items.reversed()), 0)
    }

    func testStoryAndCues() {
        var rng = SeededRNG(seed: 14)
        let config = StoryConfig(mode: .storyChain, level: 10)
        let items = StoryGenerator.items(config: config, rng: &rng)
        XCTAssertEqual(items.count, config.count)
        let story = StoryGenerator.story(for: items, rng: &rng)
        XCTAssertEqual(story.count, items.count)
        let cues = StoryGenerator.cueQuestions(items: items, count: 6, rng: &rng)
        XCTAssertEqual(cues.count, 6)
        for q in cues {
            let idx = items.firstIndex { $0.id == q.itemID }!
            let expected = q.askNext ? items[idx + 1] : items[idx - 1]
            XCTAssertEqual(q.options[q.answer], expected.id)
        }
        let few = Array(items.prefix(3))
        XCTAssertLessThanOrEqual(StoryGenerator.cueQuestions(items: few, count: 6, rng: &rng).count, 4)
    }

    func testArithmetic() {
        var rng = SeededRNG(seed: 15)
        for _ in 0..<50 {
            let t = ArithmeticTask.make(rng: &rng, level: 20)
            XCTAssertEqual(Set(t.options).count, 3)
            let parts = t.text.components(separatedBy: " ")
            let a = Int(parts[0])!, b = Int(parts[2])!
            XCTAssertEqual(t.options[t.answer], parts[1] == "+" ? a + b : a - b)
        }
    }
}

final class DigitsTests: XCTestCase {
    func testSequenceRules() {
        var rng = SeededRNG(seed: 21)
        for _ in 0..<100 {
            let s = DigitGenerator.sequence(length: 10, rng: &rng)
            XCTAssertEqual(s.count, 10)
            for i in 1..<s.count { XCTAssertNotEqual(s[i], s[i - 1]) }
            let d = DigitGenerator.distractor(for: s, rng: &rng)
            for i in s.indices { XCTAssertNotEqual(s[i], d[i]) }
        }
    }

    func testExpected() {
        XCTAssertEqual(DigitGenerator.expected([3, 1, 2], mode: .digitsBackward), [2, 1, 3])
        XCTAssertEqual(DigitGenerator.expected([3, 1, 2], mode: .digitsSorted), [1, 2, 3])
        XCTAssertEqual(DigitGenerator.expected([3, 1, 2], mode: .digitsForward), [3, 1, 2])
        XCTAssertEqual(DigitGenerator.positionAccuracy(expected: [1, 2, 3, 4], answer: [1, 2, 4, 3]), 0.5)
    }

    func testLengthGrows() {
        XCTAssertLessThan(DigitConfig(mode: .digitsForward, level: 1).length, DigitConfig(mode: .digitsForward, level: 20).length)
        XCTAssertLessThanOrEqual(DigitConfig(mode: .digitsForward, level: 30).length, 13)
        XCTAssertEqual(DigitGenerator.evaluate(exact: 3, trials: 3, meanPositionAccuracy: 1).outcome, .excellent)
        XCTAssertEqual(DigitGenerator.evaluate(exact: 2, trials: 3, meanPositionAccuracy: 0.9).outcome, .pass)
        XCTAssertEqual(DigitGenerator.evaluate(exact: 1, trials: 3, meanPositionAccuracy: 0.6).outcome, .fail)
        XCTAssertEqual(NumberCode.table.count, 10)
    }
}

final class MirrorTests: XCTestCase {
    func testShapesInUnitSquare() {
        for kind in ShapeKind.allCases {
            let pts = ShapeLibrary.points(kind)
            XCTAssertEqual(pts.count, 160, "\(kind)")
            for p in pts {
                XCTAssertTrue((0...1).contains(p.x) && (0...1).contains(p.y), "\(kind) \(p)")
            }
        }
    }

    func testPerfectTraceScoresHigh() {
        let target = ShapeLibrary.points(.heart)
        var l = TraceTracker(target: target, tolerance: 0.06)
        var r = TraceTracker(target: ShapeLibrary.mirrored(target), tolerance: 0.06)
        var ls: [(t: Double, p: Double)] = []
        var rs: [(t: Double, p: Double)] = []
        for (i, p) in target.enumerated() {
            l.add(p)
            r.add(Vec2(1 - p.x, p.y))
            ls.append((Double(i) * 0.02, l.coverage))
            rs.append((Double(i) * 0.02, r.coverage))
        }
        XCTAssertGreaterThan(l.coverage, 0.99)
        XCTAssertGreaterThan(l.precision, 0.99)
        let sync = MirrorScorer.synchrony(left: ls, right: rs)
        XCTAssertGreaterThan(sync, 0.95)
        XCTAssertGreaterThan(MirrorScorer.roundScore(left: l, right: r, synchrony: sync), 95)
    }

    func testScribbleScoresLow() {
        let target = ShapeLibrary.points(.star)
        var l = TraceTracker(target: target, tolerance: 0.05)
        var rng = SeededRNG(seed: 31)
        for _ in 0..<100 { l.add(Vec2(rng.double(in: 0...1), rng.double(in: 0...1))) }
        let r = TraceTracker(target: target, tolerance: 0.05)
        XCTAssertLessThan(MirrorScorer.roundScore(left: l, right: r, synchrony: 0), 50)
    }

    func testTargetsByMode() {
        var rng = SeededRNG(seed: 32)
        let diff = MirrorConfig(mode: .mirrorDifferent, level: 12).targets(rng: &rng)
        XCTAssertNotEqual(diff.left, diff.right)
        let sym = MirrorConfig(mode: .mirrorSymmetric, level: 12).targets(rng: &rng)
        XCTAssertEqual(sym.rightPoints.first?.x ?? 0, 1 - (sym.leftPoints.first?.x ?? 0), accuracy: 1e-9)
    }

    func testRhythm() {
        let c = RhythmConfig(level: 5)
        XCTAssertEqual(c.leftBeats, 2)
        XCTAssertEqual(c.rightBeats, 3)
        let exp = c.expectedTimes(beats: 3, from: 0, cycles: 0..<2)
        XCTAssertEqual(exp.count, 6)
        let perfect = RhythmScorer.match(taps: exp, expected: exp, window: 0.2)
        XCTAssertEqual(perfect.hitRate, 1)
        XCTAssertEqual(RhythmScorer.score(hitRate: perfect.hitRate, meanError: perfect.meanError, window: 0.2, extra: 0, expectedCount: 6), 100)
        let off = RhythmScorer.match(taps: exp.map { $0 + 0.5 }, expected: exp, window: 0.2)
        XCTAssertEqual(off.hitRate, 0)
    }
}

final class SortingTests: XCTestCase {
    func testSwitchModeSwitches() {
        var rng = SeededRNG(seed: 41)
        let config = SortConfig(mode: .sortSwitch, level: 3)
        let trials = SortGenerator.trials(config: config, rng: &rng)
        XCTAssertEqual(trials.count, config.trials)
        XCTAssertGreaterThan(trials.filter(\.ruleChanged).count, 1)
        XCTAssertEqual(Set(trials.map(\.rule)), Set(config.rules))
        for t in trials { XCTAssertTrue(t.tier.range.contains(t.price)) }
    }

    func testHiddenTrialsUnambiguous() {
        var rng = SeededRNG(seed: 42)
        let config = SortConfig(mode: .sortHidden, level: 12)
        let trials = SortGenerator.trials(config: config, rng: &rng)
        for t in trials {
            XCTAssertEqual(Set([t.answer(for: .category), t.answer(for: .price), t.answer(for: .color)]).count, 3)
        }
    }

    func testHiddenRuleEngine() {
        var rng = SeededRNG(seed: 43)
        let config = SortConfig(mode: .sortHidden, level: 12)
        let trials = SortGenerator.trials(config: config, rng: &rng)
        var engine = HiddenRuleEngine(runLength: config.hiddenRun, rng: &rng)
        var lastRule = engine.rule
        for t in trials {
            let ok = engine.respond(bucket: t.answer(for: engine.rule), trial: t, rng: &rng)
            XCTAssertTrue(ok)
            if engine.rule != lastRule { lastRule = engine.rule }
        }
        XCTAssertEqual(engine.categoriesDone, trials.count / config.hiddenRun)
        XCTAssertEqual(engine.errors, 0)
        // 坚持旧规则算持续性错误
        let prev = engine.previousRule!
        let t = trials[0]
        _ = engine.respond(bucket: t.answer(for: prev), trial: t, rng: &rng)
        XCTAssertEqual(engine.perseverativeErrors, 1)
    }
}
