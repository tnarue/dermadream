//
//  ChatView.swift
//  dermadream
//

import SwiftUI

struct ChatView: View {
    var seed: String?
    @EnvironmentObject private var engine: DermadreamEngine
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var didApplySeed: Bool = false

    private var isSendDisabled: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(engine.chatMessages) { message in
                                ChatBubble(message: message)
                                    .id(message.id.uuidString)
                            }

                            if engine.isLoading {
                                TypingIndicator()
                                    .id("typing-indicator")
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: engine.chatMessages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: engine.isLoading) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }

                composer
            }
            .background(DermadreamTheme.workspaceBackground.ignoresSafeArea())
            .navigationTitle("Ask Dermadream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Ask Dermadream")
                        .font(DermadreamTheme.displaySemibold(17))
                        .foregroundStyle(DermadreamTheme.charcoalGray)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(DermadreamTheme.displaySemibold(16))
                        .foregroundStyle(DermadreamTheme.deepUmber)
                }
            }
            .toolbarBackground(DermadreamTheme.creamShell, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                guard !didApplySeed else { return }
                didApplySeed = true
                if let seed, !seed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    engine.sendMessage(seed)
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        let anchor: String
        if engine.isLoading {
            anchor = "typing-indicator"
        } else if let last = engine.chatMessages.last {
            anchor = last.id.uuidString
        } else {
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(anchor, anchor: .bottom)
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField(
                "",
                text: $draft,
                prompt: Text("Ask Dermadream...")
                    .foregroundStyle(DermadreamTheme.softSlate),
                axis: .vertical
            )
            .lineLimit(1...4)
            .font(DermadreamTheme.displaySemibold(15))
            .foregroundStyle(DermadreamTheme.charcoalGray)
            .tint(DermadreamTheme.deepUmber)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DermadreamTheme.creamShell)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DermadreamTheme.softSlate.opacity(0.4), lineWidth: 1)
                    )
            )
            .disabled(engine.isLoading)

            Button {
                let text = draft
                draft = ""
                engine.sendMessage(text)
            } label: {
                Group {
                    if engine.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(DermadreamTheme.deepUmber)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: DermadreamTheme.deepUmber.opacity(isSendDisabled ? 0 : 0.18), radius: 8, x: 0, y: 4)
            }
            .disabled(isSendDisabled)
            .opacity(isSendDisabled ? 0.4 : 1)
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(DermadreamTheme.deepUmber)
                        .frame(width: 8, height: 8)
                        .scaleEffect(phase == index ? 1.3 : 0.7)
                        .opacity(phase == index ? 1.0 : 0.4)
                        .animation(.easeInOut(duration: 0.35), value: phase)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: DermadreamTheme.charcoalGray.opacity(0.05), radius: 10, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DermadreamTheme.subtleBorder, lineWidth: 1)
            )
            Spacer(minLength: 40)
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(DermadreamTheme.displaySemibold(15))
                .foregroundStyle(message.role == .user ? Color.white : DermadreamTheme.charcoalGray)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.role == .user ? DermadreamTheme.deepUmber : Color.white)
                        .shadow(color: DermadreamTheme.charcoalGray.opacity(message.role == .user ? 0 : 0.05), radius: 10, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(message.role == .user ? Color.clear : DermadreamTheme.subtleBorder, lineWidth: 1)
                )
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    ChatView(seed: "What should I stop using?")
        .environmentObject(DermadreamEngine())
}
