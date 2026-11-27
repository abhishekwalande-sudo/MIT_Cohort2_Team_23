//
//  RaceSimulationView.swift
//  f1
//
//  Screen 4 of TRY-ON Flow: Realistic 3D RealityKit F1 Race Simulation
//  connected to live tyre degradation, pit stops, camera switcher, and running order.
//

import RealityKit
import SwiftUI

struct RaceSimulationView: View {
    @Bindable var store: TryOnStore
    @State private var sceneController = RaceSceneController()

    private var circuit: Circuit { store.selectedCircuit }
    private var state: RaceState { store.raceState }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                topBar

                ScreenTitle(
                    eyebrow: "LIVE TELEMETRY · \(circuit.name.uppercased())",
                    title: "RACE SIMULATION",
                    subtitle: "\(circuit.weather) · Track \(circuit.trackTempC)°C"
                )

                hudRow
                realityViewportCard

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
        HStack(spacing: 8) {
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
                label: "SPEED",
                value: "\(state.userSpeedKmh)",
                unit: "km/h",
                accent: .white
            )
            hudTile(
                label: "POS",
                value: "P\(state.userPosition)",
                accent: state.userPosition == 1 ? F1.green : F1.yellow
            )
        }
    }

    private func hudTile(label: String, value: String, unit: String? = nil, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .tracking(1.1)
                .foregroundStyle(F1.muted)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(F1.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .flowCard(radius: 14)
    }

    // MARK: - 3D RealityKit Viewport

    private var realityViewportCard: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                RealityView { content in
                    sceneController.setupScene(
                        in: content,
                        circuit: circuit,
                        spline: store.trackSpline,
                        initialState: state
                    )
                } update: { _ in
                    sceneController.update(state: store.raceState, cameraMode: store.cameraMode)
                }
                .frame(height: 330)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Top-left live broadcast pill + legend
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(F1.red)
                            .frame(width: 6, height: 6)
                            .pulse()
                        Text("3D LIVE")
                            .font(.system(size: 9, weight: .black))
                            .tracking(1.2)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.62), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))

                    Spacer()

                    HStack(spacing: 10) {
                        LegendDot(color: Driver.user.color, name: Driver.user.shortCode)
                        LegendDot(color: Driver.bot.color, name: Driver.bot.shortCode)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.62), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
                }
                .padding(12)

                // Pit box live timer overlay
                if state.isUserInPitBox {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(F1.yellow)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("PIT CREW SERVICING")
                                    .font(.system(size: 9, weight: .black))
                                    .tracking(1)
                                    .foregroundStyle(F1.yellow)
                                Text("Fitting \(state.userCompound.name) Tyres")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Text(String(format: "%.1fs", state.userPitTimerRemaining))
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(F1.yellow)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(F1.yellow.opacity(0.65), lineWidth: 1.2))
                        .padding(12)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .onChange(of: store.raceState) { _, newState in
                sceneController.update(state: newState, cameraMode: store.cameraMode)
            }
            .onChange(of: store.cameraMode) { _, newMode in
                sceneController.update(state: store.raceState, cameraMode: newMode)
            }

            // Camera mode switcher
            HStack(spacing: 6) {
                ForEach(RaceCameraMode.allCases) { mode in
                    let selected = store.cameraMode == mode
                    HButton(feedback: .selection) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            store.setCameraMode(mode)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 10, weight: .bold))
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(selected ? .white : F1.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(selected ? F1.redGradient : LinearGradient(colors: [F1.background.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(selected ? F1.red : .white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        .padding(12)
        .flowCard(radius: 22)
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
        .padding(.vertical, 11)
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
        let ordered: [(pos: Int, driver: Driver, compound: TyreCompound, pits: Int, speed: Int, isLeader: Bool)] = userFirst
            ? [
                (1, .user, state.userCompound, state.userPitsCompleted, state.userSpeedKmh, true),
                (2, .bot, state.botCompound, state.botPitsCompleted, state.botSpeedKmh, false)
            ]
            : [
                (1, .bot, state.botCompound, state.botPitsCompleted, state.botSpeedKmh, true),
                (2, .user, state.userCompound, state.userPitsCompleted, state.userSpeedKmh, false)
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
                        Text("\(entry.pits) pit\(entry.pits == 1 ? "" : "s") · \(entry.speed) km/h")
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
