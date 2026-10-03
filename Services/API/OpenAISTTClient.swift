import Foundation

final class OpenAISTTClient: STTAPIClient {
    private let endpoint = "https://api.openai.com/v1/audio/transcriptions"
    private let apiKeyManager: APIKeyManager

    init(apiKeyManager: APIKeyManager = .shared) {
        self.apiKeyManager = apiKeyManager
    }

    func transcribe(
        audioData: Data,
        model: STTModel,
        language: String?,
        originalExtension: String? = nil
    ) async throws -> TranscriptionResult {
        guard let apiKey = await apiKeyManager.apiKey(for: .openAI) else {
            throw STTError.apiError(apiKeyManager.unavailableReason(for: .openAI))
        }

        let format = AudioFormatConverter.normalizeFormat(audioData, originalExtension: originalExtension)
        let boundary = UUID().uuidString
        var body = Data()

        // Add file field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.\(format.fileExtension)\"\r\n")
        body.append("Content-Type: \(format.mimeType)\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // Add model field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("\(model.rawValue)\r\n")

        // Add response_format field
        let responseFormat = model == .whisper1 ? "verbose_json" : "json"
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        body.append("\(responseFormat)\r\n")

        // Add include[] for logprobs (non-whisper models)
        if model != .whisper1 {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"include[]\"\r\n\r\n")
            body.append("logprobs\r\n")
        }

        // Add language if specified
        if let lang = language, lang != "auto" {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            body.append("\(lang)\r\n")
        }

        body.append("--\(boundary)--\r\n")

        guard let url = URL(string: endpoint) else {
            throw STTError.apiError("Invalid API endpoint URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 180

        let (data, _) = try await STTAPIHelper.performRequest(request, providerName: "OpenAI")


        let json = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)

        let confidence: Double?
        if let logprobs = json.logprobs, !logprobs.isEmpty {
            let avgLogprob = logprobs.map { $0.logprob }.reduce(0, +) / Double(logprobs.count)
            confidence = exp(avgLogprob)
        } else if let segments = json.segments, !segments.isEmpty {
            let avgLogprob = segments.map { $0.avgLogprob }.reduce(0, +) / Double(segments.count)
            confidence = exp(avgLogprob)
        } else {
            confidence = nil
        }

        return TranscriptionResult(
            text: json.text.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: confidence,
            languageCode: json.language
        )
    }
}

private struct OpenAITranscriptionResponse: Decodable {
    let text: String
    let language: String?
    let logprobs: [LogprobEntry]?
    let segments: [Segment]?

    struct LogprobEntry: Decodable {
        let logprob: Double
    }

    struct Segment: Decodable {
        let avgLogprob: Double

        enum CodingKeys: String, CodingKey {
            case avgLogprob = "avg_logprob"
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - API Retry Helper

/// Helper for STT API requests with retry logic for transient errors (429, 5xx)
enum STTAPIHelper {
    private static let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    private static let maxRetries = 3

    /// Returns a successful HTTP 200 response, or throws after retrying transient errors.
    static func performRequest(_ request: URLRequest, providerName: String) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw STTError.networkError(URLError(.badServerResponse))
                }

                APIKeyManager.shared.noteResponse(statusCode: httpResponse.statusCode, providerName: providerName)


                if httpResponse.statusCode == 200 {
                    return (data, httpResponse)
                }

                if retryableStatusCodes.contains(httpResponse.statusCode) {
                    if attempt < maxRetries - 1 {
                        let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                        try await Task.sleep(nanoseconds: delay)
                        dprint("\(providerName) STT: Retry \(attempt + 1)/\(maxRetries) after HTTP \(httpResponse.statusCode)")

                        continue
                    }
                }

                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw STTError.apiError("\(providerName) API Error (\(httpResponse.statusCode)): \(errorMessage)")

            } catch let error as STTError {
                throw error
            } catch {
                lastError = error

                if attempt < maxRetries - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try await Task.sleep(nanoseconds: delay)
                    dprint("\(providerName) STT: Retry \(attempt + 1)/\(maxRetries) after error: \(error.localizedDescription)")

                    continue
                }
            }
        }

        if let error = lastError {
            throw STTError.networkError(error)
        }

        throw STTError.networkError(URLError(.unknown))
    }
}
