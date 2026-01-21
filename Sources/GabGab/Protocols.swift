import Foundation

/// Protocol for HTTP client operations
public protocol HTTPClientProtocol: Actor {
    func synthesizeSpeech(
        text: String,
        voice: String,
        model: String,
        langCode: String
    ) async throws -> Data
    
    func transcribeAudio(audioData: Data) async throws -> String
    
    func checkHealth() async -> Bool
}

/// Protocol for Audio Player operations
@MainActor
public protocol AudioPlayerProtocol: AnyObject {
    func playAudio(data: Data) async throws
    func stop() async
}

/// Protocol for TTS operations (Fallback)
@MainActor
public protocol TTSProtocol: AnyObject {
    func synthesizeAudioData(text: String, voice: String) async throws -> Data
    func synthesize(text: String, voice: String) async throws
}

/// Protocol for STT operations (Fallback)
public protocol STTProtocol: Actor {
    func transcribe(audioData: Data) async throws -> String
}
