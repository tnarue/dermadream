//
//  GeminiService.swift
//  dermadream
//

import Foundation
import FirebaseFunctions

// MARK: - Gemini JSON Schema (Codable)

/// A single text part within a Gemini content message.
struct GeminiTextPart: Codable {
    let text: String
}

/// Base64-encoded inline image data for the Gemini vision endpoint.
struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

/// One part in a Gemini content message — either text or inline image data.
struct GeminiPart: Codable {
    var text: String?
    var inlineData: GeminiInlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }

    static func textPart(_ text: String) -> GeminiPart {
        GeminiPart(text: text, inlineData: nil)
    }

    static func imagePart(mimeType: String, base64: String) -> GeminiPart {
        GeminiPart(text: nil, inlineData: GeminiInlineData(mimeType: mimeType, data: base64))
    }
}

/// A single message in the Gemini conversation (role + parts).
struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

/// Top-level request body sent to the Cloud Function.
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
}

// MARK: - Gemini Response Schema

struct GeminiCandidate: Codable {
    let content: GeminiContent
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
    let error: GeminiErrorPayload?

    /// Extracts the first text response from the model, if available.
    var firstTextResponse: String? {
        candidates?
            .first?
            .content
            .parts
            .compactMap(\.text)
            .joined(separator: "\n")
    }
}

struct GeminiErrorPayload: Codable {
    let message: String?
    let code: Int?
}

// MARK: - Service Errors

enum GeminiServiceError: LocalizedError {
    case emptyResponse
    case apiError(String)
    case decodingFailed(String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Dermadream received an empty response. Please try again."
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingFailed(let detail):
            return "Could not read the response: \(detail)"
        case .networkUnavailable:
            return "No network connection. Check your internet and try again."
        }
    }
}

// MARK: - Service

final class GeminiService {
    private let functions: Functions

    init(region: String = "us-central1") {
        self.functions = Functions.functions(region: region)
    }

    // MARK: - Product Analysis

    /// Sends a product lookup (name/brand or barcode) plus the user's skin
    /// profile to Gemini and returns a structured `GeminiProductAnalysis`.
    func analyzeProduct(
        lookup: ProductLookupMethod,
        userContext: String,
        functionName: String = "geminiChat"
    ) async throws -> GeminiProductAnalysis {
        let prompt = Self.buildAnalysisPrompt(lookup: lookup, userContext: userContext)
        let contents: [GeminiContent] = [
            GeminiContent(role: "user", parts: [.textPart(prompt)])
        ]

        let rawJSON = try await sendChat(contents: contents, functionName: functionName)

        let sanitised = rawJSON
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = sanitised.data(using: .utf8) else {
            throw GeminiServiceError.decodingFailed("Response was not valid UTF-8 text.")
        }

        do {
            return try JSONDecoder().decode(GeminiProductAnalysis.self, from: data)
        } catch {
            throw GeminiServiceError.decodingFailed(
                "Gemini returned text that could not be parsed as a product analysis: \(error.localizedDescription)"
            )
        }
    }

    private static func buildAnalysisPrompt(lookup: ProductLookupMethod, userContext: String) -> String {
        let productIdentifier: String
        switch lookup {
        case .nameAndBrand(let name, let brand):
            productIdentifier = brand.isEmpty
                ? "Product name: \"\(name)\""
                : "Product: \"\(name)\" by \"\(brand)\""
        case .barcode(let code):
            productIdentifier = "Product barcode (EAN/UPC): \(code)"
        }

        return """
        You are Dermadream AI, a dermatology-focused ingredient safety analyst.

        \(userContext)

        The user wants to check the safety of a skincare / cosmetic product.
        \(productIdentifier)

        Identify the product and its full INCI ingredient list. Cross-reference \
        every ingredient against the user's known allergens, skin baseline, \
        symptom history, and current routine products. For each ingredient that \
        poses any irritation risk, explain why it is risky for THIS specific user.

        Return ONLY valid JSON (no markdown, no commentary) in exactly this schema:
        {
          "product_name": "<resolved product name>",
          "brand": "<brand>",
          "overall_risk_percent": <0-100>,
          "irritants": [
            {
              "name": "<INCI ingredient name>",
              "reason": "<1-2 sentence explanation of why this ingredient is risky for the user>",
              "risk_percent": <0-100>
            }
          ],
          "summary": "<2-3 sentence overall assessment and recommendation>"
        }

        Rules:
        - overall_risk_percent reflects the combined irritation risk for this user.
        - Only include ingredients that actually pose a risk; safe ingredients are omitted.
        - Each irritant's risk_percent is its individual contribution likelihood.
        - If you cannot identify the product, set overall_risk_percent to 0, \
          irritants to an empty array, and explain in the summary.
        """
    }

    // MARK: - Chat

    /// Sends a Gemini-formatted conversation to the Firebase Cloud Function
    /// and returns the model's text reply.
    ///
    /// The Cloud Function name defaults to `"geminiChat"`. Adjust if your
    /// deployed function uses a different identifier.
    func sendChat(
        contents: [GeminiContent],
        functionName: String = "geminiChat"
    ) async throws -> String {
        let request = GeminiRequest(contents: contents)

        let encoded: Any
        do {
            let jsonData = try JSONEncoder().encode(request)
            encoded = try JSONSerialization.jsonObject(with: jsonData)
        } catch {
            throw GeminiServiceError.decodingFailed("Failed to encode request: \(error.localizedDescription)")
        }

        let result: HTTPSCallableResult
        do {
            let callable = functions.httpsCallable(functionName)
            result = try await callable.call(encoded)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                throw GeminiServiceError.networkUnavailable
            }
            throw GeminiServiceError.apiError(error.localizedDescription)
        }

        let responseData: Any = result.data
        guard JSONSerialization.isValidJSONObject(responseData) else {
            throw GeminiServiceError.emptyResponse
        }

        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: responseData)
        } catch {
            throw GeminiServiceError.decodingFailed("Response is not valid JSON: \(error.localizedDescription)")
        }

        let geminiResponse: GeminiResponse
        do {
            geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: jsonData)
        } catch {
            throw GeminiServiceError.decodingFailed(error.localizedDescription)
        }

        if let apiErr = geminiResponse.error {
            throw GeminiServiceError.apiError(apiErr.message ?? "Unknown API error (code \(apiErr.code ?? -1))")
        }

        guard let text = geminiResponse.firstTextResponse, !text.isEmpty else {
            throw GeminiServiceError.emptyResponse
        }

        return text
    }
}
