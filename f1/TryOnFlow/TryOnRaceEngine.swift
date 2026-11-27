//
//  TryOnRaceEngine.swift
//  f1
//
//  Deterministic mathematical race simulation engine for TRY-ON Strategy Lab.
//

import Foundation

struct SimulatedTimeline: Equatable {
    let circuit: Circuit
    let userStrategy: RaceStrategy
    let botStrategy: RaceStrategy
    let userLapTimes: [Double]
    let botLapTimes: [Double]
    let userCumulative: [Double] // length == totalLaps + 1, index 0 = 0.0
    let botCumulative: [Double]  // length == totalLaps + 1, index 0 = 0.0

    var totalLaps: Int { circuit.totalLaps }
}

enum TryOnRaceEngine {

    /// Builds a deterministic, reproducible timeline for both YOU and the BOT.
    static func simulate(circuit: Circuit, userStrategy: RaceStrategy, botStrategy: RaceStrategy) -> SimulatedTimeline {
        let userSeed = circuit.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } + 17
        let botSeed = userSeed + 53

        let userLaps = computeLapTimes(circuit: circuit, strategy: userStrategy, seed: userSeed, paceOffset: 0.0)
        // Bot runs at a slightly competitive pace offset so strategy decisions matter most.
        let botLaps = computeLapTimes(circuit: circuit, strategy: botStrategy, seed: botSeed, paceOffset: 0.12)

        var userCum = [0.0]
        var botCum = [0.0]
        for lap in 0..<circuit.totalLaps {
            userCum.append(userCum[lap] + userLaps[lap])
            botCum.append(botCum[lap] + botLaps[lap])
        }

        return SimulatedTimeline(
            circuit: circuit,
            userStrategy: userStrategy,
            botStrategy: botStrategy,
            userLapTimes: userLaps,
            botLapTimes: botLaps,
            userCumulative: userCum,
            botCumulative: botCum
        )
    }

    private static func computeLapTimes(
        circuit: Circuit,
        strategy: RaceStrategy,
        seed: Int,
        paceOffset: Double
    ) -> [Double] {
        let totalLaps = circuit.totalLaps
        let pitSet = Set(strategy.pitLaps)
        var laps: [Double] = []
        laps.reserveCapacity(totalLaps)

        for lap in 1...totalLaps {
            let info = strategy.compound(forLap: lap, totalLaps: totalLaps)
            let compound = info.compound
            let age = info.tyreAge

            // Fuel load burns down linearly over the race
            let fuelGain = -0.04 * Double(lap - 1)

            // Warm-up on first lap of stint
            let warmUp = age == 1 ? compound.warmUpPenalty : 0.0

            // Linear tyre degradation scaled by track wear factor
            let linearDeg = Double(age - 1) * compound.degRate * circuit.tyreWearFactor

            // Cliff penalty when pushing a tyre past its optimal stint window
            let cliffThreshold = max(3.0, compound.optimalStintFraction * Double(totalLaps))
            let cliffExcess = max(0.0, Double(age) - cliffThreshold)
            let cliffPenalty = cliffExcess > 0 ? (0.18 * pow(cliffExcess, 1.38) * circuit.tyreWearFactor) : 0.0

            // Deterministic micro-variance (+/- 0.16s)
            let jitter = (flowRand(seed, lap) - 0.5) * 0.32

            // Pit lane time loss when boxing at the end of a configured pit lap
            let pitLoss = pitSet.contains(lap) ? circuit.pitLossSeconds : 0.0

            let lapTime = circuit.baseLapTime
                + paceOffset
                + compound.baseDelta
                + fuelGain
                + warmUp
                + linearDeg
                + cliffPenalty
                + jitter
                + pitLoss

            laps.append(max(45.0, lapTime))
        }
        return laps
    }

    /// Evaluates live race state at a simulated elapsed race clock `raceClockSeconds`.
    /// Note: `userPitBonusSeconds` grants a minor execution reward (up to 0.6s) if the user taps BOX NOW on cue.
    static func state(
        at raceClockSeconds: Double,
        timeline: SimulatedTimeline,
        userPitBonusSeconds: Double,
        acknowledgedPitLaps: Set<Int>,
        isPaused: Bool,
        speedMultiplier: Double
    ) -> RaceState {
        let totalLaps = timeline.totalLaps
        let userCum = adjustCumulative(timeline.userCumulative, pitLaps: timeline.userStrategy.pitLaps, bonus: userPitBonusSeconds)
        let botCum = timeline.botCumulative

        let maxUserTime = userCum.last ?? 0
        let maxBotTime = botCum.last ?? 0
        let finishClock = max(maxUserTime, maxBotTime)

        let clampedClock = min(max(0, raceClockSeconds), finishClock)
        let finished = raceClockSeconds >= finishClock

        let uPos = progress(at: clampedClock, cumulative: userCum, pitLaps: timeline.userStrategy.pitLaps, circuit: timeline.circuit)
        let bPos = progress(at: clampedClock, cumulative: botCum, pitLaps: timeline.botStrategy.pitLaps, circuit: timeline.circuit)

        let leaderLap = finished ? totalLaps : min(totalLaps, max(uPos.lap, bPos.lap))
        let userLap = finished ? totalLaps : uPos.lap
        let userInfo = timeline.userStrategy.compound(forLap: userLap, totalLaps: totalLaps)
        let botInfo = timeline.botStrategy.compound(forLap: finished ? totalLaps : bPos.lap, totalLaps: totalLaps)

        let maxOptimalLaps = max(3.0, userInfo.compound.optimalStintFraction * Double(totalLaps) * 1.15)
        let tyreHealth = max(0.08, min(1.0, 1.0 - (Double(userInfo.tyreAge - 1) / maxOptimalLaps) * 0.72))

        let userPitsDone = timeline.userStrategy.pitLaps.filter { userLap > $0 || finished }.count
        let botPitsDone = timeline.botStrategy.pitLaps.filter { (finished ? totalLaps : bPos.lap) > $0 || finished }.count
        let nextPit = timeline.userStrategy.pitLaps.first { $0 >= userLap }

        // User effective distance (lap + trackProgress) determines live running order
        let userRaceDistance = finished ? Double(totalLaps) : (Double(uPos.lap - 1) + uPos.lapFraction)
        let botRaceDistance = finished ? Double(totalLaps) : (Double(bPos.lap - 1) + bPos.lapFraction)
        let userAhead: Bool = {
            if finished {
                return maxUserTime <= maxBotTime
            }
            return userRaceDistance >= botRaceDistance
        }()

        // Live time gap between leader and trailing car
        let liveGap: Double = {
            if finished {
                return abs(maxUserTime - maxBotTime)
            }
            return abs(userRaceDistance - botRaceDistance) * timeline.circuit.baseLapTime
        }()

        // Current effective elapsed gap estimate
        let userDisplayTime = min(clampedClock, maxUserTime)
        let botDisplayTime = min(clampedClock, maxBotTime)

        let promptLap: Int? = {
            if !finished && timeline.userStrategy.pitLaps.contains(userLap) && !acknowledgedPitLaps.contains(userLap) && !uPos.isInPit {
                return userLap
            }
            return nil
        }()

        let banner: String? = {
            if finished {
                return maxUserTime <= maxBotTime ? "CHEQUERED FLAG! P1 FINISH!" : "CHEQUERED FLAG! P2 FINISH"
            }
            if uPos.isInPit {
                let nextCompound = timeline.userStrategy.compound(forLap: min(totalLaps, userLap + 1), totalLaps: totalLaps).compound
                return "IN PIT LANE · Fitting \(nextCompound.name) tyres"
            }
            if bPos.isInPit {
                return "BOT IN PITS · Gain track position!"
            }
            if let promptLap {
                return "BOX BOX! Pit stop scheduled end of Lap \(promptLap)"
            }
            if userAhead {
                return "P1 · Leading \(Driver.bot.shortCode) on \(userInfo.compound.name)s"
            } else {
                return "P2 · Chasing \(Driver.bot.shortCode) on \(userInfo.compound.name)s"
            }
        }()

        return RaceState(
            currentLap: leaderLap,
            totalLaps: totalLaps,
            elapsedTime: clampedClock,
            userTotalTime: userDisplayTime,
            botTotalTime: botDisplayTime,
            liveGapSeconds: liveGap,
            userPosition: userAhead ? 1 : 2,
            userCompound: userInfo.compound,
            botCompound: botInfo.compound,
            userStintIndex: userInfo.stintIndex,
            userTyreAge: userInfo.tyreAge,
            userTyreHealth: tyreHealth,
            userPitsCompleted: userPitsDone,
            botPitsCompleted: botPitsDone,
            nextPitLap: finished ? nil : nextPit,
            isPittingUser: uPos.isInPit,
            isPittingBot: bPos.isInPit,
            pitPromptLap: promptLap,
            userTrackProgress: finished ? 0.0 : uPos.lapFraction,
            botTrackProgress: finished ? 0.0 : bPos.lapFraction,
            statusBanner: banner,
            isPaused: isPaused,
            speedMultiplier: speedMultiplier,
            isFinished: finished
        )
    }

    static func buildResult(timeline: SimulatedTimeline, userPitBonusSeconds: Double) -> RaceResult {
        let adjustedUserCum = adjustCumulative(timeline.userCumulative, pitLaps: timeline.userStrategy.pitLaps, bonus: userPitBonusSeconds)
        var adjustedUserLaps = timeline.userLapTimes
        if userPitBonusSeconds > 0, let firstPit = timeline.userStrategy.pitLaps.first, firstPit - 1 < adjustedUserLaps.count {
            adjustedUserLaps[firstPit - 1] = max(45.0, adjustedUserLaps[firstPit - 1] - userPitBonusSeconds)
        }

        let userTotal = adjustedUserCum.last ?? 0
        let botTotal = timeline.botCumulative.last ?? 0
        let ahead = userTotal <= botTotal

        return RaceResult(
            circuit: timeline.circuit,
            userStrategy: timeline.userStrategy,
            botStrategy: timeline.botStrategy,
            finalPosition: ahead ? 1 : 2,
            finishedAheadOfBot: ahead,
            userTotalTime: userTotal,
            botTotalTime: botTotal,
            timeDelta: userTotal - botTotal,
            userPitStops: timeline.userStrategy.pitStopCount,
            botPitStops: timeline.botStrategy.pitStopCount,
            userPitLossTotal: timeline.userStrategy.estimatedPitLoss(for: timeline.circuit) - userPitBonusSeconds,
            botPitLossTotal: timeline.botStrategy.estimatedPitLoss(for: timeline.circuit),
            userLapTimes: adjustedUserLaps,
            botLapTimes: timeline.botLapTimes
        )
    }

    // MARK: - Helpers

    private static func adjustCumulative(_ cumulative: [Double], pitLaps: [Int], bonus: Double) -> [Double] {
        guard bonus > 0, let firstPit = pitLaps.first else { return cumulative }
        return cumulative.enumerated().map { idx, val in
            idx >= firstPit ? max(0, val - bonus) : val
        }
    }

    private struct CarProgress {
        let lap: Int
        let lapFraction: Double
        let isInPit: Bool
    }

    private static func progress(
        at clock: Double,
        cumulative: [Double],
        pitLaps: [Int],
        circuit: Circuit
    ) -> CarProgress {
        let totalLaps = cumulative.count - 1
        guard totalLaps > 0 else { return CarProgress(lap: 1, lapFraction: 0, isInPit: false) }
        if clock >= cumulative[totalLaps] {
            return CarProgress(lap: totalLaps, lapFraction: 1.0, isInPit: false)
        }

        var lapIdx = 0
        while lapIdx < totalLaps - 1 && clock >= cumulative[lapIdx + 1] {
            lapIdx += 1
        }
        let lapNum = lapIdx + 1
        let tStart = cumulative[lapIdx]
        let tEnd = cumulative[lapIdx + 1]
        let lapDuration = max(0.1, tEnd - tStart)
        let elapsedInLap = max(0, clock - tStart)

        if pitLaps.contains(lapNum) {
            let drivingDuration = max(1.0, lapDuration - circuit.pitLossSeconds)
            if elapsedInLap < drivingDuration {
                let frac = min(0.97, elapsedInLap / drivingDuration * 0.97)
                return CarProgress(lap: lapNum, lapFraction: frac, isInPit: false)
            } else {
                let pitFrac = (elapsedInLap - drivingDuration) / max(1.0, circuit.pitLossSeconds)
                return CarProgress(lap: lapNum, lapFraction: 0.97 + min(0.03, pitFrac * 0.03), isInPit: true)
            }
        } else {
            let frac = min(0.999, elapsedInLap / lapDuration)
            return CarProgress(lap: lapNum, lapFraction: frac, isInPit: false)
        }
    }

    static func formatRaceTime(_ seconds: Double) -> String {
        let total = max(0, seconds)
        let mins = Int(total) / 60
        let secs = total - Double(mins * 60)
        return String(format: "%d:%05.2f", mins, secs)
    }

    static func formatDelta(_ delta: Double) -> String {
        let sign = delta <= 0 ? "−" : "+"
        return String(format: "%@%.2fs", sign, abs(delta))
    }
}
