import Foundation

/// Errors that can occur in the GabGab voice processing system
public enum GabGabError: Error, LocalizedError {
    case invalidServerURL(String)
    case serverError(Int, String?)
    case networkError(Error)
    case invalidResponseFormat
    case audioPlaybackError(Error)
    case speechRecognitionUnavailable
    case speechRecognitionUnauthorized
    case speechRecognitionFailed(String)
    case emptyTranscriptionResult
    case invalidAudioData
    
    public var errorDescription: String? {
        switch self {
        case .invalidServerURL(let url):
            return "Invalid server URL: \(url)"
        case let .serverError(code, message):
            return "Server error \(code): \(message ?? "Unknown error")"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponseFormat:
            return "Invalid response format from server"
        case .audioPlaybackError(let error):
            return "Audio playback error: \(error.localizedDescription)"
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available on this system"
        case .speechRecognitionUnauthorized:
            return "Speech recognition authorization not granted"
        case .speechRecognitionFailed(let reason):
            return "Speech recognition failed: \(reason)"
        case .emptyTranscriptionResult:
            return "Transcription produced empty result"
        case .invalidAudioData:
            return "Invalid audio data provided"
        }
    }
}
