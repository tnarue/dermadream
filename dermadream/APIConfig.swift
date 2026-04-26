//
//  APIConfig.swift
//  dermadream
//
//  Reads build-time secrets (e.g. GEMINI_API_KEY) from the app's Info.plist,
//  which is populated from Config.xcconfig. The key is never hardcoded.
//
//  Setup:
//  1. In Config.xcconfig:
//         GEMINI_API_KEY = your_actual_key_here
//  2. In the app target's Info.plist, add:
//         <key>GEMINI_API_KEY</key>
//         <string>$(GEMINI_API_KEY)</string>
//  3. Make sure Config.xcconfig is listed in the target's "Configurations".
//

import Foundation

enum APIConfig {
    enum ConfigError: LocalizedError {
        case missingKey(String)
        case emptyKey(String)

        var errorDescription: String? {
            switch self {
            case .missingKey(let key):
                return "Missing required key \"\(key)\" in Info.plist. Check your Config.xcconfig."
            case .emptyKey(let key):
                return "Info.plist key \"\(key)\" is present but empty. Check your Config.xcconfig."
            }
        }
    }

    /// The Gemini API key, sourced from `Config.xcconfig` via `Info.plist`.
    /// Crashes at launch-time if missing so misconfiguration is caught early
    /// in development rather than silently leaking empty keys to the network.
    static var apiKey: String {
        do {
            return try value(forKey: "GEMINI_API_KEY")
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    /// Non-fatal variant that returns a typed error instead of trapping.
    static func apiKeyThrowing() throws -> String {
        try value(forKey: "GEMINI_API_KEY")
    }

    /// Throwing accessor for the Barcode Lookup API key.
    static func barcodeLookupAPIKeyThrowing() throws -> String {
        try value(forKey: "BARCODELOOKUP_API_KEY")
    }

    /// The Gemini API base URL (without model suffix).
    static var geminiBaseURL: String {
        do {
            return try geminiBaseURLThrowing()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    static func geminiBaseURLThrowing() throws -> String {
        try value(forKey: "GEMINI_BASE_URL")
    }

    /// The Barcode Lookup API base URL.
    static var barcodeLookupBaseURL: String {
        do {
            return try barcodeLookupBaseURLThrowing()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    static func barcodeLookupBaseURLThrowing() throws -> String {
        try value(forKey: "BARCODELOOKUP_BASE_URL")
    }

    /// Throwing accessor for the base URL of the MongoDB HTTP bridge
    /// hosting the `user_records` collection. For physical-device runs
    /// this MUST be your Mac's LAN IP (e.g. `http://192.168.1.12:3000`).
    static func userRecordsBaseURLThrowing() throws -> String {
        try value(forKey: "USER_RECORDS_BASE_URL")
    }

    // MARK: - Internals

    private static func value(forKey key: String) throws -> String {
        guard let string = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            throw ConfigError.missingKey(key)
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("$("),
              !trimmed.hasPrefix("YOUR_"),
              trimmed != "YOUR_API_KEY"
        else {
            throw ConfigError.emptyKey(key)
        }

        return trimmed
    }
}
