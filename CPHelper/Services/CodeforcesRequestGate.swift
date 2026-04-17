import Foundation

actor CodeforcesRequestGate {
    static let shared = CodeforcesRequestGate()

    private let minimumDelay: TimeInterval = 2.15
    private var lastRequestTime: Date?

    func waitIfNeeded() async throws {
        if let lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastRequestTime)
            if elapsed < minimumDelay {
                let sleepNanoseconds = UInt64((minimumDelay - elapsed) * 1_000_000_000)
                try await Task.sleep(nanoseconds: sleepNanoseconds)
            }
        }

        lastRequestTime = Date()
    }
}
