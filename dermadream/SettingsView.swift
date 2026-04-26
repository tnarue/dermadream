//
//  SettingsView.swift
//  dermadream
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var engine: DermadreamEngine
    @State private var allergenDraft: String = ""

    var body: some View {
        Form {
            Section {
                Picker("Baseline skin state", selection: Binding(
                    get: { engine.baselineSkin },
                    set: { engine.updateBaseline($0) }
                )) {
                    ForEach(BaselineSkinState.allCases) { state in
                        Text(state.rawValue).tag(state)
                    }
                }
                .font(DermadreamTheme.displaySemibold(16))

                Text(engine.baselineSkin.detail)
                    .font(DermadreamTheme.displaySemibold(13))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Product onboarding")
            }

            Section {
                TextEditor(text: $allergenDraft)
                    .frame(minHeight: 120)
                    .font(DermadreamTheme.displaySemibold(14))
                Button("Save allergen keywords") {
                    let parts = allergenDraft
                        .split(whereSeparator: \.isNewline)
                        .flatMap { $0.split(separator: ",") }
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    engine.replaceAllergens(parts)
                }
                .font(DermadreamTheme.displaySemibold(16))
                .tint(DermadreamTheme.deepUmber)
            } header: {
                Text("Allergy lexicon")
            } footer: {
                Text("One keyword per line or comma-separated. Matching is substring-based for this prototype.")
                    .font(DermadreamTheme.displaySemibold(12))
            }

            Section("Active keywords") {
                if engine.knownAllergens.isEmpty {
                    Text("None saved")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(engine.knownAllergens, id: \.self) { token in
                        Text(token)
                            .font(DermadreamTheme.displaySemibold(14))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DermadreamTheme.workspaceBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .onAppear {
            allergenDraft = engine.knownAllergens.joined(separator: ", ")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(DermadreamEngine())
    }
}
