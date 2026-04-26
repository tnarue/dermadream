//
//  SuspectProductFlowView.swift
//  dermadream
//
//  Step 2 of the Acute Irritation pipeline.
//
//  After the user maps regions / type / severity in `AnatomySelectionView`,
//  they land here. The screen lets them log any new product that might
//  have triggered the flare (saved straight into the main Routine tab),
//  or skip if there are none, and then runs the Gemini-powered Acute
//  Irritation analysis. Result is rendered by `IrritationReportView`.
//

import SwiftUI
import UIKit

struct SuspectProductFlowView: View {
    @EnvironmentObject private var engine: DermadreamEngine

    let context: AcuteIrritationContext

    @State private var productName: String = ""
    @State private var brand: String = ""
    @State private var slot: RoutineSlot = .morning
    @State private var usageFrequency: ProductUsageFrequency = .everyday
    @State private var showBarcodeScanSheet = false
    @State private var addedThisSession: Int = 0
    @State private var skippedNewProducts: Bool = false
    @State private var saveBanner: String?

    @State private var goToReport: Bool = false

    private var canSave: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var headerText: String {
        addedThisSession == 0 ? "Any New Product Recently?" : "Any More New Products?"
    }

    private var headerSubtitle: String {
        addedThisSession == 0
            ? "Add anything you started using around the time the irritation began. We'll log it to your Routine and feed it into the analysis."
            : "Great — added \(addedThisSession) product\(addedThisSession == 1 ? "" : "s") so far. Add another, or run the analysis below."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroHeader

                logProductCard

                noNewProductsButton

                currentRoutineCard

                acuteIrritationButton

                if let err = engine.acuteIrritationError {
                    errorBanner(err)
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
        .background(DermadreamTheme.creamShell.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Suspect product")
                    .font(DermadreamTheme.displaySemibold(17))
                    .foregroundStyle(DermadreamTheme.deepUmber)
            }
        }
        .toolbarBackground(DermadreamTheme.creamShell, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationDestination(isPresented: $goToReport) {
            IrritationReportView(context: context)
        }
        .onChange(of: engine.acuteIrritationReport) { _, newValue in
            if newValue != nil {
                goToReport = true
            }
        }
        .onAppear {
            // Start fresh — a previous report from a different flare
            // shouldn't auto-navigate us out of this screen.
            engine.clearAcuteIrritation()
        }
        .sheet(isPresented: $showBarcodeScanSheet) {
            ProductLookupBarcodeSheet(
                isPresented: $showBarcodeScanSheet,
                onResult: { result in
                    let title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let brandText = result.brand.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        productName = title
                    } else {
                        productName = result.targetProductName
                    }
                    brand = brandText
                }
            )
            .environmentObject(engine)
        }
    }

    // MARK: - Hero header (matches reference image)

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(headerText)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(DermadreamTheme.charcoalGray)
                .fixedSize(horizontal: false, vertical: true)

            Text(headerSubtitle)
                .font(DermadreamTheme.displaySemibold(14))
                .foregroundStyle(DermadreamTheme.softSlate)
                .fixedSize(horizontal: false, vertical: true)

            concernPill
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var concernPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "stethoscope")
                .font(.system(size: 12, weight: .bold))
            Text(context.concernHeadline)
                .font(DermadreamTheme.displaySemibold(13))
                .lineLimit(2)
        }
        .foregroundStyle(DermadreamTheme.deepUmber)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DermadreamTheme.sandstone.opacity(0.5))
        )
    }

    // MARK: - Log product card

    private var logProductCard: some View {
        flowCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Log a suspect product")
                    .font(DermadreamTheme.displayBold(17))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                Text("Even sample sizes count. Saving here also adds it to your Routine tab.")
                    .font(DermadreamTheme.displaySemibold(13))
                    .foregroundStyle(DermadreamTheme.softSlate)

                fieldLabel("Product name")
                inputField($productName, placeholder: "e.g. Cloud Cleanse")

                fieldLabel("Brand")
                inputField($brand, placeholder: "Optional")

                scanBarcodeButton

                fieldLabel("When do you use it?")
                RoutineSlotChipRow(selection: $slot)

                fieldLabel("How frequent?")
                ProductUsageFrequencyChipRow(selection: $usageFrequency)

                Button(action: addProduct) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Add to my routine")
                            .font(DermadreamTheme.displaySemibold(16))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(canSave ? DermadreamTheme.deepUmber : DermadreamTheme.deepUmber.opacity(0.4))
                    )
                    .shadow(
                        color: DermadreamTheme.deepUmber.opacity(canSave ? 0.18 : 0),
                        radius: 12, x: 0, y: 6
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.top, 2)

                if let banner = saveBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(banner)
                            .font(DermadreamTheme.displaySemibold(13))
                    }
                    .foregroundStyle(DermadreamTheme.mutedSage)
                    .transition(.opacity)
                }
            }
        }
    }

    private var noNewProductsButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                skippedNewProducts = true
                saveBanner = "Skipped — we'll analyse the products already in your routine."
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.2)) { saveBanner = nil }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: skippedNewProducts ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                Text(skippedNewProducts ? "No new products — got it" : "No, nothing new recently")
                    .font(DermadreamTheme.displaySemibold(15))
            }
            .foregroundStyle(DermadreamTheme.deepUmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DermadreamTheme.deepUmber.opacity(0.4), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DermadreamTheme.sandstone.opacity(0.25))
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current routine grouped by slot

    private var currentRoutineCard: some View {
        flowCard {
            RoutineGroupedRosterCard(
                title: "My current routine",
                subtitle: "These will be sent to the analysis along with your reaction history.",
                onStopEntry: nil
            )
        }
    }

    // MARK: - Acute irritation CTA

    private var acuteIrritationButton: some View {
        VStack(spacing: 10) {
            Button {
                engine.runAcuteIrritation(context)
            } label: {
                HStack(spacing: 10) {
                    if engine.isAnalyzingAcuteIrritation {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(engine.isAnalyzingAcuteIrritation ? "Analyzing..." : "Run Acute Irritation analysis")
                        .font(DermadreamTheme.displaySemibold(17))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DermadreamTheme.deepUmber)
                )
                .shadow(
                    color: DermadreamTheme.deepUmber.opacity(0.22),
                    radius: 14, x: 0, y: 7
                )
            }
            .buttonStyle(.plain)
            .disabled(engine.isAnalyzingAcuteIrritation)

            Text("Sends your symptom map, current routine, and reaction history to AI.")
                .font(DermadreamTheme.displaySemibold(12))
                .foregroundStyle(DermadreamTheme.softSlate)
                .multilineTextAlignment(.center)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(DermadreamTheme.displaySemibold(13))
        }
        .foregroundStyle(DermadreamTheme.terracotta)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DermadreamTheme.terracotta.opacity(0.12))
        )
    }

    // MARK: - Actions

    private func addProduct() {
        let name = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let brandClean = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let entry = RoutineEntry(
            productName: name,
            brand: brandClean,
            status: .current,
            startDate: nil,
            endDate: nil,
            slot: slot,
            usageFrequency: usageFrequency
        )
        engine.addRoutineEntry(entry)
        addedThisSession += 1

        let label = entry.displayLine
        withAnimation(.easeOut(duration: 0.2)) {
            saveBanner = "Added \(label) to your \(slot.rawValue) routine."
        }

        productName = ""
        brand = ""
        usageFrequency = .everyday

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.2)) { saveBanner = nil }
        }
    }

    // MARK: - Reusable styling

    private func flowCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(DermadreamTheme.softSlate)
    }

    private var scanBarcodeButton: some View {
        Button {
            showBarcodeScanSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                Text("SCAN BARCODE")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tracking(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.86, green: 0.65, blue: 0.45),
                                DermadreamTheme.deepUmber
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: DermadreamTheme.charcoalGray.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func inputField(_ binding: Binding<String>, placeholder: String) -> some View {
        TextField(
            "",
            text: binding,
            prompt: Text(placeholder).foregroundStyle(DermadreamTheme.softSlate)
        )
        .font(DermadreamTheme.displaySemibold(15))
        .foregroundStyle(DermadreamTheme.charcoalGray)
        .tint(DermadreamTheme.deepUmber)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DermadreamTheme.creamShell)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DermadreamTheme.softSlate.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        SuspectProductFlowView(
            context: AcuteIrritationContext(
                regions: [.leftCheek, .rightCheek],
                irritationType: .visual,
                visualSymptoms: [.redness],
                nonVisualSymptoms: [.burning],
                severity: 4
            )
        )
        .environmentObject(DermadreamEngine())
    }
}
