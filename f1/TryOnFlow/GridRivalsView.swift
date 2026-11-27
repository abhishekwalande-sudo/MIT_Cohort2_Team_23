//
//  GridRivalsView.swift
//  f1
//
//  Multiplayer / friends room creation and join flow for TRY-ON Grid Rivals.
//

import SwiftUI

struct GridRivalsView: View {
    @Bindable var store: TryOnStore

    @State private var playerCount: Int = 2
    @State private var createdCode: String?
    @State private var joinCodeInput: String = ""
    @State private var joinFeedback: String?
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                FlowBackBar(title: "TRY-ON") {
                    store.backToHome()
                }
                .reveal(appeared, 0)

                ScreenTitle(
                    eyebrow: "TRY-ON · MULTIPLAYER",
                    title: "GRID RIVALS",
                    subtitle: "Two or four friends. One circuit. Whose strategy is fastest?"
                )
                .reveal(appeared, 0)

                createRoomCard
                    .reveal(appeared, 1)

                joinRoomCard
                    .reveal(appeared, 2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .onAppear { appeared = true }
    }

    private var createRoomCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("CREATE A ROOM")

            Text("Selected Circuit: \(store.selectedCircuit.name)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(F1.muted)

            HStack(spacing: 8) {
                ForEach([2, 4], id: \.self) { count in
                    let selected = playerCount == count
                    HButton(feedback: .selection) {
                        playerCount = count
                    } label: {
                        Text("\(count) Players")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(selected ? .white : F1.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selected ? F1.purple.opacity(0.24) : F1.background.opacity(0.6),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selected ? F1.purple : .white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressStyle())
                }
            }

            if let code = createdCode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ROOM CODE READY (PREVIEW)")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(F1.purple)
                    HStack {
                        Text(code)
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("1 / \(playerCount) Joined")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(F1.green)
                    }
                    Text("Live multiplayer lobbies are coming soon. Share this preview code or test solo in Strategy Lab.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(F1.muted)
                }
                .padding(12)
                .background(F1.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(F1.purple.opacity(0.45), lineWidth: 1))
            }

            RedPillButton(label: createdCode == nil ? "Create Room" : "Regenerate Room Code", icon: "plus.circle.fill") {
                let digits = Int.random(in: 1000...9999)
                createdCode = "F1-\(digits)"
            }
        }
        .padding(16)
        .flowCard(radius: 20, stroke: F1.purple.opacity(0.30))
    }

    private var joinRoomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("JOIN WITH CODE")

            TextField("", text: $joinCodeInput, prompt: Text("Enter room code (e.g. F1-4821)").foregroundStyle(F1.muted))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(F1.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))

            if let joinFeedback {
                Text(joinFeedback)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(F1.yellow)
            }

            HButton(feedback: .impact(weight: .medium)) {
                let trimmed = joinCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if trimmed.count < 4 {
                    joinFeedback = "Enter a valid room code to join."
                } else {
                    joinFeedback = "Room \(trimmed) preview: live multiplayer matchmaking is coming soon."
                }
            } label: {
                Text("Join Room")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(F1.surfaceHi, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
        }
        .padding(16)
        .flowCard(radius: 20)
    }
}
