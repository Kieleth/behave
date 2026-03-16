import Foundation

/// Classifies speech patterns: filler words, pace, pauses, breathing.
struct SpeechClassifier {

    struct Result {
        let fillerWordCount: Int
        let recentFillers: [String]
        let wordsPerMinute: Double
        let isSpeaking: Bool
        let shouldBreathe: Bool          // started speaking without pause
        let continuousSpeakingSeconds: Double
        let secondsSinceLastPause: Double
        let details: String
    }

    static let fillerWords: Set<String> = [
        "um", "uh", "like", "you know", "actually", "basically",
        "literally", "right", "so", "well", "I mean", "kind of",
        "sort of", "honestly", "obviously", "anyway",
    ]

    /// Minimum pause before speaking to count as "took a breath" (seconds)
    var minBreathPause: Double = 1.5

    /// Max continuous speaking before suggesting a breath (seconds)
    var maxContinuousSpeaking: Double = 30.0

    // State tracking
    private var lastWordTimestamp: TimeInterval = 0
    private var speechStartTimestamp: TimeInterval = 0
    private var wasSpeaking = false
    private var hadBreathPause = false
    private var lastPauseTimestamp: TimeInterval = 0
    private var previousWordCount = 0

    mutating func classify(words: [SpeechDetector.TranscribedWord], sessionDurationSeconds: TimeInterval) -> Result {
        guard !words.isEmpty, sessionDurationSeconds > 0 else {
            wasSpeaking = false
            return Result(fillerWordCount: 0, recentFillers: [], wordsPerMinute: 0,
                         isSpeaking: false, shouldBreathe: false,
                         continuousSpeakingSeconds: 0, secondsSinceLastPause: 0,
                         details: "No speech detected")
        }

        // --- Detect speaking state ---
        let latestWord = words.last!
        let now = sessionDurationSeconds
        let timeSinceLastWord = now - latestWord.timestamp
        let isSpeaking = timeSinceLastWord < 2.0  // speaking if word within 2s
        let newWordsArrived = words.count > previousWordCount
        previousWordCount = words.count

        // --- Breathing detection ---
        var shouldBreathe = false
        var continuousSpeaking: Double = 0

        if isSpeaking {
            if !wasSpeaking {
                // Transition: silence → speaking
                let pauseDuration = now - lastWordTimestamp
                hadBreathPause = pauseDuration >= minBreathPause || lastWordTimestamp == 0
                speechStartTimestamp = now
                if !hadBreathPause && lastWordTimestamp > 0 {
                    shouldBreathe = true  // started speaking without breathing
                }
            }
            continuousSpeaking = now - speechStartTimestamp
            if continuousSpeaking > maxContinuousSpeaking {
                shouldBreathe = true  // speaking too long without a pause
            }
        }

        if newWordsArrived {
            lastWordTimestamp = latestWord.timestamp
        }

        // Detect pauses within speech (gaps > 1s between words)
        var secondsSinceLastPause = now - lastPauseTimestamp
        if words.count >= 2 {
            let prev = words[words.count - 2]
            let gap = latestWord.timestamp - prev.timestamp
            if gap > 1.0 {
                lastPauseTimestamp = latestWord.timestamp
                secondsSinceLastPause = 0
            }
        }

        wasSpeaking = isSpeaking

        // --- Filler words ---
        var fillerCount = 0
        var recentFillers: [String] = []
        for word in words {
            let lower = word.text.lowercased()
            if Self.fillerWords.contains(lower) {
                fillerCount += 1
                if recentFillers.count < 5 { recentFillers.append(lower) }
            }
        }

        // --- Words per minute ---
        let wpm = Double(words.count) / (sessionDurationSeconds / 60.0)

        // --- Details ---
        var issues: [String] = []
        if shouldBreathe && !hadBreathPause { issues.append("breathe first") }
        if shouldBreathe && continuousSpeaking > maxContinuousSpeaking {
            issues.append("pause to breathe")
        }
        if fillerCount > 0 { issues.append("\(fillerCount) fillers") }
        if wpm > 160 { issues.append("fast (\(Int(wpm)) wpm)") }
        else if wpm > 0 && wpm < 100 { issues.append("slow (\(Int(wpm)) wpm)") }

        let details = issues.isEmpty ? "Speech is clear" : issues.joined(separator: ", ")

        return Result(
            fillerWordCount: fillerCount,
            recentFillers: recentFillers,
            wordsPerMinute: wpm,
            isSpeaking: isSpeaking,
            shouldBreathe: shouldBreathe,
            continuousSpeakingSeconds: continuousSpeaking,
            secondsSinceLastPause: secondsSinceLastPause,
            details: details
        )
    }
}
