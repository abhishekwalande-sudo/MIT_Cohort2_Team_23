//
//  PredictionLockedView.swift
//  f1
//
//  Screen 2 of Standings Flow: Prediction Locked confirmation.
//

import SwiftUI

struct PredictionLockedView: View {
    @Bindable var store: StandingsPredictionStore
    @State private var appeared = false

    private var lockedDrivers: [(PodiumSlot, GPDriver)] {
        let byId = Dictionary(uniqueKeysWithValues: GPDriver.roster.map { ($0.id, $0) })
        return PodiumSlot.allCases.compactMap { slot in
            if let locked = store.lockedPrediction,
               let d = byId[locked.driverId(for: slot)] {
                return (slot, d)
            }
            if let d = store.driver(for: slot) {
                return (slot, d)
            }
            return nil
        }
    }

    private var shareMessage: String {
        let picks = lockedDrivers.map { "\($0.0.label): \($0.1.full)" }.joined(separator: " · ")
        return "My \(store.targetRace.circuit.name) Podium Prediction — \(picks)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                FlowBackBar(title: "Make Your Picks") {
                    store.step = .makePicks
                }
                .reveal(appeared, 0)

                ScreenTitle(
                    eyebrow: "SUBMISSION CONFIRMED",
                    title: "PREDICTION LOCKED",
                    subtitle: "You're on the grid · Three picks · One race"
                )
                .reveal(appeared, 0)

                confirmationBadge
                    .reveal(appeared, 1)

                podiumSummarySection
                    .reveal(appeared, 2)

                raceStatusCard
                    .reveal(appeared, 3)

                lockedExplanationCard
                    .reveal(appeared, 4)

                VStack(spacing: 10) {
                    RedPillButton(label: "Show Race Results", icon: "flag.checkered") {
                        store.showRaceResults()
                    }

                    ShareLink(item: shareMessage) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .bold))
                            Text("Share Prediction")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(F1.surface, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                }
                .padding(.top, 4)
                .reveal(appeared, 5)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .onAppear { appeared = true }
    }

    private var confirmationBadge: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(F1.green.opacity(0.16))
                    .frame(width: 54, height: 54)
                Circle()
                    .stroke(F1.green.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 54, height: 54)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(F1.green)
            }
            Text("SAMPLE PROTOTYPE · PICKS SAVED")
                .font(.system(size: 10, weight: .black))
                .tracking(1.6)
                .foregroundStyle(F1.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .flowCard(radius: 20, stroke: F1.green.opacity(0.28))
    }

    private var podiumSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("PODIUM SUMMARY")
            HStack(spacing: 10) {
                ForEach(lockedDrivers, id: \.0.id) { slot, driver in
                    VStack(spacing: 8) {
                        Text(slot.label)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(slot == .p1 ? F1.yellow : F1.muted)
                        DriverMonogramBadge(driver: driver, size: 40)
                        Text(driver.last)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(driver.team)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(F1.muted)
                            .lineLimit(1)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .flowCard(radius: 16, stroke: driver.color.opacity(0.45))
                }
            }
        }
    }

    private var raceStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(F1.green)
                Text("RACE STATUS")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.6)
                    .foregroundStyle(F1.green)
                Spacer()
                Text("SAMPLE DATA")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(F1.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(F1.surfaceHi, in: Capsule())
            }

            Text("COMPLETED (SIMULATED)")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(.white)

            Text("\(store.targetRace.circuit.name) · \(store.targetRace.circuit.place)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(F1.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flowCard(radius: 18, stroke: F1.green.opacity(0.32))
    }

    private var lockedExplanationCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Prediction is locked")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            Text("Predictions cannot be edited after locking. This sample race classification is ready to score against your picks.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(F1.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flowCard(radius: 16)
    }
}

// MARK: - Shared Back Bar for Standings Flow

struct FlowBackBar: View {
    let title: String
    let action: () -> Void

    var body: some View {
        HButton(feedback: .impact(weight: .light), action: action) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(F1.surfaceHi, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(F1.muted)
                Spacer()
            }
        }
        .buttonStyle(PressStyle())
    }
}
