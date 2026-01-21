import Foundation

/// MCP Protocol Handler using stdio transport
@MainActor
public final class MCPProtocolHandler {
    private let server: GabGabMCPServer

    public init(server: GabGabMCPServer) {
        self.server = server
    }

    /// Factory method to create handler with default server
    public static func create() -> MCPProtocolHandler {
        MCPProtocolHandler(server: GabGabMCPServer.create())
    }

    public func run() async {
        let stdin = FileHandle.standardInput
        let stdout = FileHandle.standardOutput

        fputs("[MCP] MLX Voice MCP Server started\n", stderr)
        var buffer = Data()

        while true {
            do {
                let inputData = stdin.availableData
                if inputData.isEmpty {
                    break
                }

                buffer.append(inputData)
                while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer.subdata(in: 0..<newlineIndex)
                    buffer.removeSubrange(0...newlineIndex)

                    let trimmedLine = lineData.trimmingTrailingCarriageReturn()
                    if trimmedLine.isEmpty {
                        continue
                    }

                    do {
                        let request = try parseRequest(from: trimmedLine)
                        do {
                            let response = try await handleRequest(request)
                            try writeResponse(response, to: stdout)
                        } catch let error as MCPError {
                            let errorResponse = jsonRpcErrorResponse(for: error, id: request["id"])
                            try writeResponse(errorResponse, to: stdout)
                        } catch {
                            let errorResponse = jsonRpcErrorResponse(
                                code: -32603,
                                message: "Internal error: \(error.localizedDescription)",
                                id: request["id"]
                            )
                            try writeResponse(errorResponse, to: stdout)
                        }
                    } catch let error as JSONParseError {
                        let errorResponse = jsonRpcErrorResponse(code: -32700, message: error.message, id: nil)
                        try writeResponse(errorResponse, to: stdout)
                    } catch {
                        let errorResponse = jsonRpcErrorResponse(
                            code: -32603,
                            message: "Internal error: \(error.localizedDescription)",
                            id: nil
                        )
                        try writeResponse(errorResponse, to: stdout)
                    }
                }
            } catch {
                fputs("[MCP] Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    private struct JSONParseError: Error {
        let message: String
    }

    private func parseRequest(from data: Data) throws -> [String: Any] {
        guard let request = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JSONParseError(message: "Parse error")
        }
        return request
    }

    private func writeResponse(_ response: [String: Any], to stdout: FileHandle) throws {
        let responseData = try JSONSerialization.data(withJSONObject: response)
        stdout.write(responseData)
        stdout.write(Data("\n".utf8))
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

    private func jsonRpcErrorResponse(for error: MCPError, id: Any?) -> [String: Any] {
        switch error {
        case .invalidRequest:
            return jsonRpcErrorResponse(code: -32600, message: "Invalid Request", id: id)
        case .methodNotFound:
            return jsonRpcErrorResponse(code: -32601, message: "Method not found", id: id)
        case .invalidParams:
            return jsonRpcErrorResponse(code: -32602, message: "Invalid params", id: id)
        }
    }

    private func jsonRpcErrorResponse(code: Int, message: String, id: Any?) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": [
                "code": code,
                "message": message
            ]
        ]
    }
}

private extension Data {
    func trimmingTrailingCarriageReturn() -> Data {
        if last == 0x0D {
            return Data(dropLast())
        }
        return self
    }
}
