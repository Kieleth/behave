import Foundation

/// Classifies speech patterns: filler words, pace, pauses.
struct SpeechClassifier {

    struct Result {
        let fillerWordCount: Int
        let recentFillers: [String]
        let wordsPerMinute: Double
        let details: String
    }

    static let fillerWords: Set<String> = [
        "um", "uh", "like", "you know", "actually", "basically",
        "literally", "right", "so", "well", "I mean", "kind of",
        "sort of", "honestly", "obviously", "anyway",
    ]

    func classify(words: [SpeechDetector.TranscribedWord], sessionDurationSeconds: TimeInterval) -> Result {
        guard !words.isEmpty, sessionDurationSeconds > 0 else {
            return Result(fillerWordCount: 0, recentFillers: [], wordsPerMinute: 0, details: "No speech detected")
        }

        // Detect fillers
        var fillerCount = 0
        var recentFillers: [String] = []
        let lowered = words.map { $0.text.lowercased() }

        for word in lowered {
            if Self.fillerWords.contains(word) {
                fillerCount += 1
                if recentFillers.count < 5 {
                    recentFillers.append(word)
                }
            }
        }

        // Words per minute
        let wpm = Double(words.count) / (sessionDurationSeconds / 60.0)

        // Generate details
        var issues: [String] = []
        if fillerCount > 0 {
            issues.append("\(fillerCount) filler word\(fillerCount == 1 ? "" : "s")")
        }
        if wpm > 160 {
            issues.append("speaking fast (\(Int(wpm)) wpm)")
        } else if wpm < 100 && wpm > 0 {
            issues.append("speaking slow (\(Int(wpm)) wpm)")
        }

        let details = issues.isEmpty ? "Speech is clear" : issues.joined(separator: ", ")

        return Result(
            fillerWordCount: fillerCount,
            recentFillers: recentFillers,
            wordsPerMinute: wpm,
            details: details
        )
    }
}
