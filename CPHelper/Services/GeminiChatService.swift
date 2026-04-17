import Foundation

enum GeminiChatError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case emptyResponse
    case apiFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing. Set GEMINI_API_KEY in the Xcode scheme environment or add it to LocalSecrets.plist."
        case .invalidURL:
            return "Could not create the Gemini request."
        case .invalidResponse:
            return "Gemini returned an unexpected response."
        case .emptyResponse:
            return "Gemini did not return any text."
        case .apiFailure(let message):
            return message
        }
    }
}

actor GeminiChatService {
    static let shared = GeminiChatService()

    private struct RequestBody: Encodable {
        let contents: [RequestContent]
        let generationConfig: GenerationConfig
    }

    private struct RequestContent: Encodable {
        let role: String
        let parts: [RequestPart]
    }

    private struct RequestPart: Encodable {
        let text: String
    }

    private struct GenerationConfig: Encodable {
        let temperature: Double
        let topP: Double
        let topK: Int
        let maxOutputTokens: Int
        let responseMimeType: String
    }

    private struct ResponseBody: Decodable {
        let candidates: [Candidate]?
        let error: ResponseError?
    }

    private struct Candidate: Decodable {
        let content: ResponseContent?
    }

    private struct ResponseContent: Decodable {
        let parts: [ResponsePart]?
    }

    private struct ResponsePart: Decodable {
        let text: String?
    }

    private struct ResponseError: Decodable {
        let message: String?
    }

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let modelName = "gemini-2.5-flash"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func reply(
        to conversation: [CPChatMessage],
        context: CPChatContextSnapshot
    ) async throws -> String {
        guard let apiKey = GoogleServiceConfiguration.geminiAPIKey() else {
            throw GeminiChatError.missingAPIKey
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent") else {
            throw GeminiChatError.invalidURL
        }

        let requestBody = RequestBody(
            contents: buildContents(from: conversation, context: context),
            generationConfig: GenerationConfig(
                temperature: 0.45,
                topP: 0.9,
                topK: 32,
                maxOutputTokens: 1024,
                responseMimeType: "text/plain"
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiChatError.invalidResponse
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let errorResponse = try? decoder.decode(ResponseBody.self, from: data)
            throw GeminiChatError.apiFailure(
                errorResponse?.error?.message ?? "Gemini returned status code \(httpResponse.statusCode)."
            )
        }

        let body = try decoder.decode(ResponseBody.self, from: data)

        if let error = body.error?.message {
            throw GeminiChatError.apiFailure(error)
        }

        let responseText = body.candidates?
            .first?
            .content?
            .parts?
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let responseText, !responseText.isEmpty else {
            throw GeminiChatError.emptyResponse
        }

        return responseText
    }

    private func buildContents(
        from conversation: [CPChatMessage],
        context: CPChatContextSnapshot
    ) -> [RequestContent] {
        var contents: [RequestContent] = [
            RequestContent(
                role: "user",
                parts: [
                    RequestPart(text: buildSystemPrompt(context: context))
                ]
            )
        ]

        for message in conversation.suffix(12) {
            contents.append(
                RequestContent(
                    role: message.role == .user ? "user" : "model",
                    parts: [RequestPart(text: message.text)]
                )
            )
        }

        return contents
    }

    private func buildSystemPrompt(context: CPChatContextSnapshot) -> String {
        let trackedHandlesSummary: String
        if context.handleInsights.isEmpty {
            trackedHandlesSummary = "No handle analysis is loaded yet. Use only visible tracked handles and ask clarifying questions when needed."
        } else {
            trackedHandlesSummary = context.handleInsights.map { insight in
                let currentRating = insight.currentRating.map(String.init) ?? "Unrated"
                let maxRating = insight.maxRating.map(String.init) ?? "Unrated"
                let strengths = insight.strengths.prefix(2).joined(separator: ", ")
                let weaknesses = insight.weaknesses.prefix(2).joined(separator: ", ")

                return """
                - \(insight.handle)\(insight.isPrimary ? " (primary)" : ""): current \(currentRating), max \(maxRating), solved \(insight.solvedCount), acceptance \(NumberFormatting.percentage(insight.acceptanceRate)), stage \(insight.roadmapStage.title), strengths [\(strengths)], weak areas [\(weaknesses)]
                """
            }
            .joined(separator: "\n")
        }

        let problemSummary: String
        if let problem = context.currentProblem {
            let rating = problem.rating.map(String.init) ?? "Unrated"
            let tags = problem.tags.isEmpty ? "No tags" : problem.tags.joined(separator: ", ")
            problemSummary = "Attached problem context: \(problem.displayID) \(problem.name), rating \(rating), tags: \(tags)."
        } else {
            problemSummary = "No specific problem is attached right now."
        }

        return """
        You are CP Coach inside the CPHelper app.
        Only help with competitive programming, Codeforces handle analysis, problem analysis, contest preparation, DSA understanding, roadmap planning, and frustration recovery after bad sessions.
        If the user asks for something outside those topics, politely refuse and steer them back to competitive programming.
        Keep answers supportive, practical, and concrete.
        When the user sounds frustrated:
        1. Validate the feeling briefly.
        2. Diagnose the likely reason from the provided handle data if available.
        3. Give a very actionable next-step plan for today.
        4. Offer a short roadmap for the next 1-2 weeks.
        Never claim you know Codeforces contest registration unless it is explicitly provided by the app.
        Avoid markdown tables.
        User name: \(context.userName)
        Tracked handles:
        \(trackedHandlesSummary)
        \(problemSummary)
        Reply only to the user's latest message while using this context.
        """
    }
}
