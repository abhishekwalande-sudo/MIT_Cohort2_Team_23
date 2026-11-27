//
//  ReactionRushView.swift
//  f1
//
//  Five red starting lights reaction-time trainer for TRY-ON.
//

import SwiftUI

struct ReactionRushView: View {
    @Bindable var store: TryOnStore

    private enum Phase {
        case idle
        case lightingUp(litCount: Int)
        case waitingForLightsOut
        case lightsOut(startedAt: Date)
        case result(ms: Int)
        case jumpStart
    }

    @State private var phase: Phase = .idle
    @State private var lastReactionMs: Int?
    @State private var sequenceTask: Task<Void, Never>?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                FlowBackBar(title: "TRY-ON") {
                    sequenceTask?.cancel()
                    store.backToHome()
                }

                ScreenTitle(
                    eyebrow: "LIGHTS OUT PRACTICE",
                    title: "REACTION RUSH",
                    subtitle: "Tap the reaction zone as soon as all five red lights go out"
                )

                statsRow
                gantryCard
                tapZoneCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .onDisappear {
            sequenceTask?.cancel()
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            statBox(
                title: "LAST REACTION",
                value: lastReactionMs.map { "\($0) ms" } ?? "—",
                accent: .white
            )
            statBox(
                title: "PERSONAL BEST",
                value: store.reactionBestMs.map { "\($0) ms" } ?? "—",
                accent: F1.green
            )
        }
    }

    private func statBox(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .tracking(1.2)
                .foregroundStyle(F1.muted)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .flowCard(radius: 16)
    }

    // MARK: - Five Red Lights Gantry

    private var litCount: Int {
        switch phase {
        case .idle, .lightsOut, .result, .jumpStart:
            return 0
        case .lightingUp(let count):
            return count
        case .waitingForLightsOut:
            return 5
        }
    }

    private var gantryCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { index in
                    let isLit = index <= litCount
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 22, height: 22)
                        Circle()
                            .fill(isLit ? F1.red : Color.white.opacity(0.09))
                            .frame(width: 30, height: 30)
                            .shadow(color: isLit ? F1.red.opacity(0.9) : .clear, radius: 12)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.10), lineWidth: 1))
                }
            }

            Text(statusHeadline)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor)
        }
        .padding(16)
        .flowCard(radius: 20)
    }

    private var statusHeadline: String {
        switch phase {
        case .idle:                return "READY ON THE GRID"
        case .lightingUp:          return "LIGHTS COMING ON..."
        case .waitingForLightsOut: return "HOLD STEADY..."
        case .lightsOut:           return "LIGHTS OUT! GO! GO! GO!"
        case .result(let ms):      return ratingLabel(for: ms)
        case .jumpStart:           return "JUMP START! +5s PENALTY"
        }
    }

    private var statusColor: Color {
        switch phase {
        case .lightsOut:  return F1.green
        case .jumpStart:  return F1.yellow
        case .result:     return F1.green
        default:          return .white
        }
    }

    private func ratingLabel(for ms: Int) -> String {
        switch ms {
        case ..<200:  return "SUPERHUMAN POLE START!"
        case ..<260:  return "F1 DRIVER REFLEXES"
        case ..<340:  return "SOLID GRID LAUNCH"
        default:      return "SLOW OFF THE LINE"
        }
    }

    // MARK: - Interactive Tap Zone

    private var tapZoneCard: some View {
        let isGo = {
            if case .lightsOut = phase { return true }
            return false
        }()

        return Button {
            handleTap()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: isGo ? "hand.tap.fill" : "timer")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(isGo ? F1.green : F1.red)

                Text(tapPromptTitle)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)

                Text(tapPromptSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(F1.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isGo ? F1.green.opacity(0.18) : F1.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isGo ? F1.green : F1.red.opacity(0.35), lineWidth: isGo ? 2 : 1)
            )
        }
        .buttonStyle(PressStyle())
    }

    private var tapPromptTitle: String {
        switch phase {
        case .idle:                         return "TAP TO START"
        case .lightingUp, .waitingForLightsOut: return "WAIT FOR LIGHTS OUT"
        case .lightsOut:                    return "TAP NOW!"
        case .result(let ms):               return "\(ms) ms · TAP TO RETRY"
        case .jumpStart:                    return "JUMP START · TAP TO RETRY"
        }
    }

    private var tapPromptSubtitle: String {
        switch phase {
        case .idle, .result, .jumpStart:
            return "Five red lights will ignite, then go out at a random interval."
        case .lightingUp, .waitingForLightsOut:
            return "Don't release early!"
        case .lightsOut:
            return "React as fast as you can!"
        }
    }

    // MARK: - Logic

    private func handleTap() {
        switch phase {
        case .idle, .result, .jumpStart:
            startSequence()
        case .lightingUp, .waitingForLightsOut:
            sequenceTask?.cancel()
            phase = .jumpStart
        case .lightsOut(let startedAt):
            let ms = max(1, Int((Date().timeIntervalSince(startedAt) * 1000.0).rounded()))
            lastReactionMs = ms
            store.recordReaction(ms: ms)
            phase = .result(ms: ms)
        }
    }

    private func startSequence() {
        sequenceTask?.cancel()
        sequenceTask = Task { @MainActor in
            for count in 1...5 {
                phase = .lightingUp(litCount: count)
                try? await Task.sleep(for: .milliseconds(650))
                if Task.isCancelled { return }
            }
            phase = .waitingForLightsOut
            let randomDelayMs = Int.random(in: 900...2600)
            try? await Task.sleep(for: .milliseconds(randomDelayMs))
            if Task.isCancelled { return }
            phase = .lightsOut(startedAt: Date())
        }
    }
}
