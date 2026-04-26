//
//  RoutineView.swift
//  dermadream
//

import SwiftUI
import UIKit

/// Routine ledger: log a product, see what's currently in rotation, and
/// peek at the most recent archived items.
struct RoutineView: View {
    @EnvironmentObject private var engine: DermadreamEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Routine")
                    .font(DermadreamTheme.navTitleSerif)
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                LogProductSection()
                CurrentRoutineSection()
                ProductHistorySection()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 120)
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
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Log Product (matches Suspect product form)

private struct LogProductSection: View {
    @EnvironmentObject private var engine: DermadreamEngine

    @State private var productName: String = ""
    @State private var brand: String = ""
    @State private var slot: RoutineSlot = .morning
    @State private var usageFrequency: ProductUsageFrequency = .everyday
    @State private var showBarcodeScanSheet = false
    @State private var saveBanner: SaveBanner?

    private var canSave: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        RoutineCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Add Product",
                    subtitle: "Track what's on your skin today. Saved to your routine and mock user history."
                )

                formFieldLabel("Product name")
                routineInput($productName, placeholder: "e.g. Cloud Cleanse")

                formFieldLabel("Brand")
                routineInput($brand, placeholder: "Optional")

                routineScanBarcodeButton { showBarcodeScanSheet = true }

                formFieldLabel("When do you use it?")
                RoutineSlotChipRow(selection: $slot)

                formFieldLabel("How frequent?")
                ProductUsageFrequencyChipRow(selection: $usageFrequency)

                Button(action: save) {
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

                if let banner = saveBanner {
                    HStack(spacing: 8) {
                        Image(systemName: banner.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(banner.text)
                            .font(DermadreamTheme.displaySemibold(13))
                    }
                    .foregroundStyle(banner.tint)
                    .transition(.opacity)
                }
            }
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

    private func formFieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(DermadreamTheme.softSlate)
    }

    private func routineInput(_ binding: Binding<String>, placeholder: String) -> some View {
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

    private func routineScanBarcodeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
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

    private func save() {
        let trimmedName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let entry = RoutineEntry(
            productName: trimmedName,
            brand: trimmedBrand,
            status: .current,
            startDate: nil,
            endDate: nil,
            slot: slot,
            usageFrequency: usageFrequency
        )

        engine.addRoutineEntry(entry, markPendingShelfRisk: true)

        let label = entry.displayLine
        withAnimation(.easeOut(duration: 0.2)) {
            saveBanner = SaveBanner(
                text: "Added \(label) — saved to routine and mock DB.",
                icon: "checkmark.circle.fill",
                tint: DermadreamTheme.mutedSage
            )
        }

        productName = ""
        brand = ""
        usageFrequency = .everyday

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                saveBanner = nil
            }
        }
    }

    private struct SaveBanner: Equatable {
        let text: String
        let icon: String
        let tint: Color
    }
}

// MARK: - Current routine

private struct CurrentRoutineSection: View {
    @EnvironmentObject private var engine: DermadreamEngine

    var body: some View {
        let entries = engine.currentRoutineEntries
        let subtitle = entries.isEmpty
            ? "Nothing logged yet — add a product above."
            : "\(entries.count) product\(entries.count == 1 ? "" : "s") in active rotation."

        RoutineCard {
            RoutineGroupedRosterCard(
                title: "My current routine",
                subtitle: subtitle,
                onStopEntry: { id in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        engine.markRoutineEntryStopped(id: id)
                    }
                }
            )
        }
    }
}

// MARK: - Product history

private struct ProductHistorySection: View {
    @EnvironmentObject private var engine: DermadreamEngine
    @State private var showFullHistory = false

    private let displayLimit = 3

    var body: some View {
        let archived = engine.archivedRoutineEntries
        let visible = Array(archived.prefix(displayLimit))
        let remaining = max(0, archived.count - displayLimit)

        RoutineCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Product History",
                    subtitle: archived.isEmpty
                        ? "Nothing archived yet."
                        : "Last \(visible.count) of \(archived.count) archived."
                )

                if archived.isEmpty {
                    EmptyHint(
                        icon: "tray",
                        message: "Stopped products will show up here."
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(visible) { entry in
                            RoutineRow(entry: entry, accessory: .none)
                        }
                    }

                    if remaining > 0 {
                        Button {
                            showFullHistory = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("See more (\(remaining))")
                                    .font(DermadreamTheme.displaySemibold(14))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(DermadreamTheme.deepUmber)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(DermadreamTheme.sandstone.opacity(0.4))
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showFullHistory) {
            RoutineHistoryView()
        }
    }
}

// MARK: - Full history list

struct RoutineHistoryView: View {
    @EnvironmentObject private var engine: DermadreamEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(engine.archivedRoutineEntries) { entry in
                    RoutineRow(
                        entry: entry,
                        accessory: .deleteButton {
                            engine.deleteRoutineEntry(id: entry.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .background(DermadreamTheme.creamShell.ignoresSafeArea())
        .navigationTitle("Product History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DermadreamTheme.creamShell, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Reusable building blocks

private struct RoutineCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
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

private struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DermadreamTheme.displayBold(20))
                .foregroundStyle(DermadreamTheme.charcoalGray)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(DermadreamTheme.displaySemibold(13))
                    .foregroundStyle(DermadreamTheme.softSlate)
            }
        }
    }
}

private struct EmptyHint: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DermadreamTheme.deepUmber)
            Text(message)
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DermadreamTheme.softSlate)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DermadreamTheme.sandstone.opacity(0.3))
        )
    }
}

private struct RoutineRow: View {
    let entry: RoutineEntry
    let accessory: Accessory

    enum Accessory {
        case none
        case stopButton(() -> Void)
        case deleteButton(() -> Void)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(DermadreamTheme.sandstone.opacity(0.5))
                    .frame(width: 40, height: 40)
                Image(systemName: entry.status == .current ? "drop.halffull" : "tray.full")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DermadreamTheme.deepUmber)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.productName)
                    .font(DermadreamTheme.displaySemibold(16))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                if !entry.brand.isEmpty {
                    Text(entry.brand)
                        .font(DermadreamTheme.displaySemibold(13))
                        .foregroundStyle(DermadreamTheme.softSlate)
                }
                metadataLine
            }

            Spacer(minLength: 0)

            accessoryView
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DermadreamTheme.creamShell)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DermadreamTheme.sandstone.opacity(0.55), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var metadataLine: some View {
        switch entry.status {
        case .current:
            if let days = entry.daysInUse {
                MetaPill(
                    icon: "clock",
                    text: "\(days) day\(days == 1 ? "" : "s") in use"
                )
            } else if let start = entry.startDate {
                MetaPill(
                    icon: "calendar",
                    text: "Since \(Self.dateFormatter.string(from: start))"
                )
            } else {
                MetaPill(icon: "sparkles", text: "Currently using")
            }
        case .stopped:
            if let end = entry.endDate {
                MetaPill(
                    icon: "calendar",
                    text: "Stopped \(Self.dateFormatter.string(from: end))"
                )
            } else {
                MetaPill(icon: "tray", text: "Archived")
            }
        }
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .stopButton(let action):
            Button(action: action) {
                Text("Stop")
                    .font(DermadreamTheme.displaySemibold(13))
                    .foregroundStyle(DermadreamTheme.deepUmber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(DermadreamTheme.sandstone.opacity(0.55))
                    )
            }
            .buttonStyle(.plain)
        case .deleteButton(let action):
            Button(action: action) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DermadreamTheme.softSlate)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()
}

private struct MetaPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(DermadreamTheme.displaySemibold(12))
        }
        .foregroundStyle(DermadreamTheme.deepUmber)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(DermadreamTheme.sandstone.opacity(0.45))
        )
    }
}

#Preview {
    NavigationStack {
        RoutineView()
            .environmentObject(DermadreamEngine())
    }
}
