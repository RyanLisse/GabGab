import Foundation

/// Manages interaction with the mlx-audio REST server and handles local fallbacks.
public actor GabGabSessionManager {
    private let httpClient: MLXHTTPClient
    private let audioPlayer: AudioPlayer
    private let fallbackTTS: FallbackTTS
    private let fallbackSTT: FallbackSTT
    private let config: MLXConfiguration
    
    public init(config: MLXConfiguration = MLXConfiguration()) {
        self.config = config
        self.httpClient = MLXHTTPClient(baseURL: config.serverURL)
        self.audioPlayer = AudioPlayer()
        self.fallbackTTS = FallbackTTS()
        self.fallbackSTT = FallbackSTT()
    }
    
    /// Convenience initializer with server URL
    public init(serverURL: URL) {
        let config = MLXConfiguration(serverURL: serverURL)
        self.config = config
        self.httpClient = MLXHTTPClient(baseURL: config.serverURL)
        self.audioPlayer = AudioPlayer()
        self.fallbackTTS = FallbackTTS()
        self.fallbackSTT = FallbackSTT()
    }
    
    /// Synthesizes text to speech and returns audio data without playing.
    public func synthesizeAudioData(
        text: String,
        voice: String = MLXConfiguration.defaultVoice,
        urgency: String = "normal"
    ) async throws -> Data {
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
        GabGabLogger.info("Transcribing audio data (\(audioData.count) bytes)")
        
        do {
            return try await httpClient.transcribeAudio(audioData: audioData)
        } catch {
            GabGabLogger.error("Server transcription failed, attempting fallback: \(error.localizedDescription)")
            return try await fallbackSTT.transcribe(audioData: audioData)
        }
    }
    
    /// Stops audio playback and engine.
    public func stop() {
        Task {
            await audioPlayer.stop()
        }
    }
}
