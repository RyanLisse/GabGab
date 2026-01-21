import Foundation

/// MCP Server for MLX Voice operations
/// Provides tools for text-to-speech and speech-to-text using local MLX models
@MainActor
public final class GabGabMCPServer {
    private let manager: GabGabSessionManager

    public init(manager: GabGabSessionManager) {
        self.manager = manager
    }

    /// Factory method to create MCP server with default configuration
    public static func create() -> GabGabMCPServer {
        GabGabMCPServer(manager: GabGabSessionManager.create())
    }

    /// Factory method to create MCP server with custom configuration
    public static func create(config: MLXConfiguration) -> GabGabMCPServer {
        GabGabMCPServer(manager: GabGabSessionManager.create(config: config))
    }

    /// Tool: Generate speech from text
    public func generateSpeech(text: String, voice: String = "af_heart", outputPath: String? = nil) async throws -> [String: Any] {
        GabGabLogger.info("[MCP] Generating speech: \(text)")

        let audioData = try await manager.synthesizeAudioData(text: text, voice: voice)

        if let outputPath = outputPath {
            let url = URL(fileURLWithPath: outputPath)
            try audioData.write(to: url)
            return [
                "success": true,
                "message": "Speech generated and saved to \(outputPath)",
                "bytes": audioData.count,
                "path": outputPath
            ]
        } else {
            // Return base64 encoded audio for MCP
            let base64Audio = audioData.base64EncodedString()
            return [
                "success": true,
                "message": "Speech generated",
                "bytes": audioData.count,
                "audio_base64": base64Audio,
                "format": "wav"
            ]
        }
    }

    /// Tool: Transcribe audio to text
    public func transcribeAudio(audioPath: String) async throws -> [String: Any] {
        GabGabLogger.info("[MCP] Transcribing audio: \(audioPath)")

        let audioURL = URL(fileURLWithPath: audioPath)
        let audioData = try Data(contentsOf: audioURL)

        let transcript = try await manager.transcribeAudioData(audioData: audioData)

        return [
            "success": true,
            "transcript": transcript,
            "audio_bytes": audioData.count
        ]
    }

    /// Tool: Check server health
    public func checkHealth() async -> [String: Any] {
        let isHealthy = await manager.checkHealth()
        let config = manager.config
        return [
            "healthy": isHealthy,
            "server_url": config.serverURL.absoluteString
        ]
    }

    /// Tool: List available voices
    public func listVoices() -> [String: Any] {
        return [
            "voices": [
                ["id": "af_heart", "name": "Female - Warm/Expressive", "language": "en"],
                ["id": "af_bella", "name": "Female - Clear/Professional", "language": "en"],
                ["id": "am_adam", "name": "Male - Deep/Authoritative", "language": "en"],
                ["id": "am_michael", "name": "Male - Neutral/Clear", "language": "en"]
            ],
            "models": [
                ["id": "kokoro-82m-bf16", "type": "tts", "quality": "high"],
                ["id": "parakeet-tdt-0.6b-v3", "type": "stt", "quality": "high"]
            ]
        ]
    }
}
