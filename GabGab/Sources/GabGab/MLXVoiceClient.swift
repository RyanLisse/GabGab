import Foundation
import AVFoundation

/// Manages interaction with the mlx-audio REST server and handles local fallbacks.
public actor GabGabSessionManager {
    private let serverURL: URL
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixer: AVAudioMixerNode
    
    public init(serverURL: URL = URL(string: "http://127.0.0.1:8080")!) {
        self.serverURL = serverURL
        self.mixer = engine.mainMixerNode
        engine.attach(playerNode)
        engine.connect(playerNode, to: mixer, format: nil)
    }
    
    /// Synthesizes text to speech and returns audio data without playing.
    public func synthesizeAudioData(text: String, voice: String = "af_heart", urgency: String = "normal") async throws -> Data {
        print("[GabGab] Synthesizing audio data: \(text)")

        let endpoint = serverURL.appendingPathComponent("/v1/audio/speech")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "mlx-community/Kokoro-82M-bf16",
            "input": text,
            "voice": voice,
            "lang_code": "a"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[GabGab] Server error, attempting local fallback...")
                return try await fallbackSynthesizeAudioData(text: text, voice: voice, urgency: urgency)
            }

            return data
        } catch {
            print("[GabGab] Connection failed: \(error.localizedDescription)")
            return try await fallbackSynthesizeAudioData(text: text, voice: voice, urgency: urgency)
        }
    }

    /// Synthesizes text to speech using the MLX server or local fallback.
    public func synthesize(text: String, voice: String = "af_heart", urgency: String = "normal") async throws {
        print("[GabGab] Synthesizing: \(text)")
        
        let endpoint = serverURL.appendingPathComponent("/v1/audio/speech")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "mlx-community/Kokoro-82M-bf16",
            "input": text,
            "voice": voice,
            "lang_code": "a"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[GabGab] Server error, attempting local fallback...")
                try await fallbackSynthesize(text: text, voice: voice, urgency: urgency)
                return
            }
            
            try await playAudio(data: data)
        } catch {
            print("[GabGab] Connection failed: \(error.localizedDescription)")
            try await fallbackSynthesize(text: text, voice: voice, urgency: urgency)
        }
    }
    
    /// Plays audio data through the system's audio output.
    public func playAudio(data: Data) async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("mlx_output_\(UUID().uuidString).wav")
        try data.write(to: tempURL)
        
        let file = try AVAudioFile(forReading: tempURL)
        if !engine.isRunning {
            try engine.start()
        }
        
        playerNode.scheduleFile(file, at: nil, completionHandler: nil)
        playerNode.play()
    }
    
    private func fallbackSynthesizeAudioData(text: String, voice: String, urgency: String) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["voice_router.py", "tts", text, "--voice", voice, "--urgency", urgency, "--output", "/tmp/fallback.wav"]

        try process.run()
        process.waitUntilExit()

        return try Data(contentsOf: URL(fileURLWithPath: "/tmp/fallback.wav"))
    }

    private func fallbackSynthesize(text: String, voice: String, urgency: String) async throws {
        let data = try await fallbackSynthesizeAudioData(text: text, voice: voice, urgency: urgency)
        try await playAudio(data: data)
    }
    
    /// Checks if the MLX server is healthy and responding.
    public func checkHealth() async -> Bool {
        let endpoint = serverURL.appendingPathComponent("/health")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Transcribes audio data to text using the MLX server or fallback.
    public func transcribeAudioData(audioData: Data) async throws -> String {
        print("[GabGab] Transcribing audio data (\(audioData.count) bytes)")

        let endpoint = serverURL.appendingPathComponent("/v1/audio/transcriptions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data", forHTTPHeaderField: "Content-Type")

        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[GabGab] Server transcription failed, attempting fallback...")
                return try await fallbackTranscribe(audioData: audioData)
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            throw NSError(domain: "GabGabClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        } catch {
            print("[GabGab] Transcription failed: \(error.localizedDescription)")
            return try await fallbackTranscribe(audioData: audioData)
        }
    }

    private func fallbackTranscribe(audioData: Data) async throws -> String {
        // Save audio to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("transcribe_\(UUID().uuidString).wav")
        try audioData.write(to: tempURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["voice_router.py", "stt", tempURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else {
            throw NSError(domain: "GabGabClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No transcription output"])
        }

        return output
    }

    public func stop() {
        playerNode.stop()
        engine.stop()
    }
}
