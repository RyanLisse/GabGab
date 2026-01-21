import Testing
import Foundation
@testable import GabGab

@Test
@MainActor
func testSynthesizeAudioDataSuccess() async throws {
    let mockHTTP = MockHTTPClient()
    let mockAudio = MockAudioPlayer()
    let mockTTS = MockTTS()
    let mockSTT = MockSTT()
    let config = MLXConfiguration()
    
    let manager = GabGabSessionManager.createForTesting(
        config: config,
        httpClient: mockHTTP,
        audioPlayer: mockAudio,
        fallbackTTS: mockTTS,
        fallbackSTT: mockSTT
    )
    
    let expectedData = Data([0x01, 0x02, 0x03])
    await mockHTTP.setSynthesizeSpeechResult(.success(expectedData))
    
    let data = try await manager.synthesizeAudioData(text: "Hello")
    
    #expect(data == expectedData)
    
    let httpCalled = await mockHTTP.synthesizeSpeechCalled
    #expect(httpCalled)
    
    let ttsCalled = await mockTTS.synthesizeAudioDataCalled
    #expect(!ttsCalled)
}

@Test
@MainActor
func testSynthesizeAudioDataFallback() async throws {
    let mockHTTP = MockHTTPClient()
    let mockAudio = MockAudioPlayer()
    let mockTTS = MockTTS()
    let mockSTT = MockSTT()
    let config = MLXConfiguration()
    
    let manager = GabGabSessionManager.createForTesting(
        config: config,
        httpClient: mockHTTP,
        audioPlayer: mockAudio,
        fallbackTTS: mockTTS,
        fallbackSTT: mockSTT
    )
    
    // Simulate HTTP failure
    await mockHTTP.setSynthesizeSpeechResult(.failure(GabGabError.serverError(500, "Fail")))
    
    // Simulate TTS success
    let expectedData = Data([0x04, 0x05])
    await mockTTS.setSynthesizeAudioDataResult(.success(expectedData))
    
    let data = try await manager.synthesizeAudioData(text: "Hello")
    
    #expect(data == expectedData)
    
    let httpCalled = await mockHTTP.synthesizeSpeechCalled
    #expect(httpCalled)
    
    let ttsCalled = await mockTTS.synthesizeAudioDataCalled
    #expect(ttsCalled)
}

@Test
@MainActor
func testCheckHealth() async {
    let mockHTTP = MockHTTPClient()
    let mockAudio = MockAudioPlayer()
    let mockTTS = MockTTS()
    let mockSTT = MockSTT()
    let config = MLXConfiguration()
    
    let manager = GabGabSessionManager.createForTesting(
        config: config,
        httpClient: mockHTTP,
        audioPlayer: mockAudio,
        fallbackTTS: mockTTS,
        fallbackSTT: mockSTT
    )
    
    let isHealthy = await manager.checkHealth()
    #expect(isHealthy)
    
    let httpCalled = await mockHTTP.checkHealthCalled
    #expect(httpCalled)
}

@Test
@MainActor
func testSynthesizeRejectsEmptyText() async throws {
    let mockHTTP = MockHTTPClient()
    let mockAudio = MockAudioPlayer()
    let mockTTS = MockTTS()
    let mockSTT = MockSTT()
    let config = MLXConfiguration()

    let manager = GabGabSessionManager.createForTesting(
        config: config,
        httpClient: mockHTTP,
        audioPlayer: mockAudio,
        fallbackTTS: mockTTS,
        fallbackSTT: mockSTT
    )

    do {
        _ = try await manager.synthesizeAudioData(text: "   ")
        #expect(Bool(false), "Expected invalidTextInput error")
    } catch let error as GabGabError {
        switch error {
        case .invalidTextInput:
            #expect(Bool(true))
        default:
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
}

@Test
@MainActor
func testTranscribeRejectsEmptyAudio() async throws {
    let mockHTTP = MockHTTPClient()
    let mockAudio = MockAudioPlayer()
    let mockTTS = MockTTS()
    let mockSTT = MockSTT()
    let config = MLXConfiguration()

    let manager = GabGabSessionManager.createForTesting(
        config: config,
        httpClient: mockHTTP,
        audioPlayer: mockAudio,
        fallbackTTS: mockTTS,
        fallbackSTT: mockSTT
    )

    do {
        _ = try await manager.transcribeAudioData(audioData: Data())
        #expect(Bool(false), "Expected invalidAudioData error")
    } catch let error as GabGabError {
        switch error {
        case .invalidAudioData:
            #expect(Bool(true))
        default:
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
}
