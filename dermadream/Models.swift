//
//  Models.swift
//  dermadream
//

import Foundation
import SwiftUI

// MARK: - Navigation

enum MainTab: String, CaseIterable, Identifiable {
    case dashboard
    case products
    case routine
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .products: return "Scan"
        case .routine: return "Routine"
        case .settings: return "Profile"
        }
    }

    /// Short tab bar caption (uppercase, minimal chrome).
    var tabCaption: String {
        switch self {
        case .dashboard: return "HOME"
        case .products: return "SCAN"
        case .routine: return "ROUTINE"
        case .settings: return "PROFILE"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "sparkles"
        case .products: return "barcode.viewfinder"
        case .routine: return "drop.halffull"
        case .settings: return "person.crop.circle"
        }
    }
}

// MARK: - Skin & products

enum BaselineSkinState: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case sensitive = "Sensitive"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .normal:
            return "Balanced barrier; standard screening thresholds."
        case .sensitive:
            return "Elevated screening for acids, fragrance, and essential oils."
        }
    }
}

struct Ingredient: Identifiable, Hashable {
    var id: String { normalizedName }
    var name: String
    var tags: [String]

    var normalizedName: String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SkincareProduct: Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: String
    var ingredients: [Ingredient]

    init(id: UUID = UUID(), name: String, category: String, ingredients: [Ingredient]) {
        self.id = id
        self.name = name
        self.category = category
        self.ingredients = ingredients
    }
}

enum ConflictSeverity: String {
    case caution
    case avoid
}

struct IngredientConflict: Identifiable, Hashable {
    let id: UUID
    let ingredientName: String
    let matchedAllergen: String
    let severity: ConflictSeverity
    let rationale: String

    init(id: UUID = UUID(), ingredientName: String, matchedAllergen: String, severity: ConflictSeverity, rationale: String) {
        self.id = id
        self.ingredientName = ingredientName
        self.matchedAllergen = matchedAllergen
        self.severity = severity
        self.rationale = rationale
    }
}

struct RecoveryRoutine: Equatable {
    var stopProducts: [String]
    var startProducts: [String]
    var careNotes: [String]
}

// MARK: - Avoid list & symptom history (product diagnostics)

/// Keywords the user avoids; compared against INCI strings (substring match in engine).
struct AvoidList: Equatable {
    var tokens: [String]

    init(tokens: [String]) {
        self.tokens = tokens
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct SymptomReport: Identifiable, Hashable {
    let id: UUID
    /// When the flare / check-in was logged.
    var recordedAt: Date
    var affectedRegions: [AnatomyRegion]
    var visualSymptoms: [VisualSymptom]
    var nonVisualSymptoms: [NonVisualSymptom]
    var severity: Int
    var notes: String?

    init(
        id: UUID = UUID(),
        recordedAt: Date,
        affectedRegions: [AnatomyRegion],
        visualSymptoms: [VisualSymptom],
        nonVisualSymptoms: [NonVisualSymptom],
        severity: Int,
        notes: String? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.affectedRegions = affectedRegions
        self.visualSymptoms = visualSymptoms
        self.nonVisualSymptoms = nonVisualSymptoms
        self.severity = min(10, max(1, severity))
        self.notes = notes
    }
}

enum IrritantSource: String, Hashable {
    case avoidList
    case sensitiveBaseline
    case symptomCorrelation
    case routineOverlap
}

struct IrritantFinding: Identifiable, Hashable {
    let id: UUID
    var ingredientName: String
    var severity: ConflictSeverity
    var source: IrritantSource
    /// Short label for the chip (e.g. "Avoid list", "Symptom history").
    var sourceLabel: String
    /// One-line headline for the row.
    var headline: String
    /// Supporting copy (allergen match, date-based reasoning, overlap).
    var detailReason: String

    init(
        id: UUID = UUID(),
        ingredientName: String,
        severity: ConflictSeverity,
        source: IrritantSource,
        sourceLabel: String,
        headline: String,
        detailReason: String
    ) {
        self.id = id
        self.ingredientName = ingredientName
        self.severity = severity
        self.source = source
        self.sourceLabel = sourceLabel
        self.headline = headline
        self.detailReason = detailReason
    }
}

/// Aggregated output for the Safety Report UI.
struct ProductSafetyAnalysis: Hashable {
    var product: SkincareProduct
    /// 0 = minimal concern, 100 = highest modeled risk for this prototype.
    var riskPercent: Int
    var findings: [IrritantFinding]
    var baselineAtAnalysis: BaselineSkinState
    /// `true` when shelf entry risk is pending.
    var shelfRiskPending: Bool = false
}

/// Recent Product Check record for Products screen history list.
struct RecentProductCheckRecord: Identifiable, Hashable {
    let id: UUID
    let targetProduct: String
    let result: AnalysisResult
    let scannedAt: Date

    init(
        id: UUID = UUID(),
        targetProduct: String,
        result: AnalysisResult,
        scannedAt: Date = .now
    ) {
        self.id = id
        self.targetProduct = targetProduct
        self.result = result
        self.scannedAt = scannedAt
    }
}

// MARK: - Routine logging

/// Where a routine product currently sits in the user's regimen.
enum RoutineStatus: String, CaseIterable, Identifiable, Codable {
    case current = "Currently Using"
    case stopped = "Stopped Using"

    var id: String { rawValue }
}

/// How often the user applies a routine product.
enum ProductUsageFrequency: String, CaseIterable, Identifiable, Codable {
    case everyday = "Everyday"
    case twoToThreeTimesWeekly = "2-3 times weekly"
    case onceWeekly = "Once weekly"
    case occasional = "Occasional"

    var id: String { rawValue }
}

/// Time-of-day bucket for grouping current-routine products. Used by
/// the Acute Irritation flow to render Morning / Night / Other sections.
enum RoutineSlot: String, CaseIterable, Identifiable, Codable {
    case morning = "Morning"
    case night = "Night"
    case both = "Both"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .night: return "moon.stars.fill"
        case .both: return "sun.and.horizon.fill"
        case .other: return "drop.halffull"
        }
    }
}

/// One product the user has logged into their routine, either active or
/// archived. Dates are optional — the status toggle is the source of truth.
struct RoutineEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var productName: String
    var brand: String
    var status: RoutineStatus
    var startDate: Date?
    var endDate: Date?
    var loggedAt: Date
    /// Where in the day the user applies this product. Defaults to
    /// `.other` for backwards-compatibility with entries logged before
    /// this field existed.
    var slot: RoutineSlot
    /// Optional frequency of use for the routine product.
    var usageFrequency: ProductUsageFrequency?

    init(
        id: UUID = UUID(),
        productName: String,
        brand: String = "",
        status: RoutineStatus,
        startDate: Date? = nil,
        endDate: Date? = nil,
        loggedAt: Date = .now,
        slot: RoutineSlot = .other,
        usageFrequency: ProductUsageFrequency? = nil
    ) {
        self.id = id
        self.productName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        self.status = status
        self.startDate = startDate
        // For archived items, the end date defaults to today if the
        // user did not pick one explicitly.
        self.endDate = status == .stopped ? (endDate ?? .now) : nil
        self.loggedAt = loggedAt
        self.slot = slot
        self.usageFrequency = usageFrequency
    }

    /// "12 days in use" style counter, only available when a start date
    /// is set and the entry is still active.
    var daysInUse: Int? {
        guard status == .current, let start = startDate else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: .now))
        return max(0, comps.day ?? 0)
    }

    /// Display title in card form ("Brand — Product" or just product name).
    var displayLine: String {
        brand.isEmpty ? productName : "\(brand) — \(productName)"
    }
}

// MARK: - Anatomy

enum AnatomyCanvas: String, CaseIterable, Identifiable, Codable {
    case face2D = "Face"
    case body2D = "Body"

    var id: String { rawValue }
}

enum AnatomyRegion: String, CaseIterable, Identifiable, Hashable, Codable {
    case forehead
    case leftCheek
    case rightCheek
    case nose
    case chin
    case neck

    case chest
    case upperBack
    case leftArm
    case rightArm
    case abdomen
    case leftLeg
    case rightLeg

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .forehead: return "Forehead"
        case .leftCheek: return "Left cheek"
        case .rightCheek: return "Right cheek"
        case .nose: return "Nose"
        case .chin: return "Chin / jaw"
        case .neck: return "Neck"
        case .chest: return "Chest"
        case .upperBack: return "Upper back"
        case .leftArm: return "Left arm"
        case .rightArm: return "Right arm"
        case .abdomen: return "Abdomen"
        case .leftLeg: return "Left leg"
        case .rightLeg: return "Right leg"
        }
    }

    static var faceRegions: [AnatomyRegion] {
        [.forehead, .leftCheek, .rightCheek, .nose, .chin, .neck]
    }

    /// Subset surfaced in the simplified Acute Irritation flow — just the
    /// four cardinal face quadrants the user can tap in `AnatomySelectionView`.
    static var faceCardinalRegions: [AnatomyRegion] {
        [.forehead, .leftCheek, .rightCheek, .chin]
    }

    static var bodyRegions: [AnatomyRegion] {
        [.chest, .upperBack, .leftArm, .rightArm, .abdomen, .leftLeg, .rightLeg]
    }
}

/// Top-level kind of acute irritation the user is reporting. The symptom
/// chip group below the type toggle is filtered to match.
enum IrritationType: String, CaseIterable, Identifiable, Codable {
    case visual = "Visual"
    case nonVisual = "Non-visual"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .visual: return "Something you can see (redness, blisters, flaking)."
        case .nonVisual: return "Something you can feel (itching, burning)."
        }
    }
}

/// One complete symptom-map submission (a single "irritation ticket").
struct IrritationMapSnapshot: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var regions: [AnatomyRegion]
    var irritationType: IrritationType
    var visualSymptoms: [VisualSymptom]
    var nonVisualSymptoms: [NonVisualSymptom]
    /// 1-5 severity scale picked in the symptom map.
    var severity: Int

    init(
        id: UUID = UUID(),
        regions: [AnatomyRegion],
        irritationType: IrritationType,
        visualSymptoms: [VisualSymptom] = [],
        nonVisualSymptoms: [NonVisualSymptom] = [],
        severity: Int
    ) {
        self.id = id
        self.regions = regions
        self.irritationType = irritationType
        self.visualSymptoms = visualSymptoms
        self.nonVisualSymptoms = nonVisualSymptoms
        self.severity = max(1, min(5, severity))
    }

    var regionsLabel: String {
        regions.map(\.displayTitle).joined(separator: ", ")
    }

    var symptomsLabel: String {
        var bits: [String] = []
        bits.append(contentsOf: visualSymptoms.map(\.rawValue))
        bits.append(contentsOf: nonVisualSymptoms.map(\.rawValue))
        return bits.joined(separator: ", ")
    }

    var concernHeadline: String {
        let symptoms = symptomsLabel
        let area = regionsLabel.lowercased()
        if symptoms.isEmpty {
            return area.isEmpty ? "Reported irritation" : "Irritation on \(area)"
        }
        return area.isEmpty ? symptoms : "\(symptoms) on \(area)"
    }
}

/// Acute Irritation flow context now supports multiple irritation tickets.
struct AcuteIrritationContext: Equatable, Hashable, Codable {
    var tickets: [IrritationMapSnapshot]

    init(tickets: [IrritationMapSnapshot]) {
        self.tickets = tickets
    }

    /// Backward-compatible initializer for single-ticket call sites/previews.
    init(
        regions: [AnatomyRegion],
        irritationType: IrritationType,
        visualSymptoms: [VisualSymptom] = [],
        nonVisualSymptoms: [NonVisualSymptom] = [],
        severity: Int
    ) {
        self.tickets = [
            IrritationMapSnapshot(
                regions: regions,
                irritationType: irritationType,
                visualSymptoms: visualSymptoms,
                nonVisualSymptoms: nonVisualSymptoms,
                severity: severity
            )
        ]
    }

    /// Compatibility projections for older code paths that expect single-map shape.
    var regions: [AnatomyRegion] { tickets.last?.regions ?? [] }
    var irritationType: IrritationType { tickets.last?.irritationType ?? .visual }
    var visualSymptoms: [VisualSymptom] { tickets.last?.visualSymptoms ?? [] }
    var nonVisualSymptoms: [NonVisualSymptom] { tickets.last?.nonVisualSymptoms ?? [] }
    var severity: Int { tickets.last?.severity ?? 3 }
    var regionsLabel: String { tickets.last?.regionsLabel ?? "" }
    var symptomsLabel: String { tickets.last?.symptomsLabel ?? "" }
    var concernHeadline: String { tickets.last?.concernHeadline ?? "Reported irritation" }
}

enum VisualSymptom: String, CaseIterable, Identifiable, Codable {
    case redness = "Redness"
    case blisters = "Blisters"
    case flaking = "Flaking"
    case acne = "Acne"

    var id: String { rawValue }
}

enum NonVisualSymptom: String, CaseIterable, Identifiable, Codable {
    case itchy = "Itchy"
    case burning = "Burning"

    var id: String { rawValue }
}

// MARK: - AI Product Analysis (Gemini-powered)

/// How the user identified the product — free-text or barcode.
enum ProductLookupMethod: Equatable {
    case nameAndBrand(name: String, brand: String)
    case barcode(String)

    var displayLabel: String {
        switch self {
        case .nameAndBrand(let name, let brand):
            return brand.isEmpty ? name : "\(brand) — \(name)"
        case .barcode(let code):
            return "Barcode: \(code)"
        }
    }
}

/// Structured JSON response from Gemini after analysing a product.
/// The Cloud Function is prompted to return exactly this shape.
struct GeminiProductAnalysis: Codable, Equatable {
    let productName: String
    let brand: String
    let overallRiskPercent: Int
    let irritants: [IngredientRisk]
    let summary: String

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brand
        case overallRiskPercent = "overall_risk_percent"
        case irritants
        case summary
    }
}

/// A single flagged ingredient in the Gemini analysis.
struct IngredientRisk: Codable, Identifiable, Equatable, Hashable {
    var id: String { name }

    let name: String
    let reason: String
    let riskPercent: Int

    enum CodingKeys: String, CodingKey {
        case name
        case reason
        case riskPercent = "risk_percent"
    }
}

// MARK: - Chat

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: ChatRole
    let text: String
    let sentAt: Date
    /// Base64-encoded image string (JPEG) attached by the user, if any.
    let imageBase64: String?

    enum ChatRole: Equatable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: ChatRole, text: String, sentAt: Date, imageBase64: String? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.sentAt = sentAt
        self.imageBase64 = imageBase64
    }

    /// Converts this message into Gemini-compatible content parts.
    var geminiParts: [GeminiPart] {
        var parts: [GeminiPart] = []
        if !text.isEmpty {
            parts.append(.textPart(text))
        }
        if let base64 = imageBase64 {
            parts.append(.imagePart(mimeType: "image/jpeg", base64: base64))
        }
        return parts
    }
}

// MARK: - App shell

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTab: MainTab = .dashboard
    @Published var showQuickComposer: Bool = false
    @Published var showChatSheet: Bool = false
    @Published var pendingChatSeed: String?
    @Published var showAnatomyFromWelcome: Bool = false

    /// Starts `true` on every launch so WelcomeView is always the landing page.
    @Published var showWelcome: Bool = true
}
