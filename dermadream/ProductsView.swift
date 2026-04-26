//
//  ProductsView.swift
//  dermadream
//

import SwiftUI
import AVFoundation

// MARK: - Diagnostic palette (taupe / charcoal + brand accents)

private enum DiagnosticStyle {
    /// Surfaces & main backgrounds — Cream Shell `#F9F7F2`.
    static let canvas = DermadreamTheme.creamShell
    /// Primary typography — Charcoal Gray `#333333`.
    static let charcoal = DermadreamTheme.charcoalGray
    /// Secondary copy / placeholders — Soft Slate `#999999`.
    static let taupe = DermadreamTheme.softSlate
    /// Card / form surfaces stay white for "minimalist contrast".
    static let card = Color.white
    /// Accent stroke / brand primary — Deep Umber `#7D5D3F`.
    static let tealStroke = DermadreamTheme.deepUmber
}

// MARK: - Entry

struct ProductsView: View {
    @EnvironmentObject private var engine: DermadreamEngine
    @State private var searchText = ""
    @State private var reportProduct: SkincareProduct?
    @State private var showManualSheet = false
    @State private var showScanSheet = false
    @State private var showAIReport = false
    @State private var targetAnalysis: TargetAnalysisPayload?

    private var filteredShelf: [SkincareProduct] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let list: [SkincareProduct] = {
            let shelf = engine.currentRoutineShelfProducts
            guard !q.isEmpty else { return shelf }
            return shelf.filter {
                $0.name.lowercased().contains(q) || $0.category.lowercased().contains(q)
            }
        }()
        return list.sorted { a, b in
            let pa = engine.safetyAnalysis(for: a)
            let pb = engine.safetyAnalysis(for: b)
            if pa.shelfRiskPending != pb.shelfRiskPending {
                // Pending (not yet scored) at the end of the list.
                return !pa.shelfRiskPending && pb.shelfRiskPending
            }
            if pa.riskPercent != pb.riskPercent { return pa.riskPercent > pb.riskPercent }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Shelf diagnostics")
                    .font(DermadreamTheme.navTitleSerif)
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                entryActionRow

                searchField

                recentScansSection

                shelfSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(DiagnosticStyle.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $reportProduct) { product in
            ProductSafetyReportView(product: product)
                .environmentObject(engine)
        }
        .navigationDestination(isPresented: $showAIReport) {
            AIProductReportView()
                .environmentObject(engine)
        }
        .navigationDestination(item: $targetAnalysis) { payload in
            TargetAnalysisResultView(
                targetProduct: payload.targetProduct,
                result: payload.result
            )
        }
        .sheet(isPresented: $showManualSheet) {
            ManualProductEntrySheet(isPresented: $showManualSheet) { target, result in
                targetAnalysis = TargetAnalysisPayload(
                    targetProduct: target,
                    result: result
                )
            }
            .environmentObject(engine)
        }
        .sheet(isPresented: $showScanSheet) {
            BarcodeScannerSheet(
                isPresented: $showScanSheet,
                onAnalyzed: { payload in
                    targetAnalysis = payload
                },
                onRequestManualInput: {
                    showManualSheet = true
                }
            )
            .environmentObject(engine)
        }
        .onAppear {
            Task { await engine.refreshRoutineLogFromMockDB() }
        }
    }

    private var entryActionRow: some View {
        HStack(spacing: 12) {
            // Both entry cards are brand actions (not warnings), so they
            // share Deep Umber and differentiate via icon + copy.
            entryCard(
                title: "Scan Product",
                subtitle: "Camera barcode capture",
                systemImage: "barcode.viewfinder",
                accent: DermadreamTheme.deepUmber,
                action: { showScanSheet = true }
            )

            entryCard(
                title: "Manual Input",
                subtitle: "Product name or brand",
                systemImage: "keyboard",
                accent: DermadreamTheme.deepUmber,
                action: { showManualSheet = true }
            )
        }
    }

    private func entryCard(title: String, subtitle: String, systemImage: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accent)
                }

                Text(title)
                    .font(DermadreamTheme.displayBold(16))
                    .foregroundStyle(DiagnosticStyle.charcoal)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(DermadreamTheme.displaySemibold(12))
                    .foregroundStyle(DiagnosticStyle.taupe)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DiagnosticStyle.card)
                    .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DermadreamTheme.teal)

            TextField("Search your shelf or a new product...", text: $searchText)
                .font(DermadreamTheme.displaySemibold(15))
                .foregroundStyle(DiagnosticStyle.charcoal)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DiagnosticStyle.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DiagnosticStyle.tealStroke, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var recentScansSection: some View {
        if !engine.recentProductCheckScans.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent scans")
                    .font(DermadreamTheme.displayBold(18))
                    .foregroundStyle(DiagnosticStyle.charcoal)

                VStack(spacing: 10) {
                    ForEach(engine.recentProductCheckScans) { rec in
                        Button {
                            targetAnalysis = TargetAnalysisPayload(
                                targetProduct: rec.targetProduct,
                                result: rec.result
                            )
                        } label: {
                            recentScanRow(rec)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recentScanRow(_ rec: RecentProductCheckRecord) -> some View {
        let risk = min(max(rec.result.irritationScorePercentage, 0), 100)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rec.targetProduct)
                    .font(DermadreamTheme.displayBold(16))
                    .foregroundStyle(DiagnosticStyle.charcoal)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                (Text("Checked ") + Text(rec.scannedAt, style: .date))
                    .font(DermadreamTheme.label(12))
                    .foregroundStyle(DiagnosticStyle.taupe)
            }
            Spacer(minLength: 0)
            riskPill(risk)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DermadreamTheme.teal.opacity(0.7))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DiagnosticStyle.card)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }

    private var shelfSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your shelf")
                .font(DermadreamTheme.displayBold(18))
                .foregroundStyle(DiagnosticStyle.charcoal)

            if filteredShelf.isEmpty {
                Text("No products match this search.")
                    .font(DermadreamTheme.displaySemibold(14))
                    .foregroundStyle(DiagnosticStyle.taupe)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredShelf) { product in
                        Button {
                            reportProduct = product
                        } label: {
                            shelfRow(product)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func shelfRow(_ product: SkincareProduct) -> some View {
        let analysis = engine.safetyAnalysis(for: product)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(DermadreamTheme.displayBold(16))
                    .foregroundStyle(DiagnosticStyle.charcoal)
                Text(product.category)
                    .font(DermadreamTheme.label(12))
                    .foregroundStyle(DiagnosticStyle.taupe)
            }
            Spacer(minLength: 0)
            shelfRiskStatusPill(analysis)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DermadreamTheme.teal.opacity(0.7))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DiagnosticStyle.card)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }

    @ViewBuilder
    private func shelfRiskStatusPill(_ analysis: ProductSafetyAnalysis) -> some View {
        if analysis.shelfRiskPending {
            Text("Newly added")
                .font(DermadreamTheme.displaySemibold(12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(DiagnosticStyle.taupe.opacity(0.2)))
                .foregroundStyle(DiagnosticStyle.taupe)
        } else {
            riskPill(analysis.riskPercent)
        }
    }

    private func riskPill(_ risk: Int) -> some View {
        // Terracotta is reserved for critical warnings only — anything
        // below 50% risk uses the calmer Deep Umber brand accent.
        let warm = risk >= 50
        let accent = warm ? DermadreamTheme.terracotta : DermadreamTheme.deepUmber
        return Text("\(risk)% risk")
            .font(DermadreamTheme.displaySemibold(12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(accent.opacity(0.16)))
            .foregroundStyle(accent)
    }
}

// MARK: - AI Product Report (Gemini-powered)

private struct AIProductReportView: View {
    @EnvironmentObject private var engine: DermadreamEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if engine.isAnalyzingProduct {
                    loadingState
                } else if let error = engine.productAnalysisError {
                    errorState(error)
                } else if let analysis = engine.productAnalysisResult {
                    analysisContent(analysis)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(DiagnosticStyle.canvas.ignoresSafeArea())
        .navigationTitle("AI Safety Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var loadingState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            ProgressView()
                .controlSize(.large)
                .tint(DermadreamTheme.teal)

            Text("Analyzing ingredients...")
                .font(DermadreamTheme.displayBold(18))
                .foregroundStyle(DiagnosticStyle.charcoal)

            Text("Dermadream AI is identifying the product, checking every ingredient against your skin profile, allergens, and product history.")
                .font(DermadreamTheme.displaySemibold(14))
                .foregroundStyle(DiagnosticStyle.taupe)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DermadreamTheme.orange)

            Text("Analysis failed")
                .font(DermadreamTheme.displayBold(20))
                .foregroundStyle(DiagnosticStyle.charcoal)

            Text(message)
                .font(DermadreamTheme.displaySemibold(14))
                .foregroundStyle(DiagnosticStyle.taupe)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                dismiss()
            } label: {
                Text("Go back")
                    .font(DermadreamTheme.displaySemibold(16))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(DermadreamTheme.deepUmber)
                    .clipShape(Capsule())
                    .shadow(color: DermadreamTheme.deepUmber.opacity(0.18), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func analysisContent(_ analysis: GeminiProductAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            headerBlock(analysis)

            AIRiskMeterView(riskPercent: analysis.overallRiskPercent)

            irritantsSection(analysis.irritants)

            summarySection(analysis.summary)
        }
    }

    private func headerBlock(_ analysis: GeminiProductAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(analysis.productName)
                .font(DermadreamTheme.displayBold(24))
                .foregroundStyle(DiagnosticStyle.charcoal)

            if !analysis.brand.isEmpty {
                Text(analysis.brand.uppercased())
                    .font(DermadreamTheme.label(11))
                    .foregroundStyle(DiagnosticStyle.taupe)
            }

            Text("Powered by Gemini AI — cross-referenced with your allergen profile, \(engine.currentRoutineShelfProducts.count) routine product(s), and \(engine.symptomReports.count) symptom report(s).")
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DiagnosticStyle.taupe)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func irritantsSection(_ irritants: [IngredientRisk]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Potential irritants")
                .font(DermadreamTheme.displayBold(18))
                .foregroundStyle(DiagnosticStyle.charcoal)

            if irritants.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(DermadreamTheme.mutedSage)
                    Text("No flagged ingredients for your profile. This product appears safe for your skin.")
                        .font(DermadreamTheme.displaySemibold(14))
                        .foregroundStyle(DermadreamTheme.softSlate)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DiagnosticStyle.card)
                )
                .shadow(color: DermadreamTheme.charcoalGray.opacity(0.05), radius: 8, x: 0, y: 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(irritants) { irritant in
                        irritantRow(irritant)
                    }
                }
            }
        }
    }

    private func irritantRow(_ irritant: IngredientRisk) -> some View {
        let isHigh = irritant.riskPercent >= 50
        let accent = isHigh ? DermadreamTheme.terracotta : DermadreamTheme.deepUmber
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(irritant.name)
                    .font(DermadreamTheme.displayBold(16))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                Spacer(minLength: 0)
                Text("\(irritant.riskPercent)%")
                    .font(DermadreamTheme.displayBold(14))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(accent.opacity(0.16)))
                    .foregroundStyle(accent)
            }

            Text(irritant.reason)
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DermadreamTheme.softSlate)
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { geo in
                let fill = geo.size.width * CGFloat(irritant.riskPercent) / 100
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DermadreamTheme.softSlate.opacity(0.18))
                        .frame(height: 6)
                    Capsule()
                        .fill(accent)
                        .frame(width: max(4, fill), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DiagnosticStyle.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isHigh
                        ? DermadreamTheme.terracotta.opacity(0.45)
                        : DermadreamTheme.softSlate.opacity(0.2),
                    lineWidth: isHigh ? 1.5 : 1
                )
        )
        .shadow(color: DermadreamTheme.charcoalGray.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(DermadreamTheme.deepUmber)
                Text("AI Summary")
                    .font(DermadreamTheme.displayBold(15))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
            }

            Text(summary)
                .font(DermadreamTheme.displaySemibold(14))
                .foregroundStyle(DermadreamTheme.softSlate)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DermadreamTheme.sandstone.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DermadreamTheme.deepUmber.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - AI Risk meter

private struct AIRiskMeterView: View {
    let riskPercent: Int

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 18)
                    .frame(width: 168, height: 168)

                Circle()
                    .trim(from: 0, to: CGFloat(riskPercent) / 100)
                    .stroke(
                        AngularGradient(
                            colors: [
                                DermadreamTheme.riskLow,
                                DermadreamTheme.riskMid,
                                DermadreamTheme.riskHigh
                            ],
                            center: .center,
                            angle: .degrees(0)
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .butt)
                    )
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(riskPercent)%")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(DiagnosticStyle.charcoal)
                    Text("Irritation risk")
                        .font(DermadreamTheme.label(12))
                        .foregroundStyle(DiagnosticStyle.taupe)
                }
            }

            Text(riskCaption)
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DiagnosticStyle.taupe)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }

    private var riskCaption: String {
        switch riskPercent {
        case 0 ..< 25: return "Low risk — this product looks compatible with your skin profile."
        case 25 ..< 55: return "Moderate risk — review flagged ingredients before daily use."
        default: return "Elevated risk — consider alternatives or consult a dermatologist."
        }
    }
}

// MARK: - Local safety report (for shelf products)

private struct ProductSafetyReportView: View {
    let product: SkincareProduct
    @EnvironmentObject private var engine: DermadreamEngine

    private var analysis: ProductSafetyAnalysis {
        engine.safetyAnalysis(for: product)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerBlock

                if analysis.shelfRiskPending {
                    pendingShelfRiskCard
                } else {
                    RiskMeterView(riskPercent: analysis.riskPercent)
                }

                irritantsSection

                baselineFooter
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(DiagnosticStyle.canvas.ignoresSafeArea())
        .navigationTitle("Safety report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(product.name)
                .font(DermadreamTheme.displayBold(24))
                .foregroundStyle(DiagnosticStyle.charcoal)
            Text(product.category.uppercased())
                .font(DermadreamTheme.label(11))
                .foregroundStyle(DiagnosticStyle.taupe)
            Text("Analysis uses your AvoidList (\(engine.avoidList.tokens.count) keywords) and \(engine.symptomReports.count) symptom report(s).")
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DiagnosticStyle.taupe)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pendingShelfRiskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 20))
                    .foregroundStyle(DermadreamTheme.deepUmber)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Not yet scored")
                        .font(DermadreamTheme.displayBold(16))
                        .foregroundStyle(DiagnosticStyle.charcoal)
                    Text("This product was added from your routine. A shelf risk percentage appears after you run an Acute Irritation analysis (Suspect product → Analyse) that includes it in the report’s suspected list.")
                        .font(DermadreamTheme.displaySemibold(13))
                        .foregroundStyle(DiagnosticStyle.taupe)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DiagnosticStyle.card)
        )
        .shadow(color: DermadreamTheme.charcoalGray.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var irritantsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Potential irritants")
                .font(DermadreamTheme.displayBold(18))
                .foregroundStyle(DiagnosticStyle.charcoal)

            if analysis.findings.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(DermadreamTheme.mutedSage)
                    Text("No flagged ingredients against your AvoidList or current sensitivity rules for this formula.")
                        .font(DermadreamTheme.displaySemibold(14))
                        .foregroundStyle(DermadreamTheme.softSlate)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DiagnosticStyle.card)
                )
                .shadow(color: DermadreamTheme.charcoalGray.opacity(0.05), radius: 8, x: 0, y: 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(analysis.findings) { finding in
                        irritantRow(finding)
                    }
                }
            }
        }
    }

    private func irritantRow(_ finding: IrritantFinding) -> some View {
        // Critical alerts (avoid / known correlation / sensitive baseline)
        // get TERRACOTTA. Everything else uses DEEP UMBER so Terracotta
        // remains reserved for warnings.
        let isCritical = finding.severity == .avoid
            || finding.source == .symptomCorrelation
            || finding.source == .sensitiveBaseline
        let accent = isCritical ? DermadreamTheme.terracotta : DermadreamTheme.deepUmber
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(finding.ingredientName)
                    .font(DermadreamTheme.displayBold(16))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                Spacer(minLength: 0)
                Text(finding.severity == .avoid ? "ALERT" : "CAUTION")
                    .font(DermadreamTheme.label(10))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(accent.opacity(0.16)))
                    .foregroundStyle(accent)
            }

            Text(finding.headline)
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DermadreamTheme.charcoalGray)

            Text(finding.detailReason)
                .font(DermadreamTheme.displaySemibold(12))
                .foregroundStyle(DermadreamTheme.softSlate)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DermadreamTheme.softSlate)
                Text(finding.sourceLabel)
                    .font(DermadreamTheme.label(11))
                    .foregroundStyle(DermadreamTheme.softSlate)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DiagnosticStyle.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isCritical
                        ? DermadreamTheme.terracotta.opacity(0.45)
                        : DermadreamTheme.softSlate.opacity(0.2),
                    lineWidth: isCritical ? 1.5 : 1
                )
        )
        .shadow(color: DermadreamTheme.charcoalGray.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var baselineFooter: some View {
        // "Current skin state" header stays charcoal. The state value
        // ("Normal" / "Sensitive") follows the sage/terracotta semantic.
        let isSensitive = analysis.baselineAtAnalysis == .sensitive
        let stateColor = isSensitive
            ? DermadreamTheme.terracotta
            : DermadreamTheme.mutedSage
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(stateColor)
                Text("Current skin state")
                    .font(DermadreamTheme.displayBold(15))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
            }

            Text(analysis.baselineAtAnalysis.rawValue)
                .font(DermadreamTheme.displaySemibold(16))
                .foregroundStyle(stateColor)

            if isSensitive {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DermadreamTheme.terracotta)
                    Text("Risk is elevated due to current skin sensitivity.")
                        .font(DermadreamTheme.displaySemibold(14))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DermadreamTheme.terracotta.opacity(0.12))
                )
            } else {
                Text(analysis.baselineAtAnalysis.detail)
                    .font(DermadreamTheme.displaySemibold(13))
                    .foregroundStyle(DermadreamTheme.softSlate)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Risk meter (local analysis)

private struct RiskMeterView: View {
    let riskPercent: Int

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 18)
                    .frame(width: 168, height: 168)

                Circle()
                    .trim(from: 0, to: CGFloat(riskPercent) / 100)
                    .stroke(
                        AngularGradient(
                            colors: [
                                DermadreamTheme.riskLow,
                                DermadreamTheme.riskMid,
                                DermadreamTheme.riskHigh
                            ],
                            center: .center,
                            angle: .degrees(0)
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .butt)
                    )
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(riskPercent)%")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(DiagnosticStyle.charcoal)
                    Text("Risk index")
                        .font(DermadreamTheme.label(12))
                        .foregroundStyle(DiagnosticStyle.taupe)
                }
            }

            Text(riskCaption)
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DiagnosticStyle.taupe)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }

    private var riskCaption: String {
        switch riskPercent {
        case 0 ..< 25: return "Lower modeled risk against your AvoidList and recent symptom pattern."
        case 25 ..< 55: return "Moderate risk — review flagged ingredients before daily use."
        default: return "Elevated risk — pause introduction until triggers are reconciled."
        }
    }
}

// MARK: - Target Analysis Result (Gemini via TargetProductAnalysisService)

/// Navigation payload that ties the user's input string to the Gemini result.
struct TargetAnalysisPayload: Hashable {
    let targetProduct: String
    let result: AnalysisResult
}

/// Risk level semantics derived from `AnalysisResult.riskLevel`.
private enum RiskLevelStyle {
    case low
    case moderate
    case high

    init(raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "high", "severe", "elevated": self = .high
        case "moderate", "medium": self = .moderate
        default: self = .low
        }
    }

    var accent: Color {
        switch self {
        // TERRACOTTA — reserved for critical warnings only.
        case .high: return DermadreamTheme.terracotta
        // DEEP UMBER — soft warning short of "critical".
        case .moderate: return DermadreamTheme.deepUmber
        // MUTED SAGE — calm / safe state copy.
        case .low: return DermadreamTheme.mutedSage
        }
    }

    var skinStateLabel: String {
        switch self {
        case .high: return "Reactive"
        case .moderate: return "Sensitive"
        case .low: return "Normal"
        }
    }

    var skinStateDetail: String {
        switch self {
        case .high:
            return "Barrier is reactive. Hold off on this product and patch-test behind the ear if you do introduce it."
        case .moderate:
            return "Current skin is more reactive than baseline. Limit introductions to one new product at a time."
        case .low:
            return "Balanced barrier; standard screening thresholds."
        }
    }

    var riskCaption: String {
        switch self {
        case .high:
            return "Elevated risk — consider alternatives or consult a dermatologist."
        case .moderate:
            return "Moderate risk — review flagged ingredients before daily use."
        case .low:
            return "Low risk — this product looks compatible with your skin profile."
        }
    }
}

struct TargetAnalysisResultView: View {
    let targetProduct: String
    /// `nil` while the request is in flight — renders skeletons + shimmer.
    let result: AnalysisResult?

    private var riskStyle: RiskLevelStyle {
        RiskLevelStyle(raw: result?.riskLevel ?? "")
    }

    private var clampedScore: Int {
        min(max(result?.irritationScorePercentage ?? 0, 0), 100)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerBlock

                gaugeBlock

                summaryCaption

                irritantsSection

                skinStateSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(DiagnosticStyle.canvas.ignoresSafeArea())
        .navigationTitle("Safety report")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(targetProduct)
                .font(DermadreamTheme.displayBold(24))
                .foregroundStyle(DiagnosticStyle.charcoal)

            Text((result?.riskLevel ?? "Analyzing").uppercased())
                .font(DermadreamTheme.label(11))
                .foregroundStyle(DiagnosticStyle.taupe)
                .modifier(ShimmerIf(result == nil))

            Text("Cross-referenced against your product history in dermadream")
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DiagnosticStyle.taupe)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Circular gauge

    private var gaugeBlock: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.06), lineWidth: 18)
                .frame(width: 168, height: 168)

            if let result {
                Circle()
                    .trim(from: 0, to: CGFloat(clampedScore) / 100)
                    .stroke(
                        AngularGradient(
                            colors: [
                                DermadreamTheme.riskLow,
                                DermadreamTheme.riskMid,
                                DermadreamTheme.riskHigh
                            ],
                            center: .center,
                            angle: .degrees(0)
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .butt)
                    )
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: result)

                VStack(spacing: 4) {
                    Text("\(clampedScore)%")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(DiagnosticStyle.charcoal)
                    Text("Risk index")
                        .font(DermadreamTheme.label(12))
                        .foregroundStyle(DiagnosticStyle.taupe)
                }
            } else {
                Circle()
                    .stroke(
                        DermadreamTheme.teal.opacity(0.18),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: 168, height: 168)
                    .modifier(Shimmer())

                VStack(spacing: 6) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 80, height: 28)
                        .modifier(Shimmer())
                    Capsule()
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 54, height: 10)
                        .modifier(Shimmer())
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary (description under the gauge)

    @ViewBuilder
    private var summaryCaption: some View {
        if let summary = result?.summaryAnalysis, !summary.isEmpty {
            Text(summary)
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DiagnosticStyle.taupe)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        } else if result != nil {
            Text(riskStyle.riskCaption)
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DiagnosticStyle.taupe)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 8) {
                Capsule().fill(Color.black.opacity(0.06)).frame(height: 10)
                Capsule().fill(Color.black.opacity(0.06)).frame(height: 10).padding(.horizontal, 40)
            }
            .modifier(Shimmer())
        }
    }

    // MARK: - Potential irritants

    private var irritantsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Potential irritants")
                .font(DermadreamTheme.displayBold(18))
                .foregroundStyle(DiagnosticStyle.charcoal)

            if let result {
                if result.concerningIngredients.isEmpty {
                    emptyIrritantsCard
                } else {
                    VStack(spacing: 12) {
                        ForEach(result.concerningIngredients) { ingredient in
                            ingredientRow(ingredient)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    irritantSkeletonRow
                    irritantSkeletonRow
                }
            }
        }
    }

    private var emptyIrritantsCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(DermadreamTheme.mutedSage)
            Text("No flagged ingredients against your AvoidList or current sensitivity rules for this formula.")
                .font(DermadreamTheme.displaySemibold(14))
                .foregroundStyle(DermadreamTheme.softSlate)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DiagnosticStyle.card)
        )
        .shadow(color: DermadreamTheme.charcoalGray.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func ingredientRow(_ ingredient: ConcerningIngredient) -> some View {
        let pct = min(max(ingredient.irritationContributionPercentage, 0), 100)
        let isHigh = pct >= 50
        // Critical (high contribution) → Terracotta. Otherwise stay neutral
        // with Deep Umber so Terracotta remains reserved for warnings.
        let accent = isHigh ? DermadreamTheme.terracotta : DermadreamTheme.deepUmber
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ingredient.ingredientName)
                    .font(DermadreamTheme.displayBold(16))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                Spacer(minLength: 0)
                Text("\(pct)%")
                    .font(DermadreamTheme.displayBold(14))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(accent.opacity(0.16))
                    )
                    .foregroundStyle(accent)
            }

            Text(ingredient.reason)
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DermadreamTheme.softSlate)
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { geo in
                let fill = geo.size.width * CGFloat(pct) / 100
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DermadreamTheme.softSlate.opacity(0.18))
                        .frame(height: 6)
                    Capsule()
                        .fill(accent)
                        .frame(width: max(4, fill), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DiagnosticStyle.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isHigh
                        ? DermadreamTheme.terracotta.opacity(0.45)
                        : DermadreamTheme.softSlate.opacity(0.2),
                    lineWidth: isHigh ? 1.5 : 1
                )
        )
        .shadow(color: DermadreamTheme.charcoalGray.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var irritantSkeletonRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule().fill(Color.black.opacity(0.08)).frame(height: 18).frame(maxWidth: 180)
            Capsule().fill(Color.black.opacity(0.06)).frame(height: 10)
            Capsule().fill(Color.black.opacity(0.06)).frame(height: 10).padding(.trailing, 80)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DiagnosticStyle.card)
        )
        .modifier(Shimmer())
    }

    // MARK: - Current skin state

    private var skinStateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(riskStyle.accent)
                Text("Current skin state")
                    .font(DermadreamTheme.displayBold(15))
                    .foregroundStyle(DiagnosticStyle.charcoal)
            }

            Text(riskStyle.skinStateLabel)
                .font(DermadreamTheme.displaySemibold(16))
                .foregroundStyle(riskStyle.accent)
                .modifier(ShimmerIf(result == nil))

            if riskStyle == .high {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DermadreamTheme.terracotta)
                    Text("Risk is elevated — this product contains ingredients that have flared your skin before.")
                        .font(DermadreamTheme.displaySemibold(14))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DermadreamTheme.terracotta.opacity(0.12))
                )
            } else {
                Text(riskStyle.skinStateDetail)
                    .font(DermadreamTheme.displaySemibold(13))
                    .foregroundStyle(DermadreamTheme.softSlate)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Shimmer

/// Lightweight shimmer used for the skeleton state on the gauge + rows.
private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -0.8

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.55),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 1.5)
                    .offset(x: phase * geo.size.width)
                    .blendMode(.plusLighter)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

/// Conditionally applies `Shimmer` without changing the view hierarchy identity.
private struct ShimmerIf: ViewModifier {
    let isActive: Bool

    init(_ isActive: Bool) {
        self.isActive = isActive
    }

    func body(content: Content) -> some View {
        Group {
            if isActive {
                content.modifier(Shimmer())
            } else {
                content
            }
        }
    }
}

// MARK: - Manual Product Entry Sheet

private struct ManualProductEntrySheet: View {
    @EnvironmentObject private var engine: DermadreamEngine
    @Binding var isPresented: Bool
    var onAnalyzed: (_ targetProduct: String, _ result: AnalysisResult) -> Void
    @State private var productName = ""
    @State private var brand = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case productName
        case brand
    }

    private var trimmedName: String {
        productName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBrand: String {
        brand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Combined "<brand> <product>" string (or just product if brand empty),
    /// with whitespace normalised so there are never double spaces.
    private var combinedTargetProductName: String {
        let name = trimmedName
        let brandValue = trimmedBrand
        let combined = brandValue.isEmpty ? name : "\(brandValue) \(name)"
        return combined
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
    }

    private var isValid: Bool {
        !trimmedName.isEmpty
    }

    private var canSubmit: Bool {
        isValid && !isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enter a product to analyze")
                        .font(DermadreamTheme.displayBold(20))
                        .foregroundStyle(DiagnosticStyle.charcoal)
                    Text("Dermadream AI will identify the product, retrieve its ingredients, and cross-check against your skin profile.")
                        .font(DermadreamTheme.displaySemibold(14))
                        .foregroundStyle(DiagnosticStyle.taupe)
                }

                VStack(spacing: 14) {
                    inputField(placeholder: "Product name", text: $productName)
                        .focused($focusedField, equals: .productName)
                        .disabled(isLoading)
                    inputField(placeholder: "Brand (optional)", text: $brand)
                        .focused($focusedField, equals: .brand)
                        .disabled(isLoading)
                }

                analyzeButton

                if let errorMessage {
                    Text(errorMessage)
                        .font(DermadreamTheme.displaySemibold(13))
                        .foregroundStyle(DermadreamTheme.terracotta)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
            .background(DermadreamTheme.creamShell.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Manual input")
                        .font(DermadreamTheme.displaySemibold(17))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                        .font(DermadreamTheme.displaySemibold(16))
                        .foregroundStyle(DermadreamTheme.deepUmber)
                        .disabled(isLoading)
                }
            }
            .toolbarBackground(DermadreamTheme.creamShell, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .interactiveDismissDisabled(isLoading)
        }
    }

    private var analyzeButton: some View {
        Button(action: submit) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Analyzing...")
                } else {
                    Text("Analyze with AI")
                }
            }
            .font(DermadreamTheme.displaySemibold(16))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        canSubmit
                            ? DermadreamTheme.deepUmber
                            : DermadreamTheme.deepUmber.opacity(0.4)
                    )
                    .shadow(
                        color: DermadreamTheme.deepUmber.opacity(canSubmit ? 0.18 : 0),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
            )
        }
        .disabled(!canSubmit)
    }

    private func submit() {
        let target = combinedTargetProductName
        guard !target.isEmpty else { return }

        errorMessage = nil
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                let result = try await engine.analyzeTargetProduct(targetProduct: target)
                isPresented = false
                onAnalyzed(target, result)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func inputField(placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt:
            Text(placeholder)
                .foregroundStyle(DermadreamTheme.softSlate)
        )
        .font(DermadreamTheme.displaySemibold(16))
        .foregroundStyle(DermadreamTheme.charcoalGray)
        .tint(DermadreamTheme.deepUmber)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DermadreamTheme.creamShell)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DermadreamTheme.softSlate.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: DermadreamTheme.charcoalGray.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Barcode Scanner Sheet

private struct BarcodeScannerSheet: View {
    @EnvironmentObject private var engine: DermadreamEngine
    @Binding var isPresented: Bool

    /// Called after both Barcode Lookup *and* Gemini analysis succeed.
    /// The parent uses the payload to drive `navigationDestination`.
    var onAnalyzed: (TargetAnalysisPayload) -> Void

    /// Called when the user opts to fall back to the manual-input flow
    /// (either from the not-found alert or when VisionKit is unsupported).
    var onRequestManualInput: () -> Void

    @State private var manualBarcode = ""
    @State private var cameraAuthorized: Bool? = nil
    @State private var phase: Phase = .idle
    @State private var activeAlert: ActiveAlert?
    @State private var scannerResetToken = UUID()

    private enum Phase: Equatable {
        case idle
        case processing(barcode: String)
    }

    private enum ActiveAlert: Identifiable {
        case notFound
        case error(String)

        var id: String {
            switch self {
            case .notFound: return "not_found"
            case .error(let message): return "error:\(message)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    scannerArea

                    manualFallback
                }

                if case let .processing(barcode) = phase {
                    processingOverlay(barcode: barcode)
                        .transition(.opacity)
                }
            }
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                        .foregroundStyle(DermadreamTheme.teal)
                        .disabled(phase != .idle)
                }
            }
            .task {
                await checkCameraAccess()
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .notFound:
                    return Alert(
                        title: Text("Product not found"),
                        message: Text("Product not found. Please try Manual Input."),
                        primaryButton: .default(Text("Manual Input")) {
                            isPresented = false
                            // Give the sheet a moment to dismiss before the
                            // parent presents the manual sheet.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onRequestManualInput()
                            }
                        },
                        secondaryButton: .cancel(Text("Close")) {
                            resumeScanning()
                        }
                    )
                case .error(let message):
                    return Alert(
                        title: Text("Something went wrong"),
                        message: Text(message),
                        dismissButton: .default(Text("OK")) {
                            resumeScanning()
                        }
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: phase)
        }
    }

    // MARK: - Scanner

    @ViewBuilder
    private var scannerArea: some View {
        if ProductLookupDataScanner.isSupported {
            switch cameraAuthorized {
            case .some(true):
                ProductLookupDataScanner(
                    resetToken: scannerResetToken,
                    isPaused: phase != .idle
                ) { code in
                    handleScannedBarcode(code)
                }
                .ignoresSafeArea(edges: .bottom)
            case .some(false):
                cameraUnavailableView
            case .none:
                ProgressView("Requesting camera access...")
                    .tint(DermadreamTheme.teal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            unsupportedDeviceView
        }
    }

    private var cameraUnavailableView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.6))
            Text("Camera access required")
                .font(DermadreamTheme.displayBold(18))
                .foregroundStyle(.white)
            Text("Enable camera access in Settings to scan barcodes, or enter the code manually below.")
                .font(DermadreamTheme.displaySemibold(14))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var unsupportedDeviceView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.6))
            Text("Scanner not available")
                .font(DermadreamTheme.displayBold(18))
                .foregroundStyle(.white)
            Text("This device can't run the live barcode scanner. Enter the barcode manually below, or use Manual Input.")
                .font(DermadreamTheme.displaySemibold(14))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Manual barcode fallback

    private var manualFallback: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("Or enter barcode manually...", text: $manualBarcode)
                    .font(DermadreamTheme.displaySemibold(15))
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                    .foregroundStyle(.white)
                    .disabled(phase != .idle)

                Button {
                    let code = manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !code.isEmpty else { return }
                    handleScannedBarcode(code)
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DermadreamTheme.teal)
                }
                .disabled(
                    phase != .idle ||
                    manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }

            #if targetEnvironment(simulator)
            Button {
                // Real EAN-13 for CeraVe Hydrating Cleanser — swap freely
                // while iterating on the scan → lookup → Gemini pipeline.
                handleScannedBarcode("3606000624078")
            } label: {
                Label("Simulate Scan", systemImage: "hammer.fill")
                    .font(DermadreamTheme.displaySemibold(13))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DermadreamTheme.teal.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(DermadreamTheme.teal, lineWidth: 1)
                            )
                    )
            }
            .disabled(phase != .idle)
            #endif
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    // MARK: - Processing overlay

    private func processingOverlay(barcode: String) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(DermadreamTheme.teal)
                    .scaleEffect(1.4)

                Text("Identifying product and checking ingredients...")
                    .font(DermadreamTheme.displaySemibold(15))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Barcode \(barcode)")
                    .font(DermadreamTheme.displaySemibold(12))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(DermadreamTheme.teal.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Flow

    private func handleScannedBarcode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, phase == .idle else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        phase = .processing(barcode: trimmed)

        Task {
            do {
                let payload = try await engine.analyzeScannedBarcode(trimmed)
                await MainActor.run {
                    phase = .idle
                    isPresented = false
                    onAnalyzed(payload)
                }
            } catch let lookupError as ProductLookupError {
                await MainActor.run {
                    phase = .idle
                    switch lookupError {
                    case .notFound:
                        activeAlert = .notFound
                    default:
                        activeAlert = .error(lookupError.localizedDescription)
                    }
                }
            } catch {
                await MainActor.run {
                    phase = .idle
                    activeAlert = .error(error.localizedDescription)
                }
            }
        }
    }

    private func resumeScanning() {
        manualBarcode = ""
        scannerResetToken = UUID()
    }

    private func checkCameraAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
        default:
            cameraAuthorized = false
        }
    }
}

#Preview {
    NavigationStack {
        ProductsView()
            .environmentObject(DermadreamEngine())
    }
}
