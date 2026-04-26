//
//  ContentView.swift
//  dermadream
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var engine: DermadreamEngine

    var body: some View {
        Group {
            if appModel.showWelcome {
                WelcomeView()
            } else {
                MainLayout()
            }
        }
        .tint(DermadreamTheme.deepUmber)
        .sheet(isPresented: $appModel.showChatSheet) {
            ChatView(seed: appModel.pendingChatSeed)
                .environmentObject(engine)
                .presentationDragIndicator(.visible)
                .onDisappear {
                    appModel.pendingChatSeed = nil
                }
        }
    }
}

// MARK: - Main chrome

struct MainLayout: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var engine: DermadreamEngine
    @State private var showComposerMenu = false
    @State private var showAnatomySheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                globalHeader

                tabHost
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomTabChrome
            }
            .background(DermadreamTheme.workspaceBackground.ignoresSafeArea())

            quickMenuOverlay
        }
        .sheet(isPresented: $showAnatomySheet) {
            NavigationStack {
                AnatomySelectionView()
                    .environmentObject(engine)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showAnatomySheet = false }
                                .foregroundStyle(DermadreamTheme.deepUmber)
                        }
                    }
            }
        }
        .task {
            await engine.refreshRoutineLogFromMockDB()
        }
    }

    /// Slim bottom bar with the + composer button living inline as the
    /// middle item — the full circle stays inside the bar so nothing
    /// gets clipped against the safe area.
    private var bottomTabChrome: some View {
        DermadreamTabBar(
            selected: $appModel.selectedTab,
            inactiveTint: DermadreamTheme.softSlate,
            onCenterTap: { withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { showComposerMenu = true } }
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

    // MARK: - Quick Menu overlay (anchored to the bottom edge)

    @ViewBuilder
    private var quickMenuOverlay: some View {
        if showComposerMenu {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismissQuickMenu() }

                quickMenuCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: showComposerMenu)
        }
    }

    private var quickMenuCard: some View {
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
                quickMenuRow(title: "Acute Irritation", systemImage: "face.smiling.inverse") {
                    showAnatomySheet = true
                }
                quickMenuRow(title: "Product Check", systemImage: "barcode.viewfinder") {
                    appModel.selectedTab = .products
                }
                quickMenuRow(title: "Add New Product", systemImage: "drop.halffull") {
                    appModel.selectedTab = .routine
                }
            }
            .padding(.horizontal, 16)

            Button {
                dismissQuickMenu()
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
        .padding(.bottom, 0)
        .ignoresSafeArea(edges: .bottom)
    }

    private func quickMenuRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            dismissQuickMenu()
            // Defer the actual action so the menu dismiss animation finishes,
            // then run with an explicit tab transition.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(DermadreamTheme.mainTabChangeAnimation) {
                    action()
                }
            }
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

    private func dismissQuickMenu() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            showComposerMenu = false
        }
    }

    private var globalHeader: some View {
        HStack(spacing: 12) {
            Button {
                appModel.showWelcome = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dermadream")
                        .font(DermadreamTheme.displayBold(24))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                    Text("Reactive skin intelligence")
                        .font(DermadreamTheme.displaySemibold(13))
                        .foregroundStyle(DermadreamTheme.softSlate)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return to welcome page")
            Spacer()
            Button {
                appModel.pendingChatSeed = nil
                appModel.showChatSheet = true
            } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DermadreamTheme.deepUmber)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(DermadreamTheme.sandstone.opacity(0.4))
                    )
            }
            .accessibilityLabel("Open chat")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background {
            DermadreamTheme.creamShell
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DermadreamTheme.sandstone.opacity(0.28))
                        .frame(height: 1)
                }
        }
    }

    @ViewBuilder
    private var tabHost: some View {
        let selected = appModel.selectedTab
        ZStack {
            tabRoot(.dashboard, isSelected: selected == .dashboard)
            tabRoot(.products, isSelected: selected == .products)
            tabRoot(.routine, isSelected: selected == .routine)
            tabRoot(.settings, isSelected: selected == .settings)
        }
        .animation(DermadreamTheme.mainTabChangeAnimation, value: appModel.selectedTab)
    }

    @ViewBuilder
    private func tabRoot(_ tab: MainTab, isSelected: Bool) -> some View {
        Group {
            switch tab {
            case .dashboard:
                NavigationStack { DashboardView() }
            case .products:
                NavigationStack { ProductsView() }
            case .routine:
                NavigationStack { RoutineView() }
            case .settings:
                NavigationStack { SettingsView() }
            }
        }
        .opacity(isSelected ? 1 : 0)
        .zIndex(isSelected ? 1 : 0)
        .allowsHitTesting(isSelected)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
        .environmentObject(DermadreamEngine())
}
