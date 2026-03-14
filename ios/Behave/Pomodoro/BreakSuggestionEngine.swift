import Foundation

/// Picks contextual break suggestions based on what was detected
/// during the preceding work interval.
struct BreakSuggestionEngine {

    struct Suggestion: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let duration: String    // e.g. "30 seconds"
        let category: String    // posture, expression, habit, general
        let icon: String        // SF Symbol name
    }

    /// Select the best suggestion given the enforcement status from the last work interval.
    static func suggest(
        postureScore: Double,
        expressionScore: Double,
        habitScore: Double,
        speechScore: Double
    ) -> Suggestion {
        // Find the worst-performing behavior
        let scores: [(String, Double)] = [
            ("posture", postureScore),
            ("expression", expressionScore),
            ("habit", habitScore),
            ("speech", speechScore),
        ]

        let worst = scores.min(by: { $0.1 < $1.1 })?.0 ?? "general"

        // Pick from the category-specific suggestions
        let candidates = suggestions.filter { $0.category == worst }
        if let pick = candidates.randomElement() {
            return pick
        }

        // Fallback to general
        return suggestions.filter { $0.category == "general" }.randomElement()
            ?? suggestions[0]
    }

    // MARK: - Curated suggestion library

    private static let suggestions: [Suggestion] = [
        // Posture
        Suggestion(
            title: "Shoulder rolls",
            description: "Roll your shoulders forward 5 times, then backward 5 times. Squeeze your shoulder blades together at the end.",
            duration: "30 seconds",
            category: "posture",
            icon: "figure.roll"
        ),
        Suggestion(
            title: "Stand and stretch",
            description: "Stand up. Interlace your fingers above your head, palms to ceiling. Hold for 10 seconds. Repeat.",
            duration: "30 seconds",
            category: "posture",
            icon: "figure.stand"
        ),
        Suggestion(
            title: "Chest opener",
            description: "Clasp your hands behind your back. Straighten your arms and gently lift. Hold 15 seconds.",
            duration: "30 seconds",
            category: "posture",
            icon: "figure.arms.open"
        ),
        Suggestion(
            title: "Neck release",
            description: "Drop your right ear to your right shoulder. Hold 10 seconds. Switch sides. Don't force it.",
            duration: "30 seconds",
            category: "posture",
            icon: "figure.cooldown"
        ),
        Suggestion(
            title: "Seated cat-cow",
            description: "Sit at the edge of your chair. Arch your back (cow), then round it (cat). Repeat 5 times slowly.",
            duration: "30 seconds",
            category: "posture",
            icon: "figure.flexibility"
        ),

        // Expression / tension
        Suggestion(
            title: "Jaw unclenching",
            description: "Open your mouth wide. Hold 5 seconds. Close gently. Repeat 3 times. Then massage your jaw muscles with your fingertips.",
            duration: "30 seconds",
            category: "expression",
            icon: "face.smiling"
        ),
        Suggestion(
            title: "Eye palming",
            description: "Rub your palms together to warm them. Cup them over your closed eyes. Breathe deeply for 20 seconds.",
            duration: "30 seconds",
            category: "expression",
            icon: "eye.slash"
        ),
        Suggestion(
            title: "20-20-20 rule",
            description: "Look at something 20+ feet away for 20 seconds. Blink deliberately. This reduces eye strain and facial tension.",
            duration: "20 seconds",
            category: "expression",
            icon: "eye"
        ),
        Suggestion(
            title: "Deep breathing",
            description: "Breathe in for 4 counts. Hold for 4. Exhale for 6. Repeat 3 times. Focus on relaxing your forehead and jaw.",
            duration: "1 minute",
            category: "expression",
            icon: "wind"
        ),

        // Habits (face touching, nail biting, picking)
        Suggestion(
            title: "Hands reset",
            description: "Place both hands flat on your desk, palms down. Press gently for 10 seconds. This breaks the hand-to-face habit loop.",
            duration: "15 seconds",
            category: "habit",
            icon: "hand.raised"
        ),
        Suggestion(
            title: "Finger stretches",
            description: "Spread your fingers wide, hold 5 seconds. Make fists, hold 5 seconds. Repeat 3 times. Gives your hands something to do.",
            duration: "30 seconds",
            category: "habit",
            icon: "hand.point.up"
        ),
        Suggestion(
            title: "Stress ball squeeze",
            description: "If you have a stress ball, squeeze it firmly for 5 seconds, release for 5. Repeat. If not, squeeze a rolled-up sock.",
            duration: "30 seconds",
            category: "habit",
            icon: "circle.circle"
        ),
        Suggestion(
            title: "Awareness check",
            description: "Notice where your hands are right now. If they're near your face or head, gently place them on your desk or lap. No judgment.",
            duration: "10 seconds",
            category: "habit",
            icon: "brain.head.profile"
        ),

        // Speech
        Suggestion(
            title: "Silent pause practice",
            description: "Think of a sentence. Say it out loud, replacing every 'um' or 'like' with a deliberate 2-second pause. Silence is powerful.",
            duration: "1 minute",
            category: "speech",
            icon: "waveform"
        ),
        Suggestion(
            title: "Breathing pace reset",
            description: "Take 3 slow breaths. Speaking too fast often comes from shallow breathing. A full exhale before speaking slows your pace naturally.",
            duration: "30 seconds",
            category: "speech",
            icon: "metronome"
        ),

        // General
        Suggestion(
            title: "Walk to a window",
            description: "Get up and walk to the nearest window. Look outside for 30 seconds. Movement and distance vision reset your focus.",
            duration: "1 minute",
            category: "general",
            icon: "window.casement"
        ),
        Suggestion(
            title: "Water break",
            description: "Get a glass of water. Hydration affects posture, concentration, and tension. Walk to get it — don't use the bottle on your desk.",
            duration: "2 minutes",
            category: "general",
            icon: "drop"
        ),
        Suggestion(
            title: "Micro walk",
            description: "Walk for 60 seconds. Around your room, to the kitchen, anywhere. Movement is the best reset.",
            duration: "1 minute",
            category: "general",
            icon: "figure.walk"
        ),
    ]
}
