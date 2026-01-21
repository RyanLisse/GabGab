import AVFoundation
import Foundation

/// Fallback TTS implementation using AVSpeechSynthesizer
/// Note: AVSpeechSynthesizer requires MainActor isolation
@MainActor
final class FallbackTTS {
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
        synthesizer.speak(speechUtterance)
    }
}
