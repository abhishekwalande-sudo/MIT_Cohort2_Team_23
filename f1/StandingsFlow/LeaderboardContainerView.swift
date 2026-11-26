//
//  LeaderboardContainerView.swift
//  f1
//
//  Screens 4, 5, and 6 of Standings Flow:
//   - Global Leaderboard
//   - Paddock Pals (Friends Leaderboard)
//   - Your Groups (Groups list, Create Group, Join with Invite Code, Group Detail)
//

import SwiftUI

struct LeaderboardContainerView: View {
    @Bindable var store: StandingsPredictionStore
    let category: LeaderboardCategory

    @State private var appeared = false

    private var headerEyebrow: String {
        switch category {
        case .global:  return "SEASON POINTS"
        case .friends: return "FRIENDS' GROUP"
        case .groups:  return "PRIVATE LEAGUES"
        }
    }

    private var headerTitle: String {
        switch category {
        case .global:  return "LEADERBOARD"
        case .friends: return "PADDOCK PALS"
        case .groups:  return "YOUR GROUPS"
        }
    }

    private var headerSubtitle: String {
        switch category {
        case .global:
            return "Position Predictor · Sample prototype - not live data"
        case .friends:
            return "\(store.sortedFriendEntries.count) members · Sample prototype - not live data"
        case .groups:
            return "Compete with friends in custom groups · Sample prototype"
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                FlowBackBar(title: store.latestResult != nil ? "Race Results" : "Make Your Picks") {
                    store.step = store.latestResult != nil ? .raceResults : .makePicks
                }
                .reveal(appeared, 0)

                ScreenTitle(
                    eyebrow: headerEyebrow,
                    title: headerTitle,
                    subtitle: headerSubtitle
                )
                .reveal(appeared, 0)

                categorySwitcher
                    .reveal(appeared, 1)

                switch category {
                case .global:
                    GlobalLeaderboardSection(store: store)
                        .reveal(appeared, 2)
                case .friends:
                    PaddockPalsSection(store: store)
                        .reveal(appeared, 2)
                case .groups:
                    YourGroupsSection(store: store)
                        .reveal(appeared, 2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .onAppear { appeared = true }
    }

    private var categorySwitcher: some View {
        HStack(spacing: 6) {
            ForEach(LeaderboardCategory.allCases) { item in
                let isSelected = item == category
                HButton(feedback: .impact(weight: .light)) {
                    store.openLeaderboard(item)
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isSelected ? .white : F1.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? F1.surfaceHi : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? .white.opacity(0.14) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .flowCard(radius: 16)
    }
}

// MARK: - Screen 4: Global Leaderboard

private struct GlobalLeaderboardSection: View {
    let store: StandingsPredictionStore

    private var entries: [LeaderboardEntry] {
        store.sortedGlobalEntries
    }

    private var topThree: [LeaderboardEntry] {
        Array(entries.prefix(3))
    }

    private var remaining: [(Int, LeaderboardEntry)] {
        entries.enumerated().dropFirst(3).map { ($0.offset + 1, $0.element) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if topThree.count >= 3 {
                podiumBlock
            }

            HStack {
                SectionTitle("SEASON STANDINGS")
                Spacer()
                Text("Form · last 3 races")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(F1.muted)
            }

            LazyVStack(spacing: 8) {
                ForEach(remaining, id: \.1.id) { rank, entry in
                    LeaderboardEntryRow(rank: rank, entry: entry, showForm: true)
                }
            }

            if store.globalRankDelta > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(F1.green)
                    Text("Up \(store.globalRankDelta) place\(store.globalRankDelta == 1 ? "" : "s") after \(store.targetRace.circuit.name)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(F1.green)
                }
                .padding(.top, 2)
            }
        }
    }

    private var podiumBlock: some View {
        HStack(alignment: .bottom, spacing: 10) {
            podiumColumn(entry: topThree[1], rank: 2, height: 86, accent: .white.opacity(0.65))
            podiumColumn(entry: topThree[0], rank: 1, height: 110, accent: F1.gold)
            podiumColumn(entry: topThree[2], rank: 3, height: 74, accent: F1.bronze)
        }
        .padding(.top, 6)
    }

    private func podiumColumn(entry: LeaderboardEntry, rank: Int, height: CGFloat, accent: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(hex: entry.avatarHex).opacity(0.25))
                    .frame(width: 38, height: 38)
                Circle()
                    .stroke(Color(hex: entry.avatarHex), lineWidth: 1.5)
                    .frame(width: 38, height: 38)
                Text(entry.initials)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
            }

            Text(entry.username)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            VStack(spacing: 2) {
                Text("\(rank)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
                Text("\(entry.totalPoints) pts")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                LinearGradient(
                    colors: [accent.opacity(0.24), F1.surface],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(accent.opacity(0.45), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Screen 5: Paddock Pals (Friends Leaderboard)

private struct PaddockPalsSection: View {
    let store: StandingsPredictionStore

    private var entries: [LeaderboardEntry] {
        store.sortedFriendEntries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let winner = store.weeklyFriendWinner {
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(F1.yellow)
                    Text("Weekly winner: \(winner.username) · \(winner.weeklyPoints) pts")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(12)
                .flowCard(radius: 14, stroke: F1.yellow.opacity(0.35))
            }

            LazyVStack(spacing: 8) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    LeaderboardEntryRow(rank: idx + 1, entry: entry, showForm: false)
                }
            }

            activityCard
        }
    }

    private var activityCard: some View {
        let userPoints = store.currentUserTotalPoints
        let nextAhead = entries.last(where: { !$0.isCurrentUser && $0.totalPoints > userPoints })
        let gapText = nextAhead.map { "\($0.username) is \($0.totalPoints - userPoints) pts ahead of you." }
            ?? "You lead the Paddock Pals standings!"

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(F1.red)
                Text("Paddock activity")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Meera locked her picks · \(gapText)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(F1.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flowCard(radius: 16)
    }
}

// MARK: - Screen 6: Your Groups

private struct YourGroupsSection: View {
    @Bindable var store: StandingsPredictionStore
    @State private var showCreateSheet = false
    @State private var newGroupName = ""
    @State private var inviteCodeInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVStack(spacing: 10) {
                ForEach(store.groups) { group in
                    HButton(feedback: .impact(weight: .light)) {
                        store.openGroup(group.id)
                    } label: {
                        groupRow(group)
                    }
                    .buttonStyle(PressStyle())
                }
            }

            RedPillButton(label: "Create group", icon: "plus") {
                showCreateSheet = true
            }

            joinWithCodeCard
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateGroupSheet(
                groupName: $newGroupName,
                onCreate: {
                    if let created = store.createGroup(named: newGroupName) {
                        newGroupName = ""
                        showCreateSheet = false
                        store.openGroup(created.id)
                    }
                },
                onCancel: {
                    newGroupName = ""
                    showCreateSheet = false
                }
            )
            .presentationDetents([.height(290)])
            .presentationDragIndicator(.visible)
        }
    }

    private func groupRow(_ group: PredictionGroup) -> some View {
        let rankText = group.currentUserRank().map { "Your rank \(ordinal($0))" } ?? "Member"
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: group.accentHex).opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: group.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: group.accentHex))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(group.members.count) member\(group.members.count == 1 ? "" : "s") · \(rankText)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(F1.muted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(F1.muted)
        }
        .padding(14)
        .flowCard(radius: 16)
    }

    private var joinWithCodeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("GOT AN INVITE?")

            Text("Enter a friend's invite code to join their paddock. Sample codes: MONZA1, SUZUKA")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(F1.muted)

            HStack(spacing: 8) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(F1.muted)
                TextField(
                    "",
                    text: $inviteCodeInput,
                    prompt: Text("Enter invite code").foregroundStyle(F1.muted)
                )
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .tint(F1.red)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(F1.surfaceHi, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))

            if let error = store.joinError {
                Text(error)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(F1.red)
            } else if let success = store.joinSuccessMessage {
                Text(success)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(F1.green)
            }

            HButton(feedback: .impact(weight: .medium)) {
                if store.joinGroup(withCode: inviteCodeInput) {
                    inviteCodeInput = ""
                }
            } label: {
                Text("Join with code")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(F1.surfaceHi, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
        }
        .padding(16)
        .flowCard(radius: 18)
    }

    private func ordinal(_ n: Int) -> String {
        let tens = (n / 10) % 10
        if tens == 1 { return "\(n)th" }
        switch n % 10 {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }
}

// MARK: - Group Detail View

struct GroupDetailView: View {
    @Bindable var store: StandingsPredictionStore
    let groupId: String
    @State private var appeared = false
    @State private var copiedCode = false

    private var group: PredictionGroup? {
        store.group(withId: groupId)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                FlowBackBar(title: "Your Groups") {
                    store.openLeaderboard(.groups)
                }
                .reveal(appeared, 0)

                if let group {
                    ScreenTitle(
                        eyebrow: "PRIVATE GROUP",
                        title: group.name.uppercased(),
                        subtitle: "\(group.members.count) member\(group.members.count == 1 ? "" : "s") · Sample prototype"
                    )
                    .reveal(appeared, 0)

                    inviteCodeCard(group)
                        .reveal(appeared, 1)

                    SectionTitle("GROUP STANDINGS")
                        .reveal(appeared, 2)

                    LazyVStack(spacing: 8) {
                        ForEach(Array(group.sortedMembers.enumerated()), id: \.element.id) { idx, member in
                            LeaderboardEntryRow(rank: idx + 1, entry: member, showForm: false)
                        }
                    }
                    .reveal(appeared, 3)
                } else {
                    Text("Group not found.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(F1.muted)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .onAppear { appeared = true }
    }

    private func inviteCodeCard(_ group: PredictionGroup) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("INVITE CODE")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(F1.muted)
                Text(group.inviteCode)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer()

            ShareLink(item: "Join my F1 prediction group \"\(group.name)\" with invite code: \(group.inviteCode)") {
                HStack(spacing: 6) {
                    Image(systemName: copiedCode ? "checkmark" : "square.and.arrow.up")
                        .font(.system(size: 12, weight: .bold))
                    Text("Share")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(F1.surfaceHi, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
        }
        .padding(14)
        .flowCard(radius: 16, stroke: Color(hex: group.accentHex).opacity(0.35))
    }
}

// MARK: - Create Group Modal

private struct CreateGroupSheet: View {
    @Binding var groupName: String
    let onCreate: () -> Void
    let onCancel: () -> Void

    private var canCreate: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            F1.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(
                    eyebrow: "NEW LEAGUE",
                    title: "CREATE GROUP",
                    subtitle: "A unique invite code will be generated automatically"
                )

                TextField(
                    "",
                    text: $groupName,
                    prompt: Text("Group name (e.g. Pit Wall Crew)").foregroundStyle(F1.muted)
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .tint(F1.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(F1.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(F1.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(F1.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onCreate) {
                        Text("Create")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule().fill(canCreate ? AnyShapeStyle(F1.redGradient) : AnyShapeStyle(F1.surfaceHi))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate)
                }
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Shared Leaderboard Row

private struct LeaderboardEntryRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let showForm: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(rank == 1 ? F1.yellow : (entry.isCurrentUser ? F1.red : .white))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.username)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    if entry.isCurrentUser {
                        Text("YOU")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(F1.red, in: Capsule())
                    }
                }

                if showForm {
                    HStack(spacing: 5) {
                        ForEach(Array(entry.recentForm.enumerated()), id: \.offset) { _, result in
                            Circle()
                                .fill(formColor(result))
                                .frame(width: 6, height: 6)
                        }
                        Text("Last 3 races")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(F1.muted)
                    }
                } else {
                    Text("+\(entry.weeklyPoints) this week")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(F1.muted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entry.totalPoints)")
                    .font(.system(size: 17, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                Text("pts")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(F1.muted)
            }
        }
        .padding(13)
        .flowCard(
            radius: 16,
            stroke: entry.isCurrentUser ? F1.red.opacity(0.6) : nil
        )
    }

    private func formColor(_ outcome: String) -> Color {
        switch outcome {
        case "exact": return F1.green
        case "partial": return F1.yellow
        default: return F1.muted
        }
    }
}
