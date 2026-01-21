import AVFoundation
import Foundation

/// Manages audio playback using AVAudioEngine
@MainActor
final class AudioPlayer: AudioPlayerProtocol {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixer: AVAudioMixerNode
    private var isEngineRunning = false
    
    init() {
        self.mixer = engine.mainMixerNode
        engine.attach(playerNode)
        engine.connect(playerNode, to: mixer, format: nil)
    }
    
    /// Plays audio data from memory
    func playAudio(data: Data) async throws {
        guard !data.isEmpty else {
            throw GabGabError.invalidAudioData
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mlx_output_\(UUID().uuidString).wav")
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        try data.write(to: tempURL)
        let file = try AVAudioFile(forReading: tempURL)
        
        if !isEngineRunning {
            try engine.start()
            isEngineRunning = true
        }
        
        await playerNode.scheduleFile(file, at: nil)
        playerNode.play()
    }
    
    /// Stops audio playback and engine
    func stop() async {
        playerNode.stop()
        if isEngineRunning {
            engine.stop()
            isEngineRunning = false
        }
    }
}
