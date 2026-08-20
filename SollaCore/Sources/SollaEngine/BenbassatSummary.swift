import MusicTheory

/// End-of-session statistics for the Benbassat degree game.
public struct BenbassatSummary: Sendable {
    public struct DegreeStat: Hashable, Sendable {
        public var correct: Int
        public var total: Int

        public var accuracy: Double {
            total == 0 ? 0 : Double(correct) / Double(total)
        }
    }

    public let correct: Int
    public let total: Int
    public let perDegree: [ScaleDegree: DegreeStat]

    public var accuracy: Double {
        total == 0 ? 0 : Double(correct) / Double(total)
    }

    public init(records: [RoundRecord<ScaleDegree>]) {
        var perDegree: [ScaleDegree: DegreeStat] = [:]
        var correct = 0
        for record in records {
            var stat = perDegree[record.expected] ?? DegreeStat(correct: 0, total: 0)
            stat.total += 1
            if record.isCorrect {
                stat.correct += 1
                correct += 1
            }
            perDegree[record.expected] = stat
        }
        self.correct = correct
        self.total = records.count
        self.perDegree = perDegree
    }
}
