//
//  AcuteIrritationService.swift
//  dermadream
//
//  Sends an acute-irritation analysis request to Gemini
//  (gemini-3-flash-preview) over plain URLSession with the API key
//  read from Info.plist via APIConfig.
//
//  Inputs:
//   - `AcuteIrritationContext`  — what the user reported on the
//     symptom map (regions, type, symptoms, severity).
//   - `AcuteIrritationRequestSnapshot` — the user's current routine
//     and recent product history at the time the analysis is run.
//
//  Output:
//   - `AcuteIrritationReport` — Routine Safety Score, symptom
//     correlations, the top offender, flagged ingredients, and
//     suspected products. Drives the Irritation Report screen.
//

import Foundation

// MARK: - Public result models

/// Top-level Gemini response. Schema matches `AcuteIrritationService.responseSchema()`.
struct AcuteIrritationReport: Codable, Equatable, Hashable {
    let routineSafetyScore: Int
    let symptomCorrelations: [SymptomCorrelation]
    let topOffender: TopOffender?
    let flaggedIngredients: [FlaggedIngredient]
    let suspectedProducts: [SuspectedProduct]
    let summary: String

    enum CodingKeys: String, CodingKey {
        case routineSafetyScore = "routine_safety_score"
        case symptomCorrelations = "symptom_correlations"
        case topOffender = "top_offender"
        case flaggedIngredients = "flagged_ingredients"
        case suspectedProducts = "suspected_products"
        case summary
    }
}

/// "Redness" → 78%. Drives the small radar chart in the report.
struct SymptomCorrelation: Codable, Equatable, Hashable, Identifiable {
    var id: String { symptom }
    let symptom: String
    let matchPercent: Int

    enum CodingKeys: String, CodingKey {
        case symptom
        case matchPercent = "match_percent"
    }
}

/// The single ingredient that shows up in the most flagged products.
struct TopOffender: Codable, Equatable, Hashable {
    let ingredient: String
    let occurrences: Int
    let reason: String
}

/// One row in the High-Risk Ingredients list.
struct FlaggedIngredient: Codable, Equatable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let irritationProbability: Int
    let reason: String
    /// Product names containing this ingredient.
    let foundIn: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case irritationProbability = "irritation_probability"
        case reason
        case foundIn = "found_in"
    }
}

/// One row in the Suspected Products list.
struct SuspectedProduct: Codable, Equatable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let irritationProbability: Int
    /// Tags pulled from the top-offender / flagged-ingredient lists.
    let flaggedTags: [String]
    /// Best-guess category so the heatmap can render the right icon.
    let category: String?

    enum CodingKeys: String, CodingKey {
        case name
        case irritationProbability = "irritation_probability"
        case flaggedTags = "flagged_tags"
        case category
    }
}

// MARK: - Request snapshot

/// What the engine knew about the user at the moment they tapped
/// "Acute Irritation". Captured up-front so the actor hop into the
/// service doesn't reach back into main-actor state.
struct AcuteIrritationRequestSnapshot: Sendable {
    let currentRoutine: [RoutineEntry]
    let archivedRoutine: [RoutineEntry]
    let knownAllergens: [String]
    let baseline: BaselineSkinState
}

// MARK: - Errors

enum AcuteIrritationError: LocalizedError {
    case invalidURL
    case missingAPIKey(String)
    case http(status: Int, body: String)
    case missingCandidate
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not build a valid Gemini API URL."
        case .missingAPIKey(let detail): return "Gemini API key is not configured. \(detail)"
        case .http(let status, let body): return "Gemini HTTP error \(status). \(body)"
        case .missingCandidate: return "Gemini response contained no candidates."
        case .decoding(let detail): return "Failed to decode Gemini response: \(detail)"
        case .transport(let detail): return "Network error: \(detail)"
        }
    }
}

// MARK: - Service

final class AcuteIrritationService {
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

    // MARK: Public

    func analyze(
        context: AcuteIrritationContext,
        snapshot: AcuteIrritationRequestSnapshot,
        userId: String
    ) async throws -> AcuteIrritationReport {
        // Pull the persisted reaction history for this user. The remote
        // bridge / mock DB returns whatever has been logged via the
        // Routine flow, including suspect-product entries from this
        // very session.
        let userRecord = try? await database.findUserRecord(userId: userId)

        let reports = context.tickets.map { ticket in
            AcuteIrritationConcern(
                regions: ticket.regions.map(\.displayTitle),
                type: ticket.irritationType.rawValue,
                visualSymptoms: ticket.visualSymptoms.map(\.rawValue),
                nonVisualSymptoms: ticket.nonVisualSymptoms.map(\.rawValue),
                severity: ticket.severity,
                summary: ticket.concernHeadline
            )
        }

        let payload = AcuteIrritationPromptPayload(
            irritationReports: reports,
            userBaseline: snapshot.baseline.rawValue,
            knownAllergens: snapshot.knownAllergens,
            currentRoutine: snapshot.currentRoutine.map(Self.routineDTO),
            archivedRoutine: snapshot.archivedRoutine.map(Self.routineDTO),
            reactionHistory: unifiedReactionHistory(from: userRecord)
        )

        let jsonString = try Self.encodeToJSONString(payload)
        let userText = """
        Analyze the following skincare irritation report and respond ONLY \
        with JSON matching the response schema:

        \(jsonString)
        """

        let body = GeminiGenerateRequest(
            systemInstruction: .init(parts: [.init(text: Self.systemInstruction)]),
            contents: [.init(role: "user", parts: [.init(text: userText)])],
            generationConfig: .init(
                responseMimeType: "application/json",
                responseSchema: Self.responseSchema()
            )
        )

        let url = try buildURL()
        let request = try Self.buildURLRequest(url: url, body: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AcuteIrritationError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AcuteIrritationError.transport("Response was not an HTTP response.")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw AcuteIrritationError.http(status: http.statusCode, body: body)
        }

        return try Self.decodeReport(from: data)
    }

    // MARK: - Decoding

    private static func decodeReport(from data: Data) throws -> AcuteIrritationReport {
        let decoder = JSONDecoder()
        let envelope: GeminiGenerateResponse
        do {
            envelope = try decoder.decode(GeminiGenerateResponse.self, from: data)
        } catch {
            throw AcuteIrritationError.decoding(error.localizedDescription)
        }
        guard
            let candidate = envelope.candidates?.first,
            let text = candidate.content.parts.first?.text,
            let textData = text.data(using: .utf8)
        else {
            throw AcuteIrritationError.missingCandidate
        }
        do {
            return try decoder.decode(AcuteIrritationReport.self, from: textData)
        } catch {
            throw AcuteIrritationError.decoding(
                "AcuteIrritationReport JSON did not match schema: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - URL + request

    private func buildURL() throws -> URL {
        let apiKey: String
        do {
            apiKey = try APIConfig.apiKeyThrowing()
        } catch {
            throw AcuteIrritationError.missingAPIKey(error.localizedDescription)
        }

        var components = URLComponents(string: "\(baseURL)/\(modelName):generateContent")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else {
            throw AcuteIrritationError.invalidURL
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
            throw AcuteIrritationError.decoding("Could not encode request body: \(error.localizedDescription)")
        }
        return request
    }

    // MARK: - DTO helpers

    private static func routineDTO(_ entry: RoutineEntry) -> AcuteIrritationRoutineDTO {
        let df = DateFormatter()
        df.dateStyle = .medium
        return AcuteIrritationRoutineDTO(
            product: combinedProductLabel(brand: entry.brand, name: entry.productName),
            slot: entry.slot.rawValue,
            status: entry.status.rawValue,
            startDate: entry.startDate.map { df.string(from: $0) },
            endDate: entry.endDate.map { df.string(from: $0) },
            usageFrequency: entry.usageFrequency?.rawValue
        )
    }

    private static func historyDTO(_ record: ProductReactionRecord) -> AcuteIrritationReactionDTO {
        AcuteIrritationReactionDTO(
            product: combinedProductLabel(brand: record.productBrand, name: record.productName),
            reactionType: record.reactionType,
            details: record.details
        )
    }

    private static func normalizedProductKey(brand: String, name: String) -> String {
        combinedProductLabel(brand: brand, name: name)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func unifiedReactionHistory(from userRecord: UserRecord?) -> [AcuteIrritationReactionDTO] {
        guard let userRecord else { return [] }
        let groupedLegacy = Dictionary(grouping: userRecord.history) {
            Self.normalizedProductKey(brand: $0.productBrand, name: $0.productName)
        }

        var seen = Set<String>()
        var merged: [AcuteIrritationReactionDTO] = userRecord.routineLog.map { entry in
            let key = Self.normalizedProductKey(brand: entry.brand, name: entry.productName)
            seen.insert(key)
            let legacy = groupedLegacy[key] ?? []
            let reactionType = legacy.last?.reactionType
                ?? (entry.status == .current ? "Routine Log" : "Past Routine")
            let details = legacy.last?.details ?? "Status: \(entry.status.rawValue)."
            return AcuteIrritationReactionDTO(
                product: Self.combinedProductLabel(brand: entry.brand, name: entry.productName),
                reactionType: reactionType,
                details: details
            )
        }

        for legacy in userRecord.history {
            let key = Self.normalizedProductKey(brand: legacy.productBrand, name: legacy.productName)
            guard !seen.contains(key) else { continue }
            merged.append(Self.historyDTO(legacy))
        }

        return merged
    }

    private static func combinedProductLabel(brand: String, name: String) -> String {
        let b = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if b.isEmpty { return n }
        if n.isEmpty { return b }
        return "\(b) \(n)"
    }

    private static func encodeToJSONString<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            let data = try encoder.encode(value)
            guard let string = String(data: data, encoding: .utf8) else {
                throw AcuteIrritationError.decoding("Unable to UTF-8 encode request payload.")
            }
            return string
        } catch {
            throw AcuteIrritationError.decoding(error.localizedDescription)
        }
    }

    // MARK: - Prompt + schema

    private static let systemInstruction = """
    You are a professional Cosmetic Ingredient Analyst. Use your internal \
    knowledge to identify ingredient lists for the listed skincare products. \
    Cross-reference current routine + history against the user's reported \
    irritation. The `irritation_reports` field may list one or more distinct \
    symptom maps (separate body areas, symptoms, and severities) — consider \
    all of them as part of the same acute episode. Your tasks:

      1. Compute a 0-100 Routine Safety Score (higher = safer).
      2. For each user-reported symptom, estimate a 0-100 percentage match \
         between known side-effects of the routine ingredients and that symptom.
      3. Identify the single Top Offender — the ingredient appearing across \
         the most products that is plausibly responsible for the irritation.
      4. Produce a list of Flagged Ingredients sorted by Irritation \
         Probability (highest first), each with the reason and which routine \
         products contain it.
      5. Produce a list of Suspected Products sorted by Irritation \
         Probability, each with tags pulled from the Top Offender and \
         Flagged Ingredients lists, plus a best-guess product category \
         (Cleanser, Toner, Serum, Moisturizer, SPF, or Other).
      6. Add a 2-3 sentence plain-language summary.

    Output ONLY valid JSON conforming to the response schema.
    """

    private static func responseSchema() -> GeminiSchema {
        GeminiSchema(
            type: "OBJECT",
            properties: [
                "routine_safety_score": GeminiSchema(
                    type: "INTEGER",
                    description: "0-100 safety score for the user's current routine in light of their symptoms."
                ),
                "symptom_correlations": GeminiSchema(
                    type: "ARRAY",
                    description: "One entry per reported symptom (Redness, Burning, etc).",
                    items: GeminiSchema(
                        type: "OBJECT",
                        properties: [
                            "symptom": GeminiSchema(type: "STRING"),
                            "match_percent": GeminiSchema(
                                type: "INTEGER",
                                description: "0-100 likelihood the symptom is explained by the current ingredients."
                            )
                        ],
                        required: ["symptom", "match_percent"]
                    )
                ),
                "top_offender": GeminiSchema(
                    type: "OBJECT",
                    properties: [
                        "ingredient": GeminiSchema(type: "STRING"),
                        "occurrences": GeminiSchema(
                            type: "INTEGER",
                            description: "How many of the user's products contain this ingredient."
                        ),
                        "reason": GeminiSchema(
                            type: "STRING",
                            description: "Why this ingredient is the prime suspect."
                        )
                    ],
                    required: ["ingredient", "occurrences", "reason"]
                ),
                "flagged_ingredients": GeminiSchema(
                    type: "ARRAY",
                    items: GeminiSchema(
                        type: "OBJECT",
                        properties: [
                            "name": GeminiSchema(type: "STRING"),
                            "irritation_probability": GeminiSchema(
                                type: "INTEGER",
                                description: "0-100 probability this specific ingredient is contributing."
                            ),
                            "reason": GeminiSchema(type: "STRING"),
                            "found_in": GeminiSchema(
                                type: "ARRAY",
                                items: GeminiSchema(type: "STRING")
                            )
                        ],
                        required: ["name", "irritation_probability", "reason", "found_in"]
                    )
                ),
                "suspected_products": GeminiSchema(
                    type: "ARRAY",
                    items: GeminiSchema(
                        type: "OBJECT",
                        properties: [
                            "name": GeminiSchema(type: "STRING"),
                            "irritation_probability": GeminiSchema(
                                type: "INTEGER",
                                description: "0-100 probability this product is responsible for the flare."
                            ),
                            "flagged_tags": GeminiSchema(
                                type: "ARRAY",
                                description: "Tags pulled from the top-offender or flagged-ingredient lists.",
                                items: GeminiSchema(type: "STRING")
                            ),
                            "category": GeminiSchema(
                                type: "STRING",
                                description: "Cleanser | Toner | Serum | Moisturizer | SPF | Other.",
                                enumValues: ["Cleanser", "Toner", "Serum", "Moisturizer", "SPF", "Other"]
                            )
                        ],
                        required: ["name", "irritation_probability", "flagged_tags"]
                    )
                ),
                "summary": GeminiSchema(
                    type: "STRING",
                    description: "Short plain-language explanation of what is likely happening and what to try next."
                )
            ],
            required: [
                "routine_safety_score",
                "symptom_correlations",
                "flagged_ingredients",
                "suspected_products",
                "summary"
            ]
        )
    }
}

// MARK: - Codable request payload

private struct AcuteIrritationPromptPayload: Codable {
    let irritationReports: [AcuteIrritationConcern]
    let userBaseline: String
    let knownAllergens: [String]
    let currentRoutine: [AcuteIrritationRoutineDTO]
    let archivedRoutine: [AcuteIrritationRoutineDTO]
    let reactionHistory: [AcuteIrritationReactionDTO]

    enum CodingKeys: String, CodingKey {
        case irritationReports = "irritation_reports"
        case userBaseline = "user_baseline"
        case knownAllergens = "known_allergens"
        case currentRoutine = "current_routine"
        case archivedRoutine = "archived_routine"
        case reactionHistory = "reaction_history"
    }
}

private struct AcuteIrritationConcern: Codable {
    let regions: [String]
    let type: String
    let visualSymptoms: [String]
    let nonVisualSymptoms: [String]
    let severity: Int
    let summary: String

    enum CodingKeys: String, CodingKey {
        case regions
        case type
        case visualSymptoms = "visual_symptoms"
        case nonVisualSymptoms = "non_visual_symptoms"
        case severity
        case summary
    }
}

private struct AcuteIrritationRoutineDTO: Codable {
    let product: String
    let slot: String
    let status: String
    let startDate: String?
    let endDate: String?
    let usageFrequency: String?

    enum CodingKeys: String, CodingKey {
        case product
        case slot
        case status
        case startDate = "start_date"
        case endDate = "end_date"
        case usageFrequency = "usage_frequency"
    }
}

private struct AcuteIrritationReactionDTO: Codable {
    let product: String
    let reactionType: String
    let details: String

    enum CodingKeys: String, CodingKey {
        case product
        case reactionType = "reaction_type"
        case details
    }
}

// MARK: - Reused Gemini wire types

/// Re-uses the shared `GeminiSchema` defined in TargetProductAnalysisService.swift.
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

private struct GeminiGenerateResponse: Codable {
    let candidates: [GeminiResponseCandidate]?
}

private struct GeminiResponseCandidate: Codable {
    let content: GeminiResponseContent
}

private struct GeminiResponseContent: Codable {
    let parts: [GeminiTextPart]
}
