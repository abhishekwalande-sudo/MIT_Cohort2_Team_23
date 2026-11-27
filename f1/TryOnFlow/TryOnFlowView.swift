//
//  TryOnFlowView.swift
//  f1
//
//  Coordinator for the TRY-ON feature module.
//

import SwiftUI

struct TryOnFlowView: View {
    @Bindable var store: TryOnStore

    var body: some View {
        ZStack {
            Backdrop()
            switch store.step {
            case .home:
                TryOnHomeView(store: store).flowTransition()
            case .circuitSelect:
                CircuitSelectionView(store: store).flowTransition()
            case .strategySetup:
                StrategySetupView(store: store).flowTransition()
            case .raceSimulation:
                RaceSimulationView(store: store).flowTransition()
            case .raceDebrief:
                RaceDebriefView(store: store).flowTransition()
            case .gridRivals:
                GridRivalsView(store: store).flowTransition()
            case .reactionRush:
                ReactionRushView(store: store).flowTransition()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.88), value: store.step)
    }
}
