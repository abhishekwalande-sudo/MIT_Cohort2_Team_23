//
//  RaceSimulationView.swift
//  f1
//
//  Screen 4 of TRY-ON Flow: Live Race Simulation with animated circuit map,
//  tyre degradation, pit stops, and running order.
//

import SwiftUI

struct RaceSimulationView: View {
    @Bindable var store: TryOnStore

    private var circuit: Circuit { store.selectedCircuit }
    private var state: RaceState { store.raceState }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                ScreenTitle(
                    eyebrow: "LIVE TELEMETRY · \(circuit.name.uppercased())",
                    title: "RACE SIMULATION",
                    subtitle: "\(circuit.weather) · Track \(circuit.trackTempC)°C"
                )

                hudRow
                circuitMapCard

                if let banner = state.statusBanner {
                    statusBannerRow(banner)
                }

                tyreAndPitCard
                runningOrderCard
                controlsRow
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            FlowBackBar(title: "Strategy Lab") {
                store.exitSimulationToSetup()
            }
            Spacer()
            HButton(feedback: .selection) {
                store.cycleSpeed()
            } label: {
                Text("\(Int(state.speedMultiplier))x SPEED")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(F1.surfaceHi, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
        }
    }

    // MARK: - HUD Row

    private var hudRow: some View {
        HStack(spacing: 10) {
            hudTile(
                label: "LAP",
                value: "\(state.currentLap)/\(state.totalLaps)",
                accent: .white
            )
            hudTile(
                label: "RACE TIME",
                value: TryOnRaceEngine.formatRaceTime(state.elapsedTime),
                accent: .white
            )
            hudTile(
                label: "POSITION",
                value: "P\(state.userPosition)",
                accent: state.userPosition == 1 ? F1.green : F1.yellow
            )
        }
    }

    private func hudTile(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(1.2)
                .foregroundStyle(F1.muted)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .flowCard(radius: 16)
    }

    // MARK: - Circuit Map

    private var circuitMapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("CIRCUIT TRACKER")
                Spacer()
                HStack(spacing: 12) {
                    LegendDot(color: Driver.user.color, name: Driver.user.shortCode)
                    LegendDot(color: Driver.bot.color, name: Driver.bot.shortCode)
                }
            }

            GeometryReader { geo in
                let inset: CGFloat = 24
                let rect = CGRect(
                    x: inset,
                    y: inset,
                    width: max(40, geo.size.width - inset * 2),
                    height: max(40, geo.size.height - inset * 2)
                )
                let path = CircuitShape(pts: circuit.pts).path(in: rect)
                let startPt = path.flowPoint(at: 0.002)
                let userPt = path.flowPoint(at: CGFloat(state.userTrackProgress))
                let botPt = path.flowPoint(at: CGFloat(state.botTrackProgress))

                ZStack {
                    path
                        .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                    path
                        .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    // Start/Finish marker
                    Circle()
                        .fill(.white)
                        .frame(width: 7, height: 7)
                        .position(startPt)

                    // BOT marker
                    carMarker(label: Driver.bot.shortCode, color: Driver.bot.color, isPitting: state.isPittingBot)
                        .position(botPt)

                    // YOU marker
                    carMarker(label: Driver.user.shortCode, color: Driver.user.color, isPitting: state.isPittingUser)
                        .position(userPt)
                }
            }
            .frame(height: 190)
            .background(
                RadialGradient(
                    colors: [circuit.tint.opacity(0.22), F1.background.opacity(0.8)],
                    center: .center,
                    startRadius: 10,
                    endRadius: 180
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        }
        .padding(16)
        .flowCard(radius: 20)
    }

    private func carMarker(label: String, color: Color, isPitting: Bool) -> some View {
        VStack(spacing: 2) {
            Text(isPitting ? "PIT" : label)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(color, in: Capsule())
                .shadow(color: color.opacity(0.8), radius: 5)
            Circle()
                .fill(.white)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(color, lineWidth: 3))
                .shadow(color: color, radius: 6)
        }
        .offset(y: -9)
    }

    // MARK: - Status Banner / Pit Prompt

    private func statusBannerRow(_ banner: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(state.isPittingUser || state.pitPromptLap != nil ? F1.yellow : F1.red)
                .frame(width: 8, height: 8)
                .pulse()
            Text(banner)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer()
            if state.pitPromptLap != nil {
                HButton(feedback: .success) {
                    store.triggerPitNow()
                } label: {
                    Text("BOX NOW")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(F1.yellow, in: Capsule())
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .flowCard(
            radius: 16,
            stroke: state.pitPromptLap != nil ? F1.yellow.opacity(0.6) : F1.red.opacity(0.35)
        )
    }

    // MARK: - Tyre & Pit Telemetry

    private var tyreAndPitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("TYRE & PIT TELEMETRY")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CURRENT TYRE")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1)
                        .foregroundStyle(F1.muted)

                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(state.userCompound.color, lineWidth: 3)
                                .frame(width: 26, height: 26)
                            Text(state.userCompound.shortCode)
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(state.userCompound.color)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(state.userCompound.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Stint \(state.userStintIndex + 1) · Age \(state.userTyreAge)L")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(F1.muted)
                        }
                    }

                    // Tyre grip bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.10))
                            Capsule()
                                .fill(state.userTyreHealth > 0.45 ? state.userCompound.color : F1.red)
                                .frame(width: geo.size.width * state.userTyreHealth)
                        }
                    }
                    .frame(height: 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 1, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    Text("PIT STOPS")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1)
                        .foregroundStyle(F1.muted)

                    Text("\(state.userPitsCompleted) / \(store.strategy.pitStopCount) Done")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)

                    if let nextPit = state.nextPitLap {
                        Text("Next stop: Lap \(nextPit)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(F1.yellow)
                    } else {
                        Text("Final stint to flag")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(F1.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .flowCard(radius: 20)
    }

    // MARK: - Running Order

    private var runningOrderCard: some View {
        let userFirst = state.userPosition == 1
        let ordered: [(pos: Int, driver: Driver, compound: TyreCompound, pits: Int, isLeader: Bool)] = userFirst
            ? [
                (1, .user, state.userCompound, state.userPitsCompleted, true),
                (2, .bot, state.botCompound, state.botPitsCompleted, false)
            ]
            : [
                (1, .bot, state.botCompound, state.botPitsCompleted, true),
                (2, .user, state.userCompound, state.userPitsCompleted, false)
            ]

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("RUNNING ORDER")

            ForEach(ordered, id: \.driver.id) { entry in
                HStack(spacing: 10) {
                    Text("P\(entry.pos)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(entry.pos == 1 ? F1.yellow : .white)
                        .frame(width: 28, alignment: .leading)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(entry.driver.color)
                        .frame(width: 3, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.driver.isUser ? "YOU" : entry.driver.name.uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(entry.pits) pit\(entry.pits == 1 ? "" : "s") completed")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(F1.muted)
                    }

                    Spacer()

                    Text(entry.compound.shortCode)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(entry.compound.color)
                        .frame(width: 22, height: 22)
                        .background(entry.compound.color.opacity(0.16), in: Circle())
                        .overlay(Circle().stroke(entry.compound.color, lineWidth: 1.5))

                    Text(entry.isLeader ? "LEADER" : String(format: "+%.2fs", state.liveGapSeconds))
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(entry.isLeader ? F1.green : F1.muted)
                        .frame(width: 68, alignment: .trailing)
                }
                .padding(11)
                .background(
                    entry.driver.isUser ? F1.red.opacity(0.08) : F1.background.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(entry.driver.isUser ? F1.red.opacity(0.35) : .white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .flowCard(radius: 20)
    }

    // MARK: - Playback Controls

    private var controlsRow: some View {
        HStack(spacing: 10) {
            HButton(feedback: .selection) {
                store.togglePause()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                    Text(state.isPaused ? "Resume" : "Pause")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .flowCard(radius: 16)
            }
            .buttonStyle(PressStyle())

            HButton(feedback: .impact(weight: .medium)) {
                store.skipToFinish()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "forward.end.fill")
                    Text("Finish Race")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(F1.redGradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressStyle())
        }
    }
}
