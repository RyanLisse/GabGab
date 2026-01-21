import Foundation
import GabGab

actor MockHTTPClient: HTTPClientProtocol {
    var synthesizeSpeechCalled = false
    var transcribeAudioCalled = false
    var checkHealthCalled = false
    
    var synthesizeSpeechResult: Result<Data, Error> = .success(Data())
    var transcribeAudioResult: Result<String, Error> = .success("Test Transcription")
    var checkHealthResult: Bool = true
    
    func setSynthesizeSpeechResult(_ result: Result<Data, Error>) {
        self.synthesizeSpeechResult = result
    }

    func setTranscribeAudioResult(_ result: Result<String, Error>) {
        self.transcribeAudioResult = result
    }

    func setCheckHealthResult(_ result: Bool) {
        self.checkHealthResult = result
    }
    
    func synthesizeSpeech(
        text: String,
        voice: String,
        model: String,
        langCode: String
    ) async throws -> Data {
        synthesizeSpeechCalled = true
        switch synthesizeSpeechResult {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }
    
    func transcribeAudio(audioData: Data) async throws -> String {
        transcribeAudioCalled = true
        switch transcribeAudioResult {
        case .success(let text): return text
        case .failure(let error): throw error
        }
    }
    
    func checkHealth() async -> Bool {
        checkHealthCalled = true
        return checkHealthResult
    }
}

@MainActor
final class MockAudioPlayer: AudioPlayerProtocol {
    var playAudioCalled = false
    var stopCalled = false
    
    var playAudioResult: Result<Void, Error> = .success(())
    
    func setPlayAudioResult(_ result: Result<Void, Error>) {
        self.playAudioResult = result
    }
    
    func playAudio(data: Data) async throws {
        playAudioCalled = true
        switch playAudioResult {
        case .success: return
        case .failure(let error): throw error
        }
    }
    
    func stop() async {
        stopCalled = true
    }
}

@MainActor
final class MockTTS: TTSProtocol {
    var synthesizeAudioDataCalled = false
    var synthesizeCalled = false
    
    var synthesizeAudioDataResult: Result<Data, Error> = .success(Data())
    var synthesizeResult: Result<Void, Error> = .success(())
    
    func setSynthesizeAudioDataResult(_ result: Result<Data, Error>) {
        self.synthesizeAudioDataResult = result
    }
    
    func setSynthesizeResult(_ result: Result<Void, Error>) {
        self.synthesizeResult = result
    }
    
    func synthesizeAudioData(text: String, voice: String) async throws -> Data {
        synthesizeAudioDataCalled = true
        switch synthesizeAudioDataResult {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }
    
    func synthesize(text: String, voice: String) async throws {
        synthesizeCalled = true
        switch synthesizeResult {
        case .success: return
        case .failure(let error): throw error
        }
    }
}

actor MockSTT: STTProtocol {
    var transcribeCalled = false
    var transcribeResult: Result<String, Error> = .success("Mock Transcription")
    
    func setTranscribeResult(_ result: Result<String, Error>) {
        self.transcribeResult = result
    }
    
    func transcribe(audioData: Data) async throws -> String {
        transcribeCalled = true
        switch transcribeResult {
        case .success(let text): return text
        case .failure(let error): throw error
        }
    }
}
