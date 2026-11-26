//
//  StandingsPredictionModels.swift
//  f1
//
//  Modular models, scoring engine, and local persistence for the Standings
//  Podium Predictor user flow. Sample prototype data is clearly isolated so
//  it can be swapped for a live backend later.
//

import Foundation
import SwiftUI

// MARK: - Navigation & Categories

enum StandingsTabMode: String, CaseIterable, Identifiable {
    case predictor = "Predictor"
    case drivers   = "Drivers"
    var id: String { rawValue }
}

enum StandingsFlowStep: Equatable {
    case makePicks
    case predictionLocked
    case raceResults
    case leaderboard(LeaderboardCategory)
    case groupDetail(String) // group id
}

enum LeaderboardCategory: String, CaseIterable, Identifiable {
    case global  = "Global"
    case friends = "Friends"
    case groups  = "Groups"
    var id: String { rawValue }
}

// MARK: - Prediction Models

enum PodiumSlot: Int, CaseIterable, Codable, Identifiable {
    case p1 = 1
    case p2 = 2
    case p3 = 3

    var id: Int { rawValue }
    var label: String { "P\(rawValue)" }
    var title: String {
        switch self {
        case .p1: return "1st Place"
        case .p2: return "2nd Place"
        case .p3: return "3rd Place"
        }
    }
}

struct SavedPrediction: Codable, Equatable {
    let raceId: String
    let raceName: String
    let p1DriverId: String
    let p2DriverId: String
    let p3DriverId: String
    let lockedAt: Date

    func driverId(for slot: PodiumSlot) -> String {
        switch slot {
        case .p1: return p1DriverId
        case .p2: return p2DriverId
        case .p3: return p3DriverId
        }
    }
}

enum PickMatchOutcome: Equatable {
    case exact(points: Int)
    case podiumWrongSpot(points: Int)
    case miss

    var points: Int {
        switch self {
        case .exact(let pts): return pts
        case .podiumWrongSpot(let pts): return pts
        case .miss: return 0
        }
    }

    var badgeText: String {
        switch self {
        case .exact(let pts): return "+\(pts)"
        case .podiumWrongSpot(let pts): return "+\(pts)"
        case .miss: return "+0"
        }
    }

    var icon: String {
        switch self {
        case .exact: return "checkmark.circle.fill"
        case .podiumWrongSpot: return "minus.circle.fill"
        case .miss: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .exact: return F1.green
        case .podiumWrongSpot: return F1.yellow
        case .miss: return F1.muted
        }
    }
}

struct ScoredPickRow: Identifiable, Equatable {
    let slot: PodiumSlot
    let predictedDriver: GPDriver
    let actualDriver: GPDriver
    let outcome: PickMatchOutcome
    let longShotBonus: Int

    var id: Int { slot.rawValue }
    var totalPoints: Int { outcome.points + longShotBonus }
}

struct RaceResultSummary: Equatable {
    let raceName: String
    let circuitPlace: String
    let rows: [ScoredPickRow]
    let perfectPodiumBonus: Int
    let isSampleResult: Bool

    var totalPointsEarned: Int {
        rows.reduce(0) { $0 + $1.totalPoints } + perfectPodiumBonus
    }

    var pointsBreakdownText: String {
        let parts = rows.map { "\($0.totalPoints)" } + (perfectPodiumBonus > 0 ? ["\(perfectPodiumBonus)"] : [])
        return parts.joined(separator: " + ") + " = \(totalPointsEarned)"
    }
}

// MARK: - Leaderboard & Group Models

struct LeaderboardEntry: Identifiable, Codable, Equatable {
    let id: String
    let username: String
    let initials: String
    let avatarHex: String
    var totalPoints: Int
    var weeklyPoints: Int
    let isCurrentUser: Bool
    /// Recent race outcomes: "exact", "partial", "miss"
    let recentForm: [String]
}

struct PredictionGroup: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let inviteCode: String
    let iconName: String
    let accentHex: String
    var members: [LeaderboardEntry]

    var sortedMembers: [LeaderboardEntry] {
        members.sorted {
            if $0.totalPoints != $1.totalPoints { return $0.totalPoints > $1.totalPoints }
            return $0.username < $1.username
        }
    }

    func currentUserRank() -> Int? {
        guard let idx = sortedMembers.firstIndex(where: { $0.isCurrentUser }) else { return nil }
        return idx + 1
    }
}

// MARK: - Scoring Rules

enum PredictionScoring {
    static let exactPositionPoints = 10
    static let podiumWrongSpotPoints = 4
    static let perfectPodiumBonus = 10
    static let longShotBonusPoints = 5

    /// Drivers outside the top 6 in the demo standings table qualify as long-shot picks.
    static let longShotDriverIDs: Set<String> = {
        let sorted = StandingsView.table.map(\.driver.id)
        return Set(sorted.dropFirst(6))
    }()

    static func isLongShot(_ driver: GPDriver) -> Bool {
        longShotDriverIDs.contains(driver.id)
    }

    static func evaluate(
        prediction: SavedPrediction,
        actualPodium: [GPDriver],
        raceName: String,
        circuitPlace: String
    ) -> RaceResultSummary {
        let driverById = Dictionary(uniqueKeysWithValues: GPDriver.roster.map { ($0.id, $0) })
        let actualIds = actualPodium.map(\.id)

        var rows: [ScoredPickRow] = []
        var exactCount = 0

        for (index, slot) in PodiumSlot.allCases.enumerated() {
            let predId = prediction.driverId(for: slot)
            let predicted = driverById[predId] ?? GPDriver.roster[0]
            let actual = actualPodium.indices.contains(index) ? actualPodium[index] : GPDriver.roster[index]

            let outcome: PickMatchOutcome
            let bonus: Int

            if predId == actual.id {
                outcome = .exact(points: exactPositionPoints)
                exactCount += 1
                bonus = isLongShot(predicted) ? longShotBonusPoints : 0
            } else if actualIds.contains(predId) {
                outcome = .podiumWrongSpot(points: podiumWrongSpotPoints)
                bonus = isLongShot(predicted) ? longShotBonusPoints : 0
            } else {
                outcome = .miss
                bonus = 0
            }

            rows.append(ScoredPickRow(
                slot: slot,
                predictedDriver: predicted,
                actualDriver: actual,
                outcome: outcome,
                longShotBonus: bonus
            ))
        }

        let perfectBonus = (exactCount == 3) ? perfectPodiumBonus : 0
        return RaceResultSummary(
            raceName: raceName,
            circuitPlace: circuitPlace,
            rows: rows,
            perfectPodiumBonus: perfectBonus,
            isSampleResult: true
        )
    }
}

// MARK: - Store (State + Persistence)

@Observable
final class StandingsPredictionStore {
    var mode: StandingsTabMode = .predictor
    var step: StandingsFlowStep = .makePicks

    // Make Your Picks state
    var activeSlot: PodiumSlot = .p1
    var p1: GPDriver?
    var p2: GPDriver?
    var p3: GPDriver?

    // Persisted locked prediction
    var lockedPrediction: SavedPrediction?

    // Computed race results (sample prototype classification)
    var latestResult: RaceResultSummary?

    // Leaderboards & Groups
    var globalEntries: [LeaderboardEntry] = []
    var friendEntries: [LeaderboardEntry] = []
    var groups: [PredictionGroup] = []
    var joinError: String?
    var joinSuccessMessage: String?

    private let predictionStorageKey = "f1_standings_locked_prediction_v1"
    private let groupsStorageKey = "f1_standings_groups_v1"
    private let baseUserPoints = 167
    private let baseGlobalRank = 7

    init() {
        loadPersistedState()
        rebuildLeaderboards()
    }

    // MARK: Upcoming Race Info

    var targetRace: Race {
        RaceCalendar.next ?? RaceCalendar.all[0]
    }

    var predictionDeadline: Date {
        // 30 minutes before lights out
        targetRace.date.addingTimeInterval(-30 * 60)
    }

    var pickedCount: Int {
        [p1, p2, p3].compactMap { $0 }.count
    }

    var canLockPrediction: Bool {
        guard lockedPrediction == nil else { return false }
        guard let a = p1, let b = p2, let c = p3 else { return false }
        return Set([a.id, b.id, c.id]).count == 3
    }

    func driver(for slot: PodiumSlot) -> GPDriver? {
        switch slot {
        case .p1: return p1
        case .p2: return p2
        case .p3: return p3
        }
    }

    func assignedSlot(for driver: GPDriver) -> PodiumSlot? {
        if p1?.id == driver.id { return .p1 }
        if p2?.id == driver.id { return .p2 }
        if p3?.id == driver.id { return .p3 }
        return nil
    }

    func assign(_ driver: GPDriver) {
        guard lockedPrediction == nil else { return }

        // If driver is already in the active slot, tap toggles it off
        if assignedSlot(for: driver) == activeSlot {
            setDriver(nil, for: activeSlot)
            return
        }

        // Prevent duplicate driver across slots: if already picked elsewhere, ignore
        if assignedSlot(for: driver) != nil {
            return
        }

        setDriver(driver, for: activeSlot)

        // Advance active slot to next empty slot
        if let nextEmpty = PodiumSlot.allCases.first(where: { self.driver(for: $0) == nil }) {
            activeSlot = nextEmpty
        }
    }

    func clearSlot(_ slot: PodiumSlot) {
        guard lockedPrediction == nil else { return }
        setDriver(nil, for: slot)
        activeSlot = slot
    }

    private func setDriver(_ driver: GPDriver?, for slot: PodiumSlot) {
        switch slot {
        case .p1: p1 = driver
        case .p2: p2 = driver
        case .p3: p3 = driver
        }
    }

    // MARK: Lock & Score

    func lockPrediction() {
        guard canLockPrediction, let p1, let p2, let p3 else { return }
        let saved = SavedPrediction(
            raceId: targetRace.id,
            raceName: targetRace.circuit.name,
            p1DriverId: p1.id,
            p2DriverId: p2.id,
            p3DriverId: p3.id,
            lockedAt: .now
        )
        lockedPrediction = saved
        savePrediction(saved)
        evaluateSampleResults()
        rebuildLeaderboards()
        step = .predictionLocked
    }

    func showRaceResults() {
        if latestResult == nil {
            evaluateSampleResults()
        }
        rebuildLeaderboards()
        step = .raceResults
    }

    func openLeaderboard(_ category: LeaderboardCategory = .global) {
        rebuildLeaderboards()
        step = .leaderboard(category)
    }

    func openGroup(_ groupId: String) {
        step = .groupDetail(groupId)
    }

    /// Evaluates the locked prediction against a clearly-labeled sample podium classification.
    private func evaluateSampleResults() {
        guard let locked = lockedPrediction else { return }
        let samplePodium = SampleStandingsData.sampleActualPodium
        latestResult = PredictionScoring.evaluate(
            prediction: locked,
            actualPodium: samplePodium,
            raceName: locked.raceName,
            circuitPlace: targetRace.circuit.place
        )
    }

    // MARK: User Leaderboard Metrics

    var earnedRacePoints: Int {
        latestResult?.totalPointsEarned ?? 0
    }

    var currentUserTotalPoints: Int {
        baseUserPoints + earnedRacePoints
    }

    var sortedGlobalEntries: [LeaderboardEntry] {
        globalEntries.sorted {
            if $0.totalPoints != $1.totalPoints { return $0.totalPoints > $1.totalPoints }
            return $0.username < $1.username
        }
    }

    var sortedFriendEntries: [LeaderboardEntry] {
        friendEntries.sorted {
            if $0.totalPoints != $1.totalPoints { return $0.totalPoints > $1.totalPoints }
            return $0.username < $1.username
        }
    }

    var currentUserGlobalRank: Int {
        (sortedGlobalEntries.firstIndex(where: { $0.isCurrentUser }) ?? 0) + 1
    }

    var globalRankDelta: Int {
        baseGlobalRank - currentUserGlobalRank
    }

    var weeklyFriendWinner: LeaderboardEntry? {
        sortedFriendEntries.max(by: { $0.weeklyPoints < $1.weeklyPoints })
    }

    // MARK: Groups (Create & Join)

    @discardableResult
    func createGroup(named rawName: String) -> PredictionGroup? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let code = generateUniqueInviteCode()
        let userMember = LeaderboardEntry(
            id: "user_you",
            username: "You",
            initials: "YO",
            avatarHex: "E8002D",
            totalPoints: currentUserTotalPoints,
            weeklyPoints: earnedRacePoints,
            isCurrentUser: true,
            recentForm: SampleStandingsData.userRecentForm(earned: earnedRacePoints)
        )

        let newGroup = PredictionGroup(
            id: "grp_\(UUID().uuidString.prefix(8))",
            name: trimmed,
            inviteCode: code,
            iconName: "flag.checkered.2.crossed",
            accentHex: "FF8000",
            members: [userMember]
        )

        groups.insert(newGroup, at: 0)
        saveGroups()
        return newGroup
    }

    func joinGroup(withCode rawCode: String) -> Bool {
        joinError = nil
        joinSuccessMessage = nil

        let normalized = rawCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !normalized.isEmpty else {
            joinError = "Enter an invite code to continue."
            return false
        }

        if let existing = groups.first(where: { $0.inviteCode.uppercased() == normalized }) {
            joinError = "You are already a member of \(existing.name)."
            return false
        }

        guard var template = SampleStandingsData.joinableDirectory[normalized] else {
            joinError = "Invalid invite code. Try sample code MONZA1 or SUZUKA."
            return false
        }

        let userMember = LeaderboardEntry(
            id: "user_you",
            username: "You",
            initials: "YO",
            avatarHex: "E8002D",
            totalPoints: currentUserTotalPoints,
            weeklyPoints: earnedRacePoints,
            isCurrentUser: true,
            recentForm: SampleStandingsData.userRecentForm(earned: earnedRacePoints)
        )

        if !template.members.contains(where: { $0.isCurrentUser }) {
            template.members.append(userMember)
        }

        groups.insert(template, at: 0)
        saveGroups()
        joinSuccessMessage = "Joined \(template.name)!"
        return true
    }

    func group(withId id: String) -> PredictionGroup? {
        groups.first(where: { $0.id == id })
    }

    private func generateUniqueInviteCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let existingCodes = Set(groups.map { $0.inviteCode.uppercased() })
            .union(SampleStandingsData.joinableDirectory.keys)
        for _ in 0..<20 {
            let suffix = String((0..<6).map { _ in chars.randomElement()! })
            if !existingCodes.contains(suffix) {
                return suffix
            }
        }
        return "F1\(Int.random(in: 1000...9999))"
    }

    // MARK: Persistence & Sync

    private func rebuildLeaderboards() {
        let earned = earnedRacePoints
        let userTotal = currentUserTotalPoints
        let userForm = SampleStandingsData.userRecentForm(earned: earned)

        let youEntry = LeaderboardEntry(
            id: "user_you",
            username: "You",
            initials: "YO",
            avatarHex: "E8002D",
            totalPoints: userTotal,
            weeklyPoints: earned,
            isCurrentUser: true,
            recentForm: userForm
        )

        globalEntries = SampleStandingsData.globalRivals + [youEntry]
        friendEntries = SampleStandingsData.friendRivals + [youEntry]

        for i in groups.indices {
            if let memberIdx = groups[i].members.firstIndex(where: { $0.isCurrentUser }) {
                groups[i].members[memberIdx].totalPoints = userTotal
                groups[i].members[memberIdx].weeklyPoints = earned
            }
        }
    }

    private func loadPersistedState() {
        if let data = UserDefaults.standard.data(forKey: predictionStorageKey),
           let saved = try? JSONDecoder().decode(SavedPrediction.self, from: data),
           saved.raceId == targetRace.id {
            lockedPrediction = saved
            let byId = Dictionary(uniqueKeysWithValues: GPDriver.roster.map { ($0.id, $0) })
            p1 = byId[saved.p1DriverId]
            p2 = byId[saved.p2DriverId]
            p3 = byId[saved.p3DriverId]
            evaluateSampleResults()
            step = .predictionLocked
        }

        if let data = UserDefaults.standard.data(forKey: groupsStorageKey),
           let savedGroups = try? JSONDecoder().decode([PredictionGroup].self, from: data),
           !savedGroups.isEmpty {
            groups = savedGroups
        } else {
            groups = SampleStandingsData.initialGroups
        }
    }

    private func savePrediction(_ prediction: SavedPrediction) {
        if let data = try? JSONEncoder().encode(prediction) {
            UserDefaults.standard.set(data, forKey: predictionStorageKey)
        }
    }

    private func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: groupsStorageKey)
        }
    }
}

// MARK: - Sample Prototype Data (clearly isolated for future API swap)

private enum SampleStandingsData {
    /// Sample podium used to demonstrate scoring without claiming live official results.
    static let sampleActualPodium: [GPDriver] = {
        let byId = Dictionary(uniqueKeysWithValues: GPDriver.roster.map { ($0.id, $0) })
        return [
            byId["NOR"] ?? GPDriver.roster[0],
            byId["LEC"] ?? GPDriver.roster[1],
            byId["VER"] ?? GPDriver.roster[2]
        ]
    }()

    static func userRecentForm(earned: Int) -> [String] {
        let latest = earned >= 18 ? "exact" : (earned > 0 ? "partial" : "miss")
        return ["exact", "partial", latest]
    }

    static let globalRivals: [LeaderboardEntry] = [
        LeaderboardEntry(id: "g_1", username: "Rohan", initials: "RO", avatarHex: "3671C6",
                         totalPoints: 214, weeklyPoints: 18, isCurrentUser: false, recentForm: ["exact", "exact", "partial"]),
        LeaderboardEntry(id: "g_2", username: "Ishita", initials: "IS", avatarHex: "A855F7",
                         totalPoints: 205, weeklyPoints: 14, isCurrentUser: false, recentForm: ["exact", "partial", "exact"]),
        LeaderboardEntry(id: "g_3", username: "Aarav", initials: "AA", avatarHex: "229971",
                         totalPoints: 199, weeklyPoints: 22, isCurrentUser: false, recentForm: ["exact", "exact", "exact"]),
        LeaderboardEntry(id: "g_4", username: "Dev", initials: "DE", avatarHex: "FF8000",
                         totalPoints: 188, weeklyPoints: 20, isCurrentUser: false, recentForm: ["exact", "exact", "miss"]),
        LeaderboardEntry(id: "g_5", username: "Meera", initials: "ME", avatarHex: "27F4D2",
                         totalPoints: 176, weeklyPoints: 14, isCurrentUser: false, recentForm: ["partial", "exact", "partial"]),
        LeaderboardEntry(id: "g_6", username: "Kabir", initials: "KA", avatarHex: "E84393",
                         totalPoints: 170, weeklyPoints: 10, isCurrentUser: false, recentForm: ["partial", "miss", "exact"])
    ]

    static let friendRivals: [LeaderboardEntry] = [
        LeaderboardEntry(id: "f_1", username: "Aarav", initials: "AA", avatarHex: "229971",
                         totalPoints: 199, weeklyPoints: 22, isCurrentUser: false, recentForm: ["exact", "exact", "exact"]),
        LeaderboardEntry(id: "f_2", username: "Dev", initials: "DE", avatarHex: "FF8000",
                         totalPoints: 188, weeklyPoints: 20, isCurrentUser: false, recentForm: ["exact", "exact", "miss"]),
        LeaderboardEntry(id: "f_3", username: "Meera", initials: "ME", avatarHex: "27F4D2",
                         totalPoints: 176, weeklyPoints: 14, isCurrentUser: false, recentForm: ["partial", "exact", "partial"])
    ]

    static let initialGroups: [PredictionGroup] = [
        PredictionGroup(
            id: "grp_paddock",
            name: "Paddock Pals",
            inviteCode: "PALS01",
            iconName: "person.2.fill",
            accentHex: "229971",
            members: friendRivals + [
                LeaderboardEntry(id: "user_you", username: "You", initials: "YO", avatarHex: "E8002D",
                                 totalPoints: 167, weeklyPoints: 0, isCurrentUser: true, recentForm: ["exact", "partial", "miss"])
            ]
        ),
        PredictionGroup(
            id: "grp_college",
            name: "College Crew",
            inviteCode: "CREW26",
            iconName: "graduationcap.fill",
            accentHex: "3671C6",
            members: [
                LeaderboardEntry(id: "c_1", username: "Rohan", initials: "RO", avatarHex: "3671C6",
                                 totalPoints: 214, weeklyPoints: 18, isCurrentUser: false, recentForm: ["exact", "exact", "partial"]),
                LeaderboardEntry(id: "c_2", username: "Ishita", initials: "IS", avatarHex: "A855F7",
                                 totalPoints: 205, weeklyPoints: 14, isCurrentUser: false, recentForm: ["exact", "partial", "exact"]),
                LeaderboardEntry(id: "c_3", username: "Kabir", initials: "KA", avatarHex: "E84393",
                                 totalPoints: 170, weeklyPoints: 10, isCurrentUser: false, recentForm: ["partial", "miss", "exact"]),
                LeaderboardEntry(id: "c_4", username: "Ananya", initials: "AN", avatarHex: "64C4FF",
                                 totalPoints: 162, weeklyPoints: 8, isCurrentUser: false, recentForm: ["partial", "miss", "partial"]),
                LeaderboardEntry(id: "user_you", username: "You", initials: "YO", avatarHex: "E8002D",
                                 totalPoints: 167, weeklyPoints: 0, isCurrentUser: true, recentForm: ["exact", "partial", "miss"])
            ]
        ),
        PredictionGroup(
            id: "grp_family",
            name: "Family League",
            inviteCode: "FAM888",
            iconName: "house.fill",
            accentHex: "FF8000",
            members: [
                LeaderboardEntry(id: "fam_1", username: "Neha", initials: "NE", avatarHex: "FF87BC",
                                 totalPoints: 158, weeklyPoints: 10, isCurrentUser: false, recentForm: ["partial", "partial", "miss"]),
                LeaderboardEntry(id: "fam_2", username: "Vikram", initials: "VI", avatarHex: "D68910",
                                 totalPoints: 145, weeklyPoints: 4, isCurrentUser: false, recentForm: ["miss", "partial", "partial"]),
                LeaderboardEntry(id: "user_you", username: "You", initials: "YO", avatarHex: "E8002D",
                                 totalPoints: 167, weeklyPoints: 0, isCurrentUser: true, recentForm: ["exact", "partial", "miss"])
            ]
        )
    ]

    static let joinableDirectory: [String: PredictionGroup] = [
        "MONZA1": PredictionGroup(
            id: "grp_monza",
            name: "Tifosi Monza Club",
            inviteCode: "MONZA1",
            iconName: "flame.fill",
            accentHex: "E8002D",
            members: [
                LeaderboardEntry(id: "m_1", username: "Marco", initials: "MA", avatarHex: "E8002D",
                                 totalPoints: 192, weeklyPoints: 16, isCurrentUser: false, recentForm: ["exact", "partial", "exact"]),
                LeaderboardEntry(id: "m_2", username: "Elena", initials: "EL", avatarHex: "FF8000",
                                 totalPoints: 174, weeklyPoints: 10, isCurrentUser: false, recentForm: ["partial", "exact", "miss"])
            ]
        ),
        "SUZUKA": PredictionGroup(
            id: "grp_suzuka",
            name: "Suzuka Night Owls",
            inviteCode: "SUZUKA",
            iconName: "bolt.fill",
            accentHex: "27F4D2",
            members: [
                LeaderboardEntry(id: "s_1", username: "Kenji", initials: "KE", avatarHex: "27F4D2",
                                 totalPoints: 201, weeklyPoints: 18, isCurrentUser: false, recentForm: ["exact", "exact", "partial"]),
                LeaderboardEntry(id: "s_2", username: "Sara", initials: "SA", avatarHex: "A855F7",
                                 totalPoints: 169, weeklyPoints: 8, isCurrentUser: false, recentForm: ["partial", "miss", "exact"])
            ]
        )
    ]
}
