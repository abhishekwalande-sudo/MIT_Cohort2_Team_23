//
//  StrategySetupView.swift
//  f1
//
//  Screen 3 of TRY-ON Flow: Strategy Setup (Pit stops, pit laps, tyre stints, live summary).
//

import SwiftUI

struct StrategySetupView: View {
    @Bindable var store: TryOnStore
    @State private var appeared = false

    private var circuit: Circuit { store.selectedCircuit }
    private var stints: [StintPlan] { store.strategy.stints(totalLaps: circuit.totalLaps) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                FlowBackBar(title: "Select Circuit") {
                    store.openCircuitSelect()
                }
                .reveal(appeared, 0)

                ScreenTitle(
                    eyebrow: "TRY-ON · PIT WALL",
                    title: "STRATEGY LAB",
                    subtitle: "Configure pit stops and tyre compounds for \(circuit.name)"
                )
                .reveal(appeared, 0)

                circuitOverviewCard
                    .reveal(appeared, 1)

                pitStopsSection
                    .reveal(appeared, 2)

                pitLapSlidersSection
                    .reveal(appeared, 3)

                tyresByStintSection
                    .reveal(appeared, 4)

                liveSummaryCard
                    .reveal(appeared, 5)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            startRaceFooter
        }
        .onAppear { appeared = true }
    }

    // MARK: - Circuit Overview

    private var circuitOverviewCard: some View {
        let botStrategy = circuit.defaultBotStrategy

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(circuit.tint.opacity(0.16))
                CircuitShape(pts: circuit.pts)
                    .stroke(F1.red, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .padding(10)
            }
            .frame(width: 78, height: 78)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.10), lineWidth: 1))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(circuit.flag)
                    Text(circuit.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    metaPill(icon: "flag.checkered", text: circuit.distanceLabel)
                    metaPill(icon: "sun.max.fill", text: "\(circuit.trackTempC)°C")
                }

                HStack(spacing: 6) {
                    Circle().fill(Driver.bot.color).frame(width: 6, height: 6)
                    Text("Rival: \(Driver.bot.name) · \(botStrategy.pitStopCount)-Stop Plan")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(F1.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .flowCard(radius: 18)
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(F1.red)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
    }

    // MARK: - Pit Stops Count

    private var pitStopsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("PIT STOPS")
                Spacer()
                Text(String(format: "~%.1fs lost per stop", circuit.pitLossSeconds))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(F1.muted)
            }

            HStack(spacing: 8) {
                ForEach([1, 2, 3], id: \.self) { count in
                    let isSelected = store.strategy.pitStopCount == count
                    HButton(feedback: .selection) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.setPitStopCount(count)
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(count)")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                            Text(count == 1 ? "STOP" : "STOPS")
                                .font(.system(size: 9, weight: .black))
                                .tracking(1)
                        }
                        .foregroundStyle(isSelected ? .white : F1.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isSelected ? F1.redGradient : LinearGradient(colors: [F1.background.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? F1.red : .white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        .padding(16)
        .flowCard(radius: 20)
    }

    // MARK: - Pit Stop Lap Sliders

    private var pitLapSlidersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle("PIT STOP LAPS")
                Spacer()
                Text("Valid: L2–L\(circuit.totalLaps - 1)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(F1.muted)
            }

            ForEach(0..<store.strategy.pitStopCount, id: \.self) { index in
                pitLapSliderRow(index: index)
                if index < store.strategy.pitStopCount - 1 {
                    Divider().overlay(.white.opacity(0.08))
                }
            }
        }
        .padding(16)
        .flowCard(radius: 20)
    }

    private func pitLapSliderRow(index: Int) -> some View {
        let range = store.strategy.validRange(forStop: index, totalLaps: circuit.totalLaps)
        let currentLap = index < store.strategy.pitLaps.count ? store.strategy.pitLaps[index] : range.lowerBound

        let binding = Binding<Double>(
            get: { Double(currentLap) },
            set: { newValue in
                store.updatePitLap(at: index, to: Int(newValue.rounded()))
            }
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PIT STOP \(index + 1)")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1)
                    .foregroundStyle(.white)
                Spacer()
                Text("LAP \(currentLap)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(F1.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(F1.red.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(F1.red.opacity(0.35), lineWidth: 1))
            }

            if range.lowerBound < range.upperBound {
                Slider(
                    value: binding,
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                )
                .tint(F1.red)
            } else {
                Text("Fixed at Lap \(range.lowerBound) (no room to shift)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(F1.muted)
            }

            HStack {
                Text("L\(range.lowerBound)")
                Spacer()
                Text("L\(range.upperBound)")
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(F1.muted)
        }
    }

    // MARK: - Tyres by Stint

    private var tyresByStintSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle("TYRES BY STINT")
                Spacer()
                Text("\(stints.count) Stints")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(F1.muted)
            }

            ForEach(stints) { stint in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("STINT \(stint.id + 1)")
                            .font(.system(size: 11, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(.white)
                        Text("· \(stint.rangeLabel) (\(stint.lapCount)L)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(F1.muted)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        ForEach(TyreCompound.allCases) { compound in
                            let selected = stint.compound == compound
                            HButton(feedback: .selection) {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    store.updateCompound(at: stint.id, to: compound)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .stroke(compound.color, lineWidth: 2.5)
                                            .frame(width: 18, height: 18)
                                        Text(compound.shortCode)
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundStyle(compound.color)
                                    }
                                    Text(compound.name)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(selected ? .white : F1.muted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selected ? compound.color.opacity(0.18) : F1.background.opacity(0.55))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selected ? compound.color : .white.opacity(0.08), lineWidth: selected ? 1.5 : 1)
                                )
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                }
            }
        }
        .padding(16)
        .flowCard(radius: 20)
    }

    // MARK: - Live Strategy Summary

    private var liveSummaryCard: some View {
        let totalLoss = store.strategy.estimatedPitLoss(for: circuit)
        let pitLabel = store.strategy.pitLaps.map { "L\($0)" }.joined(separator: ", ")

        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle("LIVE STRATEGY SUMMARY")

            // Proportional compound bar
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(stints) { stint in
                        let fraction = CGFloat(stint.lapCount) / CGFloat(max(1, circuit.totalLaps))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(stint.compound.color)
                            .frame(width: max(18, (geo.size.width - CGFloat(max(0, stints.count - 1)) * 3) * fraction))
                            .overlay {
                                Text(stint.compound.shortCode)
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.black.opacity(0.85))
                            }
                    }
                }
            }
            .frame(height: 22)

            VStack(spacing: 6) {
                ForEach(stints) { stint in
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(stint.compound.color).frame(width: 8, height: 8)
                            Text("\(stint.compound.name): \(stint.rangeLabel)")
                                .font(.system(size: 12, weight: .bold))
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("PIT LAPS")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1)
                        .foregroundStyle(F1.muted)
                    Text(pitLabel)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("EST. PIT LOSS")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1)
                        .foregroundStyle(F1.muted)
                    Text(String(format: "%.1fs", totalLoss))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(F1.yellow)
                }
            }
        }
        .padding(16)
        .flowCard(radius: 20, stroke: F1.red.opacity(0.30))
    }

    private var startRaceFooter: some View {
        VStack(spacing: 0) {
            RedPillButton(label: "START RACE", icon: "flag.checkered") {
                store.startRace()
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [F1.background.opacity(0), F1.background.opacity(0.92), F1.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
