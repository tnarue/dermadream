//
//  WelcomeView.swift
//  dermadream
//

import SwiftUI

private enum WelcomeConcern: String, CaseIterable, Identifiable {
    case acuteIrritation
    case productCheck
    case skincareRoutine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .acuteIrritation: return "Acute Irritation"
        case .productCheck: return "Product Check"
        case .skincareRoutine: return "Skincare Routine"
        }
    }

    var subtitle: String {
        switch self {
        case .acuteIrritation:
            return "Sudden redness, itching, or flares."
        case .productCheck:
            return "Check new products against your allergy history."
        case .skincareRoutine:
            return "Add or update your skincare routine."
        }
    }

    var systemImage: String {
        switch self {
        case .acuteIrritation: return "asterisk"
        case .productCheck: return "magnifyingglass.circle.fill"
        case .skincareRoutine: return "drop.halffull"
        }
    }

    var usesOrangeAccent: Bool {
        self == .acuteIrritation
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedConcern: WelcomeConcern?

    private let heroHeightFraction: CGFloat = 0.38

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let heroH = max(260, geo.size.height * heroHeightFraction)

                ZStack(alignment: .bottom) {
                    DermadreamTheme.creamShell.ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            welcomeHero(width: geo.size.width, height: heroH)

                            VStack(alignment: .leading, spacing: 20) {
                                Text("To personalize your laboratory-grade routine, choose how you'd like to get started.")
                                    .font(DermadreamTheme.displaySemibold(15))
                                    .foregroundStyle(DermadreamTheme.softSlate)
                                    .fixedSize(horizontal: false, vertical: true)

                                VStack(spacing: 12) {
                                    ForEach(WelcomeConcern.allCases) { concern in
                                        concernCard(concern)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 22)
                            .padding(.bottom, 120)
                        }
                    }
                    .scrollContentBackground(.hidden)

                    bottomChrome
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $appModel.showAnatomyFromWelcome) {
                // Resetting `showAnatomyFromWelcome` must not live on this wrapper:
                // it fires when pushing SuspectProductFlowView (parent is covered) and
                // dismisses the whole stack. `AnatomySelectionView` clears the flag
                // only when truly popping back to welcome (see `isFromWelcomeFlow`).
                AnatomySelectionView(isFromWelcomeFlow: true)
            }
        }
    }

    // MARK: - Hero

    private func welcomeHero(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image("WelcomeHero")
                .renderingMode(.original)
                .resizable()
                .scaledToFill()
                .brightness(0.06)
                .frame(width: width, height: height)
                .clipped()

            // Warm, light grade: pulls the hero away from grey/blue cast and
            // toward cream / sandstone so it matches the rest of the palette.
            LinearGradient(
                stops: [
                    .init(
                        color: Color(red: 0.99, green: 0.96, blue: 0.92).opacity(0.55),
                        location: 0
                    ),
                    .init(color: Color.clear, location: 0.42),
                    .init(
                        color: DermadreamTheme.sandstone.opacity(0.22),
                        location: 0.78
                    ),
                    .init(
                        color: DermadreamTheme.creamShell.opacity(0.45),
                        location: 1
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.softLight)
            .allowsHitTesting(false)

            // Bottom seam: smooth handoff into the scroll area (warm, not grey).
            VStack {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [
                        .clear,
                        DermadreamTheme.creamShell.opacity(0.2),
                        DermadreamTheme.creamShell
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: min(72, height * 0.18))
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Copy sits on the open right (reference layout); deep umber
            // reads warmly against the cream backdrop.
            VStack(alignment: .trailing, spacing: 14) {
                Text("WELCOME TO DERMADREAM")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(DermadreamTheme.sandstone)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )

                Text("Let's find your\nperfect match.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(DermadreamTheme.deepUmber)
                    .multilineTextAlignment(.trailing)
                    .shadow(color: DermadreamTheme.creamShell.opacity(0.85), radius: 6, x: 0, y: 0)
                    .shadow(color: DermadreamTheme.charcoalGray.opacity(0.06), radius: 2, x: 0, y: 1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .bottomTrailing)
        }
        .frame(width: width, height: height)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Cards

    private func concernCard(_ concern: WelcomeConcern) -> some View {
        let isOn = selectedConcern == concern
        // Acute Irritation = critical pathway → terracotta. Product Check
        // = standard brand action → deep umber.
        let accent = concern.usesOrangeAccent
            ? DermadreamTheme.terracotta
            : DermadreamTheme.deepUmber

        return Button {
            selectedConcern = concern
        } label: {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 54, height: 54)
                        .shadow(color: DermadreamTheme.charcoalGray.opacity(0.08), radius: 6, x: 0, y: 3)
                    Image(systemName: concern.systemImage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(concern.title)
                        .font(DermadreamTheme.displayBold(17))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                    Text(concern.subtitle)
                        .font(DermadreamTheme.displaySemibold(13))
                        .foregroundStyle(DermadreamTheme.softSlate)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DermadreamTheme.sandstone.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isOn ? accent : Color.clear, lineWidth: 2)
            )
            .shadow(color: DermadreamTheme.charcoalGray.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom bar

    private var bottomChrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    appModel.showWelcome = false
                } label: {
                    Text("Skip")
                        .font(DermadreamTheme.displaySemibold(16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DermadreamTheme.sandstone.opacity(0.4))
                        )
                        .foregroundStyle(DermadreamTheme.deepUmber)
                }

                Button {
                    continueTapped()
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(DermadreamTheme.displaySemibold(16))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DermadreamTheme.deepUmber)
                            .shadow(
                                color: DermadreamTheme.deepUmber.opacity(selectedConcern == nil ? 0 : 0.18),
                                radius: 12, x: 0, y: 6
                            )
                    )
                    .foregroundStyle(.white)
                }
                .disabled(selectedConcern == nil)
                .opacity(selectedConcern == nil ? 0.45 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                DermadreamTheme.creamShell
                    .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DermadreamTheme.sandstone.opacity(0.35))
                    .frame(height: 1)
            }
        }
    }

    private func continueTapped() {
        guard let concern = selectedConcern else { return }

        switch concern {
        case .acuteIrritation:
            appModel.showAnatomyFromWelcome = true
        case .productCheck:
            appModel.showWelcome = false
            appModel.selectedTab = .products
        case .skincareRoutine:
            appModel.showWelcome = false
            appModel.selectedTab = .routine
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppModel())
        .environmentObject(DermadreamEngine())
}
