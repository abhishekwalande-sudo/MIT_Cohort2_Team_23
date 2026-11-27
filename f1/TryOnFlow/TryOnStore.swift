//
//  TryOnStore.swift
//  f1
//
//  Central state management for the TRY-ON feature flow.
//

import Foundation
import SwiftUI

@Observable
final class TryOnStore {
    var step: TryOnStep = .home
    let circuits: [Circuit] = Circuit.all
    var selectedCircuit: Circuit
    var strategy: RaceStrategy
    var raceState: RaceState
    var raceResult: RaceResult?

    // Reaction Rush persistence
    var reactionBestMs: Int?

    // Active race simulation state
    private var timeline: SimulatedTimeline?
    private var raceClockSeconds: Double = 0
    private var userPitBonusSeconds: Double = 0
    private var acknowledgedPitLaps: Set<Int> = []
    private var simTask: Task<Void, Never>?

    private let reactionBestKey = "f1_tryon_reaction_best_ms_v1"

    init() {
        let initialCircuit = Circuit.all[0]
        let initialStrategy = RaceStrategy.defaultStrategy(pitStops: 2, totalLaps: initialCircuit.totalLaps)
        self.selectedCircuit = initialCircuit
        self.strategy = initialStrategy
        self.raceState = RaceState.initial(circuit: initialCircuit, strategy: initialStrategy)

        let savedBest = UserDefaults.standard.integer(forKey: reactionBestKey)
        self.reactionBestMs = savedBest > 0 ? savedBest : nil
    }

    // MARK: - Navigation

    func backToHome() {
        stopSimulationLoop()
        step = .home
    }

    func openCircuitSelect() {
        stopSimulationLoop()
        step = .circuitSelect
    }

    func openGridRivals() {
        step = .gridRivals
    }

    func openReactionRush() {
        step = .reactionRush
    }

    func selectCircuit(_ circuit: Circuit) {
        selectedCircuit = circuit
        strategy = RaceStrategy.defaultStrategy(pitStops: strategy.pitStopCount, totalLaps: circuit.totalLaps)
        raceResult = nil
        step = .strategySetup
    }

    // MARK: - Strategy Configuration

    func setPitStopCount(_ count: Int) {
        let clamped = min(max(count, 1), 3)
        guard clamped != strategy.pitStopCount else { return }

        let newPits = RaceStrategy.evenPitLaps(count: clamped, totalLaps: selectedCircuit.totalLaps)
        let neededStints = clamped + 1
        var newCompounds = strategy.stintCompounds
        let fallbackDefaults: [TyreCompound] = [.soft, .medium, .hard, .soft]
        while newCompounds.count < neededStints {
            newCompounds.append(fallbackDefaults[newCompounds.count % fallbackDefaults.count])
        }
        if newCompounds.count > neededStints {
            newCompounds = Array(newCompounds.prefix(neededStints))
        }

        strategy = RaceStrategy(
            pitStopCount: clamped,
            pitLaps: newPits,
            stintCompounds: newCompounds
        )
    }

    func updatePitLap(at index: Int, to newLap: Int) {
        guard index >= 0 && index < strategy.pitLaps.count else { return }
        let range = strategy.validRange(forStop: index, totalLaps: selectedCircuit.totalLaps)
        let clamped = min(max(newLap, range.lowerBound), range.upperBound)
        if strategy.pitLaps[index] != clamped {
            strategy.pitLaps[index] = clamped
        }
    }

    func updateCompound(at stintIndex: Int, to compound: TyreCompound) {
        guard stintIndex >= 0 && stintIndex < strategy.stintCompounds.count else { return }
        strategy.stintCompounds[stintIndex] = compound
    }

    // MARK: - Race Simulation Lifecycle

    func startRace() {
        stopSimulationLoop()
        raceResult = nil
        raceClockSeconds = 0
        userPitBonusSeconds = 0
        acknowledgedPitLaps = []

        let botStrategy = selectedCircuit.defaultBotStrategy
        let simTimeline = TryOnRaceEngine.simulate(
            circuit: selectedCircuit,
            userStrategy: strategy,
            botStrategy: botStrategy
        )
        timeline = simTimeline
        raceState = RaceState.initial(circuit: selectedCircuit, strategy: strategy)
        step = .raceSimulation
        startSimulationLoop()
    }

    func togglePause() {
        raceState.isPaused.toggle()
    }

    func cycleSpeed() {
        let next: Double
        switch raceState.speedMultiplier {
        case 1.0: next = 2.0
        case 2.0: next = 4.0
        default:  next = 1.0
        }
        raceState.speedMultiplier = next
    }

    func triggerPitNow() {
        guard let lap = raceState.pitPromptLap else { return }
        acknowledgedPitLaps.insert(lap)
        // Small pit-crew synchronization bonus (0.45s) for reacting to BOX BOX
        userPitBonusSeconds = min(0.90, userPitBonusSeconds + 0.45)
        refreshRaceState()
    }

    func skipToFinish() {
        guard let timeline else { return }
        stopSimulationLoop()
        let finishClock = max(timeline.userCumulative.last ?? 0, timeline.botCumulative.last ?? 0)
        raceClockSeconds = finishClock
        refreshRaceState()
        completeRace()
    }

    func exitSimulationToSetup() {
        stopSimulationLoop()
        step = .strategySetup
    }

    func rematch() {
        stopSimulationLoop()
        raceResult = nil
        step = .strategySetup
    }

    // MARK: - Reaction Rush

    func recordReaction(ms: Int) {
        if let best = reactionBestMs {
            if ms < best {
                reactionBestMs = ms
                UserDefaults.standard.set(ms, forKey: reactionBestKey)
            }
        } else {
            reactionBestMs = ms
            UserDefaults.standard.set(ms, forKey: reactionBestKey)
        }
    }

    // MARK: - Simulation Loop

    private func startSimulationLoop() {
        stopSimulationLoop()
        simTask = Task { @MainActor [weak self] in
            // ~30 FPS update; 1x speed runs roughly 1 race lap per 1.4 real seconds
            let tickNanoseconds: UInt64 = 33_000_000
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: tickNanoseconds)
                guard !Task.isCancelled, let self, self.timeline != nil else { return }

                if !self.raceState.isPaused {
                    // Scale real dt (0.033s) into race-seconds so a 20-lap race (~1700s) plays in ~28s at 1x
                    let simRate = self.selectedCircuit.baseLapTime / 1.4
                    self.raceClockSeconds += 0.033 * simRate * self.raceState.speedMultiplier
                    self.refreshRaceState()

                    if self.raceState.isFinished {
                        self.stopSimulationLoop()
                        try? await Task.sleep(nanoseconds: 750_000_000)
                        if !Task.isCancelled {
                            self.completeRace()
                        }
                        return
                    }
                }
            }
        }
    }

    private func stopSimulationLoop() {
        simTask?.cancel()
        simTask = nil
    }

    private func refreshRaceState() {
        guard let timeline else { return }
        raceState = TryOnRaceEngine.state(
            at: raceClockSeconds,
            timeline: timeline,
            userPitBonusSeconds: userPitBonusSeconds,
            acknowledgedPitLaps: acknowledgedPitLaps,
            isPaused: raceState.isPaused,
            speedMultiplier: raceState.speedMultiplier
        )
    }

    private func completeRace() {
        guard let timeline else { return }
        raceResult = TryOnRaceEngine.buildResult(timeline: timeline, userPitBonusSeconds: userPitBonusSeconds)
        step = .raceDebrief
    }
}
