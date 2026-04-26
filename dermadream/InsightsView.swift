//
//  InsightsView.swift
//  dermadream
//

import SwiftUI

struct InsightsView: View {
    private let weeks = ["W1", "W2", "W3", "W4"]
    private let calmScores: [CGFloat] = [0.62, 0.58, 0.74, 0.81]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Insights")
                    .font(DermadreamTheme.displayBold(26))
                    .foregroundStyle(DermadreamTheme.charcoalGray)

                Text("Trendlines are illustrative in this prototype build.")
                    .font(DermadreamTheme.displaySemibold(14))
                    .foregroundStyle(DermadreamTheme.softSlate)

                chartCard

                HStack(spacing: 12) {
                    insightPill(title: "Barrier", value: "Stable", tint: DermadreamTheme.mutedSage)
                    insightPill(title: "Alerts", value: "2", tint: DermadreamTheme.terracotta)
                }
            }
            .padding(20)
        }
        .background(DermadreamTheme.workspaceBackground.ignoresSafeArea())
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calm index")
                .font(DermadreamTheme.displayBold(17))
                .foregroundStyle(DermadreamTheme.charcoalGray)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DermadreamTheme.aquaGlow.opacity(0.18),
                                    Color.white
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Path { path in
                        guard calmScores.count > 1 else { return }
                        let stepX = w / CGFloat(calmScores.count - 1)
                        for (idx, score) in calmScores.enumerated() {
                            let x = CGFloat(idx) * stepX
                            let y = h - (score * h * 0.78) - 12
                            if idx == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(DermadreamTheme.deepUmber, style: StrokeStyle(lineWidth: 3, lineJoin: .round))

                    Path { path in
                        guard calmScores.count > 1 else { return }
                        let stepX = w / CGFloat(calmScores.count - 1)
                        path.move(to: CGPoint(x: 0, y: h))
                        for (idx, score) in calmScores.enumerated() {
                            let x = CGFloat(idx) * stepX
                            let y = h - (score * h * 0.78) - 12
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                DermadreamTheme.deepUmber.opacity(0.30),
                                DermadreamTheme.deepUmber.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    HStack {
                        ForEach(weeks, id: \.self) { label in
                            Text(label)
                                .font(DermadreamTheme.label(11))
                                .foregroundStyle(DermadreamTheme.softSlate)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: DermadreamTheme.charcoalGray.opacity(0.06), radius: 16, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(DermadreamTheme.subtleBorder, lineWidth: 1)
                )
        )
    }

    private func insightPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(DermadreamTheme.label(11))
                .foregroundStyle(DermadreamTheme.softSlate)
            Text(value)
                .font(DermadreamTheme.displayBold(22))
                .foregroundStyle(tint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DermadreamTheme.subtleBorder, lineWidth: 1)
                )
        )
        .shadow(color: DermadreamTheme.charcoalGray.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
}
