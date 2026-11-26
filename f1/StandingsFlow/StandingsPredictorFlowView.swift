//
//  StandingsPredictorFlowView.swift
//  f1
//
//  Coordinator for the 6-screen Standings Podium Predictor flow.
//

import SwiftUI

struct StandingsPredictorFlowView: View {
    @Bindable var store: StandingsPredictionStore

    var body: some View {
        ZStack {
            switch store.step {
            case .makePicks:
                MakeYourPicksView(store: store).flowTransition()
            case .predictionLocked:
                PredictionLockedView(store: store).flowTransition()
            case .raceResults:
                RaceResultsView(store: store).flowTransition()
            case .leaderboard(let category):
                LeaderboardContainerView(store: store, category: category).flowTransition()
            case .groupDetail(let groupId):
                GroupDetailView(store: store, groupId: groupId).flowTransition()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.88), value: store.step)
    }
}
