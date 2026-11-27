//
//  CircuitSelectionView.swift
//  f1
//
//  Screen 2 of TRY-ON Flow: Select Circuit (2-column grid with search).
//

import SwiftUI

struct CircuitSelectionView: View {
    @Bindable var store: TryOnStore
    @State private var query = ""
    @State private var appeared = false

    private var filtered: [Circuit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.circuits }
        return store.circuits.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.place.localizedCaseInsensitiveContains(q) ||
            $0.id.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                FlowBackBar(title: "TRY-ON") {
                    store.backToHome()
                }
                .reveal(appeared, 0)

                ScreenTitle(
                    eyebrow: "TRY-ON · CIRCUIT",
                    title: "SELECT CIRCUIT",
                    subtitle: "2026 FIA Formula One World Championship"
                )
                .reveal(appeared, 0)

                CapsuleSearchField(prompt: "Search circuits or Grand Prix", text: $query)
                    .reveal(appeared, 1)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, circuit in
                        HButton(action: { store.selectCircuit(circuit) }) {
                            TryOnCircuitCard(
                                circuit: circuit,
                                isSelected: store.selectedCircuit.id == circuit.id
                            )
                        }
                        .buttonStyle(PressStyle())
                        .reveal(appeared, index + 2)
                    }
                }

                if filtered.isEmpty {
                    Text("No circuits found. Try another search.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(F1.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .onAppear { appeared = true }
    }
}

private struct TryOnCircuitCard: View {
    let circuit: Circuit
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [circuit.tint.opacity(0.55), Color(hex: "0B0A10")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            BokehLayer(seed: circuit.name.count * 7, color: circuit.tint)

            CircuitShape(pts: circuit.pts)
                .stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .shadow(color: .white.opacity(0.5), radius: 4)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 48)

            LinearGradient(colors: [.black.opacity(0.80), .clear], startPoint: .bottom, endPoint: .center)

            VStack {
                HStack {
                    Text(circuit.flag)
                        .font(.system(size: 14))
                    Spacer()
                    Text("\(circuit.totalLaps)L")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                Spacer()
            }
            .padding(9)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(circuit.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(circuit.place)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(isSelected ? F1.red : .white.opacity(0.15), in: Circle())
            }
            .padding(10)
        }
        .frame(height: 146)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? F1.red : .white.opacity(0.14), lineWidth: isSelected ? 1.8 : 1)
        )
        .drawingGroup()
    }
}
