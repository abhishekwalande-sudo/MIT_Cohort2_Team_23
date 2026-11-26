//
//  RaceResultsView.swift
//  f1
//
//  Screen 3 of Standings Flow: Race Results & Prediction Scoring.
//

import SwiftUI

struct RaceResultsView: View {
    @Bindable var store: StandingsPredictionStore
    @State private var appeared = false

    private var summary: RaceResultSummary? {
        store.latestResult
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                FlowBackBar(title: "Prediction Locked") {
                    store.step = .predictionLocked
                }
                .reveal(appeared, 0)

                ScreenTitle(
                    eyebrow: "SAMPLE CLASSIFICATION",
                    title: "RACE RESULTS",
                    subtitle: "\(store.targetRace.circuit.name) · Simulated prototype results (not official F1)"
                )
                .reveal(appeared, 0)

                if let summary {
                    scoreHeroCard(summary)
                        .reveal(appeared, 1)

                    predictionVsActualCard(summary)
                        .reveal(appeared, 2)

                    leaderboardImpactRow
                        .reveal(appeared, 3)

                    howPointsWorkCard
                        .reveal(appeared, 4)

                    RedPillButton(label: "View Leaderboard", icon: "trophy.fill") {
                        store.openLeaderboard(.global)
                    }
                    .padding(.top, 4)
                    .reveal(appeared, 5)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Score Hero

    private func scoreHeroCard(_ summary: RaceResultSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("YOUR RACE SCORE")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.6)
                    .foregroundStyle(F1.muted)
                Spacer()
                Text("SAMPLE SCORE")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(F1.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(F1.red.opacity(0.14), in: Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(summary.totalPointsEarned)")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("points earned")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(F1.red)
            }

            Text(summary.pointsBreakdownText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(F1.muted)

            if summary.perfectPodiumBonus > 0 {
                Text("Includes +\(summary.perfectPodiumBonus) Perfect Podium Bonus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(F1.green)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                F1.surface
                RadialGradient(
                    colors: [F1.red.opacity(0.25), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 200
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Prediction vs Actual

    private func predictionVsActualCard(_ summary: RaceResultSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("PREDICTION VS ACTUAL")

            VStack(spacing: 10) {
                ForEach(summary.rows) { row in
                    HStack(spacing: 10) {
                        DriverMonogramBadge(driver: row.predictedDriver, size: 34)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your pick · \(row.slot.label)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(F1.muted)
                            Text(row.predictedDriver.last)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Actual · \(row.slot.label)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(F1.muted)
                            Text(row.actualDriver.last)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .trailing, spacing: 2) {
                            Image(systemName: row.outcome.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(row.outcome.color)
                            Text("+\(row.totalPoints)")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(row.totalPoints > 0 ? row.outcome.color : F1.muted)
                        }
                    }
                    .padding(12)
                    .flowCard(radius: 14, stroke: row.totalPoints > 0 ? row.outcome.color.opacity(0.35) : nil)
                }
            }
        }
    }

    // MARK: - Leaderboard Impact

    private var leaderboardImpactRow: some View {
        let rank = store.currentUserGlobalRank
        let delta = store.globalRankDelta

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("UPDATED LEADERBOARD")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(F1.muted)
                Text("\(store.currentUserTotalPoints) pts")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .flowCard(radius: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("NEW POSITION")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(F1.muted)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(ordinal(rank))
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    if delta > 0 {
                        Text("+\(delta)")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(F1.green)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .flowCard(radius: 16)
        }
    }

    // MARK: - Scoring Legend

    private var howPointsWorkCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(F1.red)
                Text("HOW POINTS WORK")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(.white)
            }

            Text("Exact position +\(PredictionScoring.exactPositionPoints) · Podium, wrong spot +\(PredictionScoring.podiumWrongSpotPoints)\nPerfect podium bonus +\(PredictionScoring.perfectPodiumBonus) · Long shot bonus +\(PredictionScoring.longShotBonusPoints) (when on podium)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(F1.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flowCard(radius: 16)
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let tens = (n / 10) % 10
        if tens == 1 {
            suffix = "th"
        } else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}
