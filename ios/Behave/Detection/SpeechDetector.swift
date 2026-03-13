import Speech
import AVFoundation
import Combine

/// On-device speech recognition using SFSpeechRecognizer.
/// Provides real-time transcription and word-level timestamps.
final class SpeechDetector: ObservableObject {
    @Published var currentTranscription = ""
    @Published var recentWords: [TranscribedWord] = []
    @Published var isListening = false
    @Published var permissionGranted = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    struct TranscribedWord {
        let text: String
        let timestamp: TimeInterval
    }

    func checkPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionGranted = (status == .authorized)
            }
        }
    }

    func start() {
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let result else { return }

            let text = result.bestTranscription.formattedString
            let words = result.bestTranscription.segments.map {
                TranscribedWord(text: $0.substring, timestamp: $0.timestamp)
            }

            DispatchQueue.main.async {
                self?.currentTranscription = text
                self?.recentWords = words
            }

            if error != nil || result.isFinal {
                self?.stop()
            }
        }

        self.recognitionRequest = request

        audioEngine.prepare()
        try? audioEngine.start()

        DispatchQueue.main.async { self.isListening = true }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        DispatchQueue.main.async { self.isListening = false }
    }
}
