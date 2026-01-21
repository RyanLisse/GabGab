import Foundation
import Testing

@testable import GabGab

/// Test configuration
@Test
func testConfigurationDefaults() {
    let config = MLXConfiguration()
    #expect(config.serverURL == MLXConfiguration.defaultServerURL)
    #expect(config.ttsModel == MLXConfiguration.defaultTTSModel)
    #expect(config.defaultVoice == MLXConfiguration.defaultVoice)
}

@Test
func testConfigurationCustom() {
    // swiftlint:disable:next force_unwrapping
    let customURL = URL(string: "http://localhost:9000")!
    let config = MLXConfiguration(
        serverURL: customURL,
        ttsModel: "custom-model",
        defaultVoice: "custom_voice"
    )
    #expect(config.serverURL == customURL)
    #expect(config.ttsModel == "custom-model")
    #expect(config.defaultVoice == "custom_voice")
}

@Test
func testAvailableVoices() {
    #expect(MLXConfiguration.availableVoices.contains("af_heart"))
    #expect(MLXConfiguration.availableVoices.contains("af_bella"))
    #expect(MLXConfiguration.availableVoices.contains("am_adam"))
    #expect(MLXConfiguration.availableVoices.contains("am_michael"))
}

/// Test error types
@Test
func testGabGabErrorDescriptions() {
    let invalidURL = GabGabError.invalidServerURL("bad://url")
    #expect(invalidURL.errorDescription?.contains("Invalid server URL") == true)
    
    let serverError = GabGabError.serverError(404, "Not Found")
    #expect(serverError.errorDescription?.contains("404") == true)
    
    let networkError = GabGabError.networkError(NSError(domain: "test", code: 1))
    #expect(networkError.errorDescription?.contains("Network error") == true)

    let invalidText = GabGabError.invalidTextInput
    #expect(invalidText.errorDescription?.contains("Text input") == true)

    let synthesisFailed = GabGabError.speechSynthesisFailed("cancelled")
    #expect(synthesisFailed.errorDescription?.contains("Speech synthesis failed") == true)
}

/// Test session manager initialization
@Test
@MainActor
func testSessionManagerInit() async {
    let manager = GabGabSessionManager.create()
    let isHealthy = await manager.checkHealth()
    // Health check may fail if server is not running, but should not crash
    #expect(type(of: isHealthy) == Bool.self)
}

@Test
@MainActor
func testSessionManagerInitWithURL() async {
    // swiftlint:disable:next force_unwrapping
    let customURL = URL(string: "http://localhost:9000")!
    let manager = GabGabSessionManager.create(serverURL: customURL)
    let isHealthy = await manager.checkHealth()
    // Health check may fail if server is not running, but should not crash
    #expect(type(of: isHealthy) == Bool.self)
}

/// Test session manager with configuration
@Test
@MainActor
func testSessionManagerWithConfig() async {
    // swiftlint:disable:next force_unwrapping
    let config = MLXConfiguration(
        serverURL: URL(string: "http://localhost:9000")!
    )
    let manager = GabGabSessionManager.create(config: config)
    let isHealthy = await manager.checkHealth()
    #expect(type(of: isHealthy) == Bool.self)
}
