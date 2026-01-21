import ArgumentParser
import Foundation
import GabGab

/// Validation error for CLI commands
struct ValidationError: Error, CustomStringConvertible {
    let message: String
    
    init(message: String) {
        self.message = message
    }
    
    var description: String {
        message
    }
}

@main
struct GabGabCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gabgab-cli",
        abstract: "MLX Voice Client CLI - Generate speech and transcribe audio using local MLX models",
        version: "1.0.0",
        subcommands: [TTS.self, STT.self, Health.self, Models.self],
        defaultSubcommand: TTS.self
    )
}

extension GabGabCLI {
    struct TTS: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "tts",
            abstract: "Generate speech from text using local MLX models"
        )

        @Option(name: .shortAndLong, help: "Text to convert to speech")
        var text: String

        @Option(name: .shortAndLong, help: "Voice model to use (default: af_heart)")
        var voice: String = "af_heart"

        @Option(name: .shortAndLong, help: "Output file path (default: speech.wav)")
        var output: String = "speech.wav"

        @Option(name: .shortAndLong, help: "MLX server URL (default: http://127.0.0.1:8080)")
        var server: String = "http://127.0.0.1:8080"

        @Flag(name: .shortAndLong, help: "Play audio after generation")
        var play: Bool = false

        @Option(name: .shortAndLong, help: "Urgency level for routing (high=cloud, normal=local)")
        var urgency: String = "normal"

        func run() async throws {
            print("🎵 Generating speech for: \"\(text)\"")
            print("🎤 Voice: \(voice)")
            print("📁 Output: \(output)")
            print("🚦 Urgency: \(urgency)")

            // Create voice session manager
            guard let serverURL = URL(string: server) else {
                throw ValidationError(message: "Invalid server URL: \(server)")
            }
            let manager = GabGabSessionManager(serverURL: serverURL)

            do {
                // Generate speech
                let audioData: Data = try await manager.synthesizeAudioData(text: text, voice: voice)

                // Write to file
                let outputURL = URL(fileURLWithPath: output)
                try audioData.write(to: outputURL)

                print("✅ Speech generated successfully (\(audioData.count) bytes)")
                print("💾 Saved to: \(output)")

                // Play if requested
                if play {
                    print("🔊 Playing audio...")
                    try await manager.playAudio(data: audioData)
                    print("✅ Playback complete")
                }

            } catch {
                print("❌ Error: \(error.localizedDescription)")
                throw error
            }
        }
    }
}

extension GabGabCLI {
    struct STT: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stt",
            abstract: "Transcribe audio to text using local MLX models"
        )

        @Argument(help: "Audio file to transcribe")
        var input: String

        @Option(name: .shortAndLong, help: "MLX server URL (default: http://127.0.0.1:8080)")
        var server: String = "http://127.0.0.1:8080"

        func run() async throws {
            print("🎧 Transcribing audio: \(input)")

            guard let serverURL = URL(string: server) else {
                throw ValidationError(message: "Invalid server URL: \(server)")
            }
            let manager = GabGabSessionManager(serverURL: serverURL)

            do {
                let audioURL = URL(fileURLWithPath: input)
                guard FileManager.default.fileExists(atPath: input) else {
                    throw ValidationError(message: "Audio file not found: \(input)")
                }
                let audioData = try Data(contentsOf: audioURL)

                let transcript = try await manager.transcribeAudioData(audioData: audioData)

                print("✅ Transcription complete:")
                print("📝 \"\(transcript)\"")

            } catch {
                print("❌ Error: \(error.localizedDescription)")
                throw error
            }
        }
    }
}

extension GabGabCLI {
    struct Health: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "health",
            abstract: "Check MLX voice server health and available models"
        )

        @Option(name: .shortAndLong, help: "MLX server URL (default: http://127.0.0.1:8080)")
        var server: String = "http://127.0.0.1:8080"

        func run() async throws {
            print("🏥 Checking MLX voice server health...")
            print("🌐 Server: \(server)")

            guard let serverURL = URL(string: server) else {
                throw ValidationError(message: "Invalid server URL: \(server)")
            }
            let manager = GabGabSessionManager(serverURL: serverURL)

            // Check if server is responding
            let isHealthy = await manager.checkHealth()

            if isHealthy {
                print("✅ Server is healthy")
            } else {
                print("❌ Server is not responding")
            }
        }
    }
}

extension GabGabCLI {
    struct Models: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "models",
            abstract: "List available voice models and configurations"
        )

        func run() async throws {
            print("📋 Available Voice Models:")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🎵 TTS Models (Kokoro/LFM):")
            print("   • af_heart - Female voice (warm, expressive)")
            print("   • af_bella - Female voice (clear, professional)")
            print("   • am_adam - Male voice (deep, authoritative)")
            print("   • am_michael - Male voice (neutral, clear)")
            print("")
            print("🎧 STT Models (Parakeet/Smart Turn):")
            print("   • parakeet-tdt-0.6b - Fast transcription")
            print("   • whisper-large-v3-turbo - High accuracy")
            print("")
            print("📊 Performance Notes:")
            print("   • Local models: <5s generation, no API costs")
            print("   • Cloud fallback: <2s generation, API costs apply")
            print("   • Quality target: UTMOS >3.5 (ElevenLabs equivalent)")
        }
    }
}
