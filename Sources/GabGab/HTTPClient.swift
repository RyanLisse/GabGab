import Foundation

/// HTTP client for MLX audio server communication
actor MLXHTTPClient {
    private let baseURL: URL
    private let session: URLSession
    
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    /// Creates a TTS request payload
    func createTTSRequest(
        text: String,
        voice: String,
        model: String,
        langCode: String
    ) throws -> (URLRequest, Data) {
        let endpoint = baseURL.appendingPathComponent("/v1/audio/speech")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": model,
            "input": text,
            "voice": voice,
            "lang_code": langCode
        ]
        
        let body = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = body
        
        return (request, body)
    }
    
    /// Performs TTS request and returns audio data
    func synthesizeSpeech(
        text: String,
        voice: String,
        model: String,
        langCode: String
    ) async throws -> Data {
        let (request, _) = try createTTSRequest(
            text: text,
            voice: voice,
            model: model,
            langCode: langCode
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GabGabError.invalidResponseFormat
        }
        
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            throw GabGabError.serverError(httpResponse.statusCode, message)
        }
        
        return data
    }
    
    /// Creates a transcription request with multipart form data
    func createTranscriptionRequest(audioData: Data) throws -> URLRequest {
        let endpoint = baseURL.appendingPathComponent("/v1/audio/transcriptions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".utf8))
        body.append(Data("Content-Type: audio/wav\r\n\r\n".utf8))
        body.append(audioData)
        body.append(Data("\r\n".utf8))
        body.append(Data("--\(boundary)--\r\n".utf8))
        
        request.httpBody = body
        
        return request
    }
    
    /// Performs transcription request and returns text
    func transcribeAudio(audioData: Data) async throws -> String {
        let request = try createTranscriptionRequest(audioData: audioData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GabGabError.invalidResponseFormat
        }
        
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            throw GabGabError.serverError(httpResponse.statusCode, message)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw GabGabError.invalidResponseFormat
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Checks server health
    func checkHealth() async -> Bool {
        let endpoint = baseURL.appendingPathComponent("/health")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
