import SpriteKit
import AVFoundation

/// World layout: waterline at y = 0, boat floats on it, depths are negative y.
/// 1 meter = 6 points.
final class GameScene: SKScene {
    /// Logical landscape canvas; aspectFill keeps proportions on every device.
    static let designSize = CGSize(width: 900, height: 420)

    weak var state: GameState?

    private let ptPerMeter: CGFloat = 6
    private let worldHalfWidth: CGFloat = 9500   // hook + camera bound
    private let fishHalfWidth: CGFloat = 10200   // fish may roam past the border, then drift back
    private var obstacles: [(center: CGPoint, radius: CGFloat)] = []
    private let terrainLayer = SKNode()
    private var denCenters: [CGPoint] = []       // cave pockets; deep ones hold mythics
    private var slowmoUntil: TimeInterval = 0

    private let cameraNode = SKCameraNode()
    private var boat = SKNode()
    private let hook = SKNode()
    private let line = SKShapeNode()
    private let fishLayer = SKNode()
    private let hazardLayer = SKNode()

    private var hooked: [(node: SKNode, species: FishSpecies)] = []
    private var gemsWon = 0
    private var fightsWon = 0
    private var stunUntil: TimeInterval = 0
    private var catchGraceUntil: TimeInterval = 0
    private var mineHits = 0
    private var bossSpawnedThisDive = false

    private var lastTime: TimeInterval = 0

    private enum Phase { case surface, diving, fighting, reeling }
    private var phase: Phase = .surface

    // tension fight
    private var fightFish: SKNode?
    private var fightSpecies: FishSpecies?
    private var fightTension: CGFloat = 0
    private var fightProgress: CGFloat = 0
    private var redlineTime: CGFloat = 0
    private var pullPhase: CGFloat = 0

    // MARK: setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.40, green: 0.66, blue: 0.65, alpha: 1) // muted #66A8A5
        addChild(cameraNode)
        camera = cameraNode

        buildBackdrop()
        rebuildBoat()

        hook.zPosition = 5
        hook.position = CGPoint(x: rodTipOffset.x, y: -20)
        hook.isHidden = true // only visible while diving
        addChild(hook)
        rebuildHook()

        // cream/brass nautical line, slightly translucent so it reads as thread
        line.strokeColor = SKColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 0.75)
        line.lineWidth = 2
        line.zPosition = 4
        addChild(line)

        fishLayer.zPosition = 3
        addChild(fishLayer)
        hazardLayer.zPosition = 3
        addChild(hazardLayer)
        populateFish()
        populateHazards()

        cameraNode.position = CGPoint(x: 0, y: 40)

    }

    static let floorDepthPts: CGFloat = 1020 * 6

    private func buildBackdrop() {
        let sky = SKSpriteNode(color: SKColor(red: 0.63, green: 0.89, blue: 0.87, alpha: 1),
                               size: CGSize(width: worldHalfWidth * 4, height: 900))
        sky.position = CGPoint(x: 0, y: 450)
        sky.zPosition = -10
        addChild(sky)

        // painted sky: one camera-locked backdrop (no tiling seams), hidden once we're deep
        let skyTex = SKTexture(imageNamed: "sky")
        if skyTex.size().width > 1 {
            let sprite = SKSpriteNode(texture: skyTex, size: CGSize(width: 1700, height: 700)) // wide enough for max zoom-out
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.position = CGPoint(x: 0, y: -85)
            sprite.zPosition = -9.5
            sprite.name = "skyBackdrop"
            cameraNode.addChild(sprite)
        }

        // ambient life: gulls circling + a buoy bobbing
        for i in 0..<5 {
            let gull = spriteOrPlaceholder("seagull", width: 44)
            gull.position = CGPoint(x: CGFloat(i - 2) * 500 + .random(in: -150...150),
                                    y: CGFloat.random(in: 190...300))
            gull.zPosition = -9
            let dx: CGFloat = .random(in: 240...420)
            let dur = Double.random(in: 7...11)
            gull.run(.repeatForever(.sequence([
                .group([.moveBy(x: dx, y: .random(in: -18...18), duration: dur),
                        .scaleX(to: -abs(gull.xScale), duration: 0.01)]),
                .group([.moveBy(x: -dx, y: .random(in: -18...18), duration: dur),
                        .scaleX(to: abs(gull.xScale), duration: 0.01)]),
            ])))
            gull.run(.repeatForever(.sequence([
                .scaleY(to: 0.85, duration: 0.35), .scaleY(to: 1.0, duration: 0.35),
            ])))
            addChild(gull)
        }
        for x in [-1500.0, 900.0, 2400.0] {
            let b = spriteOrPlaceholder("buoy", width: 56)
            b.position = CGPoint(x: x, y: 14)
            b.zPosition = 1
            b.run(.repeatForever(.sequence([
                .group([.moveBy(x: 0, y: 8, duration: 1.4), .rotate(toAngle: 0.08, duration: 1.4)]),
                .group([.moveBy(x: 0, y: -8, duration: 1.4), .rotate(toAngle: -0.08, duration: 1.4)]),
            ])))
            addChild(b)
        }

        // smooth depth gradient: turquoise -> blue -> navy -> near-black
        let depthPts = Self.floorDepthPts + 200
        let size = CGSize(width: 4, height: 512)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            // moody: thin muted-teal haze at the very top, then deep navy/near-black fast
            let colors = [
                UIColor(red: 0.40, green: 0.66, blue: 0.65, alpha: 1).cgColor, // #66A8A5 haze
                UIColor(red: 0.11, green: 0.24, blue: 0.25, alpha: 1).cgColor, // teal falloff
                UIColor(red: 0.08, green: 0.16, blue: 0.16, alpha: 1).cgColor, // #152A29
                UIColor(red: 0.04, green: 0.12, blue: 0.12, alpha: 1).cgColor, // #0B1F1E
            ]
            // haze dies by ~30m, full navy by ~150m — most of the dive reads deep
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 0.03, 0.15, 1])!
            ctx.cgContext.drawLinearGradient(grad, start: .zero,
                                             end: CGPoint(x: 0, y: size.height), options: [])
        }
        let water = SKSpriteNode(texture: SKTexture(image: img),
                                 size: CGSize(width: worldHalfWidth * 4, height: depthPts))
        water.position = CGPoint(x: 0, y: -depthPts / 2)
        water.zPosition = -9
        addChild(water)

        // god rays near the surface
        for i in 0..<36 {
            let ray = SKSpriteNode(color: .white, size: CGSize(width: 60, height: 700))
            ray.alpha = 0.035
            ray.zRotation = CGFloat.random(in: -0.28 ... -0.12)
            ray.position = CGPoint(x: -worldHalfWidth + CGFloat(i) * worldHalfWidth / 17.5
                                       + .random(in: -60...60),
                                   y: -320)
            ray.zPosition = -8.5
            ray.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.02, duration: Double.random(in: 2.5...4)),
                .fadeAlpha(to: 0.08, duration: Double.random(in: 2.5...4)),
            ])))
            addChild(ray)
        }

        buildWaves()
        buildParallaxSilhouettes()
        startAmbientBubbles()
        terrainLayer.zPosition = 2.5
        addChild(terrainLayer)
        generateTerrain()

        let foam = SKSpriteNode(color: .white, size: CGSize(width: worldHalfWidth * 4, height: 4))
        foam.alpha = 0.25 // soft surface hint, not a hard white bar
        foam.position = .zero
        foam.zPosition = -8
        addChild(foam)
    }

    private let parallaxLayer = SKNode()

    /// Distant terrain silhouettes that scroll slower than the world — cheap depth.
    private func buildParallaxSilhouettes() {
        parallaxLayer.zPosition = -8.8
        for _ in 0..<70 {
            let id = ["rock1", "rock2", "rock_pillar", "seaweed1"].randomElement()!
            let n = spriteOrPlaceholder(id, width: .random(in: 140...340))
            n.color = SKColor(red: 0.01, green: 0.05, blue: 0.05, alpha: 1)
            n.colorBlendFactor = 1.0 // pure near-black silhouette
            n.alpha = 0.7
            // spread across 60% of world coords: layer moves at 0.4x camera so it covers the view
            n.position = CGPoint(x: .random(in: -worldHalfWidth * 0.62 ... worldHalfWidth * 0.62),
                                 y: -CGFloat.random(in: 40...1000) * ptPerMeter)
            parallaxLayer.addChild(n)
        }
        addChild(parallaxLayer)
    }

    /// Ambient bubbles rising through the water column near the camera.
    private func startAmbientBubbles() {
        run(.repeatForever(.sequence([
            .wait(forDuration: 1.4), // sparse — mood, not soda
            .run { [weak self] in
                guard let self else { return }
                let cam = self.cameraNode.position
                guard cam.y < 60 else { return } // only underwater
                let b = SKShapeNode(circleOfRadius: .random(in: 2...5))
                b.fillColor = SKColor(white: 1, alpha: 0.12)
                b.strokeColor = SKColor(white: 1, alpha: 0.06)
                b.position = CGPoint(x: cam.x + .random(in: -500...500),
                                     y: cam.y - .random(in: 100...260))
                b.zPosition = 2.2
                self.addChild(b)
                b.run(.sequence([
                    .group([.moveBy(x: .random(in: -20...20), y: .random(in: 260...420),
                                    duration: .random(in: 4...7)),
                            .fadeOut(withDuration: .random(in: 4...7))]),
                    .removeFromParent(),
                ]))
            },
        ])))
    }

    /// Two scrolling sine-wave bands at the surface.
    private func buildWaves() {
        let waveSize = CGSize(width: 512, height: 36)
        func waveTexture(alpha: CGFloat) -> SKTexture {
            let img = UIGraphicsImageRenderer(size: waveSize).image { ctx in
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 0, y: waveSize.height))
                p.addLine(to: CGPoint(x: 0, y: 20))
                for x in stride(from: 0.0, through: 512.0, by: 8) {
                    p.addLine(to: CGPoint(x: x, y: 20 - 9 * sin(x / 512 * .pi * 4)))
                }
                p.addLine(to: CGPoint(x: 512, y: waveSize.height))
                p.close()
                UIColor(white: 1, alpha: alpha).setFill()
                p.fill()
            }
            return SKTexture(image: img)
        }
        for (i, cfg) in [(alpha: 0.35, speed: 60.0, y: 4.0), (alpha: 0.2, speed: -40.0, y: 10.0)].enumerated() {
            let tex = waveTexture(alpha: cfg.alpha)
            // two tiles per layer, leapfrogging for an endless scroll
            for k in 0...1 {
                let span = worldHalfWidth * 2 + 1024
                let w = SKSpriteNode(texture: tex, size: CGSize(width: span, height: waveSize.height))
                w.position = CGPoint(x: CGFloat(k) * span - span / 2, y: cfg.y)
                w.zPosition = -7.5 + CGFloat(i) * 0.1
                addChild(w)
                let dur = Double(span) / abs(cfg.speed)
                let dx = cfg.speed > 0 ? span : -span
                w.run(.repeatForever(.sequence([
                    .moveBy(x: dx, y: 0, duration: dur),
                    .moveBy(x: -dx, y: 0, duration: 0),
                ])))
            }
        }
    }

    // MARK: procedural terrain — regenerated every dive

    /// Solid block: sprite stretched to (w,h), collision approximated with a row of circles.
    private func addSolid(_ asset: String, at p: CGPoint, w: CGFloat, h: CGFloat) {
        let node = spriteOrPlaceholder(asset, width: w)
        node.size = CGSize(width: w, height: h)
        node.position = p
        terrainLayer.addChild(node)
        let r = min(w, h) * 0.48
        let count = max(1, Int(max(w, h) / (r * 1.4)))
        for i in 0..<count {
            let t = count == 1 ? 0.5 : CGFloat(i) / CGFloat(count - 1)
            let c = w > h
                ? CGPoint(x: p.x - w / 2 + r + (w - 2 * r) * t, y: p.y)
                : CGPoint(x: p.x, y: p.y - h / 2 + r + (h - 2 * r) * t)
            obstacles.append((c, r))
        }
    }

    private func addGreenery(near p: CGPoint, spread: CGFloat) {
        let id = ["seaweed1", "seaweed2", "coral1", "coral2"].randomElement()!
        let deco = spriteOrPlaceholder(id, width: .random(in: 80...170))
        deco.position = CGPoint(x: p.x + .random(in: -spread...spread), y: p.y + .random(in: 20...70))
        deco.zPosition = 2.7
        deco.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.05, duration: Double.random(in: 1.6...2.4)),
            .rotate(toAngle: -0.05, duration: Double.random(in: 1.6...2.4)),
        ])))
        terrainLayer.addChild(deco)
    }

    private func spawnChest(at p: CGPoint) {
        let chest = spriteOrPlaceholder("chest", width: 56)
        chest.position = p
        chest.userData = ["hazard": "chest"]
        chest.run(.repeatForever(.sequence([
            .scale(to: 1.08, duration: 0.8), .scale(to: 1.0, duration: 0.8),
        ])))
        hazardLayer.addChild(chest)
    }

    /// Walls, ledges, pillars, floating reefs and cave dens — new layout every dive.
    private func generateTerrain() {
        terrainLayer.removeAllChildren()
        obstacles = []
        denCenters = []

        // side walls jutting in, alternating-ish, every 100–200m of depth
        var d: CGFloat = 70
        while d < 980 {
            let side: CGFloat = Bool.random() ? 1 : -1
            let jut = CGFloat.random(in: 500...1500)
            let h = CGFloat.random(in: 220...420)
            addSolid("rock_wall", at: CGPoint(x: side * (worldHalfWidth - jut / 2 + 100), y: -d * ptPerMeter),
                     w: jut, h: h)
            addGreenery(near: CGPoint(x: side * (worldHalfWidth - jut + 160), y: -d * ptPerMeter + h / 2), spread: jut * 0.3)
            d += .random(in: 100...200)
        }

        // pillars rising from the abyss
        for _ in 0..<14 {
            let x = CGFloat.random(in: -worldHalfWidth * 0.85 ... worldHalfWidth * 0.85)
            let top = CGFloat.random(in: 350...900)
            let h = CGFloat.random(in: 900...2400)
            addSolid("rock_pillar", at: CGPoint(x: x, y: -top * ptPerMeter - h / 2), w: .random(in: 160...260), h: h)
        }

        // mid-water ledges
        for _ in 0..<30 {
            let p = CGPoint(x: .random(in: -worldHalfWidth * 0.9 ... worldHalfWidth * 0.9),
                            y: -CGFloat.random(in: 60...950) * ptPerMeter)
            addSolid("rock_ledge", at: p, w: .random(in: 320...640), h: .random(in: 70...110))
            addGreenery(near: CGPoint(x: p.x, y: p.y + 40), spread: 200)
        }

        // floating reef islands — alive clusters in open water
        for _ in 0..<30 {
            let p = CGPoint(x: .random(in: -worldHalfWidth...worldHalfWidth),
                            y: -CGFloat.random(in: 40...900) * ptPerMeter)
            addSolid(["rock1", "rock2"].randomElement()!, at: p, w: .random(in: 180...320), h: .random(in: 150...260))
            for _ in 0..<Int.random(in: 2...4) { addGreenery(near: p, spread: 160) }
        }

        // cave dens: floor + roof slabs with a side entrance; chest inside, deep ones host mythics
        for i in 0..<6 {
            let depth = CGFloat.random(in: 150 + CGFloat(i) * 130 ... 220 + CGFloat(i) * 140)
            let cx = CGFloat.random(in: -worldHalfWidth * 0.8 ... worldHalfWidth * 0.8)
            let c = CGPoint(x: cx, y: -min(depth, 960) * ptPerMeter)
            let w = CGFloat.random(in: 700...1000)
            addSolid("rock_wall", at: CGPoint(x: c.x, y: c.y - 170), w: w, h: 150)          // floor
            addSolid("rock_wall", at: CGPoint(x: c.x, y: c.y + 190), w: w, h: 150)          // roof
            let entranceSide: CGFloat = Bool.random() ? 1 : -1
            addSolid("rock2", at: CGPoint(x: c.x - entranceSide * w / 2, y: c.y), w: 170, h: 240) // back wall
            denCenters.append(c)
            spawnChest(at: CGPoint(x: c.x + entranceSide * .random(in: -60...60), y: c.y - 70))
            addGreenery(near: CGPoint(x: c.x, y: c.y - 120), spread: w * 0.3)
        }

        generateLandmarks()
    }

    /// One set piece per biome per dive; each guarantees a rare+ fish nearby.
    /// Reef: shipwreck. Kelp: caves already exist (dens). Abyss: thermal vent. Trench: vent + extra chest.
    private var landmarkCenters: [CGPoint] = []
    private func generateLandmarks() {
        landmarkCenters = []

        // shipwreck in the reef band
        let wreckP = CGPoint(x: .random(in: -worldHalfWidth * 0.7 ... worldHalfWidth * 0.7),
                             y: -CGFloat.random(in: 90...220) * ptPerMeter)
        let wreck = spriteOrPlaceholder("shipwreck", width: 420)
        wreck.position = wreckP
        wreck.zPosition = 2.6
        terrainLayer.addChild(wreck)
        obstacles.append((wreckP, 140)) // hull is solid-ish
        spawnChest(at: CGPoint(x: wreckP.x + .random(in: -80...80), y: wreckP.y + 40))
        landmarkCenters.append(wreckP)

        // thermal vents in abyss and trench bands
        for depth in [CGFloat.random(in: 520...760), CGFloat.random(in: 830...970)] {
            let p = CGPoint(x: .random(in: -worldHalfWidth * 0.8 ... worldHalfWidth * 0.8),
                            y: -depth * ptPerMeter)
            let vent = spriteOrPlaceholder("thermal_vent", width: 220)
            vent.position = p
            vent.zPosition = 2.6
            terrainLayer.addChild(vent)
            obstacles.append((p, 90))
            // rising glow plume
            let plume = SKSpriteNode(texture: Self.glowTexture, size: CGSize(width: 60, height: 60))
            plume.color = SKColor(red: 1, green: 0.45, blue: 0.15, alpha: 1)
            plume.colorBlendFactor = 1
            plume.blendMode = .add
            plume.alpha = 0.5
            plume.position = CGPoint(x: p.x, y: p.y + 110)
            terrainLayer.addChild(plume)
            plume.run(.repeatForever(.sequence([
                .group([.moveBy(x: 0, y: 90, duration: 1.8), .fadeAlpha(to: 0.1, duration: 1.8)]),
                .run { plume.position.y -= 90; plume.alpha = 0.5 },
            ])))
            landmarkCenters.append(p)
        }
    }

    func rebuildHook() {
        hook.removeAllChildren()
        // beefs up with each hook upgrade: 24pt → 42pt at lvl 10
        let hookWidth = 24 + CGFloat((state?.hookStrength ?? 1) - 1) * 2
        let sprite = spriteOrPlaceholder(state?.currentHook ?? "hook_classic", width: hookWidth)
        hook.addChild(sprite)
    }

    // MARK: feedback

    private var sfxPlayers: [String: AVAudioPlayer] = [:]

    private func sfx(_ name: String) {
        guard let state, state.soundOn, state.soundVolume > 0 else { return }
        if sfxPlayers[name] == nil,
           let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            sfxPlayers[name] = try? AVAudioPlayer(contentsOf: url)
        }
        guard let p = sfxPlayers[name] else { return }
        p.volume = Float(state.soundVolume)
        p.currentTime = 0
        p.play()
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard state?.hapticsOn != false else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Everything that must scale/anchor per boat: sprite size, rod, captain, line origin, surface zoom.
    private var layout = hullLayouts["skiff"]!
    private var boatUnit: ModularBoatNode?
    private var rodTipOffset: CGPoint { layout.rodTipOffset }
    var surfaceZoom: CGFloat { layout.surfaceZoom }

    func rebuildBoat() {
        guard let state else { return }
        layout = hullLayouts[state.effectiveHullId] ?? layout
        boat.removeFromParent()
        boat = SKNode()

        // modular unit: hull + deck + rod + captain + detail; rod art tracks the reel tier
        let tier = state.levels[.reel] ?? 1
        let rodAsset = state.currentRodId ?? "rod_\(tier)"
        let unit = ModularBoatNode(layout: layout,
                                   rodAsset: rodAsset,
                                   captainAsset: state.currentCaptainId ?? "captain",
                                   deckId: state.currentDeckId,
                                   detailId: state.currentDetailId)
        boatUnit = unit
        // swap animation: new boat scales/fades in
        unit.alpha = 0
        unit.setScale(0.92)
        boat.addChild(unit)
        unit.run(.group([.fadeIn(withDuration: 0.25), .scale(to: 1.0, duration: 0.25)]))

        // water reflection: flipped, faded hull with a slow ripple (PNG hulls only)
        // UIImage probe — SKTexture(imageNamed:) fakes a red-X texture for missing assets
        let hullImg = UIImage(named: "hull_\(layout.id)")
            ?? layout.legacyAsset.flatMap { UIImage(named: $0) }
        if let hullImg {
            let hullTex = SKTexture(image: hullImg)
            let scale = layout.size.width / hullTex.size().width
            let h = hullTex.size().height * scale
            let reflection = SKSpriteNode(texture: hullTex,
                                          size: CGSize(width: layout.size.width, height: h))
            reflection.yScale = -0.7
            reflection.alpha = 0.13
            reflection.position = CGPoint(x: 0, y: -layout.waterlineOffset - h * 0.55)
            reflection.zPosition = -0.5
            boat.addChild(reflection)
            reflection.run(.repeatForever(.sequence([
                .group([.scaleX(to: 1.03, duration: 1.6), .fadeAlpha(to: 0.09, duration: 1.6)]),
                .group([.scaleX(to: 1.0, duration: 1.6), .fadeAlpha(to: 0.13, duration: 1.6)]),
            ])))
        }

        // soft hull shadow at the waterline, breathing with the bob
        let hullShadow = SKShapeNode(ellipseOf: CGSize(width: layout.size.width * 0.9,
                                                       height: layout.size.width * 0.07))
        hullShadow.fillColor = SKColor(white: 0, alpha: 0.28)
        hullShadow.strokeColor = .clear
        hullShadow.position = CGPoint(x: 0, y: -6)
        hullShadow.zPosition = -0.4
        boat.addChild(hullShadow)
        hullShadow.run(.repeatForever(.sequence([
            .group([.scaleX(to: 1.06, duration: 1.2), .fadeAlpha(to: 0.2, duration: 1.2)]),
            .group([.scaleX(to: 1.0, duration: 1.2), .fadeAlpha(to: 0.28, duration: 1.2)]),
        ])))

        // bow spray: little white droplets kicked up while the boat rocks at the surface
        boat.run(.repeatForever(.sequence([
            .wait(forDuration: 0.9, withRange: 0.5),
            .run { [weak self, weak boat] in
                guard let self, let boat, self.phase == .surface else { return }
                let bowX = self.layout.size.width * 0.48 * (Bool.random() ? 1 : -1)
                for _ in 0..<Int.random(in: 2...4) {
                    let drop = SKShapeNode(circleOfRadius: .random(in: 1.5...3))
                    drop.fillColor = SKColor(white: 1, alpha: 0.55)
                    drop.strokeColor = .clear
                    drop.position = CGPoint(x: bowX + .random(in: -10...10), y: 2)
                    boat.addChild(drop)
                    drop.run(.sequence([
                        .group([.moveBy(x: .random(in: -14...14), y: .random(in: 10...26), duration: 0.35),
                                .fadeOut(withDuration: 0.35)]),
                        .removeFromParent(),
                    ]))
                }
            },
        ])))

        boat.zPosition = 2
        addChild(boat)
        // bob + rock with the waves
        boat.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 6, duration: 1.2),
            .moveBy(x: 0, y: -6, duration: 1.2),
        ])))
        boat.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.035, duration: 1.7),
            .rotate(toAngle: -0.035, duration: 1.7),
        ])))
    }

    /// Sprite from bundled art; falls back to a themed silhouette if the asset is missing.
    private func spriteOrPlaceholder(_ assetName: String, width: CGFloat) -> SKSpriteNode {
        let tex = SKTexture(imageNamed: assetName)
        if tex.size().width > 1 {
            let node = SKSpriteNode(texture: tex)
            let scale = width / tex.size().width
            node.size = CGSize(width: width, height: tex.size().height * scale)
            return node
        }
        // navy silhouette w/ faint outline — reads as "content coming", not "bug"
        let size = CGSize(width: width, height: width * 0.5)
        let img = UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: min(10, width * 0.2))
            UIColor(red: 0.07, green: 0.16, blue: 0.25, alpha: 0.55).setFill()
            path.fill()
            UIColor(white: 1, alpha: 0.35).setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
        return SKSpriteNode(texture: SKTexture(image: img), size: size)
    }

    /// Quick bubble burst where a fish got bagged.
    private func catchBurst(at p: CGPoint) {
        for _ in 0..<8 {
            let r = CGFloat.random(in: 2.5...5)
            let b = SKShapeNode(circleOfRadius: r)
            b.fillColor = SKColor(white: 1, alpha: 0.7)
            b.strokeColor = .clear
            b.position = p
            b.zPosition = 6
            addChild(b)
            b.run(.sequence([
                .group([.moveBy(x: .random(in: -30...30), y: .random(in: 20...60),
                                duration: 0.5),
                        .fadeOut(withDuration: 0.5),
                        .scale(to: 0.3, duration: 0.5)]),
                .removeFromParent(),
            ]))
        }
    }

    private func populateFish() {
        let bait = state?.equippedBait ?? "bait_worm"
        for sp in allFish where !sp.isBoss {
            var count: Int
            switch sp.rarity {
            case .mythic: count = 0 // mythics live in cave dens only
            case .legendary: count = 4
            case .epic: count = 10
            default: count = sp.isBig ? 13 : 24
            }
            // bait boosts spawn counts for its niche
            switch bait {
            case "bait_shrimp" where sp.rarity == .uncommon: count = count * 3 / 2
            case "bait_squid" where sp.rarity == .rare: count = count * 2
            case "bait_glowbug" where sp.minDepth >= 400: count = count * 3 / 2
            case "bait_golden" where sp.rarity == .legendary: count = count * 7 / 4
            default: break
            }
            if sp.rarity <= .uncommon {
                // commons swim in loose schools of 4-8 around a shared anchor
                var remaining = count
                while remaining > 0 {
                    let schoolSize = min(remaining, Int.random(in: 4...8))
                    let anchor = CGPoint(x: .random(in: -fishHalfWidth...fishHalfWidth),
                                         y: -CGFloat.random(in: sp.minDepth...sp.maxDepth) * ptPerMeter)
                    for _ in 0..<schoolSize {
                        let p = CGPoint(x: anchor.x + .random(in: -120...120),
                                        y: anchor.y + .random(in: -80...80))
                        spawnFish(sp, at: p, school: anchor)
                    }
                    remaining -= schoolSize
                }
            } else {
                // one instance per width slot so no species clumps in one spot
                let slots = min(max(count, 1), 12)
                let slotW = fishHalfWidth * 2 / CGFloat(slots)
                for i in 0..<count {
                    let x = -fishHalfWidth + slotW * CGFloat(i % slots) + .random(in: 0...slotW)
                    let depth = CGFloat.random(in: sp.minDepth...sp.maxDepth)
                    spawnFish(sp, at: CGPoint(x: x, y: -depth * ptPerMeter))
                }
            }
        }
        // each mythic guards the den closest to its home depth
        let mythics = allFish.filter { $0.rarity == .mythic }
        var dens = denCenters
        for sp in mythics {
            let target = -(sp.minDepth + sp.maxDepth) / 2 * ptPerMeter
            guard let den = dens.min(by: { abs($0.y - target) < abs($1.y - target) }) else { break }
            dens.removeAll { $0 == den }
            spawnFish(sp, at: CGPoint(x: den.x, y: den.y - 40))
        }
        // golden lure: one extra mythic prowls a spare den
        if bait == "bait_golden", let den = dens.randomElement(), let sp = mythics.randomElement() {
            spawnFish(sp, at: CGPoint(x: den.x, y: den.y - 40))
        }
        // landmarks guarantee a rare+ fish that suits the depth
        for c in landmarkCenters {
            let depthM = -c.y / ptPerMeter
            let candidates = allFish.filter {
                !$0.isBoss && $0.rarity >= .rare && $0.rarity <= .legendary
                    && $0.minDepth - 80 < depthM && depthM < $0.maxDepth + 80
            }
            if let sp = candidates.randomElement() {
                spawnFish(sp, at: CGPoint(x: c.x + .random(in: -100...100), y: c.y + 30))
            }
        }

        // ponytail: UI-test hook, spawns big fish right under the boat. Remove before ship.
        if ProcessInfo.processInfo.environment["SPAWN_BIG_SHALLOW"] != nil,
           let big = allFish.first(where: { $0.isBig }) {
            for i in 0..<3 { spawnFish(big, at: CGPoint(x: 0, y: -(80 + CGFloat(i) * 60))) }
        }
    }

    private func spawnFish(_ sp: FishSpecies, at fixed: CGPoint? = nil, school: CGPoint? = nil) {
        let node = spriteOrPlaceholder(sp.id, width: sp.size)
        node.userData = ["id": sp.id]
        if let school {
            node.userData?["schoolX"] = school.x
            node.userData?["schoolY"] = school.y
        }
        let depth = CGFloat.random(in: sp.minDepth...sp.maxDepth) * ptPerMeter
        node.position = fixed ?? CGPoint(x: .random(in: -worldHalfWidth...worldHalfWidth), y: -depth)
        fishLayer.addChild(node)
        let heading = CGFloat.random(in: 0...(2 * .pi))
        node.userData?["vx"] = cos(heading) * sp.speed
        node.userData?["vy"] = sin(heading) * sp.speed * 0.4
        node.xScale = abs(node.xScale) * (cos(heading) > 0 ? -1 : 1) // art faces left

        // 2-frame swim flip-book when the _f2 sprite exists; faster fish beat faster
        let f2 = SKTexture(imageNamed: "\(sp.id)_f2")
        if f2.size().width > 1, let f1 = node.texture {
            let beat = max(0.16, 0.45 - Double(sp.speed) / 500)
            node.run(.repeatForever(.animate(with: [f1, f2], timePerFrame: beat, resize: false, restore: true)))
        }

        // body flex: warp the trailing half up/down in a swim-beat rhythm —
        // reads as tail undulation without extra art
        let cols = 2, rows = 1
        let src: [SIMD2<Float>] = [[0, 0], [0.5, 0], [1, 0], [0, 1], [0.5, 1], [1, 1]]
        func bent(_ dy: Float) -> [SIMD2<Float>] {
            [[0, 0], [0.5, 0], [1, dy], [0, 1], [0.5, 1], [1, 1 + dy]]
        }
        node.warpGeometry = SKWarpGeometryGrid(columns: cols, rows: rows,
                                               sourcePositions: src, destinationPositions: src)
        let beat = max(0.18, 0.5 - Double(sp.speed) / 450)
        if let up = SKAction.warp(to: SKWarpGeometryGrid(columns: cols, rows: rows,
                                                         sourcePositions: src, destinationPositions: bent(0.07)),
                                  duration: beat),
           let down = SKAction.warp(to: SKWarpGeometryGrid(columns: cols, rows: rows,
                                                           sourcePositions: src, destinationPositions: bent(-0.07)),
                                    duration: beat) {
            up.timingMode = .easeInEaseOut
            down.timingMode = .easeInEaseOut
            node.run(.repeatForever(.sequence([up, down])))
        }

        // burst-glide phase: fish pulse speed instead of cruising at constant velocity
        node.userData?["ph"] = CGFloat.random(in: 0...(2 * .pi))

        // rarity glow: epic+ get a soft pulsing halo in their rarity color
        if sp.rarity >= .epic {
            let tint: SKColor = switch sp.rarity {
            case .epic: SKColor(red: 0.65, green: 0.35, blue: 0.9, alpha: 1)
            case .legendary: SKColor(red: 0.96, green: 0.78, blue: 0.3, alpha: 1)
            default: SKColor(red: 0.35, green: 0.9, blue: 0.9, alpha: 1) // mythic/boss
            }
            let glow = SKSpriteNode(texture: Self.glowTexture, size: CGSize(width: sp.size * 1.9, height: sp.size * 1.9))
            glow.color = tint
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.alpha = 0.35
            glow.zPosition = -0.1
            node.addChild(glow)
            glow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.5, duration: 1.1), .fadeAlpha(to: 0.25, duration: 1.1),
            ])))
        }

        // bioluminescent dot for deep dwellers — reads as anglerfish lure in the dark
        if sp.minDepth >= 500 {
            let dot = SKSpriteNode(texture: Self.glowTexture, size: CGSize(width: 14, height: 14))
            dot.color = SKColor(red: 0.5, green: 0.95, blue: 0.9, alpha: 1)
            dot.colorBlendFactor = 1
            dot.blendMode = .add
            dot.position = CGPoint(x: sp.size * 0.45, y: sp.size * 0.12)
            node.addChild(dot)
            dot.run(.repeatForever(.sequence([
                .fadeAlpha(to: 1, duration: 0.7), .fadeAlpha(to: 0.4, duration: 0.7),
            ])))
        }
    }

    /// Shared soft radial glow texture (rendered once).
    private static let glowTexture: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor(white: 1, alpha: 0.9).cgColor,
                                           UIColor(white: 1, alpha: 0).cgColor] as CFArray,
                                  locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(grad, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                             endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
        return SKTexture(image: img)
    }()

    private func populateHazards() {
        // jellyfish 130–370m, mines 380–990m
        for _ in 0..<48 {
            let j = spriteOrPlaceholder("jellyfish", width: 46)
            j.userData = ["hazard": "jelly"]
            j.position = CGPoint(x: .random(in: -worldHalfWidth...worldHalfWidth),
                                 y: -CGFloat.random(in: 130...370) * ptPerMeter)
            j.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 24, duration: 1.6),
                .moveBy(x: 0, y: -24, duration: 1.6),
            ])))
            hazardLayer.addChild(j)
        }
        for _ in 0..<62 {
            let m = spriteOrPlaceholder("mine", width: 52)
            m.userData = ["hazard": "mine"]
            m.position = CGPoint(x: .random(in: -worldHalfWidth...worldHalfWidth),
                                 y: -CGFloat.random(in: 380...990) * ptPerMeter)
            hazardLayer.addChild(m)
        }
    }

    private func maybeSpawnBoss(state: GameState) {
        bossSpawnedThisDive = false
        // deepest boss whose zone the line can reach; 30% chance per dive
        let reachable = allFish.filter { $0.isBoss && $0.minDepth < state.maxDepthMeters }
        guard let boss = reachable.max(by: { $0.minDepth < $1.minDepth }),
              .random(in: 0..<1) < 0.3 else { return }
        spawnFish(boss)
        bossSpawnedThisDive = true
    }

    // MARK: public controls

    func startDive() {
        guard phase == .surface, let state else { return }
        phase = .diving
        state.phase = .diving
        state.bagCount = 0
        hooked = []
        gemsWon = 0
        fightsWon = 0
        mineHits = 0
        stunUntil = 0
        hook.position = CGPoint(x: boat.position.x + rodTipOffset.x, y: -20)
        hook.isHidden = false
        hookTrail = []
        maxDepthThisDive = 0
        state.consumeBaitForDive()
        rebuildHook() // hook size tracks upgrade level
        state.joyX = 0
        state.joyY = 0
        // fresh world every dive: new terrain layout, hazards, fish and dens
        hazardLayer.removeAllChildren() // before terrain — dens drop chests into this layer
        generateTerrain()
        populateHazards()
        fishLayer.removeAllChildren()
        removeAction(forKey: "respawn")
        populateFish()
        maybeSpawnBoss(state: state)
    }

    func startReel() {
        guard phase == .diving else { return }
        phase = .reeling
        state?.phase = .reeling
    }

    // MARK: frame update

    override func update(_ currentTime: TimeInterval) {
        var dt = lastTime == 0 ? 0 : min(currentTime - lastTime, 1 / 30)
        lastTime = currentTime
        guard let state, dt > 0 else { return }
        if currentTime < slowmoUntil { dt *= 0.3 } // mythic reveal slow-mo

        moveFish(dt: CGFloat(dt))

        switch phase {
        case .surface:
            break
        case .diving:
            updateDiving(dt: CGFloat(dt), state: state, now: currentTime)
        case .fighting:
            updateFight(dt: CGFloat(dt), state: state)
        case .reeling:
            updateReeling(dt: CGFloat(dt), state: state)
        }

        updateLine()
        updateCamera()
        state.depthMeters = max(0, Int(-hook.position.y / ptPerMeter))
        maxDepthThisDive = max(maxDepthThisDive, state.depthMeters)
    }

    private func updateDiving(dt: CGFloat, state: GameState, now: TimeInterval) {
        // full 2D joystick drive; idle = hover
        // vertical crawl ~8 m/s so 1000m takes ~2 min; horizontal stays nimble
        let stunned = now < stunUntil
        let vSpeed: CGFloat = stunned ? 0 : 50
        // ponytail: reel track doubles as the horizontal-thrust upgrade — lvl1 ≈ old 130, lvl10 = 400.
        // Vertical descent untouched so 1000m stays ~2 min.
        let reelLvl = CGFloat(state.levels[.reel] ?? 1)
        let hSpeed: CGFloat = stunned ? 0 : 130 + (reelLvl - 1) * 30
        var pos = hook.position
        pos.y -= (stunned ? 10 : 0) * dt
        pos.x += CGFloat(state.joyX) * hSpeed * dt
        pos.y += CGFloat(state.joyY) * vSpeed * dt
        pos.x = min(max(pos.x, -worldHalfWidth), worldHalfWidth)
        pos.y = min(max(pos.y, -state.maxDepthMeters * ptPerMeter), -10)
        // solid formations: push the hook out so it slides around rocks/coral
        for ob in obstacles {
            let dx = pos.x - ob.center.x, dy = pos.y - ob.center.y
            let d = hypot(dx, dy)
            let minD = ob.radius + 14
            if d < minD {
                let ux = d > 1 ? dx / d : 0, uy = d > 1 ? dy / d : -1
                pos.x = ob.center.x + ux * minD
                pos.y = ob.center.y + uy * minD
            }
        }
        hook.position = pos

        if !stunned {
            checkHazards(state: state, now: now)
            if now >= catchGraceUntil { checkCatches(state: state) }
        }

        if hooked.count >= state.bagCapacity {
            startReel()
        }
    }

    private func updateReeling(dt: CGFloat, state: GameState) {
        hook.position.y += state.reelSpeed * dt
        hook.position.x += (boat.position.x + rodTipOffset.x - hook.position.x) * 2 * dt
        if hook.position.y >= -20 {
            hook.position.y = -20
            finishDive(state: state)
        }
    }

    private func checkHazards(state: GameState, now: TimeInterval) {
        for node in hazardLayer.children {
            guard let kind = node.userData?["hazard"] as? String else { continue }
            let d = hypot(node.position.x - hook.position.x, node.position.y - hook.position.y)
            guard d < 40 else { continue }

            if kind == "chest" {
                let coins = Int.random(in: 60...200)
                let gems = Int.random(in: 0...3)
                state.coins += coins
                state.gems += gems
                state.catchToast = .init(speciesId: "chest",
                                         name: gems > 0 ? "Treasure! +\(coins) sand dollars, +\(gems) gems"
                                                        : "Treasure! +\(coins) sand dollars")
                sfx("sfx_win")
                haptic(.medium)
                node.removeFromParent()
                continue
            }
            if kind == "jelly" {
                stunUntil = now + 1.5
                node.run(.sequence([.scale(to: 1.4, duration: 0.1), .scale(to: 1, duration: 0.2)]))
                // one fish escapes the bag and swims off
                if let (_, sp) = hooked.popLast() {
                    state.bagCount = hooked.count
                    let escapee = spriteOrPlaceholder(sp.id, width: sp.size)
                    escapee.position = hook.position
                    fishLayer.addChild(escapee)
                    escapee.run(.sequence([
                        .group([.moveBy(x: .random(in: 150...260) * (Bool.random() ? 1 : -1),
                                        y: .random(in: -80...40), duration: 0.7),
                                .fadeOut(withDuration: 0.7)]),
                        .removeFromParent(),
                    ]))
                }
            } else { // mine
                mineHits += 1
                sfx("sfx_boom")
                haptic(.heavy)
                state.mineFlash += 1 // red edge flash in the SwiftUI layer
                cameraNode.run(.sequence((0..<6).map { _ in
                    .moveBy(x: .random(in: -14...14), y: .random(in: -14...14), duration: 0.04)
                }))
                let boom = SKLabelNode(text: "💥")
                boom.fontSize = 60
                boom.position = node.position
                addChild(boom)
                boom.run(.sequence([.scale(to: 1.6, duration: 0.25), .fadeOut(withDuration: 0.2), .removeFromParent()]))
                node.removeFromParent()
                if mineHits >= 2 {
                    // line snaps: lose everything, dive over
                    for (n, _) in hooked { n.removeFromParent() }
                    hooked = []
                    state.bagCount = 0
                    startReel()
                    return
                }
            }
        }
    }

    private func checkCatches(state: GameState) {
        guard hooked.count < state.bagCapacity else { return }
        for node in fishLayer.children {
            guard let id = node.userData?["id"] as? String,
                  let sp = species(for: id) else { continue }
            let d = hypot(node.position.x - hook.position.x, node.position.y - hook.position.y)
            guard d < 30 + sp.size / 2 else { continue }
            guard sp.hookReq <= state.hookStrength else {
                node.run(.moveBy(x: node.xScale < 0 ? 220 : -220, y: -40, duration: 0.4))
                continue
            }
            // commons/uncommons auto-catch; rare+ get the tension fight, harder by rarity
            if sp.rarity >= .rare {
                startFight(node, species: sp, state: state)
                return
            }
            snag(node, species: sp, state: state)
            // one fish per bite: schools cluster tightly, so without this pause the
            // hook vacuums a whole school (and the bag) in a single frame
            catchGraceUntil = lastTime + 0.4
            return
        }
    }

    private func snag(_ fish: SKNode, species sp: FishSpecies, state: GameState) {
        // fly-to-bag: fish arcs up to the bag counter (top-right of screen) and pops
        fish.userData?["vx"] = nil
        fish.userData?["vy"] = nil
        fish.removeAllActions()
        fish.zPosition = 20
        let bagTarget = convert(CGPoint(x: size.width / 2 - 130, y: size.height / 2 - 40), from: cameraNode)
        let arc = SKAction.sequence([
            .group([.move(to: hook.position, duration: 0.1), .scale(to: 0.8, duration: 0.1)]),
            .group([.move(to: bagTarget, duration: 0.45), .scale(to: 0.25, duration: 0.45)]),
            .removeFromParent(),
        ])
        arc.timingMode = .easeIn
        fish.run(arc)
        catchBurst(at: hook.position)
        catchPop(at: hook.position, species: sp)
        hooked.append((fish, sp))
        run(.sequence([.wait(forDuration: 0.55), .run { [weak state] in
            state?.bagCount += 1 // pop the counter when the fish lands in the bag
        }]))
        sfx("sfx_catch")
        haptic(.light)

        if !sp.isBoss {
            run(.sequence([.wait(forDuration: 4), .run { [weak self] in
                self?.spawnFish(sp)
            }]))
        }
    }

    /// "CATCH!" pop + coin shower at the hook; rare+ get bigger text and more coins.
    private func catchPop(at p: CGPoint, species sp: FishSpecies) {
        let label = SKLabelNode(text: "CATCH!")
        label.fontName = "Fredoka-Bold"
        label.fontSize = sp.rarity >= .rare ? 34 : 24
        label.fontColor = SKColor(red: 0.96, green: 0.82, blue: 0.47, alpha: 1)
        label.position = CGPoint(x: p.x, y: p.y + 40)
        label.zPosition = 30
        label.setScale(0.3)
        addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.18), .moveBy(x: 0, y: 22, duration: 0.6)]),
            .fadeOut(withDuration: 0.25),
            .removeFromParent(),
        ]))
        let coins = sp.rarity >= .rare ? 8 : 4
        for _ in 0..<coins {
            let c = SKShapeNode(circleOfRadius: .random(in: 3...5))
            c.fillColor = SKColor(red: 0.96, green: 0.82, blue: 0.47, alpha: 1)
            c.strokeColor = SKColor(red: 0.78, green: 0.62, blue: 0.28, alpha: 1)
            c.position = p
            c.zPosition = 29
            addChild(c)
            c.run(.sequence([
                .group([.moveBy(x: .random(in: -50...50), y: .random(in: 30...80), duration: 0.5),
                        .fadeOut(withDuration: 0.5)]),
                .removeFromParent(),
            ]))
        }
    }

    private func finishDive(state: GameState) {
        let haul = hooked.map { CaughtFish(species: $0.species) }
        for (node, _) in hooked { node.removeFromParent() }
        hooked = []
        // clear any leftover boss so it doesn't linger across dives
        for node in fishLayer.children {
            if let id = node.userData?["id"] as? String, species(for: id)?.isBoss == true {
                node.removeFromParent()
            }
        }
        phase = .surface
        hook.isHidden = true
        // records feed achievements + local leaderboards
        state.bumpRecord("totalCatches", by: haul.count)
        state.bumpRecord("fightsWon", by: fightsWon)
        state.bumpRecord("mythicsCaught", by: haul.filter { $0.species.rarity == .mythic }.count)
        state.bumpRecord("coinsEarned", by: haul.reduce(0) { $0 + $1.species.value })
        state.maxRecord("deepestDive", maxDepthThisDive)
        state.endDive(haul: haul, gemsWon: gemsWon, fightsWon: fightsWon)
    }

    private func moveFish(dt: CGFloat) {
        let hookActive = phase == .diving
        for node in fishLayer.children {
            guard var vx = node.userData?["vx"] as? CGFloat,
                  var vy = node.userData?["vy"] as? CGFloat,
                  let id = node.userData?["id"] as? String,
                  let sp = species(for: id) else { continue }

            let toHook = CGVector(dx: node.position.x - hook.position.x,
                                  dy: node.position.y - hook.position.y)
            let dist = hypot(toHook.dx, toHook.dy)

            // mythic reveal: brief slow-mo + glow pulse the first time one gets close
            if hookActive, sp.rarity == .mythic, dist < 340, node.userData?["revealed"] == nil {
                node.userData?["revealed"] = true
                slowmoUntil = lastTime + 1.1
                node.run(.sequence([.scale(to: 1.35, duration: 0.3), .scale(to: 1.0, duration: 0.5)]))
                haptic(.heavy)
            }

            // skittish rares: flee sooner and faster — approach slow or lose them
            let fleeRange: CGFloat = sp.rarity >= .rare ? 170 : 70
            let fleeSpeed: CGFloat = sp.rarity >= .rare ? min(sp.speed * 1.6, 220) : min(sp.speed * 1.2, 150)
            if hookActive && dist < fleeRange {
                vx = toHook.dx / max(dist, 1) * fleeSpeed
                vy = toHook.dy / max(dist, 1) * fleeSpeed
            } else {
                // free 2D wander: heading drifts randomly, speed stays ~species speed
                var heading = atan2(vy, vx)
                heading += CGFloat.random(in: -2.6...2.6) * dt
                if Int.random(in: 0..<240) == 0 { heading = .random(in: 0...(2 * .pi)) }
                // burst-glide: kick then coast, like real fish — not a constant cruise
                let ph = node.userData?["ph"] as? CGFloat ?? 0
                let pulse = 0.55 + 0.45 * pow(sin(CGFloat(lastTime) * 2.2 + ph), 2)
                vx = cos(heading) * sp.speed * pulse
                vy = sin(heading) * sp.speed * pulse // full vertical freedom
            }

            // schooling: commons drift gently toward their school anchor
            if let sx = node.userData?["schoolX"] as? CGFloat,
               let sy = node.userData?["schoolY"] as? CGFloat {
                vx += (sx - node.position.x) * 0.06 * dt * 60
                vy += (sy - node.position.y) * 0.06 * dt * 60
                vx = min(max(vx, -sp.speed * 1.4), sp.speed * 1.4)
                vy = min(max(vy, -sp.speed * 1.4), sp.speed * 1.4)
            }

            // depth currents: alternating horizontal drift per 250m band — ambience
            let band = Int(min(3, max(0, -node.position.y / (250 * ptPerMeter))))
            node.position.x += [14.0, -11.0, 9.0, -13.0][band] * dt

            // loose home band: free roam, but drift back when far outside it
            let bandTop = -sp.minDepth * ptPerMeter
            let bandBottom = -sp.maxDepth * ptPerMeter
            let slack: CGFloat = 60 * ptPerMeter // ponytail: one slack for all species, tune if deep fish surface
            if node.position.y > bandTop { vy -= sp.speed * min((node.position.y - bandTop) / slack, 1.5) }
            if node.position.y < bandBottom { vy += sp.speed * min((bandBottom - node.position.y) / slack, 1.5) }

            node.userData?["vx"] = vx
            node.userData?["vy"] = vy
            node.position.x += vx * dt
            node.position.y += vy * dt
            if abs(vx) > 4 { node.xScale = abs(node.xScale) * (vx > 0 ? -1 : 1) }
            // pitch the body toward the direction of travel (nose up when climbing)
            let facing: CGFloat = node.xScale < 0 ? 1 : -1
            let pitch = atan2(vy, abs(vx) + 30) * 0.55
            node.zRotation += (pitch * facing - node.zRotation) * min(1, 6 * dt)

            // soft side edges: swim past the border, then get nudged back — no teleport
            if node.position.x > fishHalfWidth { node.userData?["vx"] = -abs(vx) }
            if node.position.x < -fishHalfWidth { node.userData?["vx"] = abs(vx) }
            node.position.y = min(max(node.position.y, -Self.floorDepthPts), -30)
        }
    }

    private var hookTrail: [CGPoint] = []
    private let maxTrailPoints = 50
    private var maxDepthThisDive = 0

    private func updateLine() {
        let path = CGMutablePath()
        // named rodTip node in the modular boat — glued through bob and roll
        let rodTip = boatUnit?.rodTipWorldPosition(in: self) ?? convert(rodTipOffset, from: boat)
        let hookEye = CGPoint(x: hook.position.x, y: hook.position.y + 20)

        // trail of recent hook positions so loops in the dive path show in the line
        if phase == .diving {
            if let last = hookTrail.last {
                if hypot(hookEye.x - last.x, hookEye.y - last.y) > 8 { hookTrail.append(hookEye) }
            } else {
                hookTrail.append(hookEye)
            }
            if hookTrail.count > maxTrailPoints { hookTrail.removeFirst(hookTrail.count - maxTrailPoints) }
        } else if !hookTrail.isEmpty {
            // reeling/surface: collapse the trail smoothly from the oldest end
            hookTrail.removeFirst(min(3, hookTrail.count))
        }

        path.move(to: rodTip)
        if hookTrail.count > 1 {
            // sag from the rod down to the start of the trail, then trace the actual path
            let first = hookTrail[0]
            let mid = CGPoint(x: (rodTip.x + first.x) / 2, y: (rodTip.y + first.y) / 2 - 24)
            path.addQuadCurve(to: first, control: mid)
            for p in hookTrail.dropFirst() { path.addLine(to: p) }
            path.addLine(to: hookEye)
        } else {
            // slight sag so the line reads as rope, not a laser
            let mid = CGPoint(x: (rodTip.x + hookEye.x) / 2, y: (rodTip.y + hookEye.y) / 2 - 24)
            path.addQuadCurve(to: hookEye, control: mid)
        }
        line.path = path
        line.isHidden = hook.isHidden
    }

    private func updateCamera() {
        cameraNode.childNode(withName: "skyBackdrop")?.isHidden = cameraNode.position.y < -80
        // parallax: distant layer follows the camera at 0.4x so it drifts slower than the world
        parallaxLayer.position.x = cameraNode.position.x * 0.4
        let target: CGPoint
        if phase == .surface {
            target = CGPoint(x: 0, y: 40)
        } else {
            target = CGPoint(x: hook.position.x, y: min(hook.position.y + 60, 40))
        }
        let p = cameraNode.position
        cameraNode.position = CGPoint(x: p.x + (target.x - p.x) * 0.1, y: p.y + (target.y - p.y) * 0.1)
        // surface zoom sells boat size. Underwater FOV grows with the hook:
        // lvl 1 = 0.6x (hook reads big, world claustrophobic) -> lvl 10 = 1.2x.
        // Fights punch in tighter for drama.
        let hookLvl = CGFloat(state?.hookStrength ?? 1)
        let fov = 0.6 + (min(hookLvl, 10) - 1) / 9 * 0.6
        let targetScale: CGFloat = switch phase {
        case .surface: layout.surfaceZoom
        case .fighting: fov * 0.8
        default: fov
        }
        let s = cameraNode.xScale
        cameraNode.setScale(s + (targetScale - s) * 0.08)
    }

    // MARK: tension fight

    // tension mini-game state
    private var fightZoneCenter: CGFloat = 0.5
    private var fightZoneWidth: CGFloat = 0.4
    private var fightStamina: CGFloat = 1
    private var fightTime: CGFloat = 0
    private var nextSpikeAt: CGFloat = 2
    private var spikeUntil: CGFloat = 0

    /// Difficulty knobs per rarity: green-zone width, zone drift speed, spike frequency.
    private func fightTuning(_ r: Rarity) -> (zone: CGFloat, drift: CGFloat, spikeEvery: CGFloat) {
        switch r {
        case .rare:      return (0.45, 0.5, 4.0)
        case .epic:      return (0.36, 0.8, 3.0)
        case .legendary: return (0.28, 1.1, 2.2)
        case .mythic:    return (0.22, 1.4, 1.8)
        case .boss:      return (0.20, 1.6, 1.5)
        default:         return (0.50, 0.4, 5.0)
        }
    }

    private func startFight(_ fish: SKNode, species sp: FishSpecies, state: GameState) {
        phase = .fighting
        fightFish = fish
        fightSpecies = sp
        fightTension = 0
        fightProgress = 0
        redlineTime = 0
        fightTime = 0
        fightStamina = 1
        let tune = fightTuning(sp.rarity)
        fightZoneWidth = tune.zone
        fightZoneCenter = 0.5
        nextSpikeAt = tune.spikeEvery
        spikeUntil = 0
        fish.userData?["vx"] = nil
        fish.userData?["vy"] = nil
        fish.removeAllActions()
        state.fightTension = 0
        state.fightProgress = 0
        state.fightPulling = false
        state.fightZoneCenter = 0.5
        state.fightZoneWidth = Double(tune.zone)
        state.fightStamina = 1
        state.fightFishName = sp.name
        state.fightIsBoss = sp.isBoss
        state.phase = .fighting

        fish.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.3, duration: 0.12),
            .rotate(toAngle: -0.3, duration: 0.12),
        ])), withKey: "thrash")
    }

    /// Tension mini-game: hold to raise tension, release to drop it. Keep the needle
    /// inside the drifting green zone to reel; red spikes shove tension up — let go or snap.
    private func updateFight(dt: CGFloat, state: GameState) {
        guard let fish = fightFish, let sp = fightSpecies else { return }
        let tune = fightTuning(sp.rarity)
        fightTime += dt

        // red spike: fish surges, tension gets shoved upward
        if fightTime >= nextSpikeAt && spikeUntil <= fightTime {
            spikeUntil = fightTime + .random(in: 0.6...1.0)
            nextSpikeAt = fightTime + tune.spikeEvery + .random(in: -0.4...0.6)
        }
        let spiking = fightTime < spikeUntil
        state.fightPulling = spiking

        // green zone drifts; exhausted fish = wider zone, slower drift
        let exhausted = fightStamina <= 0
        let driftSpeed = tune.drift * (exhausted ? 0.4 : 1)
        fightZoneCenter = 0.5 + sin(fightTime * driftSpeed) * 0.28
        let zoneW = fightZoneWidth * (exhausted ? 1.7 : 1)

        // needle physics
        let hookBoost = 1 + 0.1 * CGFloat(state.hookStrength - 1)
        if state.fightHolding {
            fightTension += 1.05 * dt
        } else {
            fightTension -= 1.35 * dt
        }
        if spiking { fightTension += 0.85 * dt }
        fightTension = min(max(fightTension, 0), 1.15)

        // progress fills while the needle sits in the green zone
        let inZone = abs(fightTension - fightZoneCenter) < zoneW / 2
        if inZone {
            fightProgress += 0.22 * dt * hookBoost
            fightStamina -= 0.1 * dt // fish tires while you play it right
        } else {
            fightProgress -= 0.05 * dt
        }
        fightProgress = min(max(fightProgress, 0), 1)
        fightStamina = max(fightStamina, 0)

        fish.position = CGPoint(
            x: hook.position.x + (spiking ? .random(in: -7...7) : 0),
            y: hook.position.y - 40)

        // line snap: pegged tension during (or right after) a spike
        if fightTension >= 1 {
            redlineTime += dt
            if redlineTime > 0.65 { loseFight(state: state); return }
        } else {
            redlineTime = 0
        }

        if fightProgress >= 1 { winFight(species: sp, state: state) }

        state.fightTension = Double(fightTension)
        state.fightProgress = Double(fightProgress)
        state.fightZoneCenter = Double(fightZoneCenter)
        state.fightZoneWidth = Double(zoneW)
        state.fightStamina = Double(fightStamina)
    }

    private func winFight(species sp: FishSpecies, state: GameState) {
        guard let fish = fightFish else { return }
        fish.removeAction(forKey: "thrash")
        fish.zRotation = 0
        gemsWon += sp.gemReward
        fightsWon += 1
        sfx("sfx_win")
        haptic(.heavy)
        // big-catch drama: shake, and a beat of slow-mo for legendary+
        cameraNode.run(.sequence((0..<4).map { _ in
            .moveBy(x: .random(in: -8...8), y: .random(in: -8...8), duration: 0.04)
        }))
        if sp.rarity >= .legendary { slowmoUntil = lastTime + 0.8 }
        endFight(state: state)
        snag(fish, species: sp, state: state)
        if hooked.count >= state.bagCapacity { startReel() }
    }

    private func loseFight(state: GameState) {
        sfx("sfx_snap")
        haptic(.rigid)
        // line-snap kick
        cameraNode.run(.sequence((0..<5).map { _ in
            .moveBy(x: .random(in: -11...11), y: .random(in: -11...11), duration: 0.04)
        }))
        if let fish = fightFish {
            fish.removeAction(forKey: "thrash")
            fish.zRotation = 0
            fish.run(.sequence([
                .moveBy(x: fish.xScale < 0 ? 350 : -350, y: -60, duration: 0.5),
                .removeFromParent(),
            ]))
            if let sp = fightSpecies, !sp.isBoss {
                run(.sequence([.wait(forDuration: 4), .run { [weak self] in
                    self?.spawnFish(sp)
                }]))
            }
        }
        endFight(state: state)
    }

    private func endFight(state: GameState) {
        catchGraceUntil = lastTime + 1.0 // breather so fights don't chain instantly
        fightFish = nil
        fightSpecies = nil
        state.fightHolding = false
        phase = .diving
        state.phase = .diving
    }
}
