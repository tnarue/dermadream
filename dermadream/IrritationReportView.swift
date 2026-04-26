//
//  IrritationReportView.swift
//  dermadream
//
//  Renders the Acute Irritation report returned by Gemini.
//
//  Layout (top -> bottom):
//   1. Routine Safety Score gauge (0-100, red -> yellow at 40% of ring -> green at 80%)
//      paired with a small radar chart of symptom correlations.
//   2. Routine Heatmap — six product-category tiles (3 per row); values use
//      product risk when a suspect matches the routine, else the report %.
//   3. High-Risk Ingredients list with Danger tag + probability bar.
//   4. Suspected Products list with ingredient tags (sourced from
//      Top Offender / Flagged Ingredients) + probability bar.
//

import SwiftUI

struct IrritationReportView: View {
    @EnvironmentObject private var engine: DermadreamEngine
    @EnvironmentObject private var appModel: AppModel
    let context: AcuteIrritationContext

    @State private var showQuickMenu = false
    @State private var showAnatomyFromReport = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heroHeader

                    if engine.isAnalyzingAcuteIrritation && engine.acuteIrritationReport == nil {
                        loadingCard
                    } else if let report = engine.acuteIrritationReport {
                        safetyScoreSection(report)
                        routineHeatmapSection(report)
                        highRiskIngredientsSection(report)
                        suspectedProductsSection(report)
                        summaryFooter(report)
                    } else if let err = engine.acuteIrritationError {
                        errorCard(err)
                    }
                }
                .padding(20)
                .padding(.bottom, 8)
            }
            .background(DermadreamTheme.creamShell.ignoresSafeArea())

            if showQuickMenu {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            showQuickMenu = false
                        }
                    }
                reportQuickMenuCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: showQuickMenu)
        .background(DermadreamTheme.creamShell.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Irritation report")
                    .font(DermadreamTheme.displaySemibold(17))
                    .foregroundStyle(DermadreamTheme.deepUmber)
            }
        }
        .toolbarBackground(DermadreamTheme.creamShell, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                DermadreamTabBar(
                    selected: $appModel.selectedTab,
                    inactiveTint: DermadreamTheme.softSlate,
                    onCenterTap: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            showQuickMenu = true
                        }
                    },
                    onTabSelect: { appModel.showWelcome = false }
                )
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .frame(maxWidth: .infinity)
                .background {
                    DermadreamTheme.creamShell
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(DermadreamTheme.sandstone.opacity(0.28))
                                .frame(height: 1)
                        }
                }
            }
        }
        .sheet(isPresented: $showAnatomyFromReport) {
            NavigationStack {
                AnatomySelectionView()
                    .environmentObject(engine)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showAnatomyFromReport = false }
                                .foregroundStyle(DermadreamTheme.deepUmber)
                        }
                    }
            }
        }
    }

    private var reportQuickMenuCard: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DermadreamTheme.softSlate.opacity(0.4))
                .frame(width: 38, height: 4)
                .padding(.top, 10)
            Text("Quick Menu")
                .font(DermadreamTheme.displaySemibold(15))
                .foregroundStyle(DermadreamTheme.softSlate)
                .padding(.top, 14)
                .padding(.bottom, 12)
            VStack(spacing: 10) {
                reportMenuRow(title: "Acute Irritation", systemImage: "face.smiling.inverse") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(DermadreamTheme.mainTabChangeAnimation) {
                            showAnatomyFromReport = true
                        }
                    }
                }
                reportMenuRow(title: "Product Check", systemImage: "barcode.viewfinder") {
                    appModel.showWelcome = false
                    withAnimation(DermadreamTheme.mainTabChangeAnimation) {
                        appModel.selectedTab = .products
                    }
                }
                reportMenuRow(title: "Add New Product", systemImage: "drop.halffull") {
                    appModel.showWelcome = false
                    withAnimation(DermadreamTheme.mainTabChangeAnimation) {
                        appModel.selectedTab = .routine
                    }
                }
            }
            .padding(.horizontal, 16)
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    showQuickMenu = false
                }
            } label: {
                Text("Cancel")
                    .font(DermadreamTheme.displaySemibold(16))
                    .foregroundStyle(DermadreamTheme.deepUmber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DermadreamTheme.sandstone.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DermadreamTheme.creamShell)
                .shadow(color: DermadreamTheme.charcoalGray.opacity(0.18), radius: 24, x: 0, y: -6)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func reportMenuRow(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { showQuickMenu = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: action)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DermadreamTheme.deepUmber)
                    .frame(width: 28)
                Text(title)
                    .font(DermadreamTheme.displaySemibold(16))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DermadreamTheme.sandstone.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What’s causing your irritation?")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(DermadreamTheme.charcoalGray)
                .fixedSize(horizontal: false, vertical: true)
            Text(context.concernHeadline)
                .font(DermadreamTheme.displaySemibold(14))
                .foregroundStyle(DermadreamTheme.softSlate)
        }
    }

    // MARK: - 1. Safety score + radar

    @ViewBuilder
    private func safetyScoreSection(_ report: AcuteIrritationReport) -> some View {
        reportCard {
            HStack(alignment: .top, spacing: 18) {
                SafetyScoreGauge(score: report.routineSafetyScore)
                    .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Routine Safety Score")
                        .font(DermadreamTheme.displayBold(16))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                    Text("Higher is safer. We weigh shared irritants across your routine against the symptom you reported.")
                        .font(DermadreamTheme.displaySemibold(12))
                        .foregroundStyle(DermadreamTheme.softSlate)

                    SymptomRadar(correlations: report.symptomCorrelations)
                        .frame(height: 130)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - 2. Routine heatmap

    @ViewBuilder
    private func routineHeatmapSection(_ report: AcuteIrritationReport) -> some View {
        reportCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Routine heatmap")
                    .font(DermadreamTheme.displayBold(17))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                Text("Six core categories, three per row. Percentages use your product risk when a suspect matches a routine line.")
                    .font(DermadreamTheme.displaySemibold(12))
                    .foregroundStyle(DermadreamTheme.softSlate)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 16
                ) {
                    ForEach(HeatmapCategory.allCases) { category in
                        let probability = topProbability(for: category, in: report)
                        HeatmapTile(category: category, probability: probability)
                    }
                }
            }
        }
    }

    private func topProbability(for category: HeatmapCategory, in report: AcuteIrritationReport) -> Int {
        report.suspectedProducts
            .filter { suspectedProductBelongs($0, in: category) }
            .map { engine.heatmapDisplayRiskPercent(for: $0) }
            .max() ?? 0
    }

    private func suspectedProductBelongs(_ sp: SuspectedProduct, in category: HeatmapCategory) -> Bool {
        let raw = sp.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty {
            return category == .other
        }
        if category == .other {
            if raw.caseInsensitiveCompare("Other") == .orderedSame { return true }
            let knownCore = Set(
                [HeatmapCategory.cleanser, .toner, .serum, .moisturizer, .spf]
                    .map { $0.rawValue }
            )
            return !knownCore.contains(where: { raw.caseInsensitiveCompare($0) == .orderedSame })
        }
        if category == .spf {
            return raw.caseInsensitiveCompare(HeatmapCategory.spf.rawValue) == .orderedSame
                || raw.caseInsensitiveCompare("Sunscreen") == .orderedSame
        }
        return raw.caseInsensitiveCompare(category.rawValue) == .orderedSame
    }

    // MARK: - 3. High-risk ingredients

    @ViewBuilder
    private func highRiskIngredientsSection(_ report: AcuteIrritationReport) -> some View {
        reportCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("High-risk ingredients")
                        .font(DermadreamTheme.displayBold(17))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                    Spacer()
                    if let top = report.topOffender {
                        Text("Top offender: \(top.ingredient)")
                            .font(DermadreamTheme.displaySemibold(12))
                            .foregroundStyle(DermadreamTheme.terracotta)
                    }
                }

                if report.flaggedIngredients.isEmpty {
                    emptyBlock("No high-risk ingredients flagged.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(report.flaggedIngredients.sorted(by: { $0.irritationProbability > $1.irritationProbability })) { item in
                            ingredientRow(item)
                        }
                    }
                }
            }
        }
    }

    private func ingredientRow(_ item: FlaggedIngredient) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(DermadreamTheme.displaySemibold(15))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                    Text(item.reason)
                        .font(DermadreamTheme.displaySemibold(12))
                        .foregroundStyle(DermadreamTheme.softSlate)
                }
                Spacer(minLength: 0)
                dangerTag(probability: item.irritationProbability)
            }

            ProbabilityBar(value: item.irritationProbability)

            if !item.foundIn.isEmpty {
                FlowChips(tags: item.foundIn, color: DermadreamTheme.deepUmber)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DermadreamTheme.creamShell)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DermadreamTheme.sandstone.opacity(0.55), lineWidth: 1)
                )
        )
    }

    private func dangerTag(probability: Int) -> some View {
        let tone = dangerTone(for: probability)
        return Text(tone.label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tone.color))
    }

    private func dangerTone(for probability: Int) -> (label: String, color: Color) {
        switch probability {
        case ..<33: return ("LOW", DermadreamTheme.mutedSage)
        case 33..<66: return ("CAUTION", DermadreamTheme.deepUmber)
        default: return ("DANGER", DermadreamTheme.terracotta)
        }
    }

    // MARK: - 4. Suspected products

    @ViewBuilder
    private func suspectedProductsSection(_ report: AcuteIrritationReport) -> some View {
        reportCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Suspected products")
                    .font(DermadreamTheme.displayBold(17))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                Text("Sorted by likelihood. Tags reuse the top-offender and flagged-ingredient lists.")
                    .font(DermadreamTheme.displaySemibold(12))
                    .foregroundStyle(DermadreamTheme.softSlate)

                if report.suspectedProducts.isEmpty {
                    emptyBlock("No products were singled out — your routine looks balanced for this concern.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(report.suspectedProducts.sorted(by: { $0.irritationProbability > $1.irritationProbability })) { item in
                            suspectedProductRow(item)
                        }
                    }
                }
            }
        }
    }

    private func suspectedProductRow(_ item: SuspectedProduct) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DermadreamTheme.sandstone.opacity(0.5))
                        .frame(width: 36, height: 36)
                    Image(systemName: HeatmapCategory(rawValue: item.category ?? "Other")?.icon ?? "drop.halffull")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DermadreamTheme.deepUmber)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(DermadreamTheme.displaySemibold(15))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                    if let category = item.category, !category.isEmpty {
                        Text(category)
                            .font(DermadreamTheme.displaySemibold(12))
                            .foregroundStyle(DermadreamTheme.softSlate)
                    }
                }
                Spacer(minLength: 0)
                dangerTag(probability: item.irritationProbability)
            }

            ProbabilityBar(value: item.irritationProbability)

            if !item.flaggedTags.isEmpty {
                FlowChips(tags: item.flaggedTags, color: DermadreamTheme.terracotta)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DermadreamTheme.creamShell)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DermadreamTheme.sandstone.opacity(0.55), lineWidth: 1)
                )
        )
    }

    // MARK: - Footer summary

    @ViewBuilder
    private func summaryFooter(_ report: AcuteIrritationReport) -> some View {
        if !report.summary.isEmpty {
            reportCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI summary")
                        .font(DermadreamTheme.displayBold(16))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                    Text(report.summary)
                        .font(DermadreamTheme.displaySemibold(14))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                }
            }
        }
    }

    // MARK: - Loading + error

    private var loadingCard: some View {
        reportCard {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(DermadreamTheme.deepUmber)
                Text("Analyzing your routine…")
                    .font(DermadreamTheme.displaySemibold(14))
                    .foregroundStyle(DermadreamTheme.softSlate)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        }
    }

    private func errorCard(_ message: String) -> some View {
        reportCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DermadreamTheme.terracotta)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Couldn't analyse this report")
                        .font(DermadreamTheme.displayBold(15))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                    Text(message)
                        .font(DermadreamTheme.displaySemibold(13))
                        .foregroundStyle(DermadreamTheme.softSlate)
                }
            }
        }
    }

    // MARK: - Reusable building blocks

    private func reportCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(DermadreamTheme.sandstone.opacity(0.55), lineWidth: 1)
                    )
            )
            .shadow(color: DermadreamTheme.charcoalGray.opacity(0.06), radius: 14, x: 0, y: 6)
    }

    private func emptyBlock(_ message: String) -> some View {
        Text(message)
            .font(DermadreamTheme.displaySemibold(13))
            .foregroundStyle(DermadreamTheme.softSlate)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DermadreamTheme.sandstone.opacity(0.25))
            )
    }
}

// MARK: - Safety score gauge

private struct SafetyScoreGauge: View {
    let score: Int

    private var clamped: Double { Double(min(100, max(0, score))) }

    /// Full-ring gradient: red → **yellow at 40%** of the ring → **green at 80%** → green to 100%.
    /// A score of 42 sits just past the yellow stop, so the arc end reads yellow / yellow-green, not “safe” green.
    private static var safetyRingGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: DermadreamTheme.riskHigh, location: 0),
                .init(color: DermadreamTheme.riskMid, location: 0.4),
                .init(color: DermadreamTheme.riskLow, location: 0.8),
                .init(color: DermadreamTheme.riskLow, location: 1.0)
            ]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    var body: some View {
        let progress = clamped / 100
        ZStack {
            Circle()
                .stroke(DermadreamTheme.sandstone.opacity(0.4), style: StrokeStyle(lineWidth: 14, lineCap: .round))

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Self.safetyRingGradient,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                Text("/ 100")
                    .font(DermadreamTheme.displaySemibold(12))
                    .foregroundStyle(DermadreamTheme.softSlate)
            }
        }
    }
}

// MARK: - Symptom radar

private struct SymptomRadar: View {
    let correlations: [SymptomCorrelation]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: size / 2)
            let radius = size / 2 - 6
            let count = max(correlations.count, 3)

            ZStack {
                // Concentric guides
                ForEach(1...3, id: \.self) { ring in
                    radarPolygon(count: count, radius: radius * CGFloat(ring) / 3, center: center)
                        .stroke(DermadreamTheme.sandstone.opacity(0.4), lineWidth: 0.8)
                }

                if correlations.isEmpty {
                    Text("No symptoms reported")
                        .font(DermadreamTheme.displaySemibold(11))
                        .foregroundStyle(DermadreamTheme.softSlate)
                } else {
                    radarShape(count: count, radius: radius, center: center)
                        .fill(DermadreamTheme.terracotta.opacity(0.25))
                    radarShape(count: count, radius: radius, center: center)
                        .stroke(DermadreamTheme.terracotta, lineWidth: 1.5)

                    ForEach(Array(correlations.enumerated()), id: \.offset) { idx, corr in
                        let angle = angleFor(index: idx, count: count)
                        let labelPoint = pointAt(angle: angle, radius: radius + 4, center: center)
                        Text("\(corr.symptom)")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(DermadreamTheme.charcoalGray)
                            .position(labelPoint)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func angleFor(index: Int, count: Int) -> Angle {
        .degrees(Double(index) / Double(count) * 360 - 90)
    }

    private func pointAt(angle: Angle, radius: CGFloat, center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle.radians)),
            y: center.y + radius * CGFloat(sin(angle.radians))
        )
    }

    private func radarShape(count: Int, radius: CGFloat, center: CGPoint) -> Path {
        Path { path in
            for (idx, corr) in correlations.enumerated() {
                let value = CGFloat(min(100, max(0, corr.matchPercent))) / 100
                let angle = angleFor(index: idx, count: count)
                let point = pointAt(angle: angle, radius: radius * value, center: center)
                if idx == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
    }

    private func radarPolygon(count: Int, radius: CGFloat, center: CGPoint) -> Path {
        Path { path in
            for idx in 0..<count {
                let angle = angleFor(index: idx, count: count)
                let point = pointAt(angle: angle, radius: radius, center: center)
                if idx == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
    }
}

// MARK: - Routine heatmap tile

private enum HeatmapCategory: String, CaseIterable, Identifiable {
    case cleanser = "Cleanser"
    case toner = "Toner"
    case serum = "Serum"
    case moisturizer = "Moisturizer"
    case spf = "SPF"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cleanser: return "drop.fill"
        case .toner: return "wand.and.stars"
        case .serum: return "eyedropper.halffull"
        case .moisturizer: return "circle.hexagongrid.fill"
        case .spf: return "sun.max.fill"
        case .other: return "square.grid.2x2"
        }
    }
}

private struct HeatmapTile: View {
    let category: HeatmapCategory
    let probability: Int

    private var glow: Color {
        switch probability {
        case ..<33: return .clear
        case 33..<66: return DermadreamTheme.deepUmber.opacity(0.18)
        default: return DermadreamTheme.terracotta.opacity(0.35)
        }
    }

    private var stroke: Color {
        probability >= 33 ? DermadreamTheme.terracotta : DermadreamTheme.sandstone.opacity(0.7)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(DermadreamTheme.creamShell)
                    .overlay(Circle().stroke(stroke, lineWidth: probability >= 33 ? 1.4 : 1))
                    .shadow(color: glow, radius: probability >= 66 ? 10 : 6, x: 0, y: 0)
                    .frame(width: 46, height: 46)
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(probability >= 33 ? DermadreamTheme.terracotta : DermadreamTheme.deepUmber)
            }
            Text(category.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(DermadreamTheme.softSlate)
            if probability > 0 {
                Text("\(probability)%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(probability >= 33 ? DermadreamTheme.terracotta : DermadreamTheme.deepUmber)
            } else {
                Text("—")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DermadreamTheme.softSlate)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Probability bar

private struct ProbabilityBar: View {
    let value: Int

    var body: some View {
        let progress = CGFloat(min(100, max(0, value))) / 100
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DermadreamTheme.sandstone.opacity(0.45))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [DermadreamTheme.deepUmber, DermadreamTheme.terracotta],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Chip flow

private struct FlowChips: View {
    let tags: [String]
    let color: Color

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 90), spacing: 6, alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.12))
                    )
            }
        }
    }
}

#Preview {
    NavigationStack {
        IrritationReportView(
            context: AcuteIrritationContext(
                regions: [.leftCheek, .rightCheek],
                irritationType: .visual,
                visualSymptoms: [.redness],
                nonVisualSymptoms: [.burning],
                severity: 4
            )
        )
        .environmentObject(DermadreamEngine())
        .environmentObject(AppModel())
    }
}
