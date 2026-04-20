import Combine
import Foundation

@MainActor
final class ChatbotViewModel: ObservableObject {
    private struct HandleTarget {
        let handle: String
        let label: String
        let isPrimary: Bool
    }

    @Published var messages: [CPChatMessage]
    @Published var draftMessage = ""
    @Published private(set) var isSending = false
    @Published private(set) var isPreparingContext = false
    @Published private(set) var handleInsights: [ChatHandleInsight] = []
    @Published var errorMessage: String?

    let problem: CodeforcesProblem?
    let preferredHandle: String?

    private let chatService: GeminiChatService
    private let analysisService: CodeforcesAnalysisService

    private var hasPrepared = false

    init(
        problem: CodeforcesProblem? = nil,
        preferredHandle: String? = nil,
        chatService: GeminiChatService = .shared,
        analysisService: CodeforcesAnalysisService = .shared
    ) {
        self.problem = problem
        self.preferredHandle = preferredHandle
        self.chatService = chatService
        self.analysisService = analysisService

        let openingLine: String
        if let problem {
            openingLine = "Problem context is attached for \(problem.displayID)."
        } else {
            openingLine = "Ask about your primary handle, friends, DSA, roadmap, or contests."
        }

        self.messages = [
            CPChatMessage(role: .assistant, text: openingLine)
        ]
    }

    func prepare(user: UserProfile?) async {
        guard !hasPrepared else { return }
        hasPrepared = true

        guard let user else { return }

        let prioritizedHandles = prioritizedHandles(from: user)
        guard !prioritizedHandles.isEmpty else { return }

        isPreparingContext = true
        defer { isPreparingContext = false }

        for target in prioritizedHandles.prefix(3) {
            do {
                let analysis = try await analysisService.loadAnalysis(for: target.handle)
                let stage = RoadmapStage.stage(for: analysis.effectiveCurrentRating)
                let insight = ChatHandleInsight(
                    handle: analysis.handle,
                    label: target.label,
                    isPrimary: target.isPrimary,
                    currentRating: analysis.summary.currentRating,
                    maxRating: analysis.summary.maxRating,
                    solvedCount: analysis.summary.solvedCount,
                    acceptanceRate: analysis.summary.overallAcceptanceRate,
                    strengths: analysis.strengths.map(\.title),
                    weaknesses: analysis.weaknesses.map(\.title),
                    roadmapStage: stage
                )

                handleInsights.removeAll { $0.handle.caseInsensitiveCompare(insight.handle) == .orderedSame }
                handleInsights.append(insight)
            } catch {
                continue
            }
        }
    }

    func sendMessage(
        user: UserProfile?,
        tutorials: [AlgorithmTutorial],
        tutorialMatcher: (String) -> AlgorithmTutorial?
    ) async -> ChatNavigationAction? {
        let messageText = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return nil }

        draftMessage = ""
        errorMessage = nil
        messages.append(CPChatMessage(role: .user, text: messageText))

        if let route = resolveRouteIntent(
            from: messageText,
            user: user,
            tutorials: tutorials,
            tutorialMatcher: tutorialMatcher
        ) {
            switch route {
            case .handleAnalysis(let handle):
                messages.append(CPChatMessage(role: .assistant, text: "Opening @\(handle)."))
            case .tutorial(let tutorialID):
                if let tutorial = tutorials.first(where: { $0.id == tutorialID }) {
                    messages.append(CPChatMessage(role: .assistant, text: "Opening \(tutorial.title)."))
                } else {
                    messages.append(CPChatMessage(role: .assistant, text: "Opening tutorial."))
                }
            case .contestCalendar:
                messages.append(CPChatMessage(role: .assistant, text: "Opening contest calendar."))
            }

            return route
        }

        if handleInsights.isEmpty {
            await prepare(user: user)
        }

        isSending = true
        defer { isSending = false }

        do {
            let context = CPChatContextSnapshot(
                userName: user?.fullName ?? "coder",
                primaryHandle: user?.primaryHandle,
                friends: user?.friends ?? [],
                handleInsights: handleInsights,
                currentProblem: problem
            )

            let reply = try await chatService.reply(
                to: messages.filter { $0.role == .user || $0.role == .assistant },
                context: context
            )

            messages.append(CPChatMessage(role: .assistant, text: reply))
        } catch {
            errorMessage = error.localizedDescription
            messages.append(
                CPChatMessage(
                    role: .assistant,
                    text: "I could not reach the coaching model just now."
                )
            )
        }

        return nil
    }

    private func resolveRouteIntent(
        from message: String,
        user: UserProfile?,
        tutorials: [AlgorithmTutorial],
        tutorialMatcher: (String) -> AlgorithmTutorial?
    ) -> ChatNavigationAction? {
        let normalized = normalize(message)

        if normalized.contains("contest calendar")
            || normalized.contains("upcoming contests")
            || normalized.contains("next contests") {
            return .contestCalendar
        }

        if shouldOpenHandleAnalysis(normalized) {
            if let explicitHandle = extractHandle(from: message, user: user) {
                return .handleAnalysis(explicitHandle)
            }

            if (normalized.contains("my handle")
                || normalized.contains("my primary handle")
                || normalized.contains("my main handle")),
               let primaryHandle = user?.primaryHandle {
                return .handleAnalysis(primaryHandle)
            }
        }

        if shouldOpenTutorial(normalized) {
            if let tutorial = tutorialMatcher(message) {
                return .tutorial(tutorial.id)
            }

            if let matchedTutorial = tutorials.first(where: {
                normalize($0.title) == normalize(message)
            }) {
                return .tutorial(matchedTutorial.id)
            }
        }

        return nil
    }

    private func shouldOpenHandleAnalysis(_ normalized: String) -> Bool {
        let analysisSignals = [
            "handle analysis",
            "analyze handle",
            "analyse handle",
            "analysis for",
            "open handle",
            "profile analysis",
            "check handle",
            "see handle",
            "my primary handle",
            "my main handle"
        ]

        if analysisSignals.contains(where: normalized.contains) {
            return true
        }

        return normalized.contains("handle")
            && (normalized.contains("analy")
                || normalized.contains("analysis")
                || normalized.contains("open")
                || normalized.contains("check")
                || normalized.contains("profile"))
    }

    private func shouldOpenTutorial(_ normalized: String) -> Bool {
        let tutorialSignals = [
            "tutorial",
            "guide",
            "article",
            "teach me",
            "read about",
            "open",
            "show me"
        ]

        return tutorialSignals.contains(where: normalized.contains)
    }

    private func extractHandle(from message: String, user: UserProfile?) -> String? {
        if let primaryHandle = user?.primaryHandle,
           message.localizedCaseInsensitiveContains(primaryHandle) {
            return primaryHandle
        }

        if let user {
            for friend in user.friends {
                if message.localizedCaseInsensitiveContains(friend.handle) {
                    return friend.handle
                }
            }
        }

        guard let regex = try? NSRegularExpression(pattern: #"@?([A-Za-z0-9_.-]{3,24})"#) else {
            return nil
        }

        let nsRange = NSRange(location: 0, length: message.utf16.count)
        let matches = regex.matches(in: message, range: nsRange)

        let blockedWords: Set<String> = [
            "handle", "analysis", "analyze", "analyse", "open", "show", "tutorial", "guide", "please"
        ]

        for match in matches {
            guard match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: message) else {
                continue
            }

            let candidate = String(message[range])
            if !blockedWords.contains(candidate.lowercased()) {
                return candidate
            }
        }

        return nil
    }

    private func prioritizedHandles(from user: UserProfile) -> [HandleTarget] {
        var targets: [HandleTarget] = []

        if let preferredHandle,
           let matchingFriend = user.friends.first(where: { $0.handle.caseInsensitiveCompare(preferredHandle) == .orderedSame }) {
            targets.append(HandleTarget(handle: matchingFriend.handle, label: matchingFriend.displayName, isPrimary: false))
        }

        if let preferredHandle,
           let primaryHandle = user.primaryHandle,
           preferredHandle.caseInsensitiveCompare(primaryHandle) == .orderedSame {
            targets.append(HandleTarget(handle: primaryHandle, label: "Primary", isPrimary: true))
        }

        if let primaryHandle = user.primaryHandle,
           !targets.contains(where: { $0.handle.caseInsensitiveCompare(primaryHandle) == .orderedSame }) {
            targets.append(HandleTarget(handle: primaryHandle, label: "Primary", isPrimary: true))
        }

        for friend in user.friends {
            if !targets.contains(where: { $0.handle.caseInsensitiveCompare(friend.handle) == .orderedSame }) {
                targets.append(HandleTarget(handle: friend.handle, label: friend.displayName, isPrimary: false))
            }
        }

        return targets
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s@._-]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
