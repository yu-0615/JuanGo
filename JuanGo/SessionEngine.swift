import SwiftUI
import SwiftData

// MARK: - Engine

@Observable final class SessionEngine {
    struct Item: Identifiable { let id = UUID(); let word: Word; let type: QType }
    private struct Snapshot {
        let queue: [Item]; let pos: Int; let word: Word; let level: Int; let due: Date?; let last: Date?
        let count: Int; let log: ReviewLog?; let done: Set<String>; let failed: Set<String>; let results: [RoundResult]
        let answered: Int
    }

    var queue: [Item]
    var pos = 0
    var done = Set<String>()
    var newLearned = Set<String>()
    /// Words answered 不會 earlier in this session; a later 會 only relearns them.
    private var failed = Set<String>()
    /// Each word's first answer this round, in the order answered (shown on the summary).
    private(set) var results: [RoundResult] = []
    let total: Int
    /// 無盡模式: the words are reshuffled and drawn again every time the queue runs out, until the user ends the round.
    let endless: Bool
    /// Questions answered 會/不確定 this session, repeats included (the endless header counts these).
    private(set) var answered = 0
    private let pool: [Word]
    private let types: [QType]?
    private let listening: Bool
    private var undoStack: [Snapshot] = []

    init(words: [Word], types: [QType]?, listening: Bool, endless: Bool = false) {
        pool = words
        self.types = types
        self.listening = listening
        self.endless = endless
        queue = []
        total = words.count
        queue = draw(words)   // already in a random order (StudyFlow shuffles once, so prefetching matches the cards)
    }

    private func draw(_ words: [Word]) -> [Item] {
        words.map { w in
            var t = types?.randomElement() ?? QType.smart(for: w, listening: listening)
            if t == .cloze, w.clozeSentence == nil { t = .zhToEn }   // nothing to blank out in this word's example
            // the voice says "something" for sth, so a phrase with sth/sb can't be spelled from hearing it
            if t == .listenSpell, Speech.spoken(w.term) != w.term { t = .spelling }
            return Item(word: w, type: t)
        }
    }

    /// Keeps an endless round going: when the last queued question is reached, deal the whole pool again,
    /// never starting the new pass with the word just shown.
    private func refillIfNeeded() {
        guard endless, !pool.isEmpty, pos >= queue.count - 1 else { return }
        var next = pool.shuffled()
        if next.count > 1, let last = queue.last?.word, next.first?.term == last.term { next.swapAt(0, 1) }
        queue += draw(next)
    }

    var current: Item? { pos < queue.count ? queue[pos] : nil }
    var canUndo: Bool { !undoStack.isEmpty }
    var progressText: String { endless ? "已完成 \(answered) 個" : "\(min(total, done.count + 1)) / \(total)" }

    func grade(_ g: Grade, ctx: ModelContext) {
        guard let it = current else { return }
        let w = it.word
        // In endless mode a word comes back many times; only its first answer of the session moves its SRS schedule.
        let counts = !endless || !results.contains(where: { $0.word.term == w.term }) || failed.contains(w.term)
        let log = counts ? ReviewLog(term: w.term, result: g.rawValue, wasNew: w.isNew) : nil
        undoStack.append(Snapshot(queue: queue, pos: pos, word: w, level: w.srsLevel, due: w.dueDate,
                                  last: w.lastReviewed, count: w.reviewCount, log: log, done: done, failed: failed,
                                  results: results, answered: answered))
        if counts {
            if w.isNew { newLearned.insert(w.term) }
            SRS.apply(g == .good && failed.contains(w.term) ? .unsure : g, to: w)
        }
        if g == .again { failed.insert(w.term) } else if endless { failed.remove(w.term) }
        if !results.contains(where: { $0.word.term == w.term }) { results.append(RoundResult(word: w, grade: g)) }
        if let log { ctx.insert(log) }
        try? ctx.save()
        if g == .again {
            let again = Item(word: w, type: it.type == .spelling || it.type == .listenSpell ? .flashcard : it.type)
            queue.insert(again, at: min(queue.count, pos + 4))
        } else {
            done.insert(w.term)
            answered += 1
        }
        refillIfNeeded()
        pos += 1
    }

    func undo(ctx: ModelContext) {
        guard let s = undoStack.popLast() else { return }
        queue = s.queue; pos = s.pos; done = s.done; failed = s.failed; results = s.results; answered = s.answered
        s.word.srsLevel = s.level; s.word.dueDate = s.due; s.word.lastReviewed = s.last; s.word.reviewCount = s.count
        if s.level == 0 { newLearned.remove(s.word.term) }
        if let log = s.log { ctx.delete(log) }
        try? ctx.save()
    }
}
