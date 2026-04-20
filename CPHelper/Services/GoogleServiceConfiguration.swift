import Foundation

enum GoogleServiceConfiguration {
    static func geminiAPIKey() -> String? {
        let environmentKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let environmentKey, !environmentKey.isEmpty {
            return environmentKey
        }

        return localSecretsValue(forKey: "GEMINI_API_KEY")
            ?? value(forKey: "GEMINI_API_KEY")
            ?? value(forKey: "API_KEY")
    }

    static func value(forKey key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ),
              let dictionary = object as? [String: Any],
              let value = dictionary[key] as? String else {
            return nil
        }

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func localSecretsValue(forKey key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "LocalSecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ),
              let dictionary = object as? [String: Any],
              let value = dictionary[key] as? String else {
            return nil
        }

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
