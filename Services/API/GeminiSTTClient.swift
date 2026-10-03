import Foundation

final class GeminiSTTClient: STTAPIClient {
    private let apiKeyManager: APIKeyManager

    init(apiKeyManager: APIKeyManager = .shared) {
        self.apiKeyManager = apiKeyManager
    }

    private func endpoint(for model: STTModel) -> String {
        "https://generativelanguage.googleapis.com/v1alpha/models/\(model.rawValue):generateContent"
    }

    func transcribe(
        audioData: Data,
        model: STTModel,
        language: String?,
        originalExtension: String? = nil
    ) async throws -> TranscriptionResult {
        guard let apiKey = await apiKeyManager.apiKey(for: .gemini) else {
            throw STTError.apiError(apiKeyManager.unavailableReason(for: .gemini))
        }

        let base64Audio = audioData.base64EncodedString()
        let format = AudioFormatConverter.normalizeFormat(audioData, originalExtension: originalExtension)
        let mimeType = AudioFormatConverter.mimeTypeForGemini(from: format)
        let prompt = buildTranscriptionPrompt(language: language)

        let requestBody: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": [
                        "mime_type": mimeType,
                        "data": base64Audio
                    ]]
                ]
            ]]
        ]

        guard let url = URL(string: endpoint(for: model)) else {
            throw STTError.apiError("Invalid Gemini API endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, _) = try await STTAPIHelper.performRequest(request, providerName: "Gemini")


        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw STTError.emptyResponse
        }

        var processedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove extra spaces for Japanese
        if language == "ja" {
            processedText = removeJapaneseMorphemeSpacing(processedText)
        }

        return TranscriptionResult(
            text: processedText,
            confidence: nil,
            languageCode: nil
        )
    }

    private func buildTranscriptionPrompt(language: String?) -> String {
        let languageNames: [String: String] = [
            "en": "English",
            "ja": "Japanese",
            "zh": "Chinese",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "ko": "Korean",
            "pt": "Portuguese",
            "it": "Italian",
            "ru": "Russian"
        ]

        if let lang = language, lang != "auto", let langName = languageNames[lang] {
            var prompt = "Please transcribe the spoken words. The primary language is expected to be \(langName), but transcribe any language if spoken. Do not describe sound effects or audio characteristics. Output only the transcribed text."
            if lang == "ja" {
                prompt += " For Japanese text, do not insert spaces between words."
            }
            return prompt
        }

        return "Please transcribe the spoken words. Do not describe sound effects or audio characteristics. Output only the transcribed text."
    }

    private func removeJapaneseMorphemeSpacing(_ text: String) -> String {
        let pattern = "([\\p{Hiragana}\\p{Katakana}\\p{Han}])\\s+([\\p{Hiragana}\\p{Katakana}\\p{Han}])"
        var result = text
        while let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: match.range,
                withTemplate: "$1$2"
            )
        }
        return result
    }
}
