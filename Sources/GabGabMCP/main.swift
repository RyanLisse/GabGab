import Foundation
import GabGab

/// MCP Server for MLX Voice operations
/// Provides tools for text-to-speech and speech-to-text using local MLX models
class GabGabMCPServer {
    private let manager = GabGabSessionManager()

    /// Tool: Generate speech from text
    func generateSpeech(text: String, voice: String = "af_heart", outputPath: String? = nil) async throws -> [String: Any] {
        print("[MCP] Generating speech: \(text)")

        let audioData = try await manager.synthesizeAudioData(text: text, voice: voice)

        if let outputPath = outputPath {
            let url = URL(fileURLWithPath: outputPath)
            try audioData.write(to: url)
            return [
                "success": true,
                "message": "Speech generated and saved to \(outputPath)",
                "bytes": audioData.count,
                "path": outputPath
            ]
        } else {
            // Return base64 encoded audio for MCP
            let base64Audio = audioData.base64EncodedString()
            return [
                "success": true,
                "message": "Speech generated",
                "bytes": audioData.count,
                "audio_base64": base64Audio,
                "format": "wav"
            ]
        }
    }

    /// Tool: Transcribe audio to text
    func transcribeAudio(audioPath: String) async throws -> [String: Any] {
        print("[MCP] Transcribing audio: \(audioPath)")

        let audioURL = URL(fileURLWithPath: audioPath)
        let audioData = try Data(contentsOf: audioURL)

        let transcript = try await manager.transcribeAudioData(audioData: audioData)

        return [
            "success": true,
            "transcript": transcript,
            "audio_bytes": audioData.count
        ]
    }

    /// Tool: Check server health
    func checkHealth() async -> [String: Any] {
        let isHealthy = await manager.checkHealth()
        return [
            "healthy": isHealthy,
            "server_url": "http://127.0.0.1:8080"
        ]
    }

    /// Tool: List available voices
    func listVoices() -> [String: Any] {
        return [
            "voices": [
                ["id": "af_heart", "name": "Female - Warm/Expressive", "language": "en"],
                ["id": "af_bella", "name": "Female - Clear/Professional", "language": "en"],
                ["id": "am_adam", "name": "Male - Deep/Authoritative", "language": "en"],
                ["id": "am_michael", "name": "Male - Neutral/Clear", "language": "en"]
            ],
            "models": [
                ["id": "kokoro-82m-bf16", "type": "tts", "quality": "high"],
                ["id": "parakeet-tdt-0.6b-v3", "type": "stt", "quality": "high"]
            ]
        ]
    }
}

/// MCP Protocol Handler using stdio transport
class MCPProtocolHandler {
    private let server = GabGabMCPServer()

    func run() async {
        let stdin = FileHandle.standardInput
        let stdout = FileHandle.standardOutput

        // Log to stderr for debugging (MCP servers typically don't log to stdout)
        fputs("[MCP] MLX Voice MCP Server started\n", stderr)

        while true {
            do {
                // Read JSON-RPC message from stdin
                guard let inputData = try? stdin.readToEnd(),
                      let inputString = String(data: inputData, encoding: .utf8),
                      let request = try? JSONSerialization.jsonObject(with: Data(inputString.utf8)) as? [String: Any] else {
                    continue
                }

                let response = try await handleRequest(request)

                if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                    stdout.write(responseData)
                    stdout.write(Data("\n".utf8))
                }

            } catch {
                fputs("[MCP] Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    private func handleRequest(_ request: [String: Any]) async throws -> [String: Any] {
        guard let id = request["id"],
              let method = request["method"] as? String else {
            throw MCPError.invalidRequest
        }

        let params = request["params"] as? [String: Any] ?? [:]

        switch method {
        case "tools/list":
            return [
                "jsonrpc": "2.0",
                "id": id,
                "result": [
                    "tools": [
                        [
                            "name": "voice/generate_speech",
                            "description": "Generate speech from text using local MLX models",
                            "inputSchema": [
                                "type": "object",
                                "properties": [
                                    "text": ["type": "string", "description": "Text to convert to speech"],
                                    "voice": ["type": "string", "description": "Voice ID (default: af_heart)", "default": "af_heart"],
                                    "output_path": ["type": "string", "description": "Optional output file path"]
                                ],
                                "required": ["text"]
                            ]
                        ],
                        [
                            "name": "voice/transcribe_audio",
                            "description": "Transcribe audio file to text using local MLX models",
                            "inputSchema": [
                                "type": "object",
                                "properties": [
                                    "audio_path": ["type": "string", "description": "Path to audio file"]
                                ],
                                "required": ["audio_path"]
                            ]
                        ],
                        [
                            "name": "voice/check_health",
                            "description": "Check if MLX voice server is healthy",
                            "inputSchema": ["type": "object"]
                        ],
                        [
                            "name": "voice/list_voices",
                            "description": "List available voices and models",
                            "inputSchema": ["type": "object"]
                        ]
                    ]
                ]
            ]

        case "tools/call":
            guard let toolName = params["name"] as? String,
                  let arguments = params["arguments"] as? [String: Any] else {
                throw MCPError.invalidParams
            }

            let result = try await callTool(toolName, arguments: arguments)

            return [
                "jsonrpc": "2.0",
                "id": id,
                "result": result
            ]

        default:
            throw MCPError.methodNotFound
        }
    }

    private func callTool(_ name: String, arguments: [String: Any]) async throws -> [String: Any] {
        switch name {
        case "voice/generate_speech":
            guard let text = arguments["text"] as? String else {
                throw MCPError.invalidParams
            }
            let voice = arguments["voice"] as? String ?? "af_heart"
            let outputPath = arguments["output_path"] as? String
            return try await server.generateSpeech(text: text, voice: voice, outputPath: outputPath)

        case "voice/transcribe_audio":
            guard let audioPath = arguments["audio_path"] as? String else {
                throw MCPError.invalidParams
            }
            return try await server.transcribeAudio(audioPath: audioPath)

        case "voice/check_health":
            return await server.checkHealth()

        case "voice/list_voices":
            return server.listVoices()

        default:
            throw MCPError.methodNotFound
        }
    }
}

enum MCPError: Error {
    case invalidRequest
    case invalidParams
    case methodNotFound
}

// MCP Server entry point
@main
struct GabGabMCPMain {
    static func main() async {
        let handler = MCPProtocolHandler()
        await handler.run()
    }
}
