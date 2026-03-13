import SwiftUI

/// Chat-based coaching interface — sends session summaries to Claude for feedback.
struct CoachingView: View {
    @State private var messages: [CoachingMessage] = [
        CoachingMessage(role: .assistant, content: "Welcome to Behave. Complete a session and I'll analyze your behavior patterns and suggest improvements.")
    ]
    @State private var inputText = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Input
                HStack(spacing: 12) {
                    TextField("Ask your coach...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("Coach")
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(CoachingMessage(role: .user, content: text))
        inputText = ""
        isLoading = true

        // TODO: Send to backend API (Step 8)
        // For now, placeholder response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            messages.append(CoachingMessage(
                role: .assistant,
                content: "Coaching integration coming soon. Connect the backend to get AI-powered feedback on your sessions."
            ))
            isLoading = false
        }
    }
}

struct CoachingMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()

    enum Role { case user, assistant }
}

struct MessageBubble: View {
    let message: CoachingMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            Text(message.content)
                .padding(12)
                .background(
                    message.role == .user
                        ? Color.blue
                        : Color(.systemGray5)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }
}
