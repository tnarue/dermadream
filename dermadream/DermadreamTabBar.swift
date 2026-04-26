//
//  DermadreamTabBar.swift
//  dermadream
//
//  Shared main tab strip (also embedded on the Irritation report screen).
//

import SwiftUI

struct DermadreamTabBar: View {
    @Binding var selected: MainTab
    var inactiveTint: Color
    var onCenterTap: () -> Void
    /// Fires before updating `selected` when a side tab is tapped.
    var onTabSelect: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.dashboard)
            tabButton(.products)
            centerComposerButton
            tabButton(.routine)
            tabButton(.settings)
        }
        .frame(height: 64)
    }

    private var centerComposerButton: some View {
        Button(action: onCenterTap) {
            ZStack {
                Circle()
                    .fill(DermadreamTheme.deepUmber)
                    .frame(width: 52, height: 52)
                    .shadow(
                        color: DermadreamTheme.deepUmber.opacity(0.28),
                        radius: 6, x: 0, y: 3
                    )
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Quick menu")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = selected == tab
        Button {
            onTabSelect?()
            selected = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(tab.tabCaption)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundStyle(isSelected ? DermadreamTheme.deepUmber : inactiveTint)
            .accessibilityLabel(tab.title)
        }
        .buttonStyle(.plain)
    }
}
