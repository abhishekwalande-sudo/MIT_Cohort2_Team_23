//
//  TryOn3DTrackBuilder.swift
//  f1
//
//  Arc-length Catmull-Rom track spline + procedural RealityKit 3D circuit builder.
//

import Foundation
import RealityKit
import SwiftUI
import UIKit
import simd

// MARK: - Track Spline (Shared by Physics & 3D Renderer)

struct TrackSample {
    let s: Float               // Normalized arc-length [0, 1)
    let position: SIMD3<Float> // World position on track center (y = 0)
    let tangent: SIMD3<Float>  // Unit forward vector
    let right: SIMD3<Float>    // Unit right vector (perpendicular in XZ)
    let curvature: Float       // Normalized corner sharpness [0, 1]
    let speedFactor: Float     // Normalized corner/straight target speed [0.32, 1.0]
}

final class TrackSpline {
    let samples: [TrackSample]
    let totalLength: Float
    let trackWidth: Float = 8.4
    let pitOffset: Float = 10.2
    let boundsCenter: SIMD3<Float>
    let boundsRadius: Float
    let tracksideCameras: [SIMD3<Float>]

    /// Cumulative normalized distance -> normalized arc-length mapping warped by corner speed,
    /// so cars naturally brake into corners and accelerate onto straights within each lap.
    private let warpedArcTable: [Double]

    private init(
        samples: [TrackSample],
        totalLength: Float,
        boundsCenter: SIMD3<Float>,
        boundsRadius: Float,
        tracksideCameras: [SIMD3<Float>],
        warpedArcTable: [Double]
    ) {
        self.samples = samples
        self.totalLength = totalLength
        self.boundsCenter = boundsCenter
        self.boundsRadius = boundsRadius
        self.tracksideCameras = tracksideCameras
        self.warpedArcTable = warpedArcTable
    }

    static func build(for circuit: Circuit) -> TrackSpline {
        let pts = circuit.pts
        let worldScaleX: Float = 210.0
        let worldScaleZ: Float = 155.0

        // Center circuit around origin
        let rawPoints: [SIMD3<Float>] = pts.map {
            SIMD3<Float>((Float($0.x) - 0.5) * worldScaleX, 0, (Float($0.y) - 0.5) * worldScaleZ)
        }

        // Dense Catmull-Rom evaluation
        let denseCount = 1200
        let n = rawPoints.count
        var dense: [SIMD3<Float>] = []
        dense.reserveCapacity(denseCount)

        for i in 0..<denseCount {
            let u = Float(i) / Float(denseCount) * Float(n)
            let seg = Int(floor(u)) % n
            let t = u - floor(u)

            let p0 = rawPoints[(seg - 1 + n) % n]
            let p1 = rawPoints[seg]
            let p2 = rawPoints[(seg + 1) % n]
            let p3 = rawPoints[(seg + 2) % n]

            let t2 = t * t
            let t3 = t2 * t

            let c0 = -0.5 * t3 + t2 - 0.5 * t
            let c1 = 1.5 * t3 - 2.5 * t2 + 1.0
            let c2 = -1.5 * t3 + 2.0 * t2 + 0.5 * t
            let c3 = 0.5 * t3 - 0.5 * t2

            let pos = p0 * c0 + p1 * c1 + p2 * c2 + p3 * c3
            dense.append(pos)
        }

        // Compute arc length
        var cumLen: [Float] = [0]
        cumLen.reserveCapacity(denseCount + 1)
        var running: Float = 0
        for i in 0..<denseCount {
            let a = dense[i]
            let b = dense[(i + 1) % denseCount]
            running += simd_length(b - a)
            cumLen.append(running)
        }
        let totalLen = max(1, running)

        // Resample into N uniform arc-length positions
        let sampleCount = 320
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(sampleCount)

        var dIdx = 0
        for i in 0..<sampleCount {
            let targetDist = Float(i) / Float(sampleCount) * totalLen
            while dIdx < denseCount - 1 && cumLen[dIdx + 1] < targetDist {
                dIdx += 1
            }
            let d0 = cumLen[dIdx]
            let d1 = cumLen[dIdx + 1]
            let frac = d1 > d0 ? (targetDist - d0) / (d1 - d0) : 0
            let a = dense[dIdx]
            let b = dense[(dIdx + 1) % denseCount]
            positions.append(simd_mix(a, b, SIMD3<Float>(repeating: frac)))
        }

        // Determine signed area to guarantee consistent outward "right" vector for pit lane
        var signedArea: Float = 0
        for i in 0..<sampleCount {
            let a = positions[i]
            let b = positions[(i + 1) % sampleCount]
            signedArea += (a.x * b.z - b.x * a.z)
        }
        let outwardSign: Float = signedArea >= 0 ? -1.0 : 1.0

        // Compute tangents, right vectors, and smoothed curvature
        var rawCurvatures = [Float](repeating: 0, count: sampleCount)
        var tangents = [SIMD3<Float>](repeating: SIMD3<Float>(1, 0, 0), count: sampleCount)
        var rights = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 1), count: sampleCount)

        for i in 0..<sampleCount {
            let prev = positions[(i - 2 + sampleCount) % sampleCount]
            let curr = positions[i]
            let next = positions[(i + 2) % sampleCount]

            let tVec = simd_normalize(next - prev)
            tangents[i] = tVec
            // Right perpendicular in XZ plane oriented toward exterior
            let perp = SIMD3<Float>(-tVec.z * outwardSign, 0, tVec.x * outwardSign)
            rights[i] = simd_normalize(perp)

            let v1 = simd_normalize(curr - prev)
            let v2 = simd_normalize(next - curr)
            let dotVal = min(1.0, max(-1.0, simd_dot(v1, v2)))
            let angle = acos(dotVal)
            rawCurvatures[i] = angle
        }

        // Smooth curvature over a local window so cars brake smoothly before apexes
        var samples: [TrackSample] = []
        samples.reserveCapacity(sampleCount)

        let maxExpectedAngle: Float = 0.24
        for i in 0..<sampleCount {
            var sumK: Float = 0
            for offset in -6...6 {
                let idx = (i + offset + sampleCount) % sampleCount
                // Weight slightly forward to simulate braking anticipation
                let weight: Float = offset >= 0 ? 1.15 : 0.85
                sumK += rawCurvatures[idx] * weight
            }
            let avgK = sumK / 13.0
            let normK = min(1.0, max(0.0, avgK / maxExpectedAngle))
            let speedFactor = max(0.36, 1.0 - normK * 0.64)

            samples.append(
                TrackSample(
                    s: Float(i) / Float(sampleCount),
                    position: positions[i],
                    tangent: tangents[i],
                    right: rights[i],
                    curvature: normK,
                    speedFactor: speedFactor
                )
            )
        }

        // Build warped arc table so time fraction maps naturally to braking/acceleration
        var timeAccum: [Double] = [0]
        timeAccum.reserveCapacity(sampleCount + 1)
        var tRunning: Double = 0
        for i in 0..<sampleCount {
            let dt = 1.0 / Double(samples[i].speedFactor)
            tRunning += dt
            timeAccum.append(tRunning)
        }
        let normalizedTimes = timeAccum.map { $0 / max(0.001, tRunning) }

        // Invert time -> arc-length for fast O(1) lookup at any linear lap fraction
        let lutCount = 256
        var lut = [Double](repeating: 0, count: lutCount + 1)
        var tIdx = 0
        for j in 0...lutCount {
            let targetTime = Double(j) / Double(lutCount)
            while tIdx < sampleCount - 1 && normalizedTimes[tIdx + 1] < targetTime {
                tIdx += 1
            }
            let t0 = normalizedTimes[tIdx]
            let t1 = normalizedTimes[tIdx + 1]
            let frac = t1 > t0 ? (targetTime - t0) / (t1 - t0) : 0
            lut[j] = (Double(tIdx) + frac) / Double(sampleCount)
        }

        // Bounds for top-down camera
        var minP = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxP = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for p in positions {
            minP = simd_min(minP, p)
            maxP = simd_max(maxP, p)
        }
        let center = (minP + maxP) * 0.5
        let radius = max(40, simd_length(maxP - minP) * 0.5)

        // 4 elevated trackside broadcast cameras around the circuit
        let camFractions: [Float] = [0.06, 0.30, 0.56, 0.80]
        let tracksideCams: [SIMD3<Float>] = camFractions.map { f in
            let idx = Int(f * Float(sampleCount)) % sampleCount
            let s = samples[idx]
            return s.position + s.right * 20.0 + SIMD3<Float>(0, 11.0, 0)
        }

        return TrackSpline(
            samples: samples,
            totalLength: totalLen,
            boundsCenter: center,
            boundsRadius: radius,
            tracksideCameras: tracksideCams,
            warpedArcTable: lut
        )
    }

    /// Maps linear lap time fraction [0, 1] -> physical spline coordinate [0, 1) with corner braking & straight acceleration.
    func visualArcProgress(fromLinearFraction f: Double) -> Float {
        let clamped = min(max(f, 0.0), 0.9999)
        let scaled = clamped * Double(warpedArcTable.count - 1)
        let i = Int(scaled)
        let next = min(i + 1, warpedArcTable.count - 1)
        let r = scaled - Double(i)
        let val = warpedArcTable[i] * (1.0 - r) + warpedArcTable[next] * r
        return Float(val.truncatingRemainder(dividingBy: 1.0))
    }

    func sample(at s: Float) -> TrackSample {
        let wrapped = s - floor(s)
        let scaled = wrapped * Float(samples.count)
        let i0 = Int(scaled) % samples.count
        let i1 = (i0 + 1) % samples.count
        let frac = scaled - floor(scaled)

        let a = samples[i0]
        let b = samples[i1]
        let pos = simd_mix(a.position, b.position, SIMD3<Float>(repeating: frac))
        let tan = simd_normalize(simd_mix(a.tangent, b.tangent, SIMD3<Float>(repeating: frac)))
        let rgt = simd_normalize(simd_mix(a.right, b.right, SIMD3<Float>(repeating: frac)))
        let curv = a.curvature * (1 - frac) + b.curvature * frac
        let spd = a.speedFactor * (1 - frac) + b.speedFactor * frac
        return TrackSample(s: wrapped, position: pos, tangent: tan, right: rgt, curvature: curv, speedFactor: spd)
    }

    /// Returns world position & tangent including smooth pit-lane lateral offset.
    func carPose(at s: Float, pitBlend: Float, raceLaneOffset: Float) -> (position: SIMD3<Float>, tangent: SIMD3<Float>, speedFactor: Float) {
        let samp = sample(at: s)
        let lateral = raceLaneOffset * (1.0 - pitBlend) + pitOffset * pitBlend
        return (samp.position + samp.right * lateral, samp.tangent, samp.speedFactor)
    }

    /// Pit box world position at s = 0.97 on the pit lane.
    var pitBoxPose: (position: SIMD3<Float>, tangent: SIMD3<Float>, right: SIMD3<Float>) {
        let samp = sample(at: 0.97)
        return (samp.position + samp.right * pitOffset, samp.tangent, samp.right)
    }
}

// MARK: - Procedural 3D Track Environment Builder

enum TryOn3DTrackBuilder {

    static func buildEnvironment(for circuit: Circuit, spline: TrackSpline) -> (root: Entity, startLights: [ModelEntity], pitCrew: [Entity]) {
        let root = Entity()

        // 1. Grass surroundings terrain
        let groundSize = spline.boundsRadius * 3.8
        var groundMat = PhysicallyBasedMaterial()
        groundMat.baseColor = .init(tint: UIColor(red: 0.06, green: 0.14, blue: 0.08, alpha: 1.0))
        groundMat.roughness = 0.95
        groundMat.metallic = 0.0
        let groundMesh = MeshResource.generatePlane(width: groundSize, depth: groundSize)
        let groundEntity = ModelEntity(mesh: groundMesh, materials: [groundMat])
        groundEntity.position = SIMD3<Float>(spline.boundsCenter.x, -0.04, spline.boundsCenter.z)
        root.addChild(groundEntity)

        // 2. Gravel / runoff apron ribbon under track
        if let runoffMesh = generateRibbonMesh(spline: spline, innerOffset: -(spline.trackWidth * 0.72), outerOffset: spline.trackWidth * 0.72, y: 0.00, closed: true) {
            var runoffMat = SimpleMaterial()
            runoffMat.color = .init(tint: UIColor(red: 0.13, green: 0.14, blue: 0.16, alpha: 1.0))
            runoffMat.roughness = 0.9
            root.addChild(ModelEntity(mesh: runoffMesh, materials: [runoffMat]))
        }

        // 3. Main racing asphalt
        let halfW = spline.trackWidth * 0.5
        if let asphaltMesh = generateRibbonMesh(spline: spline, innerOffset: -halfW, outerOffset: halfW, y: 0.02, closed: true) {
            var asphaltMat = SimpleMaterial()
            asphaltMat.color = .init(tint: UIColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0))
            asphaltMat.roughness = 0.78
            root.addChild(ModelEntity(mesh: asphaltMesh, materials: [asphaltMat]))
        }

        // 4. White track boundary lines
        var whiteMat = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.88))
        whiteMat.color = .init(tint: UIColor.white.withAlphaComponent(0.85))
        if let leftLine = generateRibbonMesh(spline: spline, innerOffset: -halfW + 0.05, outerOffset: -halfW + 0.28, y: 0.03, closed: true) {
            root.addChild(ModelEntity(mesh: leftLine, materials: [whiteMat]))
        }
        if let rightLine = generateRibbonMesh(spline: spline, innerOffset: halfW - 0.28, outerOffset: halfW - 0.05, y: 0.03, closed: true) {
            root.addChild(ModelEntity(mesh: rightLine, materials: [whiteMat]))
        }

        // 5. Red and white kerbs on corners
        addCornerKerbs(to: root, spline: spline, halfWidth: halfW)

        // 6. Safety barriers along track edges
        addSafetyBarriers(to: root, spline: spline)

        // 7. Pit lane asphalt & pit box markings
        addPitLane(to: root, spline: spline)

        // 8. Start/Finish chequered line & F1 lights gantry
        let lights = addStartFinishGantry(to: root, spline: spline)

        // 9. Trackside grandstands & light towers
        addTracksideDetails(to: root, spline: spline)

        // 10. Animated pit crew at pit box
        let crew = addPitCrew(to: root, spline: spline)

        return (root, lights, crew)
    }

    // MARK: - Ribbon Mesh Generator

    private static func generateRibbonMesh(
        spline: TrackSpline,
        innerOffset: Float,
        outerOffset: Float,
        y: Float,
        closed: Bool,
        rangeIndices: [Int]? = nil,
        pitLane: Bool = false
    ) -> MeshResource? {
        let count = spline.samples.count
        let indices = rangeIndices ?? Array(0..<count)
        guard indices.count >= 2 else { return nil }

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [UInt32] = []

        for idx in indices {
            let s = spline.samples[idx % count]
            let centerOffset: Float = pitLane ? spline.pitOffset : 0
            let pInner = s.position + s.right * (centerOffset + innerOffset) + SIMD3<Float>(0, y, 0)
            let pOuter = s.position + s.right * (centerOffset + outerOffset) + SIMD3<Float>(0, y, 0)
            positions.append(pInner)
            positions.append(pOuter)
            normals.append(SIMD3<Float>(0, 1, 0))
            normals.append(SIMD3<Float>(0, 1, 0))
        }

        let segCount = closed ? indices.count : (indices.count - 1)
        for i in 0..<segCount {
            let i0 = UInt32(i * 2)
            let i1 = UInt32(i * 2 + 1)
            let nextBase = ((i + 1) % indices.count) * 2
            let i2 = UInt32(nextBase)
            let i3 = UInt32(nextBase + 1)

            // Upward-facing winding
            triangles.append(contentsOf: [i0, i2, i1])
            triangles.append(contentsOf: [i1, i2, i3])
            // Reverse winding fallback so double-sided visibility never culls
            triangles.append(contentsOf: [i0, i1, i2])
            triangles.append(contentsOf: [i1, i3, i2])
        }

        var descriptor = MeshDescriptor(name: "TrackRibbon")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.primitives = .triangles(triangles)
        return try? MeshResource.generate(from: [descriptor])
    }

    // MARK: - Kerbs & Barriers

    private static func addCornerKerbs(to root: Entity, spline: TrackSpline, halfWidth: Float) {
        let kerbRed = UnlitMaterial(color: UIColor(red: 0.92, green: 0.05, blue: 0.12, alpha: 1.0))
        let kerbWhite = UnlitMaterial(color: UIColor.white)
        let kerbMesh = MeshResource.generateBox(width: 1.05, height: 0.07, depth: 1.55)

        for i in stride(from: 0, to: spline.samples.count, by: 2) {
            let s = spline.samples[i]
            guard s.curvature > 0.28 else { continue }
            let mat = (i / 2) % 2 == 0 ? kerbRed : kerbWhite
            let yaw = atan2(s.tangent.x, s.tangent.z)

            for side in [-1.0 as Float, 1.0 as Float] {
                let kerb = ModelEntity(mesh: kerbMesh, materials: [mat])
                kerb.position = s.position + s.right * (side * (halfWidth + 0.45)) + SIMD3<Float>(0, 0.035, 0)
                kerb.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
                root.addChild(kerb)
            }
        }
    }

    private static func addSafetyBarriers(to root: Entity, spline: TrackSpline) {
        var barrierMat = SimpleMaterial()
        barrierMat.color = .init(tint: UIColor(red: 0.30, green: 0.32, blue: 0.37, alpha: 1.0))
        barrierMat.metallic = 0.65
        barrierMat.roughness = 0.4

        let redRailMat = UnlitMaterial(color: UIColor(red: 0.92, green: 0.05, blue: 0.12, alpha: 1.0))

        let postMesh = MeshResource.generateBox(width: 0.45, height: 0.85, depth: 3.1)
        let railMesh = MeshResource.generateBox(width: 0.50, height: 0.14, depth: 3.1)

        // Outer barrier every 4 samples; inner barrier skipping pit-lane zone [0.87..1.0, 0..0.11]
        for i in stride(from: 0, to: spline.samples.count, by: 3) {
            let s = spline.samples[i]
            let yaw = atan2(s.tangent.x, s.tangent.z)
            let isPitZone = s.s >= 0.87 || s.s <= 0.11

            // Left / inside barrier
            let leftWall = ModelEntity(mesh: postMesh, materials: [barrierMat])
            leftWall.position = s.position - s.right * (spline.trackWidth * 0.82) + SIMD3<Float>(0, 0.42, 0)
            leftWall.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            root.addChild(leftWall)

            // Outer barrier (pushed out around pit lane)
            let outerDist = isPitZone ? (spline.pitOffset + 3.8) : (spline.trackWidth * 0.82)
            let rightWall = ModelEntity(mesh: postMesh, materials: [barrierMat])
            rightWall.position = s.position + s.right * outerDist + SIMD3<Float>(0, 0.42, 0)
            rightWall.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            root.addChild(rightWall)

            if s.curvature > 0.36 {
                let topRail = ModelEntity(mesh: railMesh, materials: [redRailMat])
                topRail.position = rightWall.position + SIMD3<Float>(0, 0.46, 0)
                topRail.orientation = rightWall.orientation
                root.addChild(topRail)
            }
        }
    }

    // MARK: - Pit Lane & Pit Box

    private static func addPitLane(to root: Entity, spline: TrackSpline) {
        let count = spline.samples.count
        let startIdx = Int(0.88 * Float(count))
        let endIdx = count + Int(0.10 * Float(count))
        let pitIndices = Array(startIdx...endIdx)

        if let pitMesh = generateRibbonMesh(spline: spline, innerOffset: -2.4, outerOffset: 2.4, y: 0.025, closed: false, rangeIndices: pitIndices, pitLane: true) {
            var pitMat = SimpleMaterial()
            pitMat.color = .init(tint: UIColor(red: 0.16, green: 0.17, blue: 0.21, alpha: 1.0))
            pitMat.roughness = 0.72
            root.addChild(ModelEntity(mesh: pitMesh, materials: [pitMat]))
        }

        // Pit box painted pad at s = 0.97
        let box = spline.pitBoxPose
        let yaw = atan2(box.tangent.x, box.tangent.z)
        let boxMat = UnlitMaterial(color: UIColor(red: 0.92, green: 0.05, blue: 0.12, alpha: 0.85))
        let boxPad = ModelEntity(mesh: MeshResource.generateBox(width: 3.1, height: 0.04, depth: 5.4), materials: [boxMat])
        boxPad.position = box.position + SIMD3<Float>(0, 0.03, 0)
        boxPad.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        root.addChild(boxPad)

        // Pit garage shelter next to pit box
        var garageMat = SimpleMaterial()
        garageMat.color = .init(tint: UIColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 1.0))
        let garage = ModelEntity(mesh: MeshResource.generateBox(width: 3.2, height: 2.2, depth: 8.5), materials: [garageMat])
        garage.position = box.position + box.right * 4.4 + SIMD3<Float>(0, 1.1, 0)
        garage.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        root.addChild(garage)
    }

    // MARK: - Start / Finish Gantry

    private static func addStartFinishGantry(to root: Entity, spline: TrackSpline) -> [ModelEntity] {
        let s0 = spline.sample(at: 0.0)
        let yaw = atan2(s0.tangent.x, s0.tangent.z)
        let rot = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))

        // Chequered start/finish line across track
        let tileW = spline.trackWidth / 8.0
        let whiteMat = UnlitMaterial(color: .white)
        let blackMat = UnlitMaterial(color: UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0))
        let tileMesh = MeshResource.generateBox(width: tileW, height: 0.035, depth: 0.75)

        for row in 0..<2 {
            for col in 0..<8 {
                let isWhite = (row + col) % 2 == 0
                let tile = ModelEntity(mesh: tileMesh, materials: [isWhite ? whiteMat : blackMat])
                let lateral = -spline.trackWidth * 0.5 + tileW * (Float(col) + 0.5)
                let fore = (Float(row) - 0.5) * 0.78
                tile.position = s0.position + s0.right * lateral + s0.tangent * fore + SIMD3<Float>(0, 0.025, 0)
                tile.orientation = rot
                root.addChild(tile)
            }
        }

        // Gantry pillars & crossbar
        var gantryMat = SimpleMaterial()
        gantryMat.color = .init(tint: UIColor(red: 0.15, green: 0.16, blue: 0.20, alpha: 1.0))
        gantryMat.metallic = 0.7

        let pillarMesh = MeshResource.generateBox(width: 0.45, height: 5.2, depth: 0.45)
        for side in [-1.0 as Float, 1.0 as Float] {
            let pillar = ModelEntity(mesh: pillarMesh, materials: [gantryMat])
            pillar.position = s0.position + s0.right * (side * (spline.trackWidth * 0.5 + 0.7)) + SIMD3<Float>(0, 2.6, 0)
            pillar.orientation = rot
            root.addChild(pillar)
        }

        let beam = ModelEntity(
            mesh: MeshResource.generateBox(width: spline.trackWidth + 2.0, height: 0.85, depth: 0.55),
            materials: [gantryMat]
        )
        beam.position = s0.position + SIMD3<Float>(0, 5.0, 0)
        beam.orientation = rot
        root.addChild(beam)

        // Five overhead starting gantry lights
        var lights: [ModelEntity] = []
        let lightMat = UnlitMaterial(color: UIColor(red: 0.92, green: 0.05, blue: 0.12, alpha: 1.0))
        let lightMesh = MeshResource.generateSphere(radius: 0.22)
        for i in 0..<5 {
            let light = ModelEntity(mesh: lightMesh, materials: [lightMat])
            let offset = Float(i - 2) * 1.15
            light.position = s0.position + s0.right * offset - s0.tangent * 0.32 + SIMD3<Float>(0, 4.85, 0)
            root.addChild(light)
            lights.append(light)
        }

        return lights
    }

    // MARK: - Trackside Details

    private static func addTracksideDetails(to root: Entity, spline: TrackSpline) {
        var standMat = SimpleMaterial()
        standMat.color = .init(tint: UIColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1.0))
        let roofMat = UnlitMaterial(color: UIColor(red: 0.92, green: 0.05, blue: 0.12, alpha: 0.85))
        var towerMat = SimpleMaterial()
        towerMat.color = .init(tint: UIColor(red: 0.45, green: 0.48, blue: 0.54, alpha: 1.0))

        // Grandstands on main straight and mid-lap straight
        for frac in [0.04 as Float, 0.48 as Float] {
            let s = spline.sample(at: frac)
            let yaw = atan2(s.tangent.x, s.tangent.z)
            let rot = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))

            let stand = ModelEntity(mesh: MeshResource.generateBox(width: 5.5, height: 3.4, depth: 18.0), materials: [standMat])
            stand.position = s.position - s.right * (spline.trackWidth * 1.55) + SIMD3<Float>(0, 1.7, 0)
            stand.orientation = rot
            root.addChild(stand)

            let roof = ModelEntity(mesh: MeshResource.generateBox(width: 6.2, height: 0.3, depth: 18.4), materials: [roofMat])
            roof.position = stand.position + SIMD3<Float>(0, 1.9, 0)
            roof.orientation = rot
            root.addChild(roof)
        }

        // Floodlight towers spaced around circuit
        let poleMesh = MeshResource.generateCylinder(height: 9.0, radius: 0.2)
        let lampMesh = MeshResource.generateBox(width: 1.5, height: 0.7, depth: 0.4)
        let lampMat = UnlitMaterial(color: UIColor(white: 0.95, alpha: 1.0))

        for frac in stride(from: 0.12 as Float, to: 0.92 as Float, by: 0.20) {
            let s = spline.sample(at: frac)
            let pole = ModelEntity(mesh: poleMesh, materials: [towerMat])
            pole.position = s.position + s.right * (spline.trackWidth * 1.45) + SIMD3<Float>(0, 4.5, 0)
            root.addChild(pole)

            let lamp = ModelEntity(mesh: lampMesh, materials: [lampMat])
            lamp.position = pole.position + SIMD3<Float>(0, 4.6, 0)
            lamp.look(at: s.position, from: lamp.position, relativeTo: nil)
            root.addChild(lamp)
        }
    }

    // MARK: - Pit Crew

    private static func addPitCrew(to root: Entity, spline: TrackSpline) -> [Entity] {
        let box = spline.pitBoxPose
        let yaw = atan2(box.tangent.x, box.tangent.z)
        let rot = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))

        let suitMat = UnlitMaterial(color: UIColor(red: 0.92, green: 0.05, blue: 0.12, alpha: 1.0))
        let helmetMat = UnlitMaterial(color: .white)
        let bodyMesh = MeshResource.generateCylinder(height: 1.25, radius: 0.24)
        let headMesh = MeshResource.generateSphere(radius: 0.18)

        // 4 crew positions (front-left, front-right, rear-left, rear-right)
        let offsets: [(lateral: Float, fore: Float)] = [
            (-1.9, 1.25), (1.9, 1.25), (-1.9, -1.25), (1.9, -1.25)
        ]

        var crew: [Entity] = []
        for off in offsets {
            let member = Entity()
            let body = ModelEntity(mesh: bodyMesh, materials: [suitMat])
            body.position = SIMD3<Float>(0, 0.62, 0)
            let head = ModelEntity(mesh: headMesh, materials: [helmetMat])
            head.position = SIMD3<Float>(0, 1.40, 0)
            member.addChild(body)
            member.addChild(head)

            member.position = box.position + box.right * off.lateral + box.tangent * off.fore
            member.orientation = rot
            member.isEnabled = false
            root.addChild(member)
            crew.append(member)
        }
        return crew
    }
}
