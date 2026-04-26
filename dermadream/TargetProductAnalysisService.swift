//
//  TargetProductAnalysisService.swift
//  dermadream
//
//  Sends a target product + the user's reaction history to Gemini
//  (gemini-3-flash-preview) over plain URLSession using an API key read
//  from Info.plist via APIConfig. Returns a strongly-typed AnalysisResult.
//

import Foundation

// MARK: - Public result

struct AnalysisResult: Codable, Equatable, Hashable {
    let irritationScorePercentage: Int
    let riskLevel: String
    let concerningIngredients: [ConcerningIngredient]
    let summaryAnalysis: String

    enum CodingKeys: String, CodingKey {
        case irritationScorePercentage = "irritation_score_percentage"
        case riskLevel = "risk_level"
        case concerningIngredients = "concerning_ingredients"
        case summaryAnalysis = "summary_analysis"
    }
}

struct ConcerningIngredient: Codable, Equatable, Hashable, Identifiable {
    var id: String { ingredientName }
    let ingredientName: String
    let reason: String
    let irritationContributionPercentage: Int

    enum CodingKeys: String, CodingKey {
        case ingredientName = "ingredient_name"
        case reason
        case irritationContributionPercentage = "irritation_contribution_percentage"
    }
}

// MARK: - Service errors

enum TargetProductAnalysisError: LocalizedError {
    case invalidURL
    case missingAPIKey(String)
    case http(status: Int, body: String)
    case missingCandidate
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build a valid Gemini API URL."
        case .missingAPIKey(let detail):
            return "Gemini API key is not configured. \(detail)"
        case .http(let status, let body):
            return "Gemini HTTP error \(status). \(body)"
        case .missingCandidate:
            return "Gemini response contained no candidates."
        case .decoding(let detail):
            return "Failed to decode Gemini response: \(detail)"
        case .transport(let detail):
            return "Network error: \(detail)"
        }
    }
}

// MARK: - Service

final class TargetProductAnalysisService {
    private let session: URLSession
    private let database: UserRecordsProviding
    private let modelName: String
    private let baseURL: String

    init(
        session: URLSession = .shared,
        database: UserRecordsProviding = UserRecordsService.current,
        modelName: String = "gemini-3-flash-preview",
        baseURL: String = APIConfig.geminiBaseURL
    ) {
        self.session = session
        self.database = database
        self.modelName = modelName
        self.baseURL = baseURL
    }

    // MARK: Public entry point

    func analyzeProduct(userId: String, targetProductName: String) async throws -> AnalysisResult {
        let userRecord = try await database.findUserRecord(userId: userId)

        let mappedHistory = Self.unifiedHistory(for: userRecord)

        let userPayload = GeminiUserPayload(
            targetProduct: targetProductName,
            userHistory: mappedHistory
        )

        let jsonString = try Self.encodeToJSONString(userPayload)
        let userText = "Analyze this skin profile: \n\n" + jsonString

        let requestBody = GeminiGenerateRequest(
            systemInstruction: .init(
                parts: [.init(text: Self.systemInstruction)]
            ),
            contents: [
                .init(role: "user", parts: [.init(text: userText)])
            ],
            generationConfig: .init(
                responseMimeType: "application/json",
                responseSchema: Self.responseSchema()
            )
        )

        let url = try buildURL()
        let request = try Self.buildURLRequest(url: url, body: requestBody)

        let (data, response) = try await performRequest(request)

        guard let http = response as? HTTPURLResponse else {
            throw TargetProductAnalysisError.transport("Response was not an HTTP response.")
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw TargetProductAnalysisError.http(status: http.statusCode, body: body)
        }

        return try Self.decodeAnalysis(from: data)
    }

    // MARK: - Networking

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw TargetProductAnalysisError.transport(error.localizedDescription)
        }
    }

    private func buildURL() throws -> URL {
        let apiKey: String
        do {
            apiKey = try APIConfig.apiKeyThrowing()
        } catch {
            throw TargetProductAnalysisError.missingAPIKey(error.localizedDescription)
        }

        var components = URLComponents(string: "\(baseURL)/\(modelName):generateContent")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components?.url else {
            throw TargetProductAnalysisError.invalidURL
        }
        return url
    }

    private static func buildURLRequest(
        url: URL,
        body: GeminiGenerateRequest
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw TargetProductAnalysisError.decoding(
                "Could not encode request body: \(error.localizedDescription)"
            )
        }

        return request
    }

    // MARK: - Decoding

    private static func decodeAnalysis(from data: Data) throws -> AnalysisResult {
        let decoder = JSONDecoder()

        let response: GeminiGenerateResponse
        do {
            response = try decoder.decode(GeminiGenerateResponse.self, from: data)
        } catch {
            throw TargetProductAnalysisError.decoding(error.localizedDescription)
        }

        guard
            let candidate = response.candidates?.first,
            let text = candidate.content.parts.first?.text
        else {
            throw TargetProductAnalysisError.missingCandidate
        }

        guard let analysisData = text.data(using: .utf8) else {
            throw TargetProductAnalysisError.decoding("Candidate text was not valid UTF-8.")
        }

        do {
            return try decoder.decode(AnalysisResult.self, from: analysisData)
        } catch {
            throw TargetProductAnalysisError.decoding(
                "AnalysisResult JSON did not match schema: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Helpers

    private static func combinedProductLabel(brand: String, name: String) -> String {
        let b = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if b.isEmpty { return n }
        if n.isEmpty { return b }
        return "\(b) \(n)"
    }

    private static func normalizedProductKey(brand: String, name: String) -> String {
        combinedProductLabel(brand: brand, name: name)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Uses `routineLog` as the primary product history source, then folds
    /// legacy reaction-only rows so analysis is driven by one unified list.
    private static func unifiedHistory(for userRecord: UserRecord) -> [GeminiHistoryItem] {
        let groupedLegacy = Dictionary(grouping: userRecord.history) {
            normalizedProductKey(brand: $0.productBrand, name: $0.productName)
        }

        var seen = Set<String>()
        var merged: [GeminiHistoryItem] = userRecord.routineLog.map { entry in
            let key = normalizedProductKey(brand: entry.brand, name: entry.productName)
            seen.insert(key)
            let legacy = groupedLegacy[key] ?? []
            let latestReaction = legacy.last
            let reactionType = latestReaction?.reactionType
                ?? (entry.status == .current ? "Routine Log" : "Past Routine")

            var detailBits: [String] = ["Status: \(entry.status.rawValue)."]
            if let start = entry.startDate {
                let df = DateFormatter()
                df.dateStyle = .medium
                detailBits.append("Started \(df.string(from: start)).")
            }
            if let end = entry.endDate, entry.status == .stopped {
                let df = DateFormatter()
                df.dateStyle = .medium
                detailBits.append("Stopped \(df.string(from: end)).")
            }
            if let freq = entry.usageFrequency {
                detailBits.append("Usage: \(freq.rawValue).")
            }
            if let legacyDetails = latestReaction?.details, !legacyDetails.isEmpty {
                detailBits.append("Reaction notes: \(legacyDetails)")
            }

            return GeminiHistoryItem(
                product: combinedProductLabel(brand: entry.brand, name: entry.productName),
                reactionType: reactionType,
                details: detailBits.joined(separator: " ")
            )
        }

        // Keep any legacy rows not represented in routineLog for backward-compat.
        for legacy in userRecord.history {
            let key = normalizedProductKey(brand: legacy.productBrand, name: legacy.productName)
            guard !seen.contains(key) else { continue }
            merged.append(
                GeminiHistoryItem(
                    product: combinedProductLabel(brand: legacy.productBrand, name: legacy.productName),
                    reactionType: legacy.reactionType,
                    details: legacy.details
                )
            )
        }

        return merged
    }

    private static func encodeToJSONString<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            let data = try encoder.encode(value)
            guard let string = String(data: data, encoding: .utf8) else {
                throw TargetProductAnalysisError.decoding("Unable to UTF-8 encode request payload.")
            }
            return string
        } catch {
            throw TargetProductAnalysisError.decoding(error.localizedDescription)
        }
    }

    // MARK: - Prompt + schema

    private static let systemInstruction = """
    You are a professional Cosmetic Ingredient Analyst. Use your internal \
    knowledge to identify the ingredient lists for the provided products. \
    Cross-reference the 'target_product' against the 'user_history'. \
    Identify shared irritants, specifically focusing on ingredients that \
    caused 'burning' or 'redness' in the past. Output ONLY valid JSON.
    """

    private static func responseSchema() -> GeminiSchema {
        GeminiSchema(
            type: "OBJECT",
            properties: [
                "irritation_score_percentage": GeminiSchema(
                    type: "INTEGER",
                    description: "Overall irritation likelihood for this user, 0-100."
                ),
                "risk_level": GeminiSchema(
                    type: "STRING",
                    description: "Categorical risk bucket.",
                    enumValues: ["low", "moderate", "high"]
                ),
                "concerning_ingredients": GeminiSchema(
                    type: "ARRAY",
                    items: GeminiSchema(
                        type: "OBJECT",
                        properties: [
                            "ingredient_name": GeminiSchema(type: "STRING"),
                            "reason": GeminiSchema(
                                type: "STRING",
                                description: "Why this ingredient is risky for THIS user, referencing their history."
                            ),
                            "irritation_contribution_percentage": GeminiSchema(
                                type: "INTEGER",
                                description: "This ingredient's contribution to the overall score, 0-100."
                            )
                        ],
                        required: ["ingredient_name", "reason", "irritation_contribution_percentage"]
                    )
                ),
                "summary_analysis": GeminiSchema(
                    type: "STRING",
                    description: "2-3 sentence plain-language recommendation."
                )
            ],
            required: [
                "irritation_score_percentage",
                "risk_level",
                "concerning_ingredients",
                "summary_analysis"
            ]
        )
    }
}

// MARK: - Codable request models

private struct GeminiGenerateRequest: Codable {
    let systemInstruction: SystemInstruction
    let contents: [GeminiRequestContent]
    let generationConfig: GenerationConfig

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
        case generationConfig = "generation_config"
    }

    struct SystemInstruction: Codable {
        let parts: [GeminiTextPart]
    }

    struct GenerationConfig: Codable {
        let responseMimeType: String
        let responseSchema: GeminiSchema

        enum CodingKeys: String, CodingKey {
            case responseMimeType = "response_mime_type"
            case responseSchema = "response_schema"
        }
    }
}

private struct GeminiRequestContent: Codable {
    let role: String
    let parts: [GeminiTextPart]
}

// MARK: - Codable schema (response_schema shape)

/// Minimal Gemini schema node. Unused fields encode as nil and are omitted.
/// Modeled as a `final class` (reference type) because the schema is
/// recursive — `properties` and `items` can contain nested `GeminiSchema`
/// nodes, which would give a value type infinite size.
final class GeminiSchema: Codable {
    let type: String
    let description: String?
    let properties: [String: GeminiSchema]?
    let items: GeminiSchema?
    let required: [String]?
    let enumValues: [String]?

    init(
        type: String,
        description: String? = nil,
        properties: [String: GeminiSchema]? = nil,
        items: GeminiSchema? = nil,
        required: [String]? = nil,
        enumValues: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.properties = properties
        self.items = items
        self.required = required
        self.enumValues = enumValues
    }

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case properties
        case items
        case required
        case enumValues = "enum"
    }
}

// MARK: - Codable user payload (serialised into the user part)

private struct GeminiUserPayload: Codable {
    let targetProduct: String
    let userHistory: [GeminiHistoryItem]

    enum CodingKeys: String, CodingKey {
        case targetProduct = "target_product"
        case userHistory = "user_history"
    }
}

private struct GeminiHistoryItem: Codable {
    let product: String
    let reactionType: String
    let details: String

    enum CodingKeys: String, CodingKey {
        case product
        case reactionType = "reaction_type"
        case details
    }
}

// MARK: - Codable response models

private struct GeminiGenerateResponse: Codable {
    let candidates: [GeminiResponseCandidate]?
}

private struct GeminiResponseCandidate: Codable {
    let content: GeminiResponseContent
}

private struct GeminiResponseContent: Codable {
    let parts: [GeminiTextPart]
}
