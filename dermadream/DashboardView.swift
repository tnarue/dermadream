//
//  DashboardView.swift
//  dermadream
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var engine: DermadreamEngine
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mission control")
                    .font(DermadreamTheme.displayBold(26))
                    .foregroundStyle(DermadreamTheme.charcoalGray)

                Text("Live snapshot of your barrier, routine load, and irritant pressure.")
                    .font(DermadreamTheme.displaySemibold(14))
                    .foregroundStyle(DermadreamTheme.softSlate)

                HStack(spacing: 12) {
                    metricTile(
                        title: "Baseline",
                        value: engine.baselineSkin.rawValue,
                        systemImage: "shield.checkered",
                        tint: DermadreamTheme.deepUmber
                    )
                    metricTile(
                        title: "Tracked products",
                        value: "\(engine.currentRoutineShelfProducts.count)",
                        systemImage: "shippingbox",
                        tint: DermadreamTheme.mutedSage
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Fast actions")
                        .font(DermadreamTheme.displayBold(17))
                        .foregroundStyle(DermadreamTheme.charcoalGray)

                    NavigationLink {
                        AnatomySelectionView()
                    } label: {
                        actionRow(
                            title: "Map acute irritation",
                            subtitle: "Segment anatomy + severity",
                            systemImage: "face.smiling.inverse",
                            tint: DermadreamTheme.terracotta
                        )
                    }

                    Button {
                        appModel.showChatSheet = true
                    } label: {
                        actionRow(
                            title: "Open AI triage",
                            subtitle: "Describe timing, products, and triggers",
                            systemImage: "bubble.left.and.text.bubble.right.fill",
                            tint: DermadreamTheme.deepUmber
                        )
                    }
                }
                .padding(16)
                .background(cardChrome)

                conflictPreview
            }
            .padding(20)
        }
        .background(DermadreamTheme.workspaceBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var conflictPreview: some View {
        if let product = engine.currentRoutineShelfProducts.first {
            let conflicts = engine.conflicts(for: product)
            let plan = engine.recoveryRoutine(for: product, conflicts: conflicts)

            VStack(alignment: .leading, spacing: 12) {
                Text("Prototype signal")
                    .font(DermadreamTheme.displayBold(17))
                    .foregroundStyle(DermadreamTheme.charcoalGray)

                Text("Sample scan on \(product.name) — \(conflicts.count) hit(s).")
                    .font(DermadreamTheme.displaySemibold(14))
                    .foregroundStyle(DermadreamTheme.softSlate)

                if conflicts.isEmpty {
                    Text("No hard conflicts detected against your current allergen list.")
                        .font(DermadreamTheme.displaySemibold(14))
                        .foregroundStyle(DermadreamTheme.softSlate)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(conflicts.prefix(3))) { hit in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: hit.severity == .avoid ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(hit.severity == .avoid ? DermadreamTheme.terracotta : DermadreamTheme.deepUmber)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hit.ingredientName)
                                        .font(DermadreamTheme.displaySemibold(14))
                                        .foregroundStyle(DermadreamTheme.charcoalGray)
                                    Text(hit.rationale)
                                        .font(DermadreamTheme.label(12))
                                        .foregroundStyle(DermadreamTheme.softSlate)
                                }
                            }
                        }
                    }
                }

                Divider().opacity(0.25)

                Text("Recovery sketch")
                    .font(DermadreamTheme.displayBold(15))
                    .foregroundStyle(DermadreamTheme.charcoalGray)

                bulletList(title: "Pause", items: plan.stopProducts)
                bulletList(title: "Introduce", items: plan.startProducts)
            }
            .padding(16)
            .background(cardChrome)
        }
    }

    private func bulletList(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(DermadreamTheme.label(11))
                .foregroundStyle(DermadreamTheme.softSlate)
            ForEach(items, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(DermadreamTheme.deepUmber)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(line)
                        .font(DermadreamTheme.displaySemibold(14))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                }
            }
        }
    }

    private var cardChrome: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white)
            .shadow(color: DermadreamTheme.charcoalGray.opacity(0.06), radius: 16, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(DermadreamTheme.subtleBorder, lineWidth: 1)
            )
    }

    private func metricTile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
            Text(title.uppercased())
                .font(DermadreamTheme.label(11))
                .foregroundStyle(DermadreamTheme.softSlate)
            Text(value)
                .font(DermadreamTheme.displayBold(20))
                .foregroundStyle(DermadreamTheme.charcoalGray)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardChrome)
    }

    private func actionRow(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DermadreamTheme.displayBold(16))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                Text(subtitle)
                    .font(DermadreamTheme.displaySemibold(13))
                    .foregroundStyle(DermadreamTheme.softSlate)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint.opacity(0.7))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DermadreamTheme.creamShell)
        )
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environmentObject(DermadreamEngine())
            .environmentObject(AppModel())
    }
}
