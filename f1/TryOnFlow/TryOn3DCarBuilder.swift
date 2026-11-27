//
//  TryOn3DCarBuilder.swift
//  f1
//
//  Procedural 3D Formula 1 car builder and RealityKit scene/camera controller.
//

import Foundation
import RealityKit
import SwiftUI
import UIKit
import simd

// MARK: - Procedural 3D F1 Car Rig

final class CarRig {
    let root = Entity()
    private let chassisTiltNode = Entity()
    private var wheelSpinNodes: [Entity] = []
    private var sidewallRings: [ModelEntity] = []
    private var currentCompound: TyreCompound?
    private var wheelSpinAngle: Float = 0

    init(primaryColor: UIColor, accentColor: UIColor, helmetColor: UIColor, initialCompound: TyreCompound) {
        root.addChild(chassisTiltNode)
        buildChassis(primaryColor: primaryColor, accentColor: accentColor, helmetColor: helmetColor)
        buildWheels()
        updateTyreCompound(initialCompound)
    }

    private func buildChassis(primaryColor: UIColor, accentColor: UIColor, helmetColor: UIColor) {
        var bodyMat = SimpleMaterial()
        bodyMat.color = .init(tint: primaryColor)
        bodyMat.metallic = 0.55
        bodyMat.roughness = 0.25

        var carbonMat = SimpleMaterial()
        carbonMat.color = .init(tint: UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))
        carbonMat.metallic = 0.2
        carbonMat.roughness = 0.7

        var accentMat = SimpleMaterial()
        accentMat.color = .init(tint: accentColor)
        accentMat.metallic = 0.4
        accentMat.roughness = 0.3

        let haloMat = UnlitMaterial(color: UIColor(white: 0.85, alpha: 1.0))
        var helmetMat = SimpleMaterial()
        helmetMat.color = .init(tint: helmetColor)
        helmetMat.metallic = 0.4
        helmetMat.roughness = 0.2

        // Carbon floor plank
        let floor = ModelEntity(mesh: MeshResource.generateBox(width: 1.56, height: 0.06, depth: 3.9, cornerRadius: 0.02), materials: [carbonMat])
        floor.position = SIMD3<Float>(0, 0.13, -0.05)
        chassisTiltNode.addChild(floor)

        // Main monocoque fuselage (+Z is forward)
        let monocoque = ModelEntity(mesh: MeshResource.generateBox(width: 0.62, height: 0.34, depth: 2.85, cornerRadius: 0.12), materials: [bodyMat])
        monocoque.position = SIMD3<Float>(0, 0.32, 0.15)
        chassisTiltNode.addChild(monocoque)

        // Tapered nose cone extending to +Z
        let nose = ModelEntity(mesh: MeshResource.generateBox(width: 0.34, height: 0.18, depth: 1.35, cornerRadius: 0.07), materials: [bodyMat])
        nose.position = SIMD3<Float>(0, 0.25, 1.85)
        nose.orientation = simd_quatf(angle: 0.09, axis: SIMD3<Float>(1, 0, 0))
        chassisTiltNode.addChild(nose)

        // Sidepods (left & right)
        for side in [-1.0 as Float, 1.0 as Float] {
            let sidepod = ModelEntity(mesh: MeshResource.generateBox(width: 0.46, height: 0.32, depth: 1.75, cornerRadius: 0.10), materials: [bodyMat])
            sidepod.position = SIMD3<Float>(side * 0.52, 0.31, -0.22)
            chassisTiltNode.addChild(sidepod)

            let intakeAccent = ModelEntity(mesh: MeshResource.generateBox(width: 0.34, height: 0.20, depth: 0.08), materials: [carbonMat])
            intakeAccent.position = SIMD3<Float>(side * 0.52, 0.33, 0.66)
            chassisTiltNode.addChild(intakeAccent)
        }

        // Engine airbox & shark fin
        let airbox = ModelEntity(mesh: MeshResource.generateBox(width: 0.30, height: 0.32, depth: 0.95, cornerRadius: 0.08), materials: [bodyMat])
        airbox.position = SIMD3<Float>(0, 0.58, -0.50)
        chassisTiltNode.addChild(airbox)

        let sharkFin = ModelEntity(mesh: MeshResource.generateBox(width: 0.04, height: 0.36, depth: 1.05), materials: [accentMat])
        sharkFin.position = SIMD3<Float>(0, 0.68, -1.15)
        chassisTiltNode.addChild(sharkFin)

        // Cockpit opening & driver helmet
        let cockpit = ModelEntity(mesh: MeshResource.generateBox(width: 0.44, height: 0.10, depth: 0.68), materials: [carbonMat])
        cockpit.position = SIMD3<Float>(0, 0.47, 0.25)
        chassisTiltNode.addChild(cockpit)

        let helmet = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.145), materials: [helmetMat])
        helmet.position = SIMD3<Float>(0, 0.56, 0.18)
        chassisTiltNode.addChild(helmet)

        // Halo hoop + center pillar
        let haloCenter = ModelEntity(mesh: MeshResource.generateBox(width: 0.05, height: 0.05, depth: 0.55), materials: [haloMat])
        haloCenter.position = SIMD3<Float>(0, 0.66, 0.45)
        haloCenter.orientation = simd_quatf(angle: 0.32, axis: SIMD3<Float>(1, 0, 0))
        chassisTiltNode.addChild(haloCenter)

        for side in [-1.0 as Float, 1.0 as Float] {
            let haloArm = ModelEntity(mesh: MeshResource.generateBox(width: 0.045, height: 0.045, depth: 0.64), materials: [haloMat])
            haloArm.position = SIMD3<Float>(side * 0.20, 0.65, 0.20)
            haloArm.orientation = simd_quatf(angle: side * -0.22, axis: SIMD3<Float>(0, 1, 0))
            chassisTiltNode.addChild(haloArm)
        }

        // Front Wing + Endplates
        let frontWing = ModelEntity(mesh: MeshResource.generateBox(width: 2.02, height: 0.06, depth: 0.52, cornerRadius: 0.02), materials: [accentMat])
        frontWing.position = SIMD3<Float>(0, 0.15, 2.38)
        chassisTiltNode.addChild(frontWing)

        for side in [-1.0 as Float, 1.0 as Float] {
            let endplate = ModelEntity(mesh: MeshResource.generateBox(width: 0.05, height: 0.24, depth: 0.56), materials: [bodyMat])
            endplate.position = SIMD3<Float>(side * 1.01, 0.22, 2.38)
            chassisTiltNode.addChild(endplate)
        }

        // Rear Wing (lower beam + upper DRS flap + twin endplates)
        let rearMain = ModelEntity(mesh: MeshResource.generateBox(width: 1.24, height: 0.07, depth: 0.38), materials: [carbonMat])
        rearMain.position = SIMD3<Float>(0, 0.86, -1.96)
        chassisTiltNode.addChild(rearMain)

        let rearFlap = ModelEntity(mesh: MeshResource.generateBox(width: 1.24, height: 0.18, depth: 0.08), materials: [accentMat])
        rearFlap.position = SIMD3<Float>(0, 0.94, -2.10)
        rearFlap.orientation = simd_quatf(angle: -0.35, axis: SIMD3<Float>(1, 0, 0))
        chassisTiltNode.addChild(rearFlap)

        for side in [-1.0 as Float, 1.0 as Float] {
            let rearEndplate = ModelEntity(mesh: MeshResource.generateBox(width: 0.05, height: 0.62, depth: 0.50), materials: [bodyMat])
            rearEndplate.position = SIMD3<Float>(side * 0.63, 0.64, -1.98)
            chassisTiltNode.addChild(rearEndplate)
        }

        // Rear FIA rain light
        let rainLight = ModelEntity(
            mesh: MeshResource.generateBox(width: 0.10, height: 0.12, depth: 0.06),
            materials: [UnlitMaterial(color: UIColor(red: 1.0, green: 0.08, blue: 0.12, alpha: 1.0))]
        )
        rainLight.position = SIMD3<Float>(0, 0.28, -2.06)
        chassisTiltNode.addChild(rainLight)
    }

    private func buildWheels() {
        var rubberMat = SimpleMaterial()
        rubberMat.color = .init(tint: UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1.0))
        rubberMat.roughness = 0.85

        var rimMat = SimpleMaterial()
        rimMat.color = .init(tint: UIColor(white: 0.55, alpha: 1.0))
        rimMat.metallic = 0.85
        rimMat.roughness = 0.25

        let configs: [(x: Float, z: Float, width: Float, radius: Float)] = [
            (-0.92,  1.58, 0.34, 0.33), // Front Left
            ( 0.92,  1.58, 0.34, 0.33), // Front Right
            (-0.96, -1.42, 0.44, 0.35), // Rear Left
            ( 0.96, -1.42, 0.44, 0.35)  // Rear Right
        ]

        let alignAxle = simd_quatf(angle: .pi * 0.5, axis: SIMD3<Float>(0, 0, 1))

        for cfg in configs {
            let spinNode = Entity()
            spinNode.position = SIMD3<Float>(cfg.x, cfg.radius, cfg.z)

            let tire = ModelEntity(mesh: MeshResource.generateCylinder(height: cfg.width, radius: cfg.radius), materials: [rubberMat])
            tire.orientation = alignAxle
            spinNode.addChild(tire)

            let rim = ModelEntity(mesh: MeshResource.generateCylinder(height: cfg.width + 0.02, radius: cfg.radius * 0.56), materials: [rimMat])
            rim.orientation = alignAxle
            spinNode.addChild(rim)

            let compoundRing = ModelEntity(
                mesh: MeshResource.generateCylinder(height: cfg.width + 0.015, radius: cfg.radius * 0.72),
                materials: [UnlitMaterial(color: .white)]
            )
            compoundRing.orientation = alignAxle
            spinNode.addChild(compoundRing)

            // Suspension wishbone link to chassis
            let arm = ModelEntity(
                mesh: MeshResource.generateBox(width: abs(cfg.x) * 0.85, height: 0.04, depth: 0.12),
                materials: [rubberMat]
            )
            arm.position = SIMD3<Float>(cfg.x * 0.52, cfg.radius, cfg.z)
            chassisTiltNode.addChild(arm)

            root.addChild(spinNode)
            wheelSpinNodes.append(spinNode)
            sidewallRings.append(compoundRing)
        }
    }

    func updateTyreCompound(_ compound: TyreCompound) {
        guard compound != currentCompound else { return }
        currentCompound = compound
        let uiColor: UIColor = {
            switch compound {
            case .soft:   return UIColor(red: 0.95, green: 0.08, blue: 0.15, alpha: 1.0)
            case .medium: return UIColor(red: 1.00, green: 0.80, blue: 0.12, alpha: 1.0)
            case .hard:   return UIColor(white: 0.94, alpha: 1.0)
            }
        }()
        let mat = UnlitMaterial(color: uiColor)
        for ring in sidewallRings {
            ring.model?.materials = [mat]
        }
    }

    func applyPose(position: SIMD3<Float>, yaw: Float, pitch: Float, speedKmh: Int, dt: Float) {
        root.position = position
        root.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        chassisTiltNode.orientation = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))

        // Rotate wheels proportionally to ground speed
        let angularSpeed = Float(speedKmh) * 0.14
        wheelSpinAngle = (wheelSpinAngle + angularSpeed * dt).truncatingRemainder(dividingBy: .pi * 2)
        let spinQuat = simd_quatf(angle: wheelSpinAngle, axis: SIMD3<Float>(1, 0, 0))
        for wheel in wheelSpinNodes {
            wheel.orientation = spinQuat
        }
    }
}

// MARK: - RealityKit Scene & Camera Controller

@MainActor
final class RaceSceneController {
    private var spline: TrackSpline?
    private var latestState: RaceState?
    private var cameraMode: RaceCameraMode = .chase

    private var carYou: CarRig?
    private var carBot: CarRig?
    private var pitCrew: [Entity] = []
    private var startLights: [ModelEntity] = []
    private var cameraEntity: PerspectiveCamera?
    private var updateSubscription: EventSubscription?

    // Smoothed camera & car animation states
    private var smoothCameraPos = SIMD3<Float>(0, 8, -14)
    private var smoothLookTarget = SIMD3<Float>(0, 0, 0)
    private var smoothUserYaw: Float = 0
    private var smoothBotYaw: Float = 0
    private var prevUserSpeed: Int = 0
    private var prevBotSpeed: Int = 0
    private var hasInitializedCamera = false

    func setupScene(in content: RealityViewCameraContent, circuit: Circuit, spline: TrackSpline, initialState: RaceState) {
        self.spline = spline
        self.latestState = initialState
        self.hasInitializedCamera = false

        // Lighting: ambient hemisphere + warm directional sun
        let sun = DirectionalLight()
        sun.light.intensity = 2400
        sun.light.color = UIColor(white: 0.98, alpha: 1.0)
        sun.look(at: spline.boundsCenter, from: spline.boundsCenter + SIMD3<Float>(60, 110, 40), relativeTo: nil)
        content.add(sun)

        let fillLight = DirectionalLight()
        fillLight.light.intensity = 900
        fillLight.light.color = UIColor(red: 0.75, green: 0.82, blue: 1.0, alpha: 1.0)
        fillLight.look(at: spline.boundsCenter, from: spline.boundsCenter + SIMD3<Float>(-70, 50, -60), relativeTo: nil)
        content.add(fillLight)

        // Track environment
        let env = TryOn3DTrackBuilder.buildEnvironment(for: circuit, spline: spline)
        self.startLights = env.startLights
        self.pitCrew = env.pitCrew
        content.add(env.root)

        // Player car (F1 Ferrari/Red livery)
        let you = CarRig(
            primaryColor: UIColor(red: 0.90, green: 0.06, blue: 0.12, alpha: 1.0),
            accentColor: UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0),
            helmetColor: .white,
            initialCompound: initialState.userCompound
        )
        content.add(you.root)
        self.carYou = you

        // Bot car (Cyan/Teal dark carbon livery)
        let bot = CarRig(
            primaryColor: UIColor(red: 0.08, green: 0.78, blue: 0.70, alpha: 1.0),
            accentColor: UIColor(red: 0.07, green: 0.10, blue: 0.16, alpha: 1.0),
            helmetColor: UIColor(red: 1.0, green: 0.80, blue: 0.12, alpha: 1.0),
            initialCompound: initialState.botCompound
        )
        content.add(bot.root)
        self.carBot = bot

        // Active PerspectiveCamera
        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 54
        content.add(cam)
        self.cameraEntity = cam

        // Place initial poses immediately
        applyFrame(dt: 0.016)

        // Subscribe to RealityKit per-frame updates for smooth 60fps camera & wheel motion
        updateSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.applyFrame(dt: min(0.05, Float(event.deltaTime)))
        }
    }

    func update(state: RaceState, cameraMode: RaceCameraMode) {
        self.latestState = state
        self.cameraMode = cameraMode
    }

    private func applyFrame(dt: Float) {
        guard let spline, let state = latestState, let carYou, let carBot, let cameraEntity else { return }

        // Separate cars slightly laterally when close on track so overtakes happen cleanly side-by-side
        let rawDiff = abs(state.userTrackProgress - state.botTrackProgress)
        let wrappedDiff = min(rawDiff, 1.0 - rawDiff)
        let proximity = max(0.0, min(1.0, (0.07 - Float(wrappedDiff)) / 0.05))
        let userLaneOffset: Float = -1.25 * proximity
        let botLaneOffset: Float = 1.25 * proximity

        let uPose = spline.carPose(at: Float(state.userTrackProgress), pitBlend: Float(state.userPitBlend), raceLaneOffset: userLaneOffset)
        let bPose = spline.carPose(at: Float(state.botTrackProgress), pitBlend: Float(state.botPitBlend), raceLaneOffset: botLaneOffset)

        let targetUserYaw = atan2(uPose.tangent.x, uPose.tangent.z)
        let targetBotYaw = atan2(bPose.tangent.x, bPose.tangent.z)

        if !hasInitializedCamera {
            smoothUserYaw = targetUserYaw
            smoothBotYaw = targetBotYaw
        } else {
            smoothUserYaw = lerpAngle(from: smoothUserYaw, to: targetUserYaw, t: min(1, dt * 10.0))
            smoothBotYaw = lerpAngle(from: smoothBotYaw, to: targetBotYaw, t: min(1, dt * 10.0))
        }

        // Subtle braking nose-dive / acceleration squat pitch
        let uAccel = Float(state.userSpeedKmh - prevUserSpeed)
        let bAccel = Float(state.botSpeedKmh - prevBotSpeed)
        prevUserSpeed = state.userSpeedKmh
        prevBotSpeed = state.botSpeedKmh
        let uPitch = max(-0.03, min(0.03, -uAccel * 0.0015))
        let bPitch = max(-0.03, min(0.03, -bAccel * 0.0015))

        carYou.updateTyreCompound(state.userCompound)
        carBot.updateTyreCompound(state.botCompound)
        carYou.applyPose(position: uPose.position, yaw: smoothUserYaw, pitch: uPitch, speedKmh: state.isPaused ? 0 : state.userSpeedKmh, dt: dt)
        carBot.applyPose(position: bPose.position, yaw: smoothBotYaw, pitch: bPitch, speedKmh: state.isPaused ? 0 : state.botSpeedKmh, dt: dt)

        // Pit crew animation when player car is stopped in pit box
        for (idx, member) in pitCrew.enumerated() {
            member.isEnabled = state.isPittingUser
            if state.isUserInPitBox {
                let side: Float = idx % 2 == 0 ? -1.45 : 1.45
                let fore: Float = idx < 2 ? 1.45 : -1.45
                let box = spline.pitBoxPose
                let targetPos = box.position + box.right * side + box.tangent * fore
                member.position = simd_mix(member.position, targetPos, SIMD3<Float>(repeating: min(1, dt * 8)))
            }
        }

        // Dim start lights after lap 1 gets underway
        let showLights = state.currentLap == 1 && state.userTrackProgress < 0.04
        for light in startLights {
            light.isEnabled = showLights
        }

        // Smooth camera system
        let desiredCam: (pos: SIMD3<Float>, lookAt: SIMD3<Float>) = {
            switch cameraMode {
            case .chase:
                let forward = SIMD3<Float>(sin(smoothUserYaw), 0, cos(smoothUserYaw))
                let camPos = uPose.position - forward * 10.5 + SIMD3<Float>(0, 4.6, 0)
                let lookTarget = uPose.position + forward * 9.5 + SIMD3<Float>(0, 0.8, 0)
                return (camPos, lookTarget)

            case .trackside:
                let nearestCam = spline.tracksideCameras.min {
                    simd_distance($0, uPose.position) < simd_distance($1, uPose.position)
                } ?? (uPose.position + SIMD3<Float>(12, 10, 12))
                return (nearestCam, uPose.position + SIMD3<Float>(0, 0.6, 0))

            case .top:
                let height = spline.boundsRadius * 2.05
                let camPos = spline.boundsCenter + SIMD3<Float>(0, height, spline.boundsRadius * 0.25)
                return (camPos, spline.boundsCenter)
            }
        }()

        if !hasInitializedCamera {
            smoothCameraPos = desiredCam.pos
            smoothLookTarget = desiredCam.lookAt
            hasInitializedCamera = true
        } else {
            let posRate: Float = cameraMode == .trackside ? 5.0 : 7.5
            let lookRate: Float = cameraMode == .trackside ? 9.0 : 10.0
            smoothCameraPos = simd_mix(smoothCameraPos, desiredCam.pos, SIMD3<Float>(repeating: min(1, dt * posRate)))
            smoothLookTarget = simd_mix(smoothLookTarget, desiredCam.lookAt, SIMD3<Float>(repeating: min(1, dt * lookRate)))
        }

        cameraEntity.look(at: smoothLookTarget, from: smoothCameraPos, relativeTo: nil)
    }

    private func lerpAngle(from a: Float, to b: Float, t: Float) -> Float {
        var diff = (b - a).truncatingRemainder(dividingBy: .pi * 2)
        if diff > .pi { diff -= .pi * 2 }
        if diff < -.pi { diff += .pi * 2 }
        return a + diff * t
    }
}
