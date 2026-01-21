import Foundation

/// Manages interaction with the mlx-audio REST server and handles local fallbacks.
@MainActor
public final class GabGabSessionManager {
    private let httpClient: any HTTPClientProtocol
    private let audioPlayer: any AudioPlayerProtocol
    private let fallbackTTS: any TTSProtocol
    private let fallbackSTT: any STTProtocol
    public let config: MLXConfiguration

    /// Initialize with dependencies (internal use - use factory methods for production)
    private init(
        config: MLXConfiguration,
        httpClient: any HTTPClientProtocol,
        audioPlayer: any AudioPlayerProtocol,
        fallbackTTS: any TTSProtocol,
        fallbackSTT: any STTProtocol
    ) {
        self.config = config
        self.httpClient = httpClient
        self.audioPlayer = audioPlayer
        self.fallbackTTS = fallbackTTS
        self.fallbackSTT = fallbackSTT
    }

    /// Factory method to create session manager with default configuration
    public static func create(config: MLXConfiguration = MLXConfiguration()) -> GabGabSessionManager {
        GabGabSessionManager(
            config: config,
            httpClient: MLXHTTPClient(baseURL: config.serverURL),
            audioPlayer: AudioPlayer(),
            fallbackTTS: FallbackTTS(),
            fallbackSTT: FallbackSTT()
        )
    }

    /// Factory method to create session manager with server URL
    public static func create(serverURL: URL) -> GabGabSessionManager {
        let config = MLXConfiguration(serverURL: serverURL)
        return GabGabSessionManager(
            config: config,
            httpClient: MLXHTTPClient(baseURL: config.serverURL),
            audioPlayer: AudioPlayer(),
            fallbackTTS: FallbackTTS(),
            fallbackSTT: FallbackSTT()
        )
    }

    /// Factory method for testing with injected dependencies
    public static func createForTesting(
        config: MLXConfiguration,
        httpClient: any HTTPClientProtocol,
        audioPlayer: any AudioPlayerProtocol,
        fallbackTTS: any TTSProtocol,
        fallbackSTT: any STTProtocol
    ) -> GabGabSessionManager {
        GabGabSessionManager(
            config: config,
            httpClient: httpClient,
            audioPlayer: audioPlayer,
            fallbackTTS: fallbackTTS,
            fallbackSTT: fallbackSTT
        )
    }
    
    /// Synthesizes text to speech and returns audio data without playing.
    public func synthesizeAudioData(
        text: String,
        voice: String = MLXConfiguration.defaultVoice,
        urgency: String = "normal"
    ) async throws -> Data {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GabGabError.invalidTextInput
        }
        GabGabLogger.info("Synthesizing audio data: \(text)")
        
        do {
            return try await httpClient.synthesizeSpeech(
                text: text,
                voice: voice,
                model: config.ttsModel,
                langCode: MLXConfiguration.defaultLangCode
            )
        } catch {
            GabGabLogger.error("Server error, attempting local fallback: \(error.localizedDescription)")
            return try await fallbackTTS.synthesizeAudioData(text: text, voice: voice)
        }
    }
    
    /// Synthesizes text to speech using the MLX server or local fallback.
    public func synthesize(
        text: String,
        voice: String = MLXConfiguration.defaultVoice,
        urgency: String = "normal"
    ) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GabGabError.invalidTextInput
        }
        GabGabLogger.info("Synthesizing: \(text)")
        
        do {
            let audioData = try await httpClient.synthesizeSpeech(
                text: text,
                voice: voice,
                model: config.ttsModel,
                langCode: MLXConfiguration.defaultLangCode
            )
            try await audioPlayer.playAudio(data: audioData)
        } catch {
            GabGabLogger.error("Connection failed, attempting fallback: \(error.localizedDescription)")
            try await fallbackTTS.synthesize(text: text, voice: voice)
        }
    }
    
    /// Plays audio data through the system's audio output.
    public func playAudio(data: Data) async throws {
        try await audioPlayer.playAudio(data: data)
    }
    
    /// Checks if the MLX server is healthy and responding.
    public func checkHealth() async -> Bool {
        await httpClient.checkHealth()
    }
    
    /// Transcribes audio data to text using the MLX server or fallback.
    public func transcribeAudioData(audioData: Data) async throws -> String {
        guard !audioData.isEmpty else {
            throw GabGabError.invalidAudioData
        }
        GabGabLogger.info("Transcribing audio data (\(audioData.count) bytes)")
        
        do {
            return try await httpClient.transcribeAudio(audioData: audioData)
        } catch {
            GabGabLogger.error("Server transcription failed, attempting fallback: \(error.localizedDescription)")
            return try await fallbackSTT.transcribe(audioData: audioData)
        }
    }
    
    /// Stops audio playback and engine.
    public func stop() async {
        await audioPlayer.stop()
    }
}
