//
//  RoutineFormChips.swift
//  dermadream
//
//  Chip-style single-select for routine time slot and usage frequency
//  (shared by Suspect product flow and Routine tab add form).
//

import SwiftUI

// MARK: - When do you use it? (time slot)

struct RoutineSlotChipRow: View {
    @Binding var selection: RoutineSlot

    /// Two per row so long copy doesn’t squeeze into one ragged row.
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private let chipMinHeight: CGFloat = 50

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(RoutineSlot.allCases) { slot in
                chipButton(
                    label: shortLabel(for: slot),
                    isSelected: selection == slot
                ) {
                    selection = slot
                }
            }
        }
    }

    private func shortLabel(for slot: RoutineSlot) -> String {
        switch slot {
        case .both: return "Both AM & PM"
        default: return slot.rawValue
        }
    }

    private func chipButton(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(DermadreamTheme.displaySemibold(13))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: chipMinHeight, alignment: .center)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isSelected
                                ? DermadreamTheme.terracotta
                                : DermadreamTheme.sandstone.opacity(0.35)
                        )
                )
                .foregroundStyle(isSelected ? Color.white : DermadreamTheme.charcoalGray)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - How frequent?

struct ProductUsageFrequencyChipRow: View {
    @Binding var selection: ProductUsageFrequency

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private let chipMinHeight: CGFloat = 50

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(ProductUsageFrequency.allCases) { freq in
                chipButton(
                    label: freq.rawValue,
                    isSelected: selection == freq
                ) {
                    selection = freq
                }
            }
        }
    }

    private func chipButton(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(DermadreamTheme.displaySemibold(13))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: chipMinHeight, alignment: .center)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isSelected
                                ? DermadreamTheme.terracotta
                                : DermadreamTheme.sandstone.opacity(0.35)
                        )
                )
                .foregroundStyle(isSelected ? Color.white : DermadreamTheme.charcoalGray)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Grouped current routine (Suspect + Routine tab)

struct RoutineGroupedRosterCard: View {
    @EnvironmentObject private var engine: DermadreamEngine
    var title: String
    var subtitle: String
    var onStopEntry: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(DermadreamTheme.displayBold(17))
                .foregroundStyle(DermadreamTheme.charcoalGray)
            Text(subtitle)
                .font(DermadreamTheme.displaySemibold(13))
                .foregroundStyle(DermadreamTheme.softSlate)

            ForEach(engine.currentRoutineGroupedBySlot(), id: \.slot) { group in
                slotSection(slot: group.slot, entries: group.entries)
            }
        }
    }

    private func slotSection(slot: RoutineSlot, entries: [RoutineEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: slot.systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DermadreamTheme.deepUmber)
                Text(slot.rawValue.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(DermadreamTheme.softSlate)
            }
            .padding(.top, 4)

            if entries.isEmpty {
                Text("Nothing logged yet.")
                    .font(DermadreamTheme.displaySemibold(13))
                    .foregroundStyle(DermadreamTheme.softSlate)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DermadreamTheme.sandstone.opacity(0.25))
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        RoutineSlotEntryRow(
                            entry: entry,
                            onStop: onStopEntry.map { h in { h(entry.id) } }
                        )
                    }
                }
            }
        }
    }
}

struct RoutineSlotEntryRow: View {
    let entry: RoutineEntry
    var onStop: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(DermadreamTheme.sandstone.opacity(0.5))
                    .frame(width: 34, height: 34)
                Image(systemName: entry.slot.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DermadreamTheme.deepUmber)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.productName)
                    .font(DermadreamTheme.displaySemibold(15))
                    .foregroundStyle(DermadreamTheme.charcoalGray)
                if !entry.brand.isEmpty {
                    Text(entry.brand)
                        .font(DermadreamTheme.displaySemibold(12))
                        .foregroundStyle(DermadreamTheme.softSlate)
                }
                if let freq = entry.usageFrequency {
                    Text(freq.rawValue)
                        .font(DermadreamTheme.displaySemibold(11))
                        .foregroundStyle(DermadreamTheme.softSlate)
                }
            }
            Spacer(minLength: 0)

            if let onStop = onStop {
                Button(action: onStop) {
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
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DermadreamTheme.creamShell)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DermadreamTheme.sandstone.opacity(0.55), lineWidth: 1)
                )
        )
    }
}
