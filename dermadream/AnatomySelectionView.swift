//
//  AnatomySelectionView.swift
//  dermadream
//
//  Acute Irritation symptom map.
//
//  Face-only flow: the user taps the affected region(s), picks Visual
//  vs. Non-visual irritation, refines with symptom chips, sets a
//  1-5 severity, then continues to the "Suspect Product" check
//  (a reused RoutineView with a custom serif header).
//

import SwiftUI
import UIKit

struct AnatomySelectionView: View {
    /// When `true` (Acute path from `WelcomeView`), we sync `appModel.showAnatomyFromWelcome`
    /// on pop. Must not clear when this screen is covered by `SuspectProductFlowView` —
    /// that case is identified via `goToSuspectProduct`.
    var isFromWelcomeFlow: Bool = false

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var engine: DermadreamEngine

    @State private var selectedRegions: Set<AnatomyRegion> = []
    @State private var irritationType: IrritationType = .visual
    @State private var visualSymptoms: Set<VisualSymptom> = []
    @State private var nonVisualSymptoms: Set<NonVisualSymptom> = []
    @State private var severity: Double = 3
    @State private var completedTickets: [IrritationMapSnapshot] = []
    @State private var activeSuspectContext: AcuteIrritationContext?

    private let severityRange: ClosedRange<Double> = 1...5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroHeader

                silhouetteCard

                typeCard

                symptomChipsCard

                severityCard

                if !selectedRegions.isEmpty {
                    Text("Mapped: \(selectedRegions.sorted { $0.displayTitle < $1.displayTitle }.map(\.displayTitle).joined(separator: ", "))")
                        .font(DermadreamTheme.displaySemibold(13))
                        .foregroundStyle(DermadreamTheme.softSlate)
                }

                irritationTicketsCard

                addIrritationButton

                continueToSuspectButton
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(DermadreamTheme.creamShell.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Symptom map")
                    .font(DermadreamTheme.displaySemibold(17))
                    .foregroundStyle(DermadreamTheme.deepUmber)
            }
        }
        .toolbarBackground(DermadreamTheme.creamShell, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            configureTypeSegmentAppearance()
        }
        .navigationDestination(item: $activeSuspectContext) { ctx in
            SuspectProductFlowView(context: ctx)
        }
        .onDisappear {
            if isFromWelcomeFlow, activeSuspectContext == nil {
                appModel.showAnatomyFromWelcome = false
            }
        }
    }

    // MARK: - Pieces

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Where is the irritation?")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(DermadreamTheme.charcoalGray)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tap the area(s) of your face that feel reactive right now.")
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DermadreamTheme.softSlate)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var silhouetteCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Face map")
                    .font(DermadreamTheme.displayBold(17))
                    .foregroundStyle(DermadreamTheme.charcoalGray)

                FaceSilhouetteCanvasView(
                    selected: selectedRegions,
                    onSelect: toggleRegion
                )
                .frame(height: 320)
                .frame(maxWidth: .infinity)

                regionChipRow
            }
        }
    }

    private var regionChipRow: some View {
        // Tap-target backup so the user can also pick regions as chips.
        let columns = [GridItem(.adaptive(minimum: 110), spacing: 10, alignment: .leading)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(AnatomyRegion.faceCardinalRegions) { region in
                Button {
                    toggleRegion(region)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedRegions.contains(region) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text(region.displayTitle)
                            .font(DermadreamTheme.displaySemibold(13))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(chipBackground(selected: selectedRegions.contains(region)))
                    .foregroundStyle(selectedRegions.contains(region) ? Color.white : DermadreamTheme.charcoalGray)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var typeCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Type of irritation")
                    .font(DermadreamTheme.displayBold(17))
                    .foregroundStyle(DermadreamTheme.charcoalGray)

                Picker("Type", selection: $irritationType) {
                    ForEach(IrritationType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Text(irritationType.subtitle)
                    .font(DermadreamTheme.displaySemibold(13))
                    .foregroundStyle(DermadreamTheme.softSlate)
            }
        }
    }

    private func configureTypeSegmentAppearance() {
        let selected = UIColor(red: 0.43, green: 0.38, blue: 0.33, alpha: 1.0)  // dark warm grey-brown
        let idle = UIColor(red: 0.86, green: 0.83, blue: 0.79, alpha: 1.0)      // light warm grey-brown

        let control = UISegmentedControl.appearance()
        control.selectedSegmentTintColor = selected
        control.backgroundColor = idle

        control.setTitleTextAttributes(
            [.foregroundColor: UIColor.white],
            for: .selected
        )
        control.setTitleTextAttributes(
            [.foregroundColor: UIColor(DermadreamTheme.charcoalGray)],
            for: .normal
        )
    }

    private var symptomChipsCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(irritationType == .visual ? "What does it look like?" : "What does it feel like?")
                    .font(DermadreamTheme.displayBold(17))
                    .foregroundStyle(DermadreamTheme.charcoalGray)

                let columns = [GridItem(.adaptive(minimum: 118), spacing: 10, alignment: .leading)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    if irritationType == .visual {
                        ForEach(VisualSymptom.allCases) { symptom in
                            chipButton(
                                label: symptom.rawValue,
                                isSelected: visualSymptoms.contains(symptom),
                                action: { toggleChip(symptom, in: &visualSymptoms) }
                            )
                        }
                    } else {
                        ForEach(NonVisualSymptom.allCases) { symptom in
                            chipButton(
                                label: symptom.rawValue,
                                isSelected: nonVisualSymptoms.contains(symptom),
                                action: { toggleChip(symptom, in: &nonVisualSymptoms) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var severityCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Severity")
                    .font(DermadreamTheme.displayBold(17))
                    .foregroundStyle(DermadreamTheme.charcoalGray)

                HStack {
                    Text("Mild")
                        .font(DermadreamTheme.label(12))
                        .foregroundStyle(DermadreamTheme.softSlate)
                    Spacer()
                    Text("Severe")
                        .font(DermadreamTheme.label(12))
                        .foregroundStyle(DermadreamTheme.softSlate)
                }
                Slider(value: $severity, in: severityRange, step: 1)
                    .tint(DermadreamTheme.terracotta)
                Text("Level \(Int(severity)) / 5")
                    .font(DermadreamTheme.displaySemibold(14))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
            }
        }
    }

    private var irritationTicketsCard: some View {
        Group {
            if !completedTickets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Irritation tickets")
                        .font(DermadreamTheme.displayBold(17))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                    ForEach(completedTickets) { ticket in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DermadreamTheme.terracotta)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ticket.concernHeadline)
                                    .font(DermadreamTheme.displaySemibold(14))
                                    .foregroundStyle(DermadreamTheme.charcoalGray)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Severity \(ticket.severity)/5 · \(ticket.regionsLabel)")
                                    .font(DermadreamTheme.displaySemibold(12))
                                    .foregroundStyle(DermadreamTheme.softSlate)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DermadreamTheme.sandstone.opacity(0.3))
                        )
                    }
                }
            }
        }
    }

    private var addIrritationButton: some View {
        Button {
            addIrritationTapped()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Add irritation")
                    .font(DermadreamTheme.displaySemibold(17))
            }
            .foregroundStyle(DermadreamTheme.deepUmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DermadreamTheme.sandstone.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(DermadreamTheme.deepUmber.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.45)
    }

    private var continueToSuspectButton: some View {
        Button {
            continueToSuspectTapped()
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(DermadreamTheme.displaySemibold(17))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(canProceedToSuspect ? DermadreamTheme.deepUmber : DermadreamTheme.deepUmber.opacity(0.4))
            )
            .shadow(
                color: DermadreamTheme.deepUmber.opacity(canProceedToSuspect ? 0.22 : 0),
                radius: 14, x: 0, y: 7
            )
        }
        .buttonStyle(.plain)
        .disabled(!canProceedToSuspect)
        .padding(.top, 6)
    }

    private var canContinue: Bool {
        !selectedRegions.isEmpty
    }

    private var canProceedToSuspect: Bool {
        !ticketsForNavigation().isEmpty
    }

    private func mapSnapshotFromState() -> IrritationMapSnapshot {
        IrritationMapSnapshot(
            regions: selectedRegions.sorted { $0.displayTitle < $1.displayTitle },
            irritationType: irritationType,
            visualSymptoms: irritationType == .visual
                ? visualSymptoms.sorted { $0.rawValue < $1.rawValue }
                : [],
            nonVisualSymptoms: irritationType == .nonVisual
                ? nonVisualSymptoms.sorted { $0.rawValue < $1.rawValue }
                : [],
            severity: Int(severity)
        )
    }

    private func ticketsForNavigation() -> [IrritationMapSnapshot] {
        var list = completedTickets
        if canContinue {
            list.append(mapSnapshotFromState())
        }
        return list
    }

    private func resetInteractiveForm() {
        selectedRegions = []
        irritationType = .visual
        visualSymptoms = []
        nonVisualSymptoms = []
        severity = 3
    }

    private func addIrritationTapped() {
        guard canContinue else { return }
        let snap = mapSnapshotFromState()
        completedTickets.append(snap)
        engine.persistIrritationMapTicket(snap)
        resetInteractiveForm()
    }

    private func continueToSuspectTapped() {
        let all: [IrritationMapSnapshot]
        if canContinue {
            let last = mapSnapshotFromState()
            engine.persistIrritationMapTicket(last)
            all = completedTickets + [last]
        } else {
            all = completedTickets
        }
        guard !all.isEmpty else { return }
        activeSuspectContext = AcuteIrritationContext(tickets: all)
    }

    // MARK: - Helpers

    private func toggleRegion(_ region: AnatomyRegion) {
        if selectedRegions.contains(region) {
            selectedRegions.remove(region)
        } else {
            selectedRegions.insert(region)
        }
    }

    private func toggleChip<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DermadreamTheme.displaySemibold(14))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(chipBackground(selected: isSelected))
                .foregroundStyle(isSelected ? Color.white : DermadreamTheme.charcoalGray)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func chipBackground(selected: Bool) -> Color {
        // Selected chip = critical signal (terracotta). Idle chip uses
        // the warmer sandstone wash so it reads as part of the harmony
        // palette instead of cold system gray.
        selected ? DermadreamTheme.terracotta : DermadreamTheme.sandstone.opacity(0.35)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
}

// MARK: - Face silhouette (face-only, four cardinal regions)

private struct FaceSilhouetteCanvasView: View {
    let selected: Set<AnatomyRegion>
    let onSelect: (AnatomyRegion) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let inset: CGFloat = 18
            let canvasSize = CGSize(width: w - inset * 2, height: h - inset * 2)
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DermadreamTheme.creamShell)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(DermadreamTheme.sandstone.opacity(0.6), lineWidth: 1)
                    )

                FaceShape(size: canvasSize, selected: selected, onSelect: onSelect)
                    .frame(width: canvasSize.width, height: canvasSize.height)
            }
        }
    }
}

private struct FaceShape: View {
    let size: CGSize
    let selected: Set<AnatomyRegion>
    let onSelect: (AnatomyRegion) -> Void

    var body: some View {
        let w = size.width
        let h = size.height
        ZStack {
            faceOutline(in: size)
                .stroke(DermadreamTheme.deepUmber.opacity(0.35), lineWidth: 2)

            silhouetteRegion(.forehead, w: w, h: h) { path in
                path.addRoundedRect(
                    in: CGRect(x: w * 0.22, y: h * 0.10, width: w * 0.56, height: h * 0.18),
                    cornerSize: CGSize(width: 18, height: 18)
                )
            }

            silhouetteRegion(.leftCheek, w: w, h: h) { path in
                path.addEllipse(
                    in: CGRect(x: w * 0.12, y: h * 0.36, width: w * 0.28, height: h * 0.24)
                )
            }

            silhouetteRegion(.rightCheek, w: w, h: h) { path in
                path.addEllipse(
                    in: CGRect(x: w * 0.60, y: h * 0.36, width: w * 0.28, height: h * 0.24)
                )
            }

            silhouetteRegion(.chin, w: w, h: h) { path in
                path.addEllipse(
                    in: CGRect(x: w * 0.30, y: h * 0.66, width: w * 0.40, height: h * 0.20)
                )
            }
        }
        .frame(width: w, height: h)
    }

    @ViewBuilder
    private func silhouetteRegion(
        _ region: AnatomyRegion,
        w: CGFloat,
        h: CGFloat,
        build: @escaping @Sendable (inout Path) -> Void
    ) -> some View {
        let isSelected = selected.contains(region)
        RegionShape(build: build)
            .fill(isSelected ? DermadreamTheme.terracotta.opacity(0.55) : DermadreamTheme.sandstone.opacity(0.45))
            .overlay(
                RegionShape(build: build)
                    .stroke(
                        isSelected ? DermadreamTheme.terracotta : DermadreamTheme.deepUmber.opacity(0.30),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .contentShape(RegionShape(build: build))
            .onTapGesture { onSelect(region) }
    }

    private func faceOutline(in size: CGSize) -> Path {
        var path = Path()
        let w = size.width
        let h = size.height
        let rect = CGRect(x: w * 0.14, y: h * 0.06, width: w * 0.72, height: h * 0.84)
        path.addEllipse(in: rect)
        return path
    }
}

private struct RegionShape: Shape {
    let build: @Sendable (inout Path) -> Void

    init(build: @escaping @Sendable (inout Path) -> Void) {
        self.build = build
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        build(&path)
        return path
    }
}

#Preview {
    NavigationStack {
        AnatomySelectionView()
            .environmentObject(AppModel())
            .environmentObject(DermadreamEngine())
    }
}
