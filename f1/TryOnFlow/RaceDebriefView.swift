//
//  RaceDebriefView.swift
//  f1
//
//  Screen 5 of TRY-ON Flow: Post-Race Debrief comparing user strategy against bot.
//

import SwiftUI

struct RaceDebriefView: View {
    @Bindable var store: TryOnStore
    @State private var appeared = false

    private var result: RaceResult? { store.raceResult }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(
                    eyebrow: "POST-RACE ANALYSIS",
                    title: "RACE DEBRIEF",
                    subtitle: "\(store.selectedCircuit.name) · \(store.selectedCircuit.distanceLabel)"
                )
                .reveal(appeared, 0)

                if let result {
                    raceResultHero(result)
                        .reveal(appeared, 1)

                    timingComparisonCard(result)
                        .reveal(appeared, 2)

                    yourRacePlanCard(result)
                        .reveal(appeared, 3)

                    botStrategyComparisonCard(result)
                        .reveal(appeared, 4)

                    actionButtons
                        .reveal(appeared, 5)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Race Result Hero

    private func raceResultHero(_ result: RaceResult) -> some View {
        let won = result.finishedAheadOfBot
        let accent = won ? F1.green : F1.red
        let deltaText = TryOnRaceEngine.formatDelta(result.timeDelta)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RACE RESULT")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(F1.muted)
                Spacer()
                Text(won ? "AHEAD OF BOT" : "BEHIND BOT")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.16), in: Capsule())
                    .overlay(Capsule().stroke(accent.opacity(0.4), lineWidth: 1))
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("P\(result.finalPosition)")
                    .font(.system(size: 46, weight: .black, design: .monospaced))
                    .foregroundStyle(won ? F1.yellow : .white)

                VStack(alignment: .leading, spacing: 3) {
                    Text(won ? "Strategy Victory!" : "Out-strategized by Bot")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Delta vs \(Driver.bot.name): \(deltaText)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                F1.surface
                RadialGradient(
                    colors: [accent.opacity(0.22), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 210
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(0.38), lineWidth: 1))
    }

    // MARK: - Timing Comparison

    private func timingComparisonCard(_ result: RaceResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("TIME & PIT COMPARISON")

            HStack(spacing: 10) {
                driverTimeTile(
                    title: "YOUR TIME",
                    time: TryOnRaceEngine.formatRaceTime(result.userTotalTime),
                    sub: "\(result.userPitStops) pit stop\(result.userPitStops == 1 ? "" : "s") · Best \(String(format: "%.2fs", result.fastestUserLap))",
                    color: Driver.user.color
                )
                driverTimeTile(
                    title: "BOT TIME",
                    time: TryOnRaceEngine.formatRaceTime(result.botTotalTime),
                    sub: "\(result.botPitStops) pit stop\(result.botPitStops == 1 ? "" : "s") · Best \(String(format: "%.2fs", result.fastestBotLap))",
                    color: Driver.bot.color
                )
            }
        }
        .padding(16)
        .flowCard(radius: 20)
    }

    private func driverTimeTile(title: String, time: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .tracking(1)
                    .foregroundStyle(F1.muted)
            }
            Text(time)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text(sub)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(F1.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(F1.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Your Race Plan Timeline

    private func yourRacePlanCard(_ result: RaceResult) -> some View {
        let stints = result.userStrategy.stints(totalLaps: result.circuit.totalLaps)
        let pitLapsText = result.userStrategy.pitLaps.map { "L\($0)" }.joined(separator: ", ")

        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle("YOUR RACE PLAN")

            // Visual stint bar
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(stints) { stint in
                        let fraction = CGFloat(stint.lapCount) / CGFloat(max(1, result.circuit.totalLaps))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(stint.compound.color)
                            .frame(width: max(20, (geo.size.width - CGFloat(max(0, stints.count - 1)) * 3) * fraction))
                            .overlay {
                                Text("\(stint.compound.shortCode) \(stint.rangeLabel)")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.85))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                    }
                }
            }
            .frame(height: 26)

            VStack(spacing: 7) {
                ForEach(stints) { stint in
                    HStack {
                        HStack(spacing: 7) {
                            Circle().fill(stint.compound.color).frame(width: 8, height: 8)
                            Text("\(stint.compound.name): \(stint.rangeLabel)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text("\(stint.lapCount) laps")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(F1.muted)
                    }
                }
            }

            Divider().overlay(.white.opacity(0.08))

            HStack {
                summaryStat("PIT STOPS", "\(result.userPitStops)")
                Spacer()
                summaryStat("PIT LAPS", pitLapsText)
                Spacer()
                summaryStat("PIT TIME LOST", String(format: "%.1fs", result.userPitLossTotal))
            }
        }
        .padding(16)
        .flowCard(radius: 20)
    }

    private func summaryStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .black))
                .tracking(1)
                .foregroundStyle(F1.muted)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Bot Strategy Reference

    private func botStrategyComparisonCard(_ result: RaceResult) -> some View {
        let botStints = result.botStrategy.stints(totalLaps: result.circuit.totalLaps)
        let desc = botStints.map { "\($0.compound.name) (\($0.rangeLabel))" }.joined(separator: " → ")

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(Driver.bot.color).frame(width: 7, height: 7)
                Text("BOT STRATEGY")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1)
                    .foregroundStyle(F1.muted)
            }
            Text(desc)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("Total pit time lost: \(String(format: "%.1fs", result.botPitLossTotal))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(F1.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flowCard(radius: 16)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            RedPillButton(label: "REMATCH", icon: "arrow.counterclockwise") {
                store.rematch()
            }

            HStack(spacing: 10) {
                HButton(feedback: .selection) {
                    store.openCircuitSelect()
                } label: {
                    Text("Change Circuit")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .flowCard(radius: 14)
                }
                .buttonStyle(PressStyle())

                HButton(feedback: .selection) {
                    store.backToHome()
                } label: {
                    Text("TRY-ON Home")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(F1.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .flowCard(radius: 14)
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.top, 4)
    }
}
