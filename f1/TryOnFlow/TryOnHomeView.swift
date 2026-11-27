//
//  TryOnHomeView.swift
//  f1
//
//  Screen 1 of TRY-ON Flow: TRY-ON Home (Strategy Lab, Grid Rivals, Reaction Rush).
//

import SwiftUI

struct TryOnHomeView: View {
    @Bindable var store: TryOnStore
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(
                    eyebrow: "SIMULATOR · PIT WALL",
                    title: "TRY-ON",
                    subtitle: "Build strategies, battle rivals, test your lights-out reflexes"
                )
                .reveal(appeared, 0)

                strategyLabBanner
                    .reveal(appeared, 1)

                gridRivalsCard
                    .reveal(appeared, 2)

                reactionRushCard
                    .reveal(appeared, 3)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .onAppear { appeared = true }
    }

    // MARK: - A. Strategy Lab Banner

    private var strategyLabBanner: some View {
        let circuit = store.selectedCircuit

        return HButton(action: { store.openCircuitSelect() }) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [F1.red.opacity(0.32), circuit.tint.opacity(0.24), F1.surface],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                CircuitShape(pts: circuit.pts)
                    .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                    .frame(width: 170, height: 120)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(16)

                CircuitShape(pts: circuit.pts)
                    .stroke(F1.red.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: F1.red.opacity(0.7), radius: 6)
                    .frame(width: 170, height: 120)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(16)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "flag.checkered.2.crossed")
                                .font(.system(size: 11, weight: .bold))
                            Text("PIT WALL SIMULATOR")
                                .font(.system(size: 9, weight: .black))
                                .tracking(1.4)
                        }
                        .foregroundStyle(F1.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(F1.red.opacity(0.16), in: Capsule())
                        .overlay(Capsule().stroke(F1.red.opacity(0.4), lineWidth: 1))

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(F1.red, in: Circle())
                            .shadow(color: F1.red.opacity(0.55), radius: 8)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("STRATEGY LAB")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(.white)
                        Text("Pick your tires. Plan your pit stops. Test your calls on the circuit.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 230, alignment: .leading)
                    }

                    Spacer(minLength: 10)

                    HStack(spacing: 8) {
                        Text(circuit.flag)
                            .font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(circuit.name)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(circuit.distanceLabel) · \(circuit.weather)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(F1.muted)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1))
                }
                .padding(18)
            }
            .frame(minHeight: 224)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(colors: [F1.red.opacity(0.6), .white.opacity(0.10)],
                                       startPoint: .topTrailing, endPoint: .bottomLeading),
                        lineWidth: 1.2
                    )
            }
            .shadow(color: F1.red.opacity(0.22), radius: 18, y: 8)
        }
        .buttonStyle(PressStyle())
    }

    // MARK: - B. Grid Rivals

    private var gridRivalsCard: some View {
        HButton(action: { store.openGridRivals() }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(F1.purple)
                            Text("MULTIPLAYER ROOM")
                                .font(.system(size: 9, weight: .black))
                                .tracking(1.4)
                                .foregroundStyle(F1.purple)
                        }
                        Text("GRID RIVALS")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(F1.surfaceHi, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                }

                Text("Two or four friends. One circuit. Whose strategy is fastest?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(F1.muted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    roomPill(icon: "plus.circle.fill", label: "Create Room", accent: F1.purple)
                    roomPill(icon: "number.square.fill", label: "Join with Code", accent: .white.opacity(0.85))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack(alignment: .topTrailing) {
                    F1.surface
                    RadialGradient(
                        colors: [F1.purple.opacity(0.20), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 190
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(F1.purple.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }

    private func roomPill(icon: String, label: String, accent: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(label).font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(F1.background.opacity(0.75), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: - C. Reaction Rush

    private var reactionRushCard: some View {
        HButton(action: { store.openReactionRush() }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(F1.red)
                            Text("LIGHTS OUT PRACTICE")
                                .font(.system(size: 9, weight: .black))
                                .tracking(1.4)
                                .foregroundStyle(F1.red)
                        }
                        Text("REACTION RUSH")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    if let best = store.reactionBestMs {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("BEST")
                                .font(.system(size: 8, weight: .black))
                                .tracking(1)
                                .foregroundStyle(F1.muted)
                            Text("\(best) ms")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(F1.green)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(F1.surfaceHi, in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                    }
                }

                // Five red starting lights gantry preview
                HStack(spacing: 10) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 16, height: 16)
                            Circle()
                                .fill(F1.red)
                                .frame(width: 20, height: 20)
                                .shadow(color: F1.red.opacity(0.85), radius: 8)
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
                    }
                }

                HStack {
                    Text("Tap when all five red lights go out")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(F1.muted)
                    Spacer()
                    Text("Launch →")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(F1.red)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .flowCard(radius: 22, stroke: F1.red.opacity(0.28))
        }
        .buttonStyle(PressStyle())
    }
}
