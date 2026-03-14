import Foundation

/// Curated library of behavioral science tips indexed by behavior category.
/// All content is bundled with the app — no network required.
struct TipLibrary {

    struct Tip: Identifiable {
        let id = UUID()
        let category: String
        let title: String
        let body: String
        let source: String   // attribution or "behavioral science" etc.
    }

    /// Get a random tip for a behavior category.
    static func tip(for category: String) -> Tip? {
        tips.filter { $0.category == category }.randomElement()
    }

    /// Get all tips for a category.
    static func tips(for category: String) -> [Tip] {
        tips.filter { $0.category == category }
    }

    // MARK: - Curated tips

    private static let tips: [Tip] = [
        // Posture
        Tip(
            category: "posture",
            title: "The 90-90-90 rule",
            body: "Keep your elbows, hips, and knees at roughly 90-degree angles when seated. This distributes weight evenly and reduces spinal load.",
            source: "Ergonomics research"
        ),
        Tip(
            category: "posture",
            title: "Monitor at eye level",
            body: "The top of your screen should be at or slightly below eye level. Looking down strains your neck; looking up strains your back.",
            source: "OSHA display screen guidelines"
        ),
        Tip(
            category: "posture",
            title: "Feet flat on the floor",
            body: "Dangling feet shift your center of gravity and cause you to compensate with your lower back. Use a footrest if your chair is too high.",
            source: "Ergonomics research"
        ),
        Tip(
            category: "posture",
            title: "Micro-movements matter",
            body: "The best posture is your next posture. Shift positions frequently — even small movements prevent the static load that causes pain.",
            source: "Spine biomechanics research"
        ),
        Tip(
            category: "posture",
            title: "Chair depth check",
            body: "There should be 2-3 fingers of space between the edge of your seat and the back of your knees. Too deep causes slouching.",
            source: "Ergonomics research"
        ),

        // Expression / tension
        Tip(
            category: "expression",
            title: "The jaw-shoulder connection",
            body: "Jaw tension radiates to your neck and shoulders. If you notice yourself clenching, place the tip of your tongue on the roof of your mouth — this makes clenching physically impossible.",
            source: "TMJ research"
        ),
        Tip(
            category: "expression",
            title: "Blink rate and screen time",
            body: "We blink 66% less when staring at screens, causing dry eyes and squinting. Set a reminder to blink deliberately every 20 minutes.",
            source: "Ophthalmology research"
        ),
        Tip(
            category: "expression",
            title: "Resting face awareness",
            body: "Many people carry tension in their forehead or around their eyes without realizing it. A quick body scan of your face every 30 minutes can break the pattern.",
            source: "Mindfulness-based stress reduction"
        ),
        Tip(
            category: "expression",
            title: "Smile feedback loop",
            body: "Research shows that facial expressions can influence mood, not just reflect it. A brief genuine smile — even to yourself — can reduce physiological stress markers.",
            source: "Facial feedback hypothesis research"
        ),

        // Habits (BFRBs)
        Tip(
            category: "habit",
            title: "Awareness is the first step",
            body: "Most body-focused repetitive behaviors happen automatically. Simply noticing — without judgment — is the most effective first intervention. That's what this app does.",
            source: "Habit reversal training (HRT)"
        ),
        Tip(
            category: "habit",
            title: "Competing response",
            body: "When you notice the urge, do a competing action: press your hands flat on the desk, squeeze a stress ball, or clasp your hands together for 60 seconds.",
            source: "Habit reversal training (HRT)"
        ),
        Tip(
            category: "habit",
            title: "Trigger mapping",
            body: "Track when habits happen. Most people discover patterns — boredom, stress, specific times of day. Once you know the trigger, you can address it directly.",
            source: "Behavioral analysis"
        ),
        Tip(
            category: "habit",
            title: "Barrier method",
            body: "Physical barriers work: wear a bandaid on the finger you bite, put lotion on your hands (makes nail biting taste bad), or wear a hat (blocks hair pulling access).",
            source: "Clinical behavioral interventions"
        ),
        Tip(
            category: "habit",
            title: "Self-compassion matters",
            body: "Shame increases stress, which increases habits. Talk to yourself like you'd talk to a friend. Progress is not linear — any reduction in frequency is a win.",
            source: "Acceptance and commitment therapy (ACT)"
        ),

        // Speech
        Tip(
            category: "speech",
            title: "The power of the pause",
            body: "Replace filler words with silence. A 2-second pause feels eternal to you but sounds confident to listeners. It also gives you time to think.",
            source: "Public speaking research"
        ),
        Tip(
            category: "speech",
            title: "Breath before you speak",
            body: "Take a full breath before starting a sentence. This naturally slows your pace, deepens your voice, and reduces filler words.",
            source: "Voice coaching"
        ),
        Tip(
            category: "speech",
            title: "Pace awareness",
            body: "Ideal conversational pace is 120-150 words per minute. Above 160 wpm, comprehension drops and filler words increase. Below 100 wpm can sound disengaged.",
            source: "Speech communication research"
        ),
        Tip(
            category: "speech",
            title: "Record yourself",
            body: "Most people are unaware of their speech patterns. Reviewing a session's speech metrics (which this app does automatically) is the modern equivalent of recording practice talks.",
            source: "Deliberate practice research"
        ),
    ]
}
