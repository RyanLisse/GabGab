import AVFoundation
import Foundation

/// Fallback TTS implementation using AVSpeechSynthesizer
/// Note: AVSpeechSynthesizer requires MainActor isolation
@MainActor
final class FallbackTTS: TTSProtocol {
    private final class SpeechDelegate: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
        let onFinish: @MainActor () -> Void
        let onCancel: @MainActor () -> Void

        init(onFinish: @escaping @MainActor () -> Void, onCancel: @escaping @MainActor () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        @MainActor
        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            onFinish()
        }

        @MainActor
        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            onCancel()
        }
    }

    private var activeSynthesizer: AVSpeechSynthesizer?
    private var activeDelegate: SpeechDelegate?

    /// Synthesizes text to speech and returns audio data
    func synthesizeAudioData(
        text: String,
        voice: String
    ) async throws -> Data {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(identifier: voice)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechUtterance.pitchMultiplier = 1.0
        speechUtterance.volume = 1.0

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fallback_tts_\(UUID().uuidString).wav")
        let synthesizer = AVSpeechSynthesizer()
        activeSynthesizer = synthesizer

        return try await withCheckedThrowingContinuation { continuation in
            var audioFile: AVAudioFile?
            var finished = false

            synthesizer.write(speechUtterance) { buffer in
                if finished {
                    return
                }

                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                    finished = true
                    do {
                        let data = try Data(contentsOf: tempURL)
                        try? FileManager.default.removeItem(at: tempURL)
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    Task { @MainActor in
                        self.activeSynthesizer = nil
                    }
                    return
                }

                if pcmBuffer.frameLength == 0 {
                    finished = true
                    do {
                        let data = try Data(contentsOf: tempURL)
                        try? FileManager.default.removeItem(at: tempURL)
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    Task { @MainActor in
                        self.activeSynthesizer = nil
                    }
                    return
                }

                do {
                    if audioFile == nil {
                        audioFile = try AVAudioFile(
                            forWriting: tempURL,
                            settings: pcmBuffer.format.settings
                        )
                    }
                    try audioFile?.write(from: pcmBuffer)
                } catch {
                    finished = true
                    continuation.resume(throwing: error)
                    Task { @MainActor in
                        self.activeSynthesizer = nil
                    }
                }
            }
        }
    }

    /// Synthesizes text to speech and plays it directly
    func synthesize(text: String, voice: String) async throws {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(identifier: voice)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechUtterance.pitchMultiplier = 1.0
        speechUtterance.volume = 1.0

        let synthesizer = AVSpeechSynthesizer()
        activeSynthesizer = synthesizer

        try await withCheckedThrowingContinuation { continuation in
            var finished = false
            let delegate = SpeechDelegate(
                onFinish: {
                    if finished {
                        return
                    }
                    finished = true
                    continuation.resume()
                },
                onCancel: {
                    if finished {
                        return
                    }
                    finished = true
                    continuation.resume(throwing: GabGabError.speechSynthesisFailed("Speech synthesis cancelled"))
                }
            )
            activeDelegate = delegate
            synthesizer.delegate = delegate
            synthesizer.speak(speechUtterance)
        }

        activeSynthesizer = nil
        activeDelegate = nil
    }
}
