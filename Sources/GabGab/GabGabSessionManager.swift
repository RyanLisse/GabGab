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
        
        // Ensure local execution is available if needed
        if config.useLocalExecution {
            // Check availability or setup environment if required
            GabGabLogger.info("Initialized in LOCAL execution mode")
        }
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
    
    /// Factory method to create session manager for local execution
    public static func createLocal() -> GabGabSessionManager {
        let config = MLXConfiguration(serverURL: URL(string: "http://localhost")!, useLocalExecution: true)
        return GabGabSessionManager(
            config: config,
            httpClient: MLXHTTPClient(baseURL: config.serverURL), // Placeholder, won't be used for synthesis
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
        
        if config.useLocalExecution {
             return try await synthesizeLocal(text: text, voice: voice)
        }
        
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
        
        if config.useLocalExecution {
            let audioData = try await synthesizeLocal(text: text, voice: voice)
            try await audioPlayer.playAudio(data: audioData)
            return
        }
        
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
        if config.useLocalExecution {
            // For local execution, we assume "healthy" if basic dependencies check out
            // Ideally we'd run a quick python check
            return true
        }
        return await httpClient.checkHealth()
    }
    
    /// Transcribes audio data to text using the MLX server or fallback.
    public func transcribeAudioData(audioData: Data) async throws -> String {
        guard !audioData.isEmpty else {
            throw GabGabError.invalidAudioData
        }
        GabGabLogger.info("Transcribing audio data (\(audioData.count) bytes)")
        
        if config.useLocalExecution {
            return try await transcribeLocal(audioData: audioData)
        }
        
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
    
    // MARK: - Local Execution
    
    private func synthesizeLocal(text: String, voice: String) async throws -> Data {
        GabGabLogger.info("Executing local MLX TTS...")
        
        // We need a temporary file for output
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        
        // Construct Python command
        // Note: Providing full path to python3 might be safer, but relying on PATH for now
        // mlx_audio.tts.generate uses --file_prefix, NOT --output
        let filePrefix = tempURL.deletingPathExtension().path
        // Using explicit model. Switched to bf16 to avoid 'bit' parsing error
        let command = "python3 -m mlx_audio.tts.generate --model mlx-community/Kokoro-82M-bf16 --text \"\(text)\" --voice \(voice) --file_prefix \"\(filePrefix)\""
        
        // Ignore unused warning by assigning to _
        // mlx_audio appends _000 to the filename
        let actualOutputPath = filePrefix + "_000" + "." + tempURL.pathExtension
        let actualOutputURL = URL(fileURLWithPath: actualOutputPath)
        
        // Ignore unused warning by assigning to _
        // We will check file existence instead of strict exit code, as mlx might exit with SIGBUS/10 on some setups purely on cleanup
        do {
            _ = try await runShellCommand(command, tempURL: tempURL)
        } catch {
            // Log error but continue to check file existence
            GabGabLogger.error("Run shell command failed with error: \(error). Checking for output file anyway.")
        }
        
        if FileManager.default.fileExists(atPath: actualOutputURL.path) {
            // Move to expected tempURL
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.moveItem(at: actualOutputURL, to: tempURL)
        } else {
             throw GabGabError.serverError(500, "Local synthesis failed to produce output file at \(actualOutputPath)")
        }
        
        // Additional check
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            throw GabGabError.serverError(500, "Local synthesis failed to produce output file after move")
        }
        
        let data = try Data(contentsOf: tempURL)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
        
        return data
    }

    private func transcribeLocal(audioData: Data) async throws -> String {
         GabGabLogger.info("Executing local MLX STT...")
         
         // We need a temporary file for input audio
         let tempInputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
         try audioData.write(to: tempInputURL)
         
         // Construct Python command
         // Capturing stdout for transcript
         // command: mlx_whisper audio_file --model ...
         let command = "python3 -m mlx_whisper.cli \"\(tempInputURL.path)\""
         
         let output = try await runShellCommand(command)
         
         // Cleanup
         try? FileManager.default.removeItem(at: tempInputURL)
         
         // Clean output (remove logs if any, mlx might be verbose)
         // Assuming last line or standard output is the text.
         // This might need refinement based on exact mlx-audio output format
         return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func runShellCommand(_ command: String, tempURL: URL? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            
            // source .venv/bin/activate and run command
            // We assume the app is running from project root or derived data has access to source root
            // For a robust solution, we might need a way to find the project root or ship a python env with the app
            // For this dev CLI tool, assuming .venv in current directory is acceptable for "local execution mode"
            let venvCommand = "set -e; source .venv/bin/activate && " + command
            process.arguments = ["-c", venvCommand]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    fputs("DEBUG: Process exited with 0\n", stderr)
                    if let path = tempURL?.path {
                        fputs("DEBUG: Output Path: \(path)\n", stderr)
                    }
                    fputs("DEBUG STDOUT: \(output)\n", stderr)
                    fputs("DEBUG STDERR: \(errorOutput)\n", stderr)
                    continuation.resume(returning: output)
                } else {
                    fputs("DEBUG: Shell command failed. Exit code: \(process.terminationStatus)\n", stderr)
                    fputs("DEBUG STDOUT: \(output)\n", stderr)
                    fputs("DEBUG STDERR: \(errorOutput)\n", stderr)
                    GabGabLogger.error("Shell command failed. Exit code: \(process.terminationStatus)")
                    // serverError expects (Int, String?)
                    continuation.resume(throwing: GabGabError.serverError(Int(process.terminationStatus), "Process failed: \(errorOutput)"))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
