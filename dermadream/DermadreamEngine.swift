//
//  DermadreamEngine.swift
//  dermadream
//

import Foundation

@MainActor
final class DermadreamEngine: ObservableObject {
    @Published private(set) var baselineSkin: BaselineSkinState = .normal
    @Published private(set) var knownAllergens: [String]
    @Published private(set) var routineProducts: [SkincareProduct]
    @Published private(set) var chatMessages: [ChatMessage] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?
    /// Logged flare / anatomy check-ins; used to contextualize product safety copy.
    @Published private(set) var symptomReports: [SymptomReport]
    /// Routine log entries (current + archived) edited via the Routine screen.
    @Published private(set) var routineEntries: [RoutineEntry]
    /// Recent Product Check scans shown in Products screen.
    @Published private(set) var recentProductCheckScans: [RecentProductCheckRecord] = []

    // AI product analysis state
    @Published private(set) var isAnalyzingProduct: Bool = false
    @Published private(set) var productAnalysisResult: GeminiProductAnalysis?
    @Published private(set) var productAnalysisError: String?

    // Acute irritation analysis state
    @Published private(set) var isAnalyzingAcuteIrritation: Bool = false
    @Published private(set) var acuteIrritationReport: AcuteIrritationReport?
    @Published private(set) var acuteIrritationError: String?

    private let geminiService = GeminiService()
    private let targetProductService = TargetProductAnalysisService()
    private let productLookupService = ProductLookupService()
    private let acuteIrritationService = AcuteIrritationService()

    /// Default user id used to fetch reaction history from `user_records`.
    /// Swap this for the authenticated user id once sign-in is wired up.
    static let currentUserId = "1"

    init() {
        knownAllergens = ["fragrance", "linalool", "limonene", "benzoyl peroxide"]
        routineProducts = DermadreamEngine.sampleRoutine
        symptomReports = DermadreamEngine.sampleSymptomReports
        routineEntries = DermadreamEngine.sampleRoutineEntries
    }

    var avoidList: AvoidList {
        AvoidList(tokens: knownAllergens)
    }

    func updateBaseline(_ state: BaselineSkinState) {
        baselineSkin = state
    }

    func replaceAllergens(_ allergens: [String]) {
        knownAllergens = allergens
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func registerProduct(_ product: SkincareProduct) {
        routineProducts = routineProducts + [product]
    }

    func removeProduct(id: UUID) {
        routineProducts = routineProducts.filter { $0.id != id }
    }

    func logSymptomReport(_ report: SymptomReport) {
        symptomReports = [report] + symptomReports
    }

    // MARK: - Routine log

    /// Items currently marked "Currently Using" (newest log first).
    var currentRoutineEntries: [RoutineEntry] {
        routineEntries
            .filter { $0.status == .current }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    /// Items the user has stopped using (newest archived first).
    var archivedRoutineEntries: [RoutineEntry] {
        routineEntries
            .filter { $0.status == .stopped }
            .sorted { ($0.endDate ?? $0.loggedAt) > ($1.endDate ?? $1.loggedAt) }
    }

    func addRoutineEntry(_ entry: RoutineEntry) {
        routineEntries = [entry] + routineEntries
        // Mirror the new product into the in-memory user_records mock so
        // Gemini sees it the next time the user runs Product Check.
        Task.detached { [weak self] in
            await self?.persistRoutineEntryToMockDB(entry)
        }
    }

    /// Compatibility overload used by the routine form flow.
    func addRoutineEntry(_ entry: RoutineEntry, markPendingShelfRisk _: Bool) {
        addRoutineEntry(entry)
    }

    /// Pushes the routine entry into `MockUserRecordsDB.shared` as a
    /// `ProductReactionRecord` with `reactionType: "Routine Log"`. The
    /// entry shows up in `user_records[userId].history` exactly the way
    /// reactions do, so the existing analysis pipeline picks it up.
    nonisolated private func persistRoutineEntryToMockDB(_ entry: RoutineEntry) async {
        let df = DateFormatter()
        df.dateStyle = .medium

        var detailFragments: [String] = ["Status: \(entry.status.rawValue)."]
        if let start = entry.startDate {
            detailFragments.append("Started \(df.string(from: start)).")
        }
        if entry.status == .stopped, let end = entry.endDate {
            detailFragments.append("Stopped \(df.string(from: end)).")
        }
        detailFragments.append("Logged via Routine screen.")

        let reaction = ProductReactionRecord(
            productBrand: entry.brand,
            productName: entry.productName,
            reactionType: "Routine Log",
            details: detailFragments.joined(separator: " ")
        )

        let userId = DermadreamEngine.currentUserIdValue
        let db = MockUserRecordsDB.shared
        do {
            try await db.appendReaction(reaction, for: userId)
        } catch UserRecordsDBError.userNotFound {
            // The seed always ships userId "1", but if it's missing for
            // any reason, upsert a fresh skeleton record so the routine
            // entry still lands somewhere observable.
            await db.upsert(
                UserRecord(
                    userId: userId,
                    skinBaseline: "Unknown",
                    knownAllergens: [],
                    history: [reaction]
                )
            )
        } catch {
            // Mock store is in-memory; surface unexpected errors via log.
            print("[Routine] Failed to mirror entry to mock DB:", error.localizedDescription)
        }
    }

    /// Nonisolated accessor to the currentUserId static so detached tasks
    /// can read it without main-actor hopping.
    nonisolated private static var currentUserIdValue: String { "1" }

    func markRoutineEntryStopped(id: UUID, endDate: Date = .now) {
        routineEntries = routineEntries.map { entry in
            guard entry.id == id else { return entry }
            var copy = entry
            copy.status = .stopped
            copy.endDate = endDate
            return copy
        }
    }

    func deleteRoutineEntry(id: UUID) {
        routineEntries = routineEntries.filter { $0.id != id }
    }

    /// Active routine entries grouped by `RoutineSlot`. Empty slots are
    /// included so the UI can show "Nothing logged" placeholders.
    func currentRoutineGroupedBySlot() -> [(slot: RoutineSlot, entries: [RoutineEntry])] {
        let active = currentRoutineEntries
        return RoutineSlot.allCases.map { slot in
            (slot, active.filter { $0.slot == slot })
        }
    }

    /// Shelf products derived from current routine entries.
    var currentRoutineShelfProducts: [SkincareProduct] {
        currentRoutineEntries.map { shelfProduct(for: $0) }
    }

    /// Kept for screen lifecycle compatibility with older flow.
    func refreshRoutineLogFromMockDB() async {}

    /// Builds a shelf card product from one routine log row.
    private func shelfProduct(for entry: RoutineEntry) -> SkincareProduct {
        let name = entry.displayLine.isEmpty ? entry.productName : entry.displayLine
        return SkincareProduct(
            name: name,
            category: "Routine",
            ingredients: []
        )
    }

    // MARK: - Acute irritation analysis

    /// Kicks off the Acute Irritation pipeline: builds the prompt from
    /// the symptom snapshot + current routine + product history, sends
    /// it to Gemini, and stores the parsed `AcuteIrritationReport` for
    /// the result screen to consume.
    func runAcuteIrritation(_ context: AcuteIrritationContext) {
        acuteIrritationReport = nil
        acuteIrritationError = nil
        isAnalyzingAcuteIrritation = true

        let snapshot = AcuteIrritationRequestSnapshot(
            currentRoutine: currentRoutineEntries,
            archivedRoutine: archivedRoutineEntries,
            knownAllergens: knownAllergens,
            baseline: baselineSkin
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                let report = try await self.acuteIrritationService.analyze(
                    context: context,
                    snapshot: snapshot,
                    userId: DermadreamEngine.currentUserId
                )
                self.acuteIrritationReport = report
            } catch {
                self.acuteIrritationError =
                    (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
            self.isAnalyzingAcuteIrritation = false
        }
    }

    /// Persists one symptom-map ticket as a synthetic history row so acute analysis
    /// can include user-reported irritation context from the same session.
    func persistIrritationMapTicket(_ ticket: IrritationMapSnapshot) {
        let regions = ticket.regions.map(\.displayTitle).joined(separator: ", ")
        let symptoms = (ticket.visualSymptoms.map(\.rawValue) + ticket.nonVisualSymptoms.map(\.rawValue))
            .joined(separator: ", ")
        let details = "Severity \(ticket.severity)/5. Regions: \(regions). Symptoms: \(symptoms)."

        let reaction = ProductReactionRecord(
            productBrand: "",
            productName: "Irritation Map Ticket",
            reactionType: "Irritation Ticket",
            details: details
        )

        Task.detached {
            do {
                try await MockUserRecordsDB.shared.appendReaction(
                    reaction,
                    for: DermadreamEngine.currentUserId
                )
            } catch {
                // Best-effort mirror only; analysis can still run without this record.
            }
        }
    }

    func clearAcuteIrritation() {
        acuteIrritationReport = nil
        acuteIrritationError = nil
    }

    /// Display risk used by the heatmap tiles in `IrritationReportView`.
    /// Keeps percentages normalized to 0...100 for UI rendering.
    func heatmapDisplayRiskPercent(for suspected: SuspectedProduct) -> Int {
        min(max(suspected.irritationProbability, 0), 100)
    }

    // MARK: - Product safety analysis (AvoidList + SymptomReports)

    func safetyAnalysis(for product: SkincareProduct) -> ProductSafetyAnalysis {
        let conflicts = conflicts(for: product)
        var findings: [IrritantFinding] = []
        let avoid = avoidList

        for conflict in conflicts {
            let source: IrritantSource
            let label: String
            let headline: String
            let detail: String

            if conflict.matchedAllergen.lowercased() == conflict.ingredientName.lowercased()
                || avoid.tokens.contains(where: { conflict.matchedAllergen.contains($0) }) {
                source = .avoidList
                label = "Avoid list"
                headline = "Recorded allergen match"
                detail = buildAvoidListDetail(conflict: conflict, avoid: avoid)
            } else if conflict.rationale.contains("Sensitive baseline") {
                source = .sensitiveBaseline
                label = "Sensitive profile"
                headline = "Elevated irritant class under sensitive baseline"
                detail = conflict.rationale
            } else {
                source = .avoidList
                label = "Avoid list"
                headline = "Profile conflict"
                detail = conflict.rationale
            }

            var mergedDetail = detail
            if let symptomLine = symptomCorrelationLine(for: product, ingredientName: conflict.ingredientName) {
                mergedDetail += " " + symptomLine
            }
            if let overlap = routineOverlapLine(for: product, ingredientName: conflict.ingredientName) {
                mergedDetail += " " + overlap
            }

            findings.append(
                IrritantFinding(
                    ingredientName: conflict.ingredientName,
                    severity: conflict.severity,
                    source: source,
                    sourceLabel: label,
                    headline: headline,
                    detailReason: mergedDetail.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }

        // Additional irritant-class rows (not already captured as conflicts) for transparency
        for ingredient in product.ingredients {
            let lowerTags = ingredient.tags.map { $0.lowercased() }
            let isExfoliantOrVitaminC = lowerTags.contains(where: { ["aha", "bha", "retinoid", "vitamin c", "ascorbic"].contains($0) })
            guard isExfoliantOrVitaminC else { continue }
            if findings.contains(where: { $0.ingredientName.caseInsensitiveCompare(ingredient.name) == .orderedSame }) {
                continue
            }
            if let line = symptomCorrelationLine(for: product, ingredientName: ingredient.name) {
                findings.append(
                    IrritantFinding(
                        ingredientName: ingredient.name,
                        severity: .caution,
                        source: .symptomCorrelation,
                        sourceLabel: "Symptom history",
                        headline: "Potential irritant class",
                        detailReason: line
                    )
                )
            }
        }

        let risk = DermadreamEngine.computeRiskPercent(
            findings: findings,
            baseline: baselineSkin,
            ingredientCount: product.ingredients.count
        )

        let sortedFindings = findings.sorted { lhs, rhs in
            if lhs.severity == rhs.severity {
                return lhs.ingredientName.localizedCaseInsensitiveCompare(rhs.ingredientName) == .orderedAscending
            }
            if lhs.severity == .avoid { return true }
            if rhs.severity == .avoid { return false }
            return lhs.severity.rawValue < rhs.severity.rawValue
        }

        return ProductSafetyAnalysis(
            product: product,
            riskPercent: risk,
            findings: sortedFindings,
            baselineAtAnalysis: baselineSkin
        )
    }

    private func buildAvoidListDetail(conflict: IngredientConflict, avoid: AvoidList) -> String {
        let token = avoid.tokens.first(where: { conflict.matchedAllergen.contains($0) || conflict.ingredientName.lowercased().contains($0) }) ?? conflict.matchedAllergen
        return "Matches your AvoidList keyword \"\(token)\" against INCI \"\(conflict.ingredientName)\"."
    }

    private func symptomCorrelationLine(for product: SkincareProduct, ingredientName: String) -> String? {
        guard let report = symptomReports.sorted(by: { $0.recordedAt > $1.recordedAt }).first else { return nil }
        let ing = ingredientName.lowercased()
        let tags = product.ingredients.first(where: { $0.name.caseInsensitiveCompare(ingredientName) == .orderedSame })?.tags.map { $0.lowercased() } ?? []
        let stressors = ["aha", "bha", "retinoid", "fragrance", "essential oil", "vitamin c", "ascorbic"]
        guard tags.contains(where: { stressors.contains($0) }) || ing.contains("acid") || ing.contains("retinol") else {
            return nil
        }

        let hadRedness = report.visualSymptoms.contains(.redness)
        let hadIrritation = report.nonVisualSymptoms.contains(where: { [.itchy, .burning].contains($0) })
        guard hadRedness || hadIrritation else { return nil }

        let df = DateFormatter()
        df.dateStyle = .medium
        let regions = report.affectedRegions.map(\.displayTitle).joined(separator: ", ")
        let regionPhrase = regions.isEmpty ? "logged areas" : regions
        return "Triggers redness and irritation patterns similar to your report from \(df.string(from: report.recordedAt)) (\(regionPhrase))."
    }

    private func routineOverlapLine(for product: SkincareProduct, ingredientName: String) -> String? {
        let key = ingredientName.lowercased()
        let others = routineProducts.filter { $0.id != product.id }
        for other in others {
            if other.ingredients.contains(where: { $0.normalizedName == key || $0.name.caseInsensitiveCompare(ingredientName) == .orderedSame }) {
                let family = ingredientFamilyLabel(ingredientName)
                return "Known overlap with your current \(other.name) (shared \(family))."
            }
        }
        return nil
    }

    private func ingredientFamilyLabel(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("ascorb") || n.contains("vitamin c") { return "vitamin C pathway" }
        if n.contains("glycol") || n.contains("lactic") || n.contains("salicyl") { return "exfoliant actives" }
        if n.contains("retinol") || n.contains("retin") { return "retinoid class" }
        if n.contains("linalool") || n.contains("limonene") || n.contains("fragrance") { return "fragrance-related INCI" }
        return "ingredient"
    }

    private static func computeRiskPercent(findings: [IrritantFinding], baseline: BaselineSkinState, ingredientCount: Int) -> Int {
        var score = 8
        for f in findings {
            switch f.severity {
            case .avoid: score += 34
            case .caution: score += 16
            }
        }
        if baseline == .sensitive { score += 12 }
        if ingredientCount > 18 { score += 6 }
        return min(100, max(0, score))
    }

    // MARK: - Conflicts

    func conflicts(for product: SkincareProduct) -> [IngredientConflict] {
        var results: [IngredientConflict] = []

        for ingredient in product.ingredients {
            let normalized = ingredient.normalizedName

            for allergen in knownAllergens where normalized.contains(allergen) {
                results.append(
                    IngredientConflict(
                        ingredientName: ingredient.name,
                        matchedAllergen: allergen,
                        severity: .avoid,
                        rationale: "Matches a recorded allergen on your profile."
                    )
                )
            }

            if baselineSkin == .sensitive {
                for tag in ingredient.tags {
                    let lowered = tag.lowercased()
                    if ["fragrance", "essential oil", "aha", "bha", "retinoid"].contains(lowered) {
                        results.append(
                            IngredientConflict(
                                ingredientName: ingredient.name,
                                matchedAllergen: tag,
                                severity: .caution,
                                rationale: "Sensitive baseline: potential barrier stressor."
                            )
                        )
                    }
                }
            }
        }

        var seen = Set<String>()
        return results.filter { conflict in
            let key = conflict.ingredientName.lowercased() + conflict.matchedAllergen.lowercased() + conflict.severity.rawValue
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    // MARK: - Recovery routine

    func recoveryRoutine(for product: SkincareProduct, conflicts: [IngredientConflict]) -> RecoveryRoutine {
        let conflictNames = Set(conflicts.map { $0.ingredientName.lowercased() })

        let overlapping = routineProducts.filter { existing in
            existing.id != product.id && existing.ingredients.contains { ing in
                conflictNames.contains(ing.normalizedName)
            }
        }

        var stop = overlapping.map(\.name)
        if !conflicts.isEmpty {
            stop.append(product.name)
        }

        stop = Array(Set(stop)).sorted()

        var start: [String] = [
            "Gentle non-foaming cleanser",
            "Ceramide / oat barrier moisturizer",
            "Mineral SPF 30+ (zinc / titanium)"
        ]

        if baselineSkin == .sensitive {
            start.append("Colloidal oatmeal compress (10 minutes)")
        }

        var notes: [String] = [
            "Pause exfoliants and treatment serums until redness calms.",
            "Patch test new introductions for 48 hours behind the ear."
        ]

        if conflicts.contains(where: { $0.severity == .avoid }) {
            notes.insert("Immediately discontinue products flagged as avoid.", at: 0)
        }

        return RecoveryRoutine(stopProducts: stop, startProducts: start, careNotes: notes)
    }

    // MARK: - AI Product Analysis

    /// Sends a product lookup to Gemini for ingredient-level risk analysis.
    func analyzeProduct(lookup: ProductLookupMethod) {
        productAnalysisResult = nil
        productAnalysisError = nil
        isAnalyzingProduct = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let context = self.buildProductAnalysisContext()
                let result = try await self.geminiService.analyzeProduct(
                    lookup: lookup,
                    userContext: context
                )
                self.productAnalysisResult = result
            } catch {
                let message = (error as? GeminiServiceError)?.errorDescription
                    ?? error.localizedDescription
                self.productAnalysisError = message
            }
            self.isAnalyzingProduct = false
        }
    }

    func clearProductAnalysis() {
        productAnalysisResult = nil
        productAnalysisError = nil
    }

    /// Async entry point used by the Manual Input sheet. Returns a
    /// strongly-typed `AnalysisResult` from `TargetProductAnalysisService`,
    /// which calls Gemini directly with the user's history from
    /// `dermadream.user_records`.
    func analyzeTargetProduct(
        targetProduct: String,
        userId: String = DermadreamEngine.currentUserId
    ) async throws -> AnalysisResult {
        let result = try await targetProductService.analyzeProduct(
            userId: userId,
            targetProductName: targetProduct
        )
        recentProductCheckScans = [
            RecentProductCheckRecord(targetProduct: targetProduct, result: result)
        ] + recentProductCheckScans
        return result
    }

    /// Full barcode scan pipeline: Barcode Lookup -> "<brand> <title>" ->
    /// Gemini product analysis. Returns a `TargetAnalysisPayload` ready
    /// to be bound to `navigationDestination(item:)`.
    ///
    /// Throws `ProductLookupError.notFound` if the barcode isn't in the
    /// Barcode Lookup DB, or forwards any network / Gemini errors.
    func analyzeScannedBarcode(
        _ barcode: String,
        userId: String = DermadreamEngine.currentUserId
    ) async throws -> TargetAnalysisPayload {
        let product = try await productLookupService.lookupProduct(barcode: barcode)

        // Send `products[0].title` verbatim — same path the Manual
        // Input sheet uses when the user types a product name.
        let targetProduct = product.targetProductName
        guard !targetProduct.isEmpty else {
            throw ProductLookupError.notFound
        }

        let analysis = try await targetProductService.analyzeProduct(
            userId: userId,
            targetProductName: targetProduct
        )
        recentProductCheckScans = [
            RecentProductCheckRecord(targetProduct: targetProduct, result: analysis)
        ] + recentProductCheckScans

        return TargetAnalysisPayload(
            targetProduct: targetProduct,
            result: analysis
        )
    }

    /// Form-only barcode lookup used by routine/suspect sheets.
    func lookupProductByBarcode(_ barcode: String) async throws -> ProductLookupResult {
        try await productLookupService.lookupProduct(barcode: barcode)
    }

    /// Builds a rich user-context string for the product analysis prompt.
    private func buildProductAnalysisContext() -> String {
        var lines: [String] = [
            "User skin baseline: \(baselineSkin.rawValue).",
            "Known allergens: \(knownAllergens.joined(separator: ", ")).",
        ]

        if !routineProducts.isEmpty {
            let descriptions = routineProducts.map { product in
                let ingredients = product.ingredients.map(\.name).joined(separator: ", ")
                return "\(product.name) (\(product.category)): \(ingredients)"
            }
            lines.append("Current routine products (product history):")
            lines.append(contentsOf: descriptions.map { "  - \($0)" })
        }

        if !symptomReports.isEmpty {
            let latest = symptomReports.prefix(3)
            lines.append("Recent symptom reports:")
            for report in latest {
                let regions = report.affectedRegions.map(\.displayTitle).joined(separator: ", ")
                let visual = report.visualSymptoms.map(\.rawValue).joined(separator: ", ")
                let nonVisual = report.nonVisualSymptoms.map(\.rawValue).joined(separator: ", ")
                lines.append("  - \(formatted(report.recordedAt)): severity \(report.severity)/10, regions: \(regions), symptoms: \(visual), \(nonVisual)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Chat

    /// Appends a user message (with optional image) to the conversation,
    /// sends the full history to Gemini via Firebase, and appends the reply.
    func sendMessage(_ text: String, imageBase64: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || imageBase64 != nil else { return }

        let userMessage = ChatMessage(role: .user, text: trimmed, sentAt: .now, imageBase64: imageBase64)
        chatMessages.append(userMessage)

        lastError = nil
        isLoading = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let reply = try await self.fetchGeminiReply()
                self.chatMessages.append(
                    ChatMessage(role: .assistant, text: reply, sentAt: .now)
                )
            } catch {
                let message = (error as? GeminiServiceError)?.errorDescription
                    ?? error.localizedDescription
                self.lastError = message
                self.chatMessages.append(
                    ChatMessage(role: .assistant, text: "Sorry, something went wrong: \(message)", sentAt: .now)
                )
            }
            self.isLoading = false
        }
    }

    func clearError() {
        lastError = nil
    }

    /// Builds the full Gemini `contents` array from chat history and calls the service.
    private func fetchGeminiReply() async throws -> String {
        let systemPreamble = buildSystemContext()

        var contents: [GeminiContent] = [
            GeminiContent(role: "user", parts: [.textPart(systemPreamble)])
        ]

        for msg in chatMessages {
            let role = msg.role == .user ? "user" : "model"
            contents.append(GeminiContent(role: role, parts: msg.geminiParts))
        }

        return try await geminiService.sendChat(contents: contents)
    }

    /// Provides Gemini with the user's skin profile so responses are personalised.
    private func buildSystemContext() -> String {
        var lines: [String] = [
            "You are Dermadream AI, a friendly dermatology assistant.",
            "Baseline skin type: \(baselineSkin.rawValue).",
            "Known allergens: \(knownAllergens.joined(separator: ", ")).",
        ]

        if !routineProducts.isEmpty {
            let names = routineProducts.map(\.name).joined(separator: ", ")
            lines.append("Current routine products: \(names).")
        }

        if let latest = symptomReports.first {
            let regions = latest.affectedRegions.map(\.displayTitle).joined(separator: ", ")
            lines.append("Latest symptom report (\(formatted(latest.recordedAt))): severity \(latest.severity)/10, regions: \(regions).")
        }

        lines.append("Keep responses concise and actionable. If a user shares a photo of skin irritation, describe what you observe and suggest next steps.")
        return lines.joined(separator: " ")
    }

    private func formatted(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }

    // MARK: - Sample data

    private static var sampleRoutine: [SkincareProduct] {
        let gentleCleanser = SkincareProduct(
            name: "COSRX Low pH Good Morning Gel Cleanser",
            category: "Cleanser",
            ingredients: []
        )

        let activeSerum = SkincareProduct(
            name: "Yves Saint Laurent Pure Shots Night Reboot Serum",
            category: "Serum",
            ingredients: []
        )

        let vitaminCSerum = SkincareProduct(
            name: "CeraVe Skin Renewing Vitamin C Serum",
            category: "Serum",
            ingredients: []
        )

        return [gentleCleanser, activeSerum, vitaminCSerum]
    }

    private static var sampleRoutineEntries: [RoutineEntry] {
        let cal = Calendar(identifier: .gregorian)
        let today = Date()
        let twentyDaysAgo = cal.date(byAdding: .day, value: -20, to: today) ?? today
        let twoMonthsAgo = cal.date(byAdding: .day, value: -62, to: today) ?? today
        let aWhileAgo = cal.date(byAdding: .day, value: -110, to: today) ?? today
        let stoppedRecently = cal.date(byAdding: .day, value: -8, to: today) ?? today
        let stoppedAgesAgo = cal.date(byAdding: .day, value: -45, to: today) ?? today

        return [
            RoutineEntry(
                productName: "COSRX Low pH Good Morning Gel Cleanser",
                brand: "CosRX",
                status: .current,
                startDate: twentyDaysAgo,
                slot: .morning
            ),
            RoutineEntry(
                productName: "CeraVe Skin Renewing Vitamin C Serum",
                brand: "CeraVe",
                status: .current,
                startDate: twoMonthsAgo,
                slot: .morning
            ),
            RoutineEntry(
                productName: "Olay Night Repair Super Serum",
                brand: "Olay",
                status: .current,
                startDate: twentyDaysAgo,
                slot: .night
            ),
            RoutineEntry(
                productName: "Yves Saint Laurent Pure Shots Night Reboot Serum",
                brand: "YSL",
                status: .stopped,
                startDate: aWhileAgo,
                endDate: stoppedRecently,
                slot: .night
            )
        ]
    }









































    private static var sampleSymptomReports: [SymptomReport] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let march15 = cal.date(from: DateComponents(year: 2026, month: 3, day: 15)) ?? Date()
        return [
            SymptomReport(
                recordedAt: march15,
                affectedRegions: [.forehead, .leftCheek],
                visualSymptoms: [.redness],
                nonVisualSymptoms: [.itchy],
                severity: 7,
                notes: "After introducing a new serum."
            )
        ]
    }
}
