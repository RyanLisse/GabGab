import Foundation
import Speech

/// Fallback STT implementation using SFSpeechRecognizer
actor FallbackSTT: STTProtocol {
    private let speechRecognizer: SFSpeechRecognizer?
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    /// Transcribes audio data to text using local speech recognition
    func transcribe(audioData: Data) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw GabGabError.speechRecognitionUnavailable
        }
        
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard authStatus == .authorized else {
            throw GabGabError.speechRecognitionUnauthorized
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcribe_\(UUID().uuidString).wav")
        try audioData.write(to: tempURL)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: tempURL)
        if #available(macOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
            recognitionRequest.addsPunctuation = true
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            func resumeOnce(_ result: Result<String, Error>) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            recognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let error = error {
                    resumeOnce(.failure(GabGabError.speechRecognitionFailed(error.localizedDescription)))
                    return
                }

                guard let result = result else {
                    return
                }

                guard result.isFinal else {
                    return
                }

                let transcribedText = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if transcribedText.isEmpty {
                    resumeOnce(.failure(GabGabError.emptyTranscriptionResult))
                } else {
                    resumeOnce(.success(transcribedText))
                }
            }
        }
    }
}
