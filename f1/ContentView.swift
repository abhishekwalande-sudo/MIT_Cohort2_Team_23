//
//  ContentView.swift
//  f1
//
//  Created by Ameya Palamwar on 26/11/26.
//

import SwiftUI

// =====================================================================
//  F1 COMPANION  ·  SwiftUI only (no UIKit)  ·  iOS 17+
//
//  FILE MAP
//   0. App entry + RootTabView (tab bar)
//   1. Theme & shared components (haptics, buttons, cards)
//   2. Data models (circuits, drivers, races, profiles)
//   3. Tab screens: Home (static) · Schedule (sheet from Home) · Standings
//   4. Telemetry tab: circuit -> drivers -> versus -> results -> moments
//   5. Telemetry maths engine
//
//  Replace the demo data in `RaceCalendar` / `GPDriver.roster` with your API.
// =====================================================================

// MARK: - 0. APP + CUSTOM TAB BAR

@main
struct F1CompanionApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
        }
    }
}

enum AppTab: CaseIterable {
    case home, telemetry, tryon, standings

    var title: String {
        switch self {
        case .home:      return "Home"
        case .telemetry: return "Telemetry"
        case .tryon:     return "TRYON"
        case .standings: return "Standings"
        }
    }

    var icon: String {
        switch self {
        case .home:      return "house"
        case .telemetry: return "chart.line.uptrend.xyaxis"
        case .tryon:     return "headphones"
        case .standings: return "trophy"
        }
    }
}

struct RootTabView: View {
    @State private var tab: AppTab = .home
    /// Owned here so the telemetry flow keeps its place when you switch tabs.
    @State private var telemetry = TelemetryModel()
    /// Owned here so the standings prediction flow keeps its place when you switch tabs.
    @State private var standingsStore = StandingsPredictionStore()
    /// Owned here so the TRY-ON simulator keeps its place when you switch tabs.
    @State private var tryOnStore = TryOnStore()

    var body: some View {
        ZStack {
            F1.background.ignoresSafeArea()

            switch tab {
            case .home:
                HomeView(onOpenTelemetry: {
                    telemetry.open(DemoMatchup.shared)
                    tab = .telemetry
                })
            case .telemetry:
                TelemetryFlowView(model: telemetry)
            case .tryon:
                TryOnFlowView(store: tryOnStore)
            case .standings:
                StandingsView(store: standingsStore)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .sensoryFeedback(.impact(weight: .light), trigger: tab)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    VStack(spacing: 5) {
                        Image(systemName: t.icon)
                            .font(.system(size: 22))
                            .frame(height: 24)
                        Text(t.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(tab == t ? F1.red : .white)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            Capsule()
                .fill(Color.black.opacity(0.75))
                .background(.ultraThinMaterial, in: Capsule())
        }
        .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 1) }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

struct PlaceholderScreen: View {
    let title: String
    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 10) {
                Text(title).font(.system(size: 28, weight: .black)).foregroundStyle(.white)
                Text("Coming soon").font(.system(size: 14)).foregroundStyle(F1.muted)
            }
        }
    }
}

// MARK: - 1. THEME & SHARED COMPONENTS

enum F1 {
    static let background = Color(red: 0.035, green: 0.035, blue: 0.055)
    static let surface    = Color(red: 0.075, green: 0.075, blue: 0.10)
    static let surfaceHi  = Color(red: 0.12,  green: 0.12,  blue: 0.15)
    static let muted      = Color(red: 0.58,  green: 0.60,  blue: 0.66)
    static let red        = Color(red: 0.92,  green: 0.05,  blue: 0.12)
    static let darkRed    = Color(red: 0.60,  green: 0.02,  blue: 0.00)
    static let purple     = Color(red: 0.62,  green: 0.30,  blue: 0.95)
    static let mclaren    = Color(red: 1.0,   green: 0.48,  blue: 0.0)
    static let yellow     = Color(red: 1.0,   green: 0.78,  blue: 0.12)
    static let green      = Color(red: 0.20,  green: 0.82,  blue: 0.48)
    static let ferrari    = Color(hex: "E8002D")
    static let gold       = Color(hex: "FFD700")
    static let bronze     = Color(hex: "CD7F32")

    static let redGradient = LinearGradient(colors: [red, darkRed], startPoint: .top, endPoint: .bottom)
    static let fadeWhite = LinearGradient(colors: [.white, .white.opacity(0.55)],
                                          startPoint: .top, endPoint: .bottom)
}

extension Color {
    /// Color(hex: "E8002D")
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let v = UInt64(cleaned, radix: 16) ?? 0
        let r, g, b, a: UInt64
        switch cleaned.count {
        case 3:  (r, g, b, a) = (((v >> 8) & 0xF) * 17, ((v >> 4) & 0xF) * 17, (v & 0xF) * 17, 255)
        case 6:  (r, g, b, a) = ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF, 255)
        case 8:  (r, g, b, a) = ((v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)
        default: (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255,
                  blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

/// Shared app background (one place, used by every tab).
struct Backdrop: View {
    var body: some View {
        ZStack {
            F1.background
            RadialGradient(colors: [F1.red.opacity(0.26), .clear],
                           center: .top, startRadius: 0, endRadius: 440)
            RadialGradient(colors: [F1.purple.opacity(0.10), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

/// SwiftUI-native haptic button (replaces UIImpactFeedbackGenerator & co).
struct HButton<Label: View>: View {
    var feedback: SensoryFeedback = .impact(weight: .medium)
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: { label() }
        .sensoryFeedback(feedback, trigger: taps)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct CountingText: View {
    let value: Double
    var body: some View {
        Text(value.formatted(.number.precision(.fractionLength(0))))
            .contentTransition(.numericText())
    }
}

struct CountUp: View {
    let to: Double
    var delay: Double = 0
    @State private var v: Double = 0
    var body: some View {
        CountingText(value: v)
            .onAppear { withAnimation(.easeOut(duration: 1.2).delay(delay)) { v = to } }
    }
}

struct LegendDot: View {
    let color: Color
    let name: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(name).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.82))
        }
    }
}

struct NameDot: View {
    let color: Color
    let name: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(name).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.85))
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(F1.red)
                .frame(width: 3, height: 14)
                .shadow(color: F1.red.opacity(0.8), radius: 4)
            Text(text).font(.system(size: 15, weight: .black)).tracking(0.3).foregroundStyle(.white)
        }
    }
}

/// Small pulsing red dot + red label used as a screen eyebrow.
struct Eyebrow: View {
    let text: String
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(F1.red).frame(width: 6, height: 6)
                .shadow(color: F1.red, radius: 4).pulse()
            Text(text).font(.system(size: 11, weight: .black)).tracking(2.5).foregroundStyle(F1.red)
        }
    }
}

struct ScreenTitle: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: eyebrow)
            Text(title).font(.system(size: 32, weight: .black)).foregroundStyle(F1.fadeWhite)
            if let subtitle {
                Text(subtitle).font(.system(size: 11, weight: .medium)).foregroundStyle(F1.muted)
            }
        }
    }
}

struct CapsuleSearchField: View {
    let prompt: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(F1.muted)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(F1.muted))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white).tint(F1.red).autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(F1.muted)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(F1.surface, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

struct RedPillButton: View {
    let label: String
    var icon: String = "arrow.right"
    var feedback: SensoryFeedback = .impact(weight: .medium)
    let action: () -> Void
    var body: some View {
        HButton(feedback: feedback, action: action) {
            HStack(spacing: 8) {
                Text(label).font(.system(size: 14, weight: .bold))
                Image(systemName: icon).font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Capsule().fill(F1.redGradient))
            .shadow(color: F1.red.opacity(0.5), radius: 12, y: 4)
        }
        .buttonStyle(PressStyle())
    }
}

struct ReplayButton: View {
    let action: () -> Void
    var body: some View {
        HButton(feedback: .impact(weight: .light), action: action) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.counterclockwise").font(.system(size: 10, weight: .bold))
                Text("Replay").font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(F1.muted)
        }
        .buttonStyle(.plain)
    }
}

/// Photo that fills its frame. If the asset is missing the faint silhouette behind it shows through.
struct SafePhoto: View {
    let asset: String
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(systemName: "person.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(.white.opacity(0.25)).padding(22)
                Image(asset)
                    .resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .clipped()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Loops a 0...cycle clock. Replay by passing a new `start`.
struct AnimClock<Content: View>: View {
    let start: Date
    let cycle: Double
    @ViewBuilder let content: (Double) -> Content
    var body: some View {
        TimelineView(.animation) { tl in
            content(max(0, tl.date.timeIntervalSince(start)).truncatingRemainder(dividingBy: cycle))
        }
    }
}

struct TypewriterText: View {
    let text: String
    let start: Date
    var cps: Double = 55
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let n = min(text.count, max(0, Int(tl.date.timeIntervalSince(start) * cps)))
            ZStack(alignment: .topLeading) {
                Text(text).opacity(0)
                Text(String(text.prefix(n)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FlowPulseModifier: ViewModifier {
    @State private var pulsing = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.08 : 0.94)
            .opacity(pulsing ? 1 : 0.72)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

extension View {
    func reveal(_ isVisible: Bool, _ order: Int) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .animation(.easeOut(duration: 0.38).delay(Double(min(max(order, 0), 12)) * 0.045), value: isVisible)
    }

    func pulse() -> some View { modifier(FlowPulseModifier()) }

    func flowCard(radius: CGFloat = 20, stroke: Color? = nil) -> some View {
        background(F1.surface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(stroke ?? Color.white.opacity(0.08), lineWidth: stroke == nil ? 1 : 1.5)
            )
    }

    func flowTransition() -> some View {
        transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)),
                               removal: .opacity))
    }
}

// MARK: - small math helpers

func flowRand(_ seed: Int, _ k: Int) -> Double {
    let x = sin(Double(seed) * 12.9898 + Double(k) * 78.233) * 43758.5453
    return x - floor(x)
}
func flowClamp(_ x: Double) -> Double { min(max(x, 0), 1) }
func flowEase(_ x: Double) -> Double { let t = flowClamp(x); return t * t * (3 - 2 * t) }

func flowValue(_ arr: [Double], _ t: Double) -> Double {
    guard !arr.isEmpty else { return 0 }
    guard arr.count > 1 else { return arr[0] }
    let f = flowClamp(t) * Double(arr.count - 1)
    let i = Int(f)
    let j = min(i + 1, arr.count - 1)
    let r = f - Double(i)
    return arr[i] * (1 - r) + arr[j] * r
}

extension Path {
    func flowPoint(at t: CGFloat) -> CGPoint {
        trimmedPath(from: 0, to: min(max(t, 0.002), 0.998)).currentPoint ?? .zero
    }
}

// MARK: - 2. MODELS

struct GPCircuit: Identifiable, Equatable {
    let id: String
    let name: String
    let place: String
    let lengthM: Double
    let tint: Color
    let pts: [CGPoint]

    static func == (l: GPCircuit, r: GPCircuit) -> Bool { l.id == r.id }

    private static func p(_ a: [(Double, Double)]) -> [CGPoint] { a.map { CGPoint(x: $0.0, y: $0.1) } }

    static let all: [GPCircuit] = [
        GPCircuit(id: "AUS", name: "Australian Grand Prix", place: "Albert Park · Melbourne", lengthM: 5278,
                  tint: Color(hex: "2B6CB0"),
                  pts: p([(0.10, 0.55), (0.12, 0.30), (0.28, 0.12), (0.50, 0.18), (0.58, 0.34), (0.74, 0.22),
                          (0.90, 0.30), (0.92, 0.55), (0.78, 0.72), (0.84, 0.88), (0.60, 0.90), (0.48, 0.72),
                          (0.30, 0.84), (0.14, 0.78)])),
        GPCircuit(id: "CHN", name: "Chinese Grand Prix", place: "Shanghai International", lengthM: 5451,
                  tint: Color(hex: "C0392B"),
                  pts: p([(0.12, 0.62), (0.10, 0.38), (0.24, 0.22), (0.40, 0.30), (0.34, 0.46), (0.50, 0.52),
                          (0.68, 0.30), (0.88, 0.18), (0.92, 0.40), (0.78, 0.62), (0.82, 0.82), (0.55, 0.86),
                          (0.32, 0.80)])),
        GPCircuit(id: "BHR", name: "Bahrain Grand Prix", place: "Sakhir · Bahrain", lengthM: 5412,
                  tint: Color(hex: "D68910"),
                  pts: p([(0.12, 0.30), (0.34, 0.14), (0.58, 0.22), (0.50, 0.38), (0.72, 0.44), (0.90, 0.30),
                          (0.92, 0.62), (0.70, 0.84), (0.46, 0.74), (0.30, 0.88), (0.12, 0.70)])),
        GPCircuit(id: "ITA", name: "Italian Grand Prix", place: "Monza · Italy", lengthM: 5793,
                  tint: Color(hex: "1E8449"),
                  pts: p([(0.08, 0.50), (0.10, 0.22), (0.30, 0.12), (0.62, 0.12), (0.90, 0.20), (0.92, 0.46),
                          (0.80, 0.58), (0.66, 0.56), (0.58, 0.74), (0.40, 0.88), (0.18, 0.84), (0.08, 0.70)])),
        GPCircuit(id: "SGP", name: "Singapore Grand Prix", place: "Marina Bay · Singapore", lengthM: 4940,
                  tint: Color(hex: "8E44AD"),
                  pts: p([(0.10, 0.20), (0.40, 0.12), (0.46, 0.30), (0.70, 0.28), (0.90, 0.38), (0.84, 0.58),
                          (0.62, 0.52), (0.58, 0.72), (0.80, 0.86), (0.40, 0.90), (0.28, 0.68), (0.12, 0.62)])),
        GPCircuit(id: "MIA", name: "Miami Grand Prix", place: "Miami Gardens · USA", lengthM: 5412,
                  tint: Color(hex: "16A5A5"),
                  pts: p([(0.10, 0.40), (0.28, 0.18), (0.56, 0.16), (0.62, 0.34), (0.84, 0.30), (0.92, 0.54),
                          (0.76, 0.74), (0.52, 0.66), (0.36, 0.84), (0.16, 0.74)])),
        GPCircuit(id: "MON", name: "Monaco Grand Prix", place: "Monte Carlo · Monaco", lengthM: 3337,
                  tint: Color(hex: "E84393"),
                  pts: p([(0.14, 0.20), (0.44, 0.12), (0.70, 0.22), (0.88, 0.18), (0.92, 0.42), (0.74, 0.52),
                          (0.84, 0.70), (0.62, 0.88), (0.36, 0.76), (0.18, 0.84), (0.10, 0.50)])),
        GPCircuit(id: "IMO", name: "Emilia-Romagna Grand Prix", place: "Imola · Italy", lengthM: 4909,
                  tint: Color(hex: "D35400"),
                  pts: p([(0.12, 0.50), (0.20, 0.24), (0.44, 0.16), (0.64, 0.30), (0.86, 0.22), (0.90, 0.50),
                          (0.72, 0.62), (0.78, 0.82), (0.50, 0.88), (0.32, 0.70), (0.18, 0.78)]))
    ]

    static func named(_ id: String) -> GPCircuit { all.first { $0.id == id } ?? all[0] }
}

struct GPDriver: Identifiable, Equatable {
    let id: String
    let first: String
    let last: String
    let team: String
    let number: String
    let asset: String
    let color: Color

    var full: String { "\(first) \(last)" }

    private static func d(_ id: String, _ f: String, _ l: String, _ team: String,
                          _ n: String, _ hex: String) -> GPDriver {
        GPDriver(id: id, first: f, last: l, team: team, number: n, asset: f, color: Color(hex: hex))
    }

    static let roster: [GPDriver] = [
        d("HUL", "Nico", "Hülkenberg", "Kick Sauber", "27", "52E252"),
        d("ALB", "Alex", "Albon", "Williams", "23", "64C4FF"),
        d("LEC", "Charles", "Leclerc", "Ferrari", "16", "E8002D"),
        d("ANT", "Kimi", "Antonelli", "Mercedes", "12", "27F4D2"),
        d("RUS", "George", "Russell", "Mercedes", "63", "27F4D2"),
        d("NOR", "Lando", "Norris", "McLaren", "4", "FF8000"),
        d("SAI", "Carlos", "Sainz", "Williams", "55", "64C4FF"),
        d("VER", "Max", "Verstappen", "Red Bull", "1", "3671C6"),
        d("PIA", "Oscar", "Piastri", "McLaren", "81", "FF8000"),
        d("HAM", "Lewis", "Hamilton", "Ferrari", "44", "E8002D"),
        d("ALO", "Fernando", "Alonso", "Aston Martin", "14", "229971"),
        d("GAS", "Pierre", "Gasly", "Alpine", "10", "FF87BC")
    ]

    /// Computed once, not on every render.
    static let teams: [String] = Array(Set(roster.map(\.team))).sorted()
}

// ---- Race calendar (demo data, dates are relative to "now" so the home screen always looks live)

struct RaceSession: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
}

struct Race: Identifiable {
    let id: String
    let round: Int
    let circuit: GPCircuit
    let date: Date                 // race start
    var isPast: Bool { date < .now }
    var sessions: [RaceSession] {
        [("Practice 1", -2.1), ("Practice 2", -2.0 + 0.1), ("Qualifying", -1.0), ("Race", 0)]
            .map { RaceSession(name: $0.0, date: date.addingTimeInterval($0.1 * 86_400)) }
    }
}

enum RaceCalendar {
    static let all: [Race] = {
        let offsets: [(String, Double)] = [
            ("AUS", -63), ("CHN", -49), ("BHR", -35), ("IMO", -21), ("MON", -7),
            ("MIA", 9), ("ITA", 23), ("SGP", 37)
        ]
        return offsets.enumerated().map { i, o in
            Race(id: o.0, round: i + 1, circuit: .named(o.0),
                 date: Date.now.addingTimeInterval(o.1 * 86_400 + 3_600 * 14))
        }
    }()
    static var next: Race? { all.first { !$0.isPast } }
    static var last: Race? { all.last { $0.isPast } }
}

// ---- Telemetry profile

struct GPProfile {
    let top, t11Brake, t11Apex, t11Exit, t12Exit, t12p50, t12p100, cornerK, lap: Double
    var gain: Double { t12p100 - t12Exit }

    static func make(_ d: GPDriver) -> GPProfile {
        switch d.id {
        case "NOR":
            return GPProfile(top: 342, t11Brake: 305, t11Apex: 142, t11Exit: 255,
                             t12Exit: 135, t12p50: 195, t12p100: 240, cornerK: 1.0, lap: 72.967)
        case "LEC":
            return GPProfile(top: 348, t11Brake: 298, t11Apex: 135, t11Exit: 248,
                             t12Exit: 132, t12p50: 186, t12p100: 225, cornerK: 0.985, lap: 72.945)
        default:
            let seed = Int(d.number) ?? 7
            func r(_ k: Int) -> Double { flowRand(seed, k) }
            let exit12 = 127 + r(5) * 14
            let p50 = exit12 + 50 + r(6) * 14
            let p100 = p50 + 38 + r(7) * 14
            return GPProfile(top: 337 + r(1) * 13, t11Brake: 296 + r(2) * 16,
                             t11Apex: 130 + r(3) * 18, t11Exit: 243 + r(4) * 18,
                             t12Exit: exit12, t12p50: p50, t12p100: p100,
                             cornerK: 0.97 + r(8) * 0.06, lap: 72.5 + r(9) * 1.0)
        }
    }
}

enum FlowMetric: String, CaseIterable, Identifiable {
    case speed = "Speed", brake = "Brake", drs = "DRS", throttle = "Throttle"
    var id: String { rawValue }
    var yRange: ClosedRange<Double> { self == .speed ? 40...360 : 0...110 }
    var blurb: String {
        switch self {
        case .speed:    return "Speed trace: how fast both drivers travel across the lap."
        case .brake:    return "Brake trace: where and how hard each driver slows down."
        case .throttle: return "Throttle trace: how much power each driver applies through the lap."
        case .drs:      return "DRS trace: when each driver's rear wing is open."
        }
    }
}

enum FlowMoment: String, Identifiable, CaseIterable {
    case straight, turn11, turn12
    var id: String { rawValue }
    var title: String {
        switch self { case .straight: "Main Straight"; case .turn11: "Turn 11"; case .turn12: "Exit T12" }
    }
    var icon: String {
        switch self { case .straight: "flag.checkered"; case .turn11: "arrow.turn.down.right"; case .turn12: "arrow.up.right" }
    }
    var accent: Color {
        switch self { case .straight: F1.mclaren; case .turn11: F1.red; case .turn12: F1.purple }
    }
    var scrubT: Double {
        switch self { case .straight: 0.95; case .turn11: 0.62; case .turn12: 0.714 }
    }
}

// MARK: - 3a. HOME  (static: no entrance, pulse, count-up or looping animations)

extension GPCircuit {
    var flag: String {
        switch id {
        case "AUS": return "🇦🇺"
        case "CHN": return "🇨🇳"
        case "BHR": return "🇧🇭"
        case "ITA", "IMO": return "🇮🇹"
        case "SGP": return "🇸🇬"
        case "MIA": return "🇺🇸"
        case "MON": return "🇲🇨"
        default:    return "🏁"
        }
    }
}

extension GPDriver {
    static func named(_ id: String) -> GPDriver { roster.first { $0.id == id } ?? roster[0] }
}

/// Built once, shared by the Home shortcut and the Telemetry tab.
enum DemoMatchup {
    static let shared = Matchup(circuit: .named("AUS"), a: .named("NOR"), b: .named("LEC"))
}

struct NewsItem: Identifiable {
    let id: String
    let source: String
    let age: String
    let title: String
    let icon: String
    let color: Color
    let asset: String
}

struct HomeView: View {
    var onOpenTelemetry: () -> Void = {}

    @AppStorage("userName") private var userName = "Ameya"
    @State private var showSchedule = false

    private let race = RaceCalendar.next ?? RaceCalendar.all[0]
    private let favourite = GPDriver.named("LEC")
    private let lastResults = ["P3", "P1", "P2", "P3", "P9"]

    private static let news: [NewsItem] = [
        NewsItem(id: "n1", source: "Ferrari", age: "2h ago",
                 title: "Ferrari's Monza aero package: a closer look",
                 icon: "wrench.and.screwdriver.fill", color: Color(hex: "E8002D"), asset: "news1"),
        NewsItem(id: "n2", source: "Red Bull", age: "5h ago",
                 title: "How Red Bull finds its edge through the corners",
                 icon: "flag.checkered", color: Color(hex: "3671C6"), asset: "news2"),
        NewsItem(id: "n3", source: "Technology", age: "1d ago",
                 title: "Inside the next generation of hybrid power",
                 icon: "bolt.fill", color: Color(hex: "FF8000"), asset: "news3")
    ]

    var body: some View {
        ZStack {
            Backdrop()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    nextRaceSection
                    favouriteSection
                    telemetryShortcut
                    newsCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showSchedule) {
            ScheduleView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(F1.background)
        }
    }

    // MARK: header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome back,").font(.system(size: 16)).foregroundStyle(.white.opacity(0.85))
                Text(userName).font(.system(size: 38, weight: .black)).foregroundStyle(.white)
            }
            Spacer()
            ProfileAvatar(initial: String(userName.prefix(1)).uppercased(), asset: "Profile")
        }
    }

    // MARK: next race

    private var nextRaceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar").font(.system(size: 16, weight: .semibold)).foregroundStyle(F1.red)
                Text("Next Race").font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
            }

            ZStack(alignment: .topLeading) {
                RaceBackdrop(circuit: race.circuit)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(race.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "FF5A4D"))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color(hex: "5A1015").opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                        Spacer()
                        HButton(feedback: .selection, action: { showSchedule = true }) {
                            HStack(spacing: 4) {
                                Text("\(race.date.formatted(.dateTime.year())) Schedule")
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(race.circuit.name)
                                .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                                .lineLimit(2).minimumScaleFactor(0.7)
                            Text(race.circuit.place)
                                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Text(race.circuit.flag).font(.system(size: 24))
                    }
                    .padding(.top, 16)

                    Spacer(minLength: 12)

                    // Ticks once a second. Digits change instantly, no transition.
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        countdown(at: ctx.date)
                    }
                }
                .padding(16)
            }
            .frame(height: 262)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay { RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.14), lineWidth: 1) }
        }
    }

    private func countdown(at now: Date) -> some View {
        let s = max(0, Int(race.date.timeIntervalSince(now)))
        return HStack(spacing: 0) {
            countUnit(s / 86_400, "Days")
            colon
            countUnit((s % 86_400) / 3_600, "Hours")
            colon
            countUnit((s % 3_600) / 60, "Minutes")
            colon
            countUnit(s % 60, "Seconds")
        }
    }

    private func countUnit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 38, weight: .bold)).monospacedDigit().foregroundStyle(.white)
            Text(label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var colon: some View {
        VStack(spacing: 9) {
            Circle().fill(.white).frame(width: 5, height: 5)
            Circle().fill(.white).frame(width: 5, height: 5)
        }
        .offset(y: -9)
    }

    // MARK: favourite driver

    private var favouriteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 22, height: 22).background(F1.red, in: RoundedRectangle(cornerRadius: 6))
                Text("FAVOURITE DRIVER").font(.system(size: 15, weight: .medium)).tracking(2).foregroundStyle(.white)
            }
            favouriteCard
        }
    }

    private var favouriteCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: "3C0E14"), Color(hex: "1A0A0E")],
                           startPoint: .topTrailing, endPoint: .bottomLeading)

            Text(favourite.number)
                .font(.system(size: 170, weight: .black)).foregroundStyle(F1.red.opacity(0.16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .offset(x: 26, y: -4)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("#\(favourite.number)").font(.system(size: 58, weight: .black)).foregroundStyle(.white)
                    Text(favourite.full).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    HStack(spacing: 6) {
                        ForEach(Array(lastResults.enumerated()), id: \.offset) { _, r in resultChip(r) }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 8)

                HStack(alignment: .bottom, spacing: 12) {
                    divider
                    stat("POINTS", "278", unit: "pts")
                    divider
                    stat("WDC STANDING", "P3", unit: nil)
                }
            }
            .padding(16)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(LinearGradient(colors: [F1.red.opacity(0.55), .white.opacity(0.08)],
                                       startPoint: .topTrailing, endPoint: .bottomLeading), lineWidth: 1)
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 64)
    }

    private func stat(_ title: String, _ value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(F1.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
                if let unit { Text(unit).font(.system(size: 13)).foregroundStyle(F1.muted) }
            }
        }
    }

    private func resultChip(_ text: String) -> some View {
        let c: Color = {
            switch text {
            case "P1": return F1.gold
            case "P2": return Color(hex: "B8B8C4")
            case "P3": return F1.bronze
            default:   return Color(hex: "8A8A96")
            }
        }()
        return Text(text)
            .font(.system(size: 11, weight: .bold)).foregroundStyle(c)
            .frame(width: 30, height: 24)
            .background(c.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(c.opacity(0.7), lineWidth: 1))
    }

    // MARK: telemetry shortcut (opens the real NOR vs LEC comparison)

    private var telemetryShortcut: some View {
        let m = DemoMatchup.shared
        let a = m.series(.speed, 0), b = m.series(.speed, 1)
        let lo = min(a.min() ?? 0, b.min() ?? 0), hi = max(a.max() ?? 1, b.max() ?? 1)

        return HButton(action: onOpenTelemetry) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(F1.red).frame(width: 6, height: 6)
                        Text("LATEST TELEMETRY").font(.system(size: 9, weight: .black)).tracking(1.5)
                            .foregroundStyle(F1.red)
                    }
                    Text("\(m.a.last) vs \(m.b.last)").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    Text("\(m.circuit.name) · Qualifying").font(.system(size: 11)).foregroundStyle(F1.muted)
                    HStack(spacing: 4) {
                        Text("Open lap replay").font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(F1.red).padding(.top, 2)
                }
                Spacer(minLength: 0)
                ZStack {
                    MiniSparkline(data: b, lo: lo, hi: hi, color: m.colorB)
                    MiniSparkline(data: a, lo: lo, hi: hi, color: m.colorA)
                }
                .frame(width: 112, height: 60)
            }
            .padding(16)
            .background(F1.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(colors: [F1.mclaren.opacity(0.5), F1.red.opacity(0.5)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: news

    private var newsCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "newspaper").font(.system(size: 16, weight: .semibold)).foregroundStyle(F1.red)
                    Text("Latest News").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                }
                Spacer()
                Text("See All").font(.system(size: 13, weight: .semibold)).foregroundStyle(F1.red)
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

            ForEach(Array(Self.news.enumerated()), id: \.element.id) { index, item in
                HButton(feedback: .impact(weight: .light), action: {}) { newsRow(item) }
                    .buttonStyle(.plain)
                if index < Self.news.count - 1 {
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                        .padding(.leading, 90).padding(.trailing, 16)
                }
            }
            Spacer().frame(height: 8)
        }
        .background(F1.surface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.10), lineWidth: 1) }
    }

    private func newsRow(_ item: NewsItem) -> some View {
        HStack(spacing: 12) {
            NewsThumb(asset: item.asset, icon: item.icon, color: item.color)
                .frame(width: 62, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(item.source) · \(item.age) · Sample").font(.system(size: 10)).foregroundStyle(F1.muted)
                Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .lineLimit(2).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: Home pieces

struct ProfileAvatar: View {
    let initial: String
    let asset: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [F1.red, Color(hex: "6E0A0F")], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initial).font(.system(size: 20, weight: .black)).foregroundStyle(.white)
            Image(asset).resizable().scaledToFill()   // covers the initial when the asset exists
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1.5))
        .overlay(Circle().stroke(F1.red.opacity(0.55), lineWidth: 1).padding(-4))
    }
}

struct NewsThumb: View {
    let asset: String
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [color.opacity(0.9), color.opacity(0.25), F1.surface],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(.white.opacity(0.9))
            Image(asset).resizable().scaledToFill()
        }
        .clipped()
    }
}

/// Static circuit artwork for the next-race card (drop-in replacement for the animated track).
struct RaceBackdrop: View {
    let circuit: GPCircuit

    var body: some View {
        ZStack {
            LinearGradient(colors: [circuit.tint.opacity(0.45), Color(hex: "100A0D")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            CircuitShape(pts: circuit.pts)
                .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                .padding(30)
            CircuitShape(pts: circuit.pts)
                .stroke(F1.red.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: F1.red.opacity(0.6), radius: 6)
                .padding(30)
            LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.10), .black.opacity(0.65)],
                           startPoint: .top, endPoint: .bottom)
        }
        .drawingGroup()
    }
}

struct MiniSparkline: View {
    let data: [Double]
    let lo: Double
    let hi: Double
    let color: Color

    var body: some View {
        GeometryReader { g in
            Path { p in
                for (i, v) in data.enumerated() {
                    let pt = CGPoint(x: g.size.width * CGFloat(i) / CGFloat(max(data.count - 1, 1)),
                                     y: g.size.height * (1 - CGFloat((v - lo) / max(hi - lo, 1))))
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.6), radius: 4)
        }
    }
}

// MARK: - 3b. SCHEDULE

struct ScheduleView: View {
    enum Filter: String, CaseIterable { case upcoming = "Upcoming", completed = "Completed" }

    @State private var filter: Filter = .upcoming
    @State private var expanded: String? = RaceCalendar.next?.id
    @State private var appeared = false
    @Namespace private var ns

    private var races: [Race] {
        let list = RaceCalendar.all.filter { filter == .upcoming ? !$0.isPast : $0.isPast }
        return filter == .upcoming ? list : list.reversed()
    }

    var body: some View {
        ZStack {
            Backdrop()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(eyebrow: "SEASON", title: "SCHEDULE",
                                subtitle: "Tap a race for session times").reveal(appeared, 0)
                    filterTabs.reveal(appeared, 1)

                    LazyVStack(spacing: 10) {
                        ForEach(races) { race in
                            RaceRow(race: race, isOpen: expanded == race.id,
                                    isNext: race.id == RaceCalendar.next?.id) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    expanded = expanded == race.id ? nil : race.id
                                }
                            }
                        }
                    }
                    if races.isEmpty {
                        Text("Nothing here yet 🏁").font(.system(size: 13, weight: .medium))
                            .foregroundStyle(F1.muted).frame(maxWidth: .infinity).padding(.top, 30)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
            }
        }
        .onAppear { appeared = true }
    }

    private var filterTabs: some View {
        HStack(spacing: 4) {
            ForEach(Filter.allCases, id: \.self) { f in
                HButton(feedback: .selection, action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { filter = f }
                }) {
                    Text(f.rawValue).font(.system(size: 13, weight: .bold))
                        .foregroundStyle(filter == f ? .white : F1.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background {
                            if filter == f {
                                Capsule().fill(F1.redGradient)
                                    .shadow(color: F1.red.opacity(0.5), radius: 8, y: 2)
                                    .matchedGeometryEffect(id: "filter", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(F1.background.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

struct RaceRow: View {
    let race: Race
    let isOpen: Bool
    let isNext: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HButton(feedback: .selection, action: onTap) {
                HStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Text(race.date.formatted(.dateTime.day()))
                            .font(.system(size: 20, weight: .black)).foregroundStyle(.white)
                        Text(race.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(.system(size: 9, weight: .black)).foregroundStyle(race.circuit.tint)
                    }
                    .frame(width: 50, height: 50)
                    .background(race.circuit.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("ROUND \(race.round)").font(.system(size: 9, weight: .black))
                            .tracking(1).foregroundStyle(F1.muted)
                        Text(race.circuit.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text(race.circuit.place).font(.system(size: 10, weight: .medium)).foregroundStyle(F1.muted)
                    }
                    Spacer(minLength: 4)

                    if isNext {
                        Text("NEXT").font(.system(size: 8, weight: .black)).tracking(1)
                            .foregroundStyle(.black).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(F1.yellow, in: Capsule())
                    } else if race.isPast {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(F1.green)
                    }
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(F1.muted).rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 8) {
                    Divider().overlay(.white.opacity(0.08))
                    ForEach(race.sessions) { s in
                        HStack {
                            Text(s.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                            Spacer()
                            Text(s.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(F1.muted)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .flowCard(radius: 18, stroke: isNext ? F1.yellow.opacity(0.5) : nil)
    }
}

// MARK: - 3c. STANDINGS

struct StandingEntry {
    let driver: GPDriver
    let points: Int
}

struct StandingsView: View {
    @Bindable var store: StandingsPredictionStore

    /// Demo points – swap with real data.
    static let table: [StandingEntry] = GPDriver.roster.enumerated()
        .map { StandingEntry(driver: $1, points: Int(flowRand(Int($1.number) ?? 1, 11) * 220) + 20) }
        .sorted { $0.points > $1.points }

    @State private var appeared = false

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                modePicker
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                switch store.mode {
                case .predictor:
                    StandingsPredictorFlowView(store: store)
                case .drivers:
                    driversStandingsList
                }
            }
        }
        .onAppear { appeared = true }
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(StandingsTabMode.allCases) { mode in
                let selected = store.mode == mode
                HButton(feedback: .impact(weight: .light)) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        store.mode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(selected ? .white : F1.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(selected ? F1.surfaceHi : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(selected ? .white.opacity(0.14) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .flowCard(radius: 15)
    }

    private var driversStandingsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(eyebrow: "DRIVERS", title: "STANDINGS",
                            subtitle: "Demo points · connect your data source").reveal(appeared, 0)
                LazyVStack(spacing: 8) {
                    ForEach(Array(Self.table.enumerated()), id: \.element.driver.id) { i, row in
                        StandingRow(row: row, position: i + 1)
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
    }
}

struct StandingRow: View {
    let row: StandingEntry
    var position: Int? = nil

    var body: some View {
        let pos = position ?? ((StandingsView.table.firstIndex { $0.driver.id == row.driver.id } ?? 0) + 1)
        HStack(spacing: 12) {
            Text("\(pos)").font(.system(size: 15, weight: .black))
                .foregroundStyle(pos == 1 ? F1.yellow : .white).frame(width: 24)
            RoundedRectangle(cornerRadius: 2).fill(row.driver.color).frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.driver.full).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                Text(row.driver.team).font(.system(size: 10, weight: .medium)).foregroundStyle(F1.muted)
            }
            Spacer()
            Text("\(row.points)").font(.system(size: 16, weight: .heavy, design: .monospaced)).foregroundStyle(.white)
            Text("PTS").font(.system(size: 8, weight: .black)).foregroundStyle(F1.muted)
        }
        .padding(12)
        .flowCard(radius: 16)
    }
}

// MARK: - 5. TELEMETRY MATHS ENGINE

/// Smooth, monotone curve through every anchor.
struct MonoCubic {
    let xs: [Double], ys: [Double], ms: [Double]

    init(_ pts: [(Double, Double)]) {
        let X = pts.map(\.0), Y = pts.map(\.1)
        let n = X.count
        precondition(n >= 2)
        var d = [Double](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) { d[i] = (Y[i + 1] - Y[i]) / (X[i + 1] - X[i]) }
        var m = [Double](repeating: 0, count: n)
        m[0] = d[0]; m[n - 1] = d[n - 2]
        if n > 2 {
            for i in 1..<(n - 1) { m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2 }
        }
        for i in 0..<(n - 1) {
            if d[i] == 0 { m[i] = 0; m[i + 1] = 0 } else {
                let a = m[i] / d[i], b = m[i + 1] / d[i]
                let s = a * a + b * b
                if s > 9 { let tau = 3 / s.squareRoot(); m[i] = tau * a * d[i]; m[i + 1] = tau * b * d[i] }
            }
        }
        xs = X; ys = Y; ms = m
    }

    func value(_ x: Double) -> Double {
        var i = 0
        while i < xs.count - 2 && x > xs[i + 1] { i += 1 }
        let h = xs[i + 1] - xs[i]
        let t = (x - xs[i]) / h, t2 = t * t, t3 = t2 * t
        return (2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h * ms[i]
             + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h * ms[i + 1]
    }
}

enum FlowMath {
    static let count = 201
    static let drs: [(Double, Double)] = [(0.0, 0.07), (0.49, 0.55), (0.89, 1.0)]

    static func anchors(_ p: GPProfile, circuitLength: Double) -> [(Double, Double)] {
        let top = p.top, s = top / 342, k = p.cornerK
        func r(_ v: Double) -> Double { min(v * s, top - 4) }
        func a(_ v: Double) -> Double { v * k }
        let len = max(circuitLength, 1)
        return [
            (0.000, top - 10), (0.035, top - 3), (0.070, top), (0.092, r(300)), (0.106, r(170)),
            (0.120, a(118)), (0.146, r(190)), (0.176, r(255)), (0.198, r(262)), (0.215, r(205)),
            (0.230, a(164)), (0.262, r(236)), (0.300, r(292)), (0.322, r(205)), (0.340, a(96)),
            (0.366, r(172)), (0.402, r(272)), (0.440, r(302)), (0.456, r(215)), (0.470, a(142)),
            (0.500, r(250)), (0.525, r(316)), (0.548, r(332)), (0.565, r(322)), (0.581, p.t11Brake),
            (0.620, p.t11Apex), (0.647, p.t11Exit), (0.668, r(215)), (0.695, a(118)), (0.705, p.t12Exit),
            (0.705 + 50 / len, p.t12p50), (0.705 + 100 / len, p.t12p100),
            (0.760, r(285)), (0.800, r(308)), (0.822, r(316)), (0.842, r(228)), (0.858, a(205)),
            (0.890, r(290)), (0.925, r(332)), (0.955, top), (1.000, top - 10)
        ]
    }

    static func speedSeries(_ p: GPProfile, circuitLength: Double) -> [Double] {
        let f = MonoCubic(anchors(p, circuitLength: circuitLength))
        return (0..<count).map { f.value(Double($0) / Double(count - 1)) }
    }

    static func smooth(_ a: [Double], window: Int = 2) -> [Double] {
        a.indices.map { i in
            let lo = max(0, i - window), hi = min(a.count - 1, i + window)
            return a[lo...hi].reduce(0, +) / Double(hi - lo + 1)
        }
    }

    static func brake(_ s: [Double]) -> [Double] {
        var out = [Double](repeating: 0, count: s.count)
        for i in 1..<s.count { out[i] = min(100, max(0, (s[i - 1] - s[i]) * 3.5)) }
        return smooth(out)
    }

    static func series(_ m: FlowMetric, speed s: [Double], drsDelay: Double) -> [Double] {
        switch m {
        case .speed: return s
        case .brake: return brake(s)
        case .throttle:
            let b = brake(s)
            return smooth(s.indices.map { i in
                let base = max(0, 100 - b[i] * 1.3)
                return s[i] < 130 ? base * 0.62 : base
            })
        case .drs:
            return smooth((0..<count).map { i in
                let t = Double(i) / Double(count - 1)
                return drs.contains { t >= $0.0 + drsDelay && t <= $0.1 } ? 100 : 0
            })
        }
    }

    static func time(_ s: [Double], lap: Double, length: Double) -> [Double] {
        let ds = length / Double(s.count - 1)
        var raw = [Double](repeating: 0, count: s.count)
        for i in 1..<s.count { raw[i] = raw[i - 1] + ds / (max((s[i] + s[i - 1]) / 2, 30) / 3.6) }
        let k = lap / raw[s.count - 1]
        return raw.map { $0 * k }
    }
}

/// Everything is computed once, when the matchup is created.
struct Matchup: Equatable {
    let id = UUID()
    let circuit: GPCircuit
    let a: GPDriver, b: GPDriver
    let colorA: Color, colorB: Color
    let pa: GPProfile, pb: GPProfile
    private let cache: [FlowMetric: [[Double]]]
    private let times: [[Double]]

    static func == (l: Matchup, r: Matchup) -> Bool { l.id == r.id }

    init(circuit: GPCircuit, a: GPDriver, b: GPDriver) {
        self.circuit = circuit; self.a = a; self.b = b
        colorA = a.color
        colorB = a.team == b.team ? Color(hex: "C040FF") : b.color
        let profA = GPProfile.make(a), profB = GPProfile.make(b)
        pa = profA; pb = profB
        let sa = FlowMath.speedSeries(profA, circuitLength: circuit.lengthM)
        let sb = FlowMath.speedSeries(profB, circuitLength: circuit.lengthM)
        cache = Dictionary(uniqueKeysWithValues: FlowMetric.allCases.map {
            ($0, [FlowMath.series($0, speed: sa, drsDelay: 0), FlowMath.series($0, speed: sb, drsDelay: 0.006)])
        })
        times = [FlowMath.time(sa, lap: profA.lap, length: circuit.lengthM),
                 FlowMath.time(sb, lap: profB.lap, length: circuit.lengthM)]
    }

    func series(_ m: FlowMetric, _ i: Int) -> [Double] { cache[m]?[i] ?? [] }
    func color(_ i: Int) -> Color { i == 0 ? colorA : colorB }
    func driver(_ i: Int) -> GPDriver { i == 0 ? a : b }
    func profile(_ i: Int) -> GPProfile { i == 0 ? pa : pb }
    func time(_ i: Int, _ t: Double) -> Double { flowValue(times[i], t) }

    var winner: Int { pa.lap <= pb.lap ? 0 : 1 }
    var gap: Double { abs(pa.lap - pb.lap) }

    func lapString(_ i: Int) -> String {
        let l = profile(i).lap
        let m = Int(l) / 60
        return String(format: "%d:%06.3f", m, l - Double(m * 60))
    }

    func sectorTime(_ i: Int, _ s: Int) -> Double { time(i, Double(s + 1) / 3) - time(i, Double(s) / 3) }
}

// MARK: - 4. TELEMETRY FLOW

enum TelemetryStep: Equatable {
    case circuit, drivers, versus, results
    case moment(FlowMoment)
}

/// Lives in RootTabView so switching tabs never loses your place.
@Observable
final class TelemetryModel {
    var step: TelemetryStep = .circuit
    var circuit: GPCircuit = GPCircuit.all[0]
    var you: GPDriver?
    var rival: GPDriver?
    var matchup: Matchup?

    func startCompare() {
        guard let y = you, let r = rival else { return }
        matchup = Matchup(circuit: circuit, a: y, b: r)
        step = .versus
    }

    /// Jump straight to a ready-made comparison (used by the Home shortcut).
    func open(_ m: Matchup) {
        circuit = m.circuit
        you = m.a
        rival = m.b
        matchup = m
        step = .results
    }
}

struct TelemetryFlowView: View {
    @Bindable var model: TelemetryModel

    var body: some View {
        ZStack {
            Backdrop()
            switch model.step {
            case .circuit:
                CircuitSelectView { model.circuit = $0; model.step = .drivers }.flowTransition()
            case .drivers:
                DriverSelectView(circuit: model.circuit, you: $model.you, rival: $model.rival,
                                 onBack: { model.step = .circuit },
                                 onCompare: { model.startCompare() }).flowTransition()
            case .versus:
                if let m = model.matchup { VersusLoadingView(matchup: m) { model.step = .results }.flowTransition() }
            case .results:
                if let m = model.matchup {
                    FlowResultsView(m: m, onBack: { model.step = .drivers },
                                    onMoment: { model.step = .moment($0) }).flowTransition()
                }
            case .moment(let kind):
                if let m = model.matchup { momentScreen(kind, m).flowTransition() }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.88), value: model.step)
    }

    @ViewBuilder
    private func momentScreen(_ kind: FlowMoment, _ m: Matchup) -> some View {
        switch kind {
        case .straight: StraightMomentView(m: m, onBack: { model.step = .results }, onNext: { model.step = .moment(.turn11) })
        case .turn11:   TurnElevenView(m: m, onBack: { model.step = .results }, onNext: { model.step = .moment(.turn12) })
        case .turn12:   TurnTwelveView(m: m, onBack: { model.step = .results }, onNext: { model.step = .results })
        }
    }
}

// MARK: 4.1 Circuit select

struct CircuitShape: Shape {
    let pts: [CGPoint]
    func path(in rect: CGRect) -> Path {
        let p = pts.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        let n = p.count
        var path = Path()
        guard n > 3 else { return path }
        path.move(to: p[0])
        for i in 0..<n {
            let p0 = p[(i - 1 + n) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n]
            path.addCurve(to: p2,
                          control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                          control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
        }
        path.closeSubpath()
        return path
    }
}

struct CircuitSelectView: View {
    let onSelect: (GPCircuit) -> Void
    @State private var query = ""
    @State private var appeared = false

    private var filtered: [GPCircuit] {
        query.isEmpty ? GPCircuit.all : GPCircuit.all.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.place.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(eyebrow: "TELEMETRY", title: "SELECT CIRCUIT",
                            subtitle: "2025 FIA Formula One World Championship").reveal(appeared, 0)
                CapsuleSearchField(prompt: "Search circuits or Grand Prix", text: $query).reveal(appeared, 1)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { i, c in
                        HButton(action: { onSelect(c) }) { CircuitCard(circuit: c) }
                            .buttonStyle(PressStyle())
                            .reveal(appeared, i + 2)
                    }
                }

                if filtered.isEmpty {
                    Text("No circuits found. Try another search 🫠")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(F1.muted)
                        .frame(maxWidth: .infinity).padding(.top, 30)
                }
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

/// Drawn once with Canvas instead of 16 separate blurred views.
struct BokehLayer: View {
    let seed: Int
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            for i in 0..<16 {
                let x = flowRand(seed, i * 3) * size.width
                let y = flowRand(seed, i * 3 + 1) * size.height
                let s = 3 + flowRand(seed, i * 3 + 2) * 9
                let c: Color = i % 3 == 0 ? .white : (i % 3 == 1 ? color : Color(hex: "FFB347"))
                ctx.fill(Path(ellipseIn: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                         with: .color(c.opacity(0.25 + flowRand(seed, i + 40) * 0.4)))
            }
        }
        .blur(radius: 1.5)
    }
}

struct CircuitCard: View {
    let circuit: GPCircuit

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [circuit.tint.opacity(0.55), Color(hex: "0B0A10")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            BokehLayer(seed: circuit.name.count * 7, color: circuit.tint)

            CircuitShape(pts: circuit.pts)
                .stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .shadow(color: .white.opacity(0.5), radius: 4)
                .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 44)

            LinearGradient(colors: [.black.opacity(0.75), .clear], startPoint: .bottom, endPoint: .center)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(circuit.name).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Text(circuit.place).font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 20, height: 20).background(.white.opacity(0.15), in: Circle())
            }
            .padding(10)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.14), lineWidth: 1))
        .drawingGroup()
    }
}

// MARK: 4.2 Driver select

struct DriverSelectView: View {
    let circuit: GPCircuit
    @Binding var you: GPDriver?
    @Binding var rival: GPDriver?
    let onBack: () -> Void
    let onCompare: () -> Void

    @State private var query = ""
    @State private var teamFilter: String?
    @State private var appeared = false

    private var filtered: [GPDriver] {
        GPDriver.roster.filter { d in
            (teamFilter == nil || d.team == teamFilter) &&
            (query.isEmpty || d.full.localizedCaseInsensitiveContains(query) || d.team.localizedCaseInsensitiveContains(query))
        }
    }
    private var canCompare: Bool { you != nil && rival != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header.reveal(appeared, 0)
                searchRow.reveal(appeared, 1)
                slots.reveal(appeared, 2)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { i, d in
                        HButton(feedback: .impact(weight: .light), action: { tap(d) }) { driverCard(d) }
                            .buttonStyle(PressStyle())
                            .reveal(appeared, i / 2 + 3)
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { cta }
        .onAppear { appeared = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                    Text("CIRCUITS").font(.system(size: 12, weight: .black)).tracking(1)
                }.foregroundStyle(F1.red)
            }.buttonStyle(.plain)

            Text("CHOOSE YOUR DRIVER").font(.system(size: 28, weight: .black)).foregroundStyle(.white)
            Text("Pick your main character, then your rival. We'll pull the receipts 🧾")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(F1.muted)

            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 9, weight: .bold))
                Text(circuit.name.uppercased()).font(.system(size: 9, weight: .black)).tracking(0.8)
            }
            .foregroundStyle(circuit.tint)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(circuit.tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(circuit.tint.opacity(0.4), lineWidth: 1))
        }
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            CapsuleSearchField(prompt: "Search drivers...", text: $query)
            Menu {
                Button("All teams") { teamFilter = nil }
                ForEach(GPDriver.teams, id: \.self) { t in Button(t) { teamFilter = t } }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease").font(.system(size: 12, weight: .bold))
                    Text(teamFilter ?? "Filter").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                }
                .foregroundStyle(teamFilter == nil ? .white : F1.red)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(F1.surface, in: Capsule())
                .overlay(Capsule().stroke(teamFilter == nil ? .white.opacity(0.1) : F1.red.opacity(0.6), lineWidth: 1))
            }
        }
    }

    private var slots: some View {
        HStack(spacing: 8) {
            slot(title: "You", tint: F1.red, driver: you) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { you = nil }
            }
            HButton(feedback: .impact(weight: .light), action: {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { swap(&you, &rival) }
            }) {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(F1.muted).frame(width: 30, height: 30)
                    .background(F1.surface, in: Circle()).overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
            slot(title: "Rival", tint: F1.purple, driver: rival) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { rival = nil }
            }
        }
    }

    private func slot(title: String, tint: Color, driver: GPDriver?, onClear: @escaping () -> Void) -> some View {
        Button(action: onClear) {
            HStack(spacing: 8) {
                if let d = driver {
                    SafePhoto(asset: d.asset).frame(width: 32, height: 32)
                        .background(d.color.opacity(0.3)).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title.uppercased()).font(.system(size: 8, weight: .black)).tracking(1).foregroundStyle(tint)
                        Text(d.full).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(d.team).font(.system(size: 8, weight: .medium)).foregroundStyle(F1.muted)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
                        Text("Select driver").font(.system(size: 10, weight: .medium)).foregroundStyle(F1.muted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(tint.opacity(driver == nil ? 0.06 : 0.14), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if driver == nil {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(tint.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                } else {
                    RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.7), lineWidth: 1.2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func tap(_ d: GPDriver) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if you?.id == d.id { you = nil }
            else if rival?.id == d.id { rival = nil }
            else if you == nil { you = d }
            else { rival = d }
        }
    }

    @ViewBuilder
    private func driverCard(_ d: GPDriver) -> some View {
        let isYou = you?.id == d.id
        let picked = isYou || rival?.id == d.id
        let ring: Color = isYou ? F1.red : F1.purple

        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [d.color.opacity(0.6), d.color.opacity(0.14), F1.surface],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(d.number).font(.system(size: 82, weight: .black, design: .rounded))
                .foregroundStyle(d.color.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 8).offset(y: -6)
            SafePhoto(asset: d.asset).frame(width: 112, height: 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .bottom, endPoint: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(d.full).font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    Circle().fill(d.color).frame(width: 5, height: 5)
                    Text(d.team).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                }
            }.padding(10)

            VStack {
                if picked {
                    Text(isYou ? "YOU" : "RIVAL").font(.system(size: 8, weight: .black)).tracking(0.8)
                        .foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(ring, in: Capsule()).shadow(color: ring.opacity(0.7), radius: 6)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                Image(systemName: picked ? "checkmark" : "chevron.right").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white).frame(width: 22, height: 22)
                    .background(picked ? ring : Color.white.opacity(0.18), in: Circle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(8)
        }
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(picked ? ring : Color.white.opacity(0.1), lineWidth: picked ? 2.5 : 1)
        }
        .shadow(color: picked ? ring.opacity(0.45) : .clear, radius: 14, y: 6)
    }

    private var cta: some View {
        HButton(feedback: .success, action: { if canCompare { onCompare() } }) {
            HStack(spacing: 8) {
                if canCompare { Image(systemName: "bolt.fill").font(.system(size: 13, weight: .bold)) }
                Text(ctaText).font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(canCompare ? .white : F1.muted)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background {
                if canCompare {
                    Capsule().fill(F1.redGradient).shadow(color: F1.red.opacity(0.6), radius: 14, y: 4)
                } else { Capsule().fill(F1.surfaceHi) }
            }
        }
        .buttonStyle(PressStyle())
        .disabled(!canCompare)
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 4)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: canCompare)
    }

    private var ctaText: String {
        if let y = you, let r = rival { return "Compare \(y.last) vs \(r.last)" }
        return "Compare [You] vs [Rival]"
    }
}

// MARK: 4.3 Versus loader

struct VersusLoadingView: View {
    let matchup: Matchup
    let onDone: () -> Void

    @State private var enter = false
    @State private var progress: CGFloat = 0
    @State private var lineIndex = 0
    @State private var finished = false

    private let lines = ["pulling the telemetry...", "checking who braked late 👀",
                         "cooking the graphs 🍳", "almost there..."]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            Text("F1 COMPANION").font(.system(size: 9, weight: .bold)).tracking(3).foregroundStyle(F1.muted)
            Spacer(minLength: 10)

            ZStack {
                HStack(spacing: 6) {
                    side(matchup.a, matchup.colorA, fromLeft: true)
                    side(matchup.b, matchup.colorB, fromLeft: false)
                }
                Text("VS").font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                    .frame(width: 46, height: 46).background(F1.red, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 2))
                    .shadow(color: F1.red.opacity(0.8), radius: 14)
                    .scaleEffect(enter ? 1 : 0.2).opacity(enter ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.35), value: enter)
            }

            Spacer(minLength: 20)

            Text("LET'S SEE HOW\nTHEY DROVE.")
                .font(.system(size: 30, weight: .black)).tracking(0.5).multilineTextAlignment(.center)
                .foregroundStyle(F1.fadeWhite)
                .opacity(enter ? 1 : 0).offset(y: enter ? 0 : 16)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: enter)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(LinearGradient(colors: [F1.red, F1.mclaren], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                        .shadow(color: F1.red.opacity(0.8), radius: 6)
                }
            }
            .frame(height: 5).padding(.horizontal, 40).padding(.top, 22)

            Text(lines[lineIndex])
                .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(F1.muted)
                .id(lineIndex).transition(.opacity.combined(with: .move(edge: .bottom))).padding(.top, 12)

            Spacer(minLength: 30)
            Text("tap to skip").font(.system(size: 9, weight: .medium))
                .foregroundStyle(F1.muted.opacity(0.6)).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onDone() }
        .sensoryFeedback(.success, trigger: finished)
        .task {
            withAnimation(.easeOut(duration: 0.7)) { enter = true }
            withAnimation(.linear(duration: 3.0)) { progress = 1 }
            for i in 1..<lines.count {
                try? await Task.sleep(for: .milliseconds(750))
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.25)) { lineIndex = i }
            }
            try? await Task.sleep(for: .milliseconds(700))
            if Task.isCancelled { return }
            finished = true
            onDone()
        }
    }

    private func side(_ d: GPDriver, _ color: Color, fromLeft: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                Capsule().fill(color.opacity(0.16)).overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1.5))
                Text(d.number).font(.system(size: 110, weight: .black, design: .rounded))
                    .foregroundStyle(color.opacity(0.45))
                    .frame(maxHeight: .infinity, alignment: .top).padding(.top, 20)
                SafePhoto(asset: d.asset).frame(width: 150, height: 230).clipShape(Capsule())
            }
            .frame(width: 150, height: 270)
            .shadow(color: color.opacity(0.5), radius: 18)

            VStack(spacing: 2) {
                Text(d.last).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                Text(d.team).font(.system(size: 9, weight: .medium)).foregroundStyle(F1.muted)
            }
        }
        .offset(x: enter ? 0 : (fromLeft ? -240 : 240))
        .opacity(enter ? 1 : 0)
        .animation(.spring(response: 0.7, dampingFraction: 0.75), value: enter)
    }
}

// MARK: 4.4 Results

struct FlowResultsView: View {
    let m: Matchup
    let onBack: () -> Void
    let onMoment: (FlowMoment) -> Void

    @State private var metric: FlowMetric = .speed
    @State private var scrub: Double = 0.62
    @State private var appeared = false
    @Namespace private var tabNS

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header.reveal(appeared, 0)
                driverComparison.reveal(appeared, 1)
                traceCard.reveal(appeared, 2)
                keyMoments.reveal(appeared, 3)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                    Text("DRIVERS").font(.system(size: 12, weight: .black)).tracking(1)
                }.foregroundStyle(F1.red)
            }.buttonStyle(.plain)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Circle().fill(F1.red).frame(width: 6, height: 6).shadow(color: F1.red, radius: 4).pulse()
                        Text("\(m.circuit.name.uppercased())  •  QUALI")
                            .font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(F1.red)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Text("TELEMETRY").font(.system(size: 38, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.5)],
                                                        startPoint: .top, endPoint: .bottom))
                }
                Spacer()
                Text("Q3").font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(F1.redGradient, in: Capsule())
                    .shadow(color: F1.red.opacity(0.55), radius: 10, y: 3)
            }
        }
    }

    private var driverComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("COMPARING DRIVERS")
                Spacer()
                Text("\(m.driver(m.winner).id) +\(String(format: "%.3f", m.gap))s 🏆")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(F1.yellow)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(F1.yellow.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(F1.yellow.opacity(0.4), lineWidth: 1))
            }
            ZStack {
                HStack(spacing: 10) { driverCard(0); driverCard(1) }
                Text("VS").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                    .frame(width: 32, height: 32).background(F1.background, in: Circle())
                    .overlay(Circle().stroke(F1.red, lineWidth: 2)).shadow(color: F1.red.opacity(0.6), radius: 8)
            }
        }
    }

    private func driverCard(_ i: Int) -> some View {
        let d = m.driver(i), color = m.color(i), isWinner = m.winner == i

        return ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [color, color.opacity(0.5), F1.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .center)
            Text(d.number).font(.system(size: 130, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.10))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).offset(x: 12, y: 20)
            SafePhoto(asset: d.asset).frame(width: 155, height: 215)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            LinearGradient(colors: [.black.opacity(0.75), .clear], startPoint: .bottom, endPoint: .center)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(isWinner ? "1" : "2").font(.system(size: 34, weight: .black))
                        Text(isWinner ? "ST" : "ND").font(.system(size: 11, weight: .black))
                    }
                    .foregroundStyle(.white).shadow(color: .black.opacity(0.35), radius: 4)
                    Spacer()
                    Image(systemName: i == 0 ? "person.fill" : "flame.fill").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white).frame(width: 24, height: 24).background(.black.opacity(0.35), in: Circle())
                }
                Spacer(minLength: 8)
                Text(d.first).font(.system(size: 12)).foregroundStyle(.white.opacity(0.9))
                Text(d.last).font(.system(size: 18, weight: .heavy)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(d.team).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                }.padding(.top, 3)
                Text(m.lapString(i)).font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 5).background(.black.opacity(0.4), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1)).padding(.top, 8)
            }.padding(12)
        }
        .frame(maxWidth: .infinity).frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .shadow(color: color.opacity(0.35), radius: 18, y: 10)
    }

    private var traceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            metricTabs

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(metric.rawValue.uppercased()) TRACE").font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                    Text("Drag to scrub the lap").font(.system(size: 9, weight: .medium)).foregroundStyle(F1.muted)
                }
                Spacer()
                HStack(spacing: 12) {
                    LegendDot(color: m.colorA, name: m.a.id)
                    LegendDot(color: m.colorB, name: m.b.id)
                }
            }

            FlowTraceGraph(m: m, metric: metric, scrub: $scrub).id(metric).frame(height: 250)

            Text(metric.blurb).font(.system(size: 10, weight: .medium)).foregroundStyle(F1.muted)
                .fixedSize(horizontal: false, vertical: true).padding(.top, -5)

            HStack {
                Text("0 m"); Spacer()
                Text("\(Int(m.circuit.lengthM / 2)) m"); Spacer()
                Text("\(Int(m.circuit.lengthM)) m")
            }
            .font(.system(size: 8, weight: .bold)).foregroundStyle(F1.muted)

            HStack(spacing: 8) {
                ForEach(FlowMoment.allCases) { k in
                    HButton(feedback: .selection, action: {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { scrub = k.scrubT }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: k.icon).font(.system(size: 10, weight: .bold))
                            Text(k.title).font(.system(size: 10, weight: .bold)).lineLimit(1)
                        }
                        .foregroundStyle(k.accent).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(k.accent.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(k.accent.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                sectorChip("LAP", m.pa.lap - m.pb.lap)
                ForEach(0..<3, id: \.self) { s in
                    sectorChip("S\(s + 1)", m.sectorTime(0, s) - m.sectorTime(1, s))
                }
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [F1.surfaceHi, F1.surface], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(LinearGradient(colors: [m.colorA.opacity(0.55), m.colorB.opacity(0.55)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }

    private var metricTabs: some View {
        HStack(spacing: 4) {
            ForEach(FlowMetric.allCases) { k in
                HButton(feedback: .selection, action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { metric = k }
                }) {
                    Text(k.rawValue).font(.system(size: 13, weight: .bold))
                        .foregroundStyle(metric == k ? .white : F1.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background {
                            if metric == k {
                                Capsule().fill(F1.redGradient).shadow(color: F1.red.opacity(0.5), radius: 8, y: 2)
                                    .matchedGeometryEffect(id: "tab", in: tabNS)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(F1.background.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
    }

    /// delta = You − Rival. Negative = you were quicker.
    private func sectorChip(_ label: String, _ delta: Double) -> some View {
        let zero = abs(delta) < 0.0005
        let color: Color = zero ? .white : (delta < 0 ? F1.green : F1.yellow)
        let text = zero ? "0.000" : String(format: "%@%.3f", delta < 0 ? "−" : "+", abs(delta))

        return VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 8, weight: .black)).foregroundStyle(F1.muted)
            Text("Δ vs rival").font(.system(size: 7, weight: .medium)).foregroundStyle(F1.muted.opacity(0.8))
            Text(text).font(.system(size: 11, weight: .heavy, design: .monospaced)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        .background(F1.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25), lineWidth: 1))
    }

    private var keyMoments: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle("KEY MOMENTS")
                Spacer()
                Text("Tap for the tea ☕").font(.system(size: 11, weight: .semibold)).foregroundStyle(F1.muted)
            }
            HStack(spacing: 10) {
                ForEach(FlowMoment.allCases) { k in
                    HButton(action: { onMoment(k) }) { momentTile(k) }.buttonStyle(PressStyle())
                }
            }
        }
    }

    private func tileDetail(_ k: FlowMoment) -> String {
        switch k {
        case .straight: "Top speed\n\(Int(max(m.pa.top, m.pb.top))) km/h"
        case .turn11:   "Apex speed\n\(Int(max(m.pa.t11Apex, m.pb.t11Apex))) km/h"
        case .turn12:   "Fastest\nacceleration"
        }
    }

    private func momentTile(_ k: FlowMoment) -> some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(colors: [k.accent.opacity(0.22), F1.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(k.accent).frame(width: 64, height: 64).blur(radius: 24).offset(x: 18, y: 18)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: k.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(k.accent)
                        .frame(width: 36, height: 36)
                        .background(k.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 14)
                Text(k.title).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.8).multilineTextAlignment(.leading)
                Text(tileDetail(k)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading).padding(.top, 3)
            }
            .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 156)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(k.accent.opacity(0.35), lineWidth: 1))
    }
}

// MARK: trace graph (static layers are split out so scrubbing doesn't redraw them)

struct FGeo: Equatable {
    let w: CGFloat, h: CGFloat, top: CGFloat
    var plotH: CGFloat { h - top }
    func x(_ t: Double) -> CGFloat { w * CGFloat(t) }
    func y(_ v: Double, _ r: ClosedRange<Double>) -> CGFloat {
        top + plotH * (1 - CGFloat((v - r.lowerBound) / (r.upperBound - r.lowerBound)))
    }
}

/// Grid + DRS zones + lines. Only redraws when the matchup, metric, size or draw-in progress changes.
struct TraceStaticLayer: View, Equatable {
    let m: Matchup
    let metric: FlowMetric
    let g: FGeo
    let progress: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            grid
            zones
            lines
        }
        .frame(width: g.w, height: g.h)
    }

    private var grid: some View {
        Path { p in
            for i in 0..<5 {
                let yy = g.top + g.plotH * CGFloat(i) / 4
                p.move(to: CGPoint(x: 0, y: yy)); p.addLine(to: CGPoint(x: g.w, y: yy))
            }
        }
        .stroke(.white.opacity(0.07), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
    }

    @ViewBuilder
    private var zones: some View {
        if metric == .speed {
            ForEach(0..<FlowMath.drs.count, id: \.self) { i in
                let z = FlowMath.drs[i]
                Rectangle()
                    .fill(LinearGradient(colors: [F1.green.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: g.x(z.1) - g.x(z.0), height: g.plotH)
                    .position(x: (g.x(z.0) + g.x(z.1)) / 2, y: g.top + g.plotH / 2)
                Text("DRS").font(.system(size: 7, weight: .black)).foregroundStyle(F1.green.opacity(0.9))
                    .position(x: (g.x(z.0) + g.x(z.1)) / 2, y: g.top + 9)
            }
        }
        Path { p in
            for i in 1..<3 {
                let xx = g.x(Double(i) / 3)
                p.move(to: CGPoint(x: xx, y: g.top)); p.addLine(to: CGPoint(x: xx, y: g.h))
            }
        }
        .stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))

        ForEach(0..<3, id: \.self) { i in
            Text("S\(i + 1)").font(.system(size: 8, weight: .black)).foregroundStyle(.white.opacity(0.35))
                .position(x: g.x((Double(i) + 0.5) / 3), y: g.h - 8)
        }
    }

    private func path(_ data: [Double], closed: Bool) -> Path {
        let n = data.count, r = metric.yRange
        return Path { p in
            for i in 0..<n {
                let pt = CGPoint(x: g.x(Double(i) / Double(n - 1)), y: g.y(data[i], r))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            if closed {
                p.addLine(to: CGPoint(x: g.x(1), y: g.h)); p.addLine(to: CGPoint(x: g.x(0), y: g.h)); p.closeSubpath()
            }
        }
    }

    @ViewBuilder
    private var lines: some View {
        let sa = m.series(metric, 0), sb = m.series(metric, 1)
        let style = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)

        path(sb, closed: true)
            .fill(LinearGradient(colors: [m.colorB.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
            .opacity(Double(progress))
        path(sa, closed: true)
            .fill(LinearGradient(colors: [m.colorA.opacity(0.30), .clear], startPoint: .top, endPoint: .bottom))
            .opacity(Double(progress))
        path(sb, closed: false).trim(from: 0, to: progress).stroke(m.colorB, style: style)
            .shadow(color: m.colorB.opacity(0.7), radius: 6)
        path(sa, closed: false).trim(from: 0, to: progress).stroke(m.colorA, style: style)
            .shadow(color: m.colorA.opacity(0.7), radius: 6)
    }
}

struct FlowTraceGraph: View {
    let m: Matchup
    let metric: FlowMetric
    @Binding var scrub: Double
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let g = FGeo(w: geo.size.width, h: geo.size.height, top: 56)
            ZStack(alignment: .topLeading) {
                TraceStaticLayer(m: m, metric: metric, g: g, progress: progress).equatable()
                scrubLayer(g)
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                        scrub = Double(min(max(v.location.x / g.w, 0), 1))
                    })
            }
            .frame(width: g.w, height: g.h)
        }
        .onAppear {
            progress = 0
            withAnimation(.easeOut(duration: 1.3)) { progress = 1 }
        }
    }

    @ViewBuilder
    private func scrubLayer(_ g: FGeo) -> some View {
        let r = metric.yRange
        let va = flowValue(m.series(metric, 0), scrub)
        let vb = flowValue(m.series(metric, 1), scrub)
        let sx = g.x(scrub)
        let tx = min(max(sx, 82), max(g.w - 82, 82))

        Rectangle()
            .fill(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
            .frame(width: 1.5, height: g.plotH + 4)
            .position(x: sx, y: g.top + g.plotH / 2 - 2)

        dot(m.colorB).position(x: sx, y: g.y(vb, r))
        dot(m.colorA).position(x: sx, y: g.y(va, r))
        tooltip(dist: m.circuit.lengthM * scrub, a: va, b: vb).position(x: tx, y: 24)
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(.white).frame(width: 10, height: 10)
            .overlay(Circle().stroke(color, lineWidth: 2.5)).shadow(color: color.opacity(0.9), radius: 6)
    }

    private func tooltip(dist: Double, a: Double, b: Double) -> some View {
        HStack(spacing: 14) {
            tipCol("DIST", "\(Int(dist)) m", .white)
            tipCol(m.a.id, String(format: "%.0f", a), m.colorA)
            tipCol(m.b.id, String(format: "%.0f", b), m.colorB)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.18), lineWidth: 1))
        .frame(width: 164)
    }

    private func tipCol(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(title).font(.system(size: 7, weight: .bold)).foregroundStyle(F1.muted)
            Text(value).font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

// MARK: 4.5 Moment screens – shared pieces

struct MomentHeader: View {
    let title: String
    let subtitle: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HButton(feedback: .impact(weight: .light), action: onBack) {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(F1.surfaceHi, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(PressStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 11, weight: .medium)).foregroundStyle(F1.muted)
            }
            Spacer()
        }
    }
}

struct MomentEyebrow: View {
    let title: String
    var desc: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RACE MOMENT BREAKDOWN").font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2).foregroundStyle(F1.red)
            Text(title).font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
            if let desc { Text(desc).font(.system(size: 12)).foregroundStyle(F1.muted) }
        }.padding(.top, 6)
    }
}

struct InsightCard: View {
    let title: String
    let text: String
    let start: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 11, weight: .bold)).foregroundStyle(F1.red)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            TypewriterText(text: text, start: start.addingTimeInterval(0.5))
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7)).lineSpacing(3)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).flowCard()
    }
}

struct ChequerEdge: View {
    var body: some View {
        Canvas { ctx, size in
            let cell: CGFloat = 6
            let rows = max(Int(size.height / cell), 2)
            let cw = size.width / 2, ch = size.height / CGFloat(rows)
            for r in 0..<rows { for c in 0..<2 {
                ctx.fill(Path(CGRect(x: CGFloat(c) * cw, y: CGFloat(r) * ch, width: cw, height: ch)),
                         with: .color((r + c) % 2 == 0 ? .white : .black))
            } }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

/// Shared "Braking / Apex / Exit" style card (Turn 11 + Turn 12).
struct CompareStatCard: View {
    let m: Matchup
    let title: String
    let a: Double
    let b: Double
    var selected = false
    let active: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            NameDot(color: m.colorA, name: m.a.last)
            value(a, m.colorA)
            NameDot(color: m.colorB, name: m.b.last).padding(.top, 2)
            value(b, m.colorB)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .flowCard(radius: 16, stroke: active ? F1.purple : nil)
        .overlay(alignment: .top) {
            if selected {
                Capsule().fill(F1.purple).frame(width: 34, height: 3)
                    .shadow(color: F1.purple, radius: 4).offset(y: -1)
            }
        }
        .scaleEffect(active ? 1.04 : 1)
        .shadow(color: active ? F1.purple.opacity(0.5) : .clear, radius: 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: active)
    }

    private func value(_ v: Double, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            CountUp(to: v, delay: 0.2).font(.system(size: 28, weight: .bold)).foregroundStyle(color)
            Text("km/h").font(.system(size: 8)).foregroundStyle(F1.muted)
        }
    }
}

struct DriverLegendRow: View {
    let m: Matchup
    var body: some View {
        HStack {
            NameDot(color: m.colorA, name: m.a.full)
            Spacer()
            NameDot(color: m.colorB, name: m.b.full)
        }
    }
}

struct SlowMoNote: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 8, weight: .medium)).foregroundStyle(F1.muted.opacity(0.7))
    }
}

// MARK: Main straight

struct StraightMomentView: View {
    let m: Matchup
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var start = Date()

    private var lead: Int { m.pa.top >= m.pb.top ? 0 : 1 }
    private var diff: Double { abs(m.pa.top - m.pb.top) }

    private var insightText: String {
        if diff < 0.5 {
            return "Both drivers topped out at the same speed on the main straight.\nIt will come down to the braking zone."
        }
        return "\(m.driver(lead).first) reached a higher top speed on the main straight by \(Int(diff.rounded()))km/h.\nA higher top speed can help with overtaking and give advantage into next turn."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                MomentHeader(title: "Main Straight", subtitle: "Lap 24 · Speed Analysis", onBack: onBack)
                MomentEyebrow(title: "Speed Showdown", desc: "Compare both drivers' speed on the main straight.")
                HStack(spacing: 12) { speedCard(0); speedCard(1) }
                stripCard
                diffCard
                InsightCard(title: "What the data shows", text: insightText, start: start)
                RedPillButton(label: "Next · Turn 11", action: onNext).padding(.top, 4)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
        .onAppear { start = Date() }
    }

    private func speedCard(_ i: Int) -> some View {
        let color = m.color(i)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(m.driver(i).full).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                CountUp(to: m.profile(i).top, delay: 0.15 * Double(i))
                    .font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
                Text("km/h").font(.system(size: 11)).foregroundStyle(F1.muted)
            }
            Text("Top Speed").font(.system(size: 10)).foregroundStyle(F1.muted).padding(.top, 2)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.45), lineWidth: 1))
        .overlay(alignment: .topLeading) {
            Capsule().fill(color).frame(width: 38, height: 3)
                .shadow(color: color.opacity(0.8), radius: 4).padding(.leading, 14)
        }
    }

    private var stripCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Main Straight").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                ReplayButton { start = Date() }
                Text("200 m").font(.system(size: 13)).foregroundStyle(F1.muted).padding(.leading, 6)
            }
            AnimClock(start: start, cycle: 5.5) { stripCanvas($0) }.frame(height: 96)
            HStack {
                Text("Start / finish"); Spacer()
                Text("Selected section").foregroundStyle(F1.purple)
            }
            .font(.system(size: 11, weight: .medium)).foregroundStyle(F1.muted)
            SlowMoNote(text: "Slow-mo race · gap exaggerated for clarity")
        }
        .padding(16).flowCard()
    }

    private func stripCanvas(_ phase: Double) -> some View {
        let tops = [m.pa.top, m.pb.top]
        let maxTop = max(tops[0], tops[1])

        return GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let pulse = 0.5 + 0.5 * sin(phase * 4)

            ZStack(alignment: .topLeading) {
                ChequerEdge().frame(width: 8, height: h).position(x: 4, y: h / 2)
                ChequerEdge().frame(width: 8, height: h).position(x: w - 4, y: h / 2)

                RoundedRectangle(cornerRadius: 12)
                    .fill(F1.purple.opacity(0.14 + 0.12 * pulse))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(F1.purple.opacity(0.8), lineWidth: 1.2))
                    .shadow(color: F1.purple.opacity(0.5 * pulse), radius: 10)
                    .frame(width: w * 0.15, height: h * 0.82).position(x: w / 2, y: h / 2)

                ForEach(0..<2, id: \.self) { i in
                    let color = m.color(i)
                    let y = h * (i == 0 ? 0.38 : 0.64)
                    let p = flowEase(phase / (2.8 + (maxTop - tops[i]) * 0.12))
                    let x = 16 + (w - 32) * p

                    Capsule().fill(color.opacity(0.35)).frame(width: w - 32, height: 2).position(x: w / 2, y: y)
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, x - 16), height: 4).position(x: 16 + max(2, x - 16) / 2, y: y)
                    Circle().fill(color).frame(width: 13, height: 13)
                        .overlay(Circle().stroke(.white, lineWidth: 2)).shadow(color: color, radius: 8).position(x: x, y: y)

                    if p >= 1 && i == lead {
                        Text("🏁").font(.system(size: 14)).position(x: w - 22, y: y - 16)
                    }
                }
            }
        }
    }

    private var diffCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SPEED DIFFERENCE").font(.system(size: 10, weight: .bold)).tracking(1.6).foregroundStyle(F1.muted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("+").font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
                    CountUp(to: diff, delay: 0.3).font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
                    Text("km/h").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                }
            }
            Spacer()
            Text(diff < 0.5 ? "Dead heat" : "\(m.driver(lead).first) faster")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(m.color(lead))
        }
        .padding(16).flowCard()
        .overlay(alignment: .leading) {
            Capsule().fill(F1.red).frame(width: 3, height: 40).shadow(color: F1.red, radius: 4)
        }
    }
}

// MARK: Turn 11

struct TurnElevenView: View {
    let m: Matchup
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var start = Date()

    private let t0 = 0.555, t1 = 0.675, tBrake = 0.581, tApex = 0.620, tExit = 0.647

    // Precomputed once (previously rebuilt every animation frame)
    private let wa: [Double]
    private let wb: [Double]
    private let lo: Double
    private let hi: Double
    private let means: [Double]

    init(m: Matchup, onBack: @escaping () -> Void, onNext: @escaping () -> Void) {
        self.m = m; self.onBack = onBack; self.onNext = onNext
        func win(_ i: Int) -> [Double] {
            let s = m.series(.speed, i)
            return Array(s[Int(0.555 * Double(s.count - 1))...Int(0.675 * Double(s.count - 1))])
        }
        let a = win(0), b = win(1)
        wa = a; wb = b
        lo = min(a.min() ?? 0, b.min() ?? 0) - 12
        hi = max(a.max() ?? 1, b.max() ?? 1) + 8
        means = [a.reduce(0, +) / Double(a.count), b.reduce(0, +) / Double(b.count)]
    }

    private func fr(_ t: Double) -> Double { (t - t0) / (t1 - t0) }

    private var insightText: String {
        let bl = m.pa.t11Brake >= m.pb.t11Brake ? 0 : 1
        let al = m.pa.t11Apex >= m.pb.t11Apex ? 0 : 1
        let L = m.driver(al).last
        if bl == al {
            return "\(L) carried more speed into the braking zone, which translated directly into a higher minimum apex speed.\nBy starting his acceleration phase from a higher baseline speed, he maintained a continuous speed advantage through the exit."
        }
        return "\(m.driver(bl).last) carried more speed into the braking zone, but \(L) held a higher minimum apex speed.\nA higher apex speed gives a stronger platform for the exit and the run to the next corner."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                MomentHeader(title: "Turn 11", subtitle: "Minimum Speed", onBack: onBack)
                MomentEyebrow(title: "Corner Journey")
                AnimClock(start: start, cycle: 7.0) { phase in
                    VStack(alignment: .leading, spacing: 12) { curveCard(phase); statRow(phase) }
                }
                InsightCard(title: "What happened?", text: insightText, start: start)
                RedPillButton(label: "Next · Turn 12 Exit", action: onNext).padding(.top, 4)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
        .onAppear { start = Date() }
    }

    private func curveCard(_ phase: Double) -> some View {
        let maxMean = max(means[0], means[1])

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TURN 11 · SELECTED").font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5).foregroundStyle(F1.purple)
                Spacer()
                ReplayButton { start = Date() }
            }

            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let drawP = flowEase(phase / 1.4)

                ZStack(alignment: .topLeading) {
                    curvePath(wa, w, h)
                        .stroke(.white.opacity(0.06), style: StrokeStyle(lineWidth: 40, lineCap: .round, lineJoin: .round))

                    ForEach(0..<2, id: \.self) { i in
                        let arr = i == 0 ? wa : wb
                        let color = m.color(i)
                        let dur = 2.8 + (maxMean - means[i]) / maxMean * 25
                        let f = flowEase((phase - 1.2) / dur)

                        curvePath(arr, w, h).trim(from: 0, to: drawP)
                            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .shadow(color: color.opacity(0.7), radius: 5)

                        if phase > 1.2 {
                            Circle().fill(.white).frame(width: 11, height: 11)
                                .overlay(Circle().stroke(color, lineWidth: 3)).shadow(color: color, radius: 8)
                                .position(point(arr, f, w, h))
                        }
                    }

                    let ap = point(wa, fr(tApex), w, h)
                    Circle().stroke(F1.purple.opacity(0.9), lineWidth: 1.5)
                        .frame(width: 16 + 6 * sin(phase * 4), height: 16 + 6 * sin(phase * 4)).position(ap)

                    Text("Braking").font(.system(size: 10, weight: .medium)).foregroundStyle(F1.muted)
                        .position(x: w * fr(tBrake) + 6, y: 8)
                    Text("Exit").font(.system(size: 10, weight: .medium)).foregroundStyle(F1.muted)
                        .position(x: w * fr(tExit) + 10, y: 8)
                    Text("Apex").font(.system(size: 11, weight: .semibold)).foregroundStyle(F1.purple)
                        .position(x: ap.x, y: h - 6)
                }
            }
            .frame(height: 150)

            DriverLegendRow(m: m)
            SlowMoNote(text: "Slow-mo · gap exaggerated for clarity")
        }
        .padding(16)
        .flowCard(stroke: F1.purple.opacity(0.5))
    }

    private func pos(_ arr: [Double], _ j: Int, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        let top: CGFloat = 26, bottom: CGFloat = 28
        return CGPoint(x: w * CGFloat(j) / CGFloat(arr.count - 1),
                       y: top + (h - top - bottom) * (1 - CGFloat((arr[j] - lo) / (hi - lo))))
    }

    private func curvePath(_ arr: [Double], _ w: CGFloat, _ h: CGFloat) -> Path {
        Path { p in
            for j in 0..<arr.count {
                let pt = pos(arr, j, w, h)
                if j == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
    }

    private func point(_ arr: [Double], _ f: Double, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        let fl = flowClamp(f) * Double(arr.count - 1)
        let j = min(Int(fl), arr.count - 2)
        let r = CGFloat(fl - Double(j))
        let a = pos(arr, j, w, h), b = pos(arr, j + 1, w, h)
        return CGPoint(x: a.x + (b.x - a.x) * r, y: a.y + (b.y - a.y) * r)
    }

    private func statRow(_ phase: Double) -> some View {
        let leadF = flowEase((phase - 1.2) / 2.8)
        let active: Int = {
            if phase < 1.2 { return -1 }
            if leadF >= fr(tExit) - 0.03 { return 2 }
            if leadF >= fr(tApex) - 0.03 { return 1 }
            if leadF >= fr(tBrake) - 0.03 { return 0 }
            return -1
        }()
        return HStack(spacing: 8) {
            CompareStatCard(m: m, title: "Braking", a: m.pa.t11Brake, b: m.pb.t11Brake, active: active == 0)
            CompareStatCard(m: m, title: "Apex", a: m.pa.t11Apex, b: m.pb.t11Apex, selected: true, active: active == 1)
            CompareStatCard(m: m, title: "Exit", a: m.pa.t11Exit, b: m.pb.t11Exit, active: active == 2)
        }
    }
}

// MARK: Turn 12

struct TurnTwelveView: View {
    let m: Matchup
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var start = Date()

    private let fExit = 0.50, f50 = 0.76, f100 = 0.98

    // Precomputed once
    private let segs: [(Double, Double)]
    private let cycle: Double

    init(m: Matchup, onBack: @escaping () -> Void, onNext: @escaping () -> Void) {
        self.m = m; self.onBack = onBack; self.onNext = onNext

        func raw(_ i: Int) -> (Double, Double) {
            let p = m.profile(i), slow = 1.6
            return (50 / (((p.t12Exit + p.t12p50) / 2) / 3.6) * slow,
                    50 / (((p.t12p50 + p.t12p100) / 2) / 3.6) * slow)
        }
        let r0 = raw(0), r1 = raw(1)
        let minA = min(r0.0, r1.0), minB = min(r0.1, r1.1), k = 8.0
        let s = [(minA + (r0.0 - minA) * k, minB + (r0.1 - minB) * k),
                 (minA + (r1.0 - minA) * k, minB + (r1.1 - minB) * k)]
        segs = s
        cycle = 1.0 + max(s[0].0 + s[0].1, s[1].0 + s[1].1) + 2.2
    }

    private var exitLead: Int { m.pa.t12Exit >= m.pb.t12Exit ? 0 : 1 }
    private var gainLead: Int { m.pa.gain >= m.pb.gain ? 0 : 1 }

    private var insightText: String {
        let el = m.driver(exitLead).last, gl = m.driver(gainLead).last, other = m.driver(1 - gainLead).last
        if exitLead == gainLead {
            return "\(el) crosses the defined corner exit point with a higher initial velocity, establishing a momentum advantage.\nAs the cars travel past the exit, \(el) increases his speed at a significantly faster rate than \(other). Total speed gain for \(el) by the 100meter mark."
        }
        return "\(el) crosses the corner exit point with a higher initial velocity, but \(gl) builds speed at a faster rate.\nTotal speed gain for \(gl) by the 100meter mark."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                MomentHeader(title: "Turn 12 Exit", subtitle: "Lap 24 · Acceleration Analysis", onBack: onBack)
                MomentEyebrow(title: "Acceleration Story")
                AnimClock(start: start, cycle: cycle) { phase in
                    VStack(alignment: .leading, spacing: 12) { bendCard(phase); statRow(phase) }
                }
                gainCard
                InsightCard(title: "What the data shows", text: insightText, start: start)
                RedPillButton(label: "Back to the graph", action: onNext).padding(.top, 4)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
        .onAppear { start = Date() }
    }

    private func bend(_ w: CGFloat, _ h: CGFloat, dy: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: w * 0.05, y: h * 0.86 + dy))
        p.addCurve(to: CGPoint(x: w * 0.30, y: h * 0.32 + dy),
                   control1: CGPoint(x: w * 0.03, y: h * 0.30 + dy), control2: CGPoint(x: w * 0.15, y: h * 0.20 + dy))
        p.addCurve(to: CGPoint(x: w * 0.96, y: h * 0.60 + dy),
                   control1: CGPoint(x: w * 0.55, y: h * 0.42 + dy), control2: CGPoint(x: w * 0.78, y: h * 0.62 + dy))
        return p
    }

    private func frac(_ phase: Double, _ i: Int) -> Double {
        let s = segs[i]
        if phase < 1.0 { return fExit * flowEase(phase) }
        let q = phase - 1.0
        if q < s.0 { return fExit + (f50 - fExit) * (q / s.0) }
        if q < s.0 + s.1 { return f50 + (f100 - f50) * ((q - s.0) / s.1) }
        return f100
    }

    private func bendCard(_ phase: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Illustrative · not measured").font(.system(size: 11, weight: .medium)).foregroundStyle(F1.muted)
                Spacer()
                ReplayButton { start = Date() }
            }

            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let pathA = bend(w, h, dy: 0), pathB = bend(w, h, dy: h * 0.07)
                let markers: [(String, Double)] = [("Exit", fExit), ("+50 m", f50), ("+100 m", f100)]

                ZStack(alignment: .topLeading) {
                    pathA.stroke(.white.opacity(0.06), style: StrokeStyle(lineWidth: 46, lineCap: .round, lineJoin: .round))

                    ForEach(0..<3, id: \.self) { k in
                        let x = pathA.flowPoint(at: CGFloat(markers[k].1)).x
                        Path { p in p.move(to: CGPoint(x: x, y: 16)); p.addLine(to: CGPoint(x: x, y: h)) }
                            .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        Text(markers[k].0).font(.system(size: 10, weight: .medium)).foregroundStyle(F1.muted)
                            .position(x: x, y: 6)
                    }

                    ForEach(0..<2, id: \.self) { i in
                        let path = i == 0 ? pathA : pathB
                        let color = m.color(i)
                        let f = frac(phase, i)

                        path.stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        path.trimmedPath(from: 0, to: CGFloat(max(f, 0.001)))
                            .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .shadow(color: color.opacity(0.8), radius: 6)
                        Circle().fill(.white).frame(width: 11, height: 11)
                            .overlay(Circle().stroke(color, lineWidth: 3)).shadow(color: color, radius: 8)
                            .position(path.flowPoint(at: CGFloat(f)))
                    }
                }
            }
            .frame(height: 130)

            DriverLegendRow(m: m)
            SlowMoNote(text: "Slow-mo · gap exaggerated for clarity")
        }
        .padding(16).flowCard()
    }

    private func statRow(_ phase: Double) -> some View {
        let lead1 = min(segs[0].0, segs[1].0), lead2 = min(segs[0].1, segs[1].1)
        let active: Int = {
            if phase >= 1.0 + lead1 + lead2 { return 2 }
            if phase >= 1.0 + lead1 { return 1 }
            if phase >= 1.0 { return 0 }
            return -1
        }()
        return HStack(spacing: 8) {
            CompareStatCard(m: m, title: "Exit", a: m.pa.t12Exit, b: m.pb.t12Exit, active: active == 0)
            CompareStatCard(m: m, title: "+50 m", a: m.pa.t12p50, b: m.pb.t12p50, active: active == 1)
            CompareStatCard(m: m, title: "+100 m", a: m.pa.t12p100, b: m.pb.t12p100, active: active == 2)
        }
    }

    private var gainCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Speed gain").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text("Exit → +100 m · same interval").font(.system(size: 9)).foregroundStyle(F1.muted)
            }
            HStack(spacing: 0) {
                gainColumn(0)
                Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 52).padding(.horizontal, 12)
                gainColumn(1)
            }
        }
        .padding(14).flowCard(radius: 16)
    }

    private func gainColumn(_ i: Int) -> some View {
        let color = m.color(i)
        return VStack(alignment: .leading, spacing: 3) {
            NameDot(color: color, name: m.driver(i).full)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                CountUp(to: m.profile(i).gain, delay: 0.3).font(.system(size: 28, weight: .bold)).foregroundStyle(color)
                Text("km/h").font(.system(size: 14, weight: .bold)).foregroundStyle(color)
            }
            if gainLead == i {
                Text("BIGGEST GAIN 🔥").font(.system(size: 8, weight: .black)).tracking(0.8).foregroundStyle(F1.yellow)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    RootTabView()
}




































































