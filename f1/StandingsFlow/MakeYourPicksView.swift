//
//  MakeYourPicksView.swift
//  f1
//
//  Screen 1 of Standings Flow: Make Your Picks (P1 / P2 / P3 podium predictor).
//

import SwiftUI

struct MakeYourPicksView: View {
    @Bindable var store: StandingsPredictionStore
    @State private var appeared = false
    @State private var showLockConfirmation = false
    @State private var searchQuery = ""

    private var filteredDrivers: [GPDriver] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return GPDriver.roster }
        return GPDriver.roster.filter {
            $0.full.localizedCaseInsensitiveContains(q) ||
            $0.team.localizedCaseInsensitiveContains(q) ||
            $0.id.localizedCaseInsensitiveContains(q)
        }
    }

    private var isLocked: Bool {
        store.lockedPrediction != nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(
                    eyebrow: "STANDINGS · PREDICTOR",
                    title: "MAKE YOUR PICKS",
                    subtitle: "\(store.targetRace.circuit.name) · \(store.targetRace.circuit.place) · Sample prototype"
                )
                .reveal(appeared, 0)

                countdownCard
                    .reveal(appeared, 1)

                if isLocked {
                    lockedNoticeCard
                        .reveal(appeared, 2)
                }

                podiumSlotsRow
                    .reveal(appeared, 2)

                driverListHeader
                    .reveal(appeared, 3)

                CapsuleSearchField(prompt: "Search driver or team", text: $searchQuery)
                    .reveal(appeared, 3)

                LazyVStack(spacing: 8) {
                    ForEach(filteredDrivers) { driver in
                        driverPickerRow(driver)
                    }
                }
                .reveal(appeared, 4)

                actionSection
                    .padding(.top, 4)
                    .reveal(appeared, 5)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .onAppear { appeared = true }
        .confirmationDialog(
            "Lock in your podium prediction?",
            isPresented: $showLockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Lock in Prediction", role: .destructive) {
                store.lockPrediction()
            }
            Button("Review Picks", role: .cancel) {}
        } message: {
            Text("P1: \(store.p1?.last ?? "-") · P2: \(store.p2?.last ?? "-") · P3: \(store.p3?.last ?? "-"). Predictions cannot be edited once locked.")
        }
    }

    // MARK: - Countdown

    private var countdownCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, store.predictionDeadline.timeIntervalSince(context.date))
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(F1.red)
                        .frame(width: 6, height: 6)
                    Text(remaining > 0 ? "CLOSES IN \(formatCountdown(remaining))" : "PICKS CLOSED")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(F1.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(F1.red.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(F1.red.opacity(0.35), lineWidth: 1))

                Spacer()

                Text("Round \(store.targetRace.round)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(F1.muted)
            }
            .padding(12)
            .flowCard(radius: 16)
        }
    }

    private var lockedNoticeCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(F1.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Prediction locked for \(store.targetRace.circuit.name)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text("Picks cannot be modified after locking.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(F1.muted)
            }
            Spacer()
            Button {
                store.step = .predictionLocked
            } label: {
                Text("View")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(F1.surfaceHi, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .flowCard(radius: 16, stroke: F1.green.opacity(0.4))
    }

    // MARK: - Podium Slots

    private var podiumSlotsRow: some View {
        HStack(spacing: 10) {
            ForEach(PodiumSlot.allCases) { slot in
                let selected = store.driver(for: slot)
                let isActive = !isLocked && store.activeSlot == slot

                HButton(feedback: .impact(weight: .light)) {
                    guard !isLocked else { return }
                    store.activeSlot = slot
                } label: {
                    VStack(spacing: 8) {
                        HStack {
                            Text(slot.label)
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(isActive ? F1.red : F1.muted)
                            Spacer()
                            if selected != nil && !isLocked {
                                Button {
                                    store.clearSlot(slot)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(F1.muted)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let d = selected {
                            DriverMonogramBadge(driver: d, size: 38)
                            Text(d.last)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("#\(d.number) · \(d.team)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(F1.muted)
                                .lineLimit(1)
                        } else {
                            ZStack {
                                Circle()
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                    .foregroundStyle(isActive ? F1.red.opacity(0.7) : .white.opacity(0.2))
                                    .frame(width: 38, height: 38)
                                Text("?")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(isActive ? F1.red : F1.muted)
                            }
                            Text(isActive ? "Picking \(slot.label)..." : "Tap to pick")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isActive ? .white : F1.muted)
                                .lineLimit(1)
                            Text(slot.title)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(F1.muted)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .flowCard(
                        radius: 16,
                        stroke: isActive ? F1.red : (selected != nil ? selected!.color.opacity(0.45) : nil)
                    )
                }
                .buttonStyle(PressStyle())
            }
        }
    }

    // MARK: - Driver Picker List

    private var driverListHeader: some View {
        HStack {
            SectionTitle(isLocked ? "LOCKED ROSTER" : "CHOOSE A DRIVER FOR \(store.activeSlot.label)")
            Spacer()
            Text("\(store.pickedCount) of 3 picked")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(store.pickedCount == 3 ? F1.green : F1.muted)
        }
    }

    private func driverPickerRow(_ driver: GPDriver) -> some View {
        let assigned = store.assignedSlot(for: driver)
        let isLongShot = PredictionScoring.isLongShot(driver)
        let points = StandingsView.table.first(where: { $0.driver.id == driver.id })?.points ?? 0

        return HButton(feedback: .impact(weight: .light)) {
            guard !isLocked else { return }
            store.assign(driver)
        } label: {
            HStack(spacing: 12) {
                DriverMonogramBadge(driver: driver, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(driver.full)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(driver.team) · #\(driver.number) · \(points) pts")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(F1.muted)
                }

                Spacer()

                if isLongShot {
                    Text("Long shot +\(PredictionScoring.longShotBonusPoints)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(F1.yellow)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(F1.yellow.opacity(0.14), in: Capsule())
                }

                if let slot = assigned {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(slot.label)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(F1.red)
                        Text("Picked")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(F1.muted)
                    }
                    .frame(minWidth: 44, alignment: .trailing)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(isLocked ? F1.muted.opacity(0.35) : .white.opacity(0.7))
                        .frame(minWidth: 44, alignment: .trailing)
                }
            }
            .padding(12)
            .flowCard(
                radius: 16,
                stroke: assigned != nil ? driver.color.opacity(0.55) : nil
            )
            .opacity(isLocked && assigned == nil ? 0.55 : 1)
        }
        .buttonStyle(PressStyle())
        .disabled(isLocked)
    }

    // MARK: - Action Button

    private var actionSection: some View {
        VStack(spacing: 8) {
            if isLocked {
                RedPillButton(label: "Continue to Prediction Locked", icon: "lock.fill") {
                    store.step = .predictionLocked
                }
            } else if store.canLockPrediction {
                RedPillButton(label: "Lock in Prediction", icon: "lock.fill") {
                    showLockConfirmation = true
                }
                Text("All 3 picks selected. Locking cannot be undone.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(F1.muted)
            } else {
                HStack(spacing: 8) {
                    Text("Lock in Prediction")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(F1.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(F1.surfaceHi, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))

                Text("Select all 3 picks to lock in. Locking cannot be undone.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(F1.muted)
            }
        }
    }

    private func formatCountdown(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let mins = (total % 3_600) / 60
        let secs = total % 60
        if days > 0 {
            return String(format: "%dd %02dh %02dm", days, hours, mins)
        }
        return String(format: "%02d:%02d:%02d", hours, mins, secs)
    }
}

// MARK: - Shared Driver Monogram Badge

struct DriverMonogramBadge: View {
    let driver: GPDriver
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(driver.color.opacity(0.22))
                .frame(width: size, height: size)
            Circle()
                .stroke(driver.color, lineWidth: 1.5)
                .frame(width: size, height: size)
            Text(driver.id)
                .font(.system(size: size * 0.3, weight: .black))
                .foregroundStyle(.white)
        }
    }
}
