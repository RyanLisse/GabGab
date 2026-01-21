import Foundation

/// Configuration for MLX voice models and server settings
public struct MLXConfiguration {
    /// Default MLX server URL
    /// Note: Force unwrap is safe here as this is a known valid URL
    public static let defaultServerURL = URL(string: "http://127.0.0.1:8080")! // swiftlint:disable:this force_unwrapping
    
    /// Default TTS model
    public static let defaultTTSModel = "mlx-community/Kokoro-82M-bf16"
    
    /// Default voice identifier
    public static let defaultVoice = "af_heart"
    
    /// Default language code
    public static let defaultLangCode = "a"
    
    /// Available voice identifiers
    public static let availableVoices = [
        "af_heart",  // Female - Warm/Expressive
        "af_bella",  // Female - Clear/Professional
        "am_adam",   // Male - Deep/Authoritative
        "am_michael" // Male - Neutral/Clear
    ]
    
    /// Server URL for MLX audio server
    public let serverURL: URL
    
    /// TTS model identifier
    public let ttsModel: String
    
    /// Default voice identifier
    public let defaultVoice: String
    
    public init(
        serverURL: URL = MLXConfiguration.defaultServerURL,
        ttsModel: String = MLXConfiguration.defaultTTSModel,
        defaultVoice: String = MLXConfiguration.defaultVoice
    ) {
        self.serverURL = serverURL
        self.ttsModel = ttsModel
        self.defaultVoice = defaultVoice
    }
}
