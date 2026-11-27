//
//  TryOnModels.swift
//  f1
//
//  Domain models for the TRY-ON racing strategy simulator module.
//

import Foundation
import SwiftUI

// MARK: - Navigation

enum TryOnStep: Equatable {
    case home
    case circuitSelect
    case strategySetup
    case raceSimulation
    case raceDebrief
    case gridRivals
    case reactionRush
}

// MARK: - Tyre Compound

enum TyreCompound: String, CaseIterable, Identifiable, Codable, Equatable {
    case soft
    case medium
    case hard

    var id: String { rawValue }

    var name: String {
        switch self {
        case .soft:   return "Soft"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }

    var shortCode: String {
        switch self {
        case .soft:   return "S"
        case .medium: return "M"
        case .hard:   return "H"
        }
    }

    var color: Color {
        switch self {
        case .soft:   return F1.red
        case .medium: return F1.yellow
        case .hard:   return Color(hex: "E6E8EE")
        }
    }

    /// Base lap-time delta in seconds relative to Medium.
    var baseDelta: Double {
        switch self {
        case .soft:   return -0.95
        case .medium: return 0.00
        case .hard:   return 0.65
        }
    }

    /// Time lost per lap of tyre age (seconds).
    var degRate: Double {
        switch self {
        case .soft:   return 0.22
        case .medium: return 0.11
        case .hard:   return 0.05
        }
    }

    /// Fraction of race distance before thermal/wear cliff accelerates.
    var optimalStintFraction: Double {
        switch self {
        case .soft:   return 0.30
        case .medium: return 0.46
        case .hard:   return 0.72
        }
    }

    /// Warm-up penalty on lap 1 of a stint.
    var warmUpPenalty: Double {
        switch self {
        case .soft:   return 0.00
        case .medium: return 0.18
        case .hard:   return 0.45
        }
    }
}

// MARK: - Circuit

struct Circuit: Identifiable, Equatable {
    let gpCircuit: GPCircuit
    let totalLaps: Int
    let baseLapTime: Double
    let pitLossSeconds: Double
    let weather: String
    let trackTempC: Int
    let tyreWearFactor: Double

    var id: String { gpCircuit.id }
    var name: String { gpCircuit.name }
    var place: String { gpCircuit.place }
    var lengthM: Double { gpCircuit.lengthM }
    var tint: Color { gpCircuit.tint }
    var pts: [CGPoint] { gpCircuit.pts }
    var flag: String { gpCircuit.flag }

    var raceDistanceKm: Double {
        Double(totalLaps) * gpCircuit.lengthM / 1000.0
    }

    var distanceLabel: String {
        String(format: "%d Laps · %.1f km", totalLaps, raceDistanceKm)
    }

    static let all: [Circuit] = [
        Circuit(gpCircuit: .named("AUS"), totalLaps: 20, baseLapTime: 80.4, pitLossSeconds: 21.5,
                weather: "Dry · Partly Cloudy", trackTempC: 27, tyreWearFactor: 1.00),
        Circuit(gpCircuit: .named("CHN"), totalLaps: 20, baseLapTime: 95.2, pitLossSeconds: 22.8,
                weather: "Overcast · Cool", trackTempC: 22, tyreWearFactor: 1.10),
        Circuit(gpCircuit: .named("BHR"), totalLaps: 20, baseLapTime: 92.8, pitLossSeconds: 23.0,
                weather: "Night · Clear", trackTempC: 26, tyreWearFactor: 1.22),
        Circuit(gpCircuit: .named("ITA"), totalLaps: 22, baseLapTime: 81.6, pitLossSeconds: 24.2,
                weather: "Dry · Sunny", trackTempC: 34, tyreWearFactor: 0.86),
        Circuit(gpCircuit: .named("SGP"), totalLaps: 20, baseLapTime: 97.4, pitLossSeconds: 26.5,
                weather: "Humid · Night", trackTempC: 31, tyreWearFactor: 1.15),
        Circuit(gpCircuit: .named("MIA"), totalLaps: 20, baseLapTime: 90.1, pitLossSeconds: 21.0,
                weather: "Dry · Warm", trackTempC: 36, tyreWearFactor: 1.05),
        Circuit(gpCircuit: .named("MON"), totalLaps: 24, baseLapTime: 73.5, pitLossSeconds: 19.5,
                weather: "Sunny · Coastal", trackTempC: 29, tyreWearFactor: 0.78),
        Circuit(gpCircuit: .named("IMO"), totalLaps: 20, baseLapTime: 77.8, pitLossSeconds: 25.0,
                weather: "Clear · Mild", trackTempC: 25, tyreWearFactor: 0.96)
    ]

    /// Deterministic default strategy for the AI bot tailored to the circuit.
    var defaultBotStrategy: RaceStrategy {
        switch id {
        case "MON", "ITA":
            // Lower wear or high pit loss favors 1-stop Medium -> Hard
            let pit = max(2, min(totalLaps - 2, Int((Double(totalLaps) * 0.45).rounded())))
            return RaceStrategy(pitStopCount: 1, pitLaps: [pit], stintCompounds: [.medium, .hard])
        case "BHR", "CHN", "SGP":
            // Higher wear favors 2-stop Soft -> Medium -> Hard
            let p1 = max(2, Int((Double(totalLaps) * 0.30).rounded()))
            let p2 = max(p1 + 2, min(totalLaps - 2, Int((Double(totalLaps) * 0.65).rounded())))
            return RaceStrategy(pitStopCount: 2, pitLaps: [p1, p2], stintCompounds: [.soft, .medium, .hard])
        default:
            let p1 = max(2, Int((Double(totalLaps) * 0.30).rounded()))
            let p2 = max(p1 + 2, min(totalLaps - 2, Int((Double(totalLaps) * 0.65).rounded())))
            return RaceStrategy(pitStopCount: 2, pitLaps: [p1, p2], stintCompounds: [.soft, .medium, .hard])
        }
    }
}

// MARK: - Driver

struct Driver: Identifiable, Equatable {
    let id: String
    let shortCode: String
    let name: String
    let teamLabel: String
    let color: Color
    let isUser: Bool

    static let user = Driver(
        id: "YOU",
        shortCode: "YOU",
        name: "You",
        teamLabel: "Strategy Lab",
        color: F1.red,
        isUser: true
    )

    static let bot = Driver(
        id: "BOT",
        shortCode: "BOT",
        name: "Apex Bot",
        teamLabel: "Default AI",
        color: Color(hex: "27F4D2"),
        isUser: false
    )
}

// MARK: - Race Strategy

struct StintPlan: Identifiable, Equatable {
    let id: Int
    let compound: TyreCompound
    let startLap: Int
    let endLap: Int

    var lapCount: Int { max(0, endLap - startLap + 1) }
    var rangeLabel: String { "L\(startLap)–\(endLap)" }
}

struct RaceStrategy: Equatable {
    var pitStopCount: Int
    var pitLaps: [Int]
    var stintCompounds: [TyreCompound]

    var stintCount: Int { pitStopCount + 1 }

    static func defaultStrategy(pitStops: Int = 2, totalLaps: Int) -> RaceStrategy {
        let clampedStops = min(max(pitStops, 1), 3)
        let laps = evenPitLaps(count: clampedStops, totalLaps: totalLaps)
        let compounds: [TyreCompound] = {
            switch clampedStops {
            case 1: return [.medium, .hard]
            case 2: return [.soft, .medium, .hard]
            default: return [.soft, .medium, .soft, .hard]
            }
        }()
        return RaceStrategy(pitStopCount: clampedStops, pitLaps: laps, stintCompounds: compounds)
    }

    static func evenPitLaps(count: Int, totalLaps: Int) -> [Int] {
        let step = Double(totalLaps) / Double(count + 1)
        var result: [Int] = []
        for i in 1...count {
            let candidate = Int((step * Double(i)).rounded())
            let minAllowed = (result.last ?? 1) + 1
            let maxAllowed = totalLaps - (count - i) - 1
            result.append(min(max(candidate, minAllowed), maxAllowed))
        }
        return result
    }

    func validRange(forStop index: Int, totalLaps: Int) -> ClosedRange<Int> {
        guard index >= 0 && index < pitLaps.count else { return 2...max(2, totalLaps - 1) }
        let lower = index == 0 ? 2 : (pitLaps[index - 1] + 1)
        let upper = index == pitLaps.count - 1 ? (totalLaps - 1) : (pitLaps[index + 1] - 1)
        return min(lower, upper)...max(lower, upper)
    }

    func stints(totalLaps: Int) -> [StintPlan] {
        let sortedPits = pitLaps.sorted()
        var plans: [StintPlan] = []
        var currentStart = 1
        for i in 0..<stintCount {
            let compound = i < stintCompounds.count ? stintCompounds[i] : .medium
            let endLap = i < sortedPits.count ? sortedPits[i] : totalLaps
            plans.append(StintPlan(id: i, compound: compound, startLap: currentStart, endLap: max(currentStart, endLap)))
            currentStart = endLap + 1
        }
        return plans
    }

    func estimatedPitLoss(for circuit: Circuit) -> Double {
        Double(pitStopCount) * circuit.pitLossSeconds
    }

    func compound(forLap lap: Int, totalLaps: Int) -> (compound: TyreCompound, stintIndex: Int, tyreAge: Int) {
        let stints = stints(totalLaps: totalLaps)
        for stint in stints {
            if lap >= stint.startLap && lap <= stint.endLap {
                return (stint.compound, stint.id, lap - stint.startLap + 1)
            }
        }
        let fallback = stintCompounds.last ?? .medium
        return (fallback, max(0, stintCount - 1), 1)
    }
}

// MARK: - Live Race State

struct RaceState: Equatable {
    var currentLap: Int
    var totalLaps: Int
    var elapsedTime: Double
    var userTotalTime: Double
    var botTotalTime: Double
    var liveGapSeconds: Double
    var userPosition: Int
    var userCompound: TyreCompound
    var botCompound: TyreCompound
    var userStintIndex: Int
    var userTyreAge: Int
    var userTyreHealth: Double
    var userPitsCompleted: Int
    var botPitsCompleted: Int
    var nextPitLap: Int?
    var isPittingUser: Bool
    var isPittingBot: Bool
    var pitPromptLap: Int?
    var userTrackProgress: Double
    var botTrackProgress: Double
    var statusBanner: String?
    var isPaused: Bool
    var speedMultiplier: Double
    var isFinished: Bool

    static func initial(circuit: Circuit, strategy: RaceStrategy) -> RaceState {
        let botStrategy = circuit.defaultBotStrategy
        return RaceState(
            currentLap: 1,
            totalLaps: circuit.totalLaps,
            elapsedTime: 0,
            userTotalTime: 0,
            botTotalTime: 0,
            liveGapSeconds: 0,
            userPosition: 1,
            userCompound: strategy.stintCompounds.first ?? .soft,
            botCompound: botStrategy.stintCompounds.first ?? .medium,
            userStintIndex: 0,
            userTyreAge: 1,
            userTyreHealth: 1.0,
            userPitsCompleted: 0,
            botPitsCompleted: 0,
            nextPitLap: strategy.pitLaps.first,
            isPittingUser: false,
            isPittingBot: false,
            pitPromptLap: nil,
            userTrackProgress: 0.0,
            botTrackProgress: 0.0,
            statusBanner: "Lights out! Race underway at \(circuit.name)",
            isPaused: false,
            speedMultiplier: 1.0,
            isFinished: false
        )
    }

    var gapSeconds: Double {
        userTotalTime - botTotalTime
    }
}

// MARK: - Post-Race Result

struct RaceResult: Equatable {
    let circuit: Circuit
    let userStrategy: RaceStrategy
    let botStrategy: RaceStrategy
    let finalPosition: Int
    let finishedAheadOfBot: Bool
    let userTotalTime: Double
    let botTotalTime: Double
    let timeDelta: Double
    let userPitStops: Int
    let botPitStops: Int
    let userPitLossTotal: Double
    let botPitLossTotal: Double
    let userLapTimes: [Double]
    let botLapTimes: [Double]

    var fastestUserLap: Double { userLapTimes.min() ?? circuit.baseLapTime }
    var fastestBotLap: Double { botLapTimes.min() ?? circuit.baseLapTime }
}
