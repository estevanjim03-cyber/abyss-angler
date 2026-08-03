import SpriteKit

// MARK: - Modular boat: hull + deck + rod mount + rod + captain + detail,
// composed from separate PNGs with styled vector fallbacks.

struct HullLayout {
    let id: String
    let size: CGSize
    let deckPosition: CGPoint
    let rodMountPosition: CGPoint
    let captainSeatPosition: CGPoint
    let waterlineOffset: CGFloat
    // composition extras
    let rodWidth: CGFloat
    let rodTipOffset: CGPoint       // where the line leaves the rod, in hull coords
    let captainWidth: CGFloat
    let surfaceZoom: CGFloat        // camera zoom-out at the surface — sells scale
    let legacyAsset: String?        // existing full-boat PNG reused as hull+deck art
}

struct RodPart { let id: String; let name: String }
struct DeckPart { let id: String; let name: String }
struct CaptainPart { let id: String; let name: String }
struct DetailPart { let id: String; let name: String }

let allRodParts = [
    RodPart(id: "rod_bamboo", name: "Bamboo Rod"),
    RodPart(id: "rod_fiberglass", name: "Fiberglass Rod"),
    RodPart(id: "rod_graphite", name: "Graphite Rod"),
    RodPart(id: "rod_trolling", name: "Deep-Sea Trolling Rod"),
]
let allDeckParts = [
    DeckPart(id: "deck_open", name: "Open Deck"),
    DeckPart(id: "deck_cabin", name: "Small Cabin"),
    DeckPart(id: "deck_console", name: "Center Console"),
    DeckPart(id: "deck_wheelhouse", name: "Wheelhouse"),
    DeckPart(id: "deck_longboat", name: "Longboat Deck"),
]
let allCaptainParts = [
    CaptainPart(id: "captain_casual", name: "Casual Angler"),
    CaptainPart(id: "captain_raincoat", name: "Raincoat Angler"),
    CaptainPart(id: "captain_abyss", name: "Abyss Explorer"),
    CaptainPart(id: "captain_viking", name: "Viking Helmsman"),
]
let allDetailParts = [
    DetailPart(id: "detail_net", name: "Fishing Net"),
    DetailPart(id: "detail_crate", name: "Bait Crate"),
    DetailPart(id: "detail_lantern", name: "Deck Lantern"),
    DetailPart(id: "detail_antenna", name: "Radio Antenna"),
    DetailPart(id: "detail_flag", name: "Pennant Flag"),
    DetailPart(id: "detail_figurehead", name: "Carved Figurehead"),
]

/// Hull tiers. skiff + sportfisher reuse the existing full-boat PNGs as their art.
let hullLayouts: [String: HullLayout] = [
    // stage-1 modular flats skiff: bare hull + console/motor/platform modules from the sprite sheet
    "flats": HullLayout(
        id: "flats", size: CGSize(width: 260, height: 36),
        deckPosition: CGPoint(x: 6, y: 58), rodMountPosition: CGPoint(x: 64, y: 30),
        captainSeatPosition: CGPoint(x: 32, y: 38), waterlineOffset: 10,
        rodWidth: 90, rodTipOffset: CGPoint(x: 150, y: 90), captainWidth: 40,
        surfaceZoom: 1.15, legacyAsset: nil),
    "skiff": HullLayout(
        id: "skiff", size: CGSize(width: 200, height: 90),
        deckPosition: CGPoint(x: -10, y: 30), rodMountPosition: CGPoint(x: 58, y: 40),
        captainSeatPosition: CGPoint(x: 4, y: 58), waterlineOffset: 26,
        rodWidth: 78, rodTipOffset: CGPoint(x: 108, y: 74), captainWidth: 42,
        surfaceZoom: 1.15, legacyAsset: "boat_classic"),
    "runabout": HullLayout(
        id: "runabout", size: CGSize(width: 260, height: 100),
        deckPosition: CGPoint(x: -20, y: 40), rodMountPosition: CGPoint(x: 82, y: 48),
        captainSeatPosition: CGPoint(x: 10, y: 66), waterlineOffset: 30,
        rodWidth: 92, rodTipOffset: CGPoint(x: 140, y: 92), captainWidth: 48,
        surfaceZoom: 1.2, legacyAsset: nil),
    "console": HullLayout(
        id: "console", size: CGSize(width: 340, height: 138),
        deckPosition: CGPoint(x: -10, y: 52), rodMountPosition: CGPoint(x: 118, y: 58),
        captainSeatPosition: CGPoint(x: 44, y: 62), waterlineOffset: 34,
        rodWidth: 116, rodTipOffset: CGPoint(x: 186, y: 118), captainWidth: 56,
        surfaceZoom: 1.3, legacyAsset: nil),
    "sportfisher": HullLayout(
        id: "sportfisher", size: CGSize(width: 640, height: 260),
        deckPosition: CGPoint(x: 0, y: 99), rodMountPosition: CGPoint(x: 244, y: 148),
        captainSeatPosition: CGPoint(x: 178, y: 138), waterlineOffset: 99,
        rodWidth: 210, rodTipOffset: CGPoint(x: 336, y: 218), captainWidth: 88,
        surfaceZoom: 1.5, legacyAsset: "boat_viking"),
    "longboat": HullLayout(
        id: "longboat", size: CGSize(width: 560, height: 180),
        deckPosition: CGPoint(x: 0, y: 66), rodMountPosition: CGPoint(x: 190, y: 80),
        captainSeatPosition: CGPoint(x: 90, y: 104), waterlineOffset: 56,
        rodWidth: 180, rodTipOffset: CGPoint(x: 290, y: 170), captainWidth: 76,
        surfaceZoom: 1.45, legacyAsset: nil),
]

/// Maps the legacy shop ids (save data) onto hull tiers. Save format unchanged.
/// Starter boat renders as the new center-console hull art.
func hullId(forBoat boatId: String) -> String {
    switch boatId {
    case "boat_viking": return "sportfisher"
    default: return "flats" // stage-1 modular skiff is the starter
    }
}

final class ModularBoatNode: SKNode {
    let layout: HullLayout
    private let rodTipNode = SKNode()

    /// extraModules: (asset, position in hull coords, width, zPosition) — used by
    /// sheet-based hulls where upgrade tiers swap consoles/motors/platforms.
    init(layout: HullLayout, rodAsset: String, captainAsset: String,
         deckId: String?, detailId: String?,
         extraModules: [(id: String, pos: CGPoint, width: CGFloat, z: CGFloat)] = []) {
        self.layout = layout
        super.init()

        // hull (+deck baked in when we're reusing a legacy full-boat PNG)
        // UIImage probe: SKTexture(imageNamed:) returns a red-X placeholder for
        // missing assets, so its size is useless as an existence check
        let hullTex = UIImage(named: "hull_\(layout.id)").map { SKTexture(image: $0) }
        let legacyTex = layout.legacyAsset.flatMap { UIImage(named: $0) }.map { SKTexture(image: $0) }
        if let hullTex {
            addModule(texture: hullTex, width: layout.size.width, at: CGPoint(x: 0, y: layout.waterlineOffset), z: 0)
            if let deckId { addDeck(deckId) }
        } else if let legacyTex {
            addModule(texture: legacyTex, width: layout.size.width, at: CGPoint(x: 0, y: layout.waterlineOffset), z: 0)
            // legacy art includes its deck — skip the deck module
        } else {
            addChild(Self.fallbackHull(layout))
            if let deckId { addDeck(deckId) }
        }

        // rod mount + rod, tip exposed as a named node for exact line attachment
        let rod = Self.sprite(rodAsset, width: layout.rodWidth)
            ?? Self.fallbackRod(width: layout.rodWidth)
        rod.xScale = -abs(rod.xScale) // art tip points up-left; stern rod points up-right
        rod.position = layout.rodMountPosition
        rod.zPosition = 1
        addChild(rod)
        rodTipNode.name = "rodTip"
        // auto-derive the tip from the rod art's actual bounds (top-outer corner,
        // stern rod points up-right after the flip) — correct for every rod tier
        let rf = rod.calculateAccumulatedFrame()
        rodTipNode.position = CGPoint(x: rf.maxX - rf.width * 0.05, y: rf.maxY - rf.height * 0.04)
        addChild(rodTipNode)

        // captain seated on the deck
        let cap = Self.sprite(captainAsset, width: layout.captainWidth)
            ?? Self.fallbackCaptain(width: layout.captainWidth)
        cap.position = layout.captainSeatPosition
        cap.zPosition = 0.9
        addChild(cap)

        // optional detail prop
        if let detailId, let d = Self.sprite(detailId, width: layout.size.width * 0.14) {
            d.position = CGPoint(x: -layout.size.width * 0.3, y: layout.waterlineOffset + 8)
            d.zPosition = 0.8
            addChild(d)
        }

        for m in extraModules {
            guard let s = Self.sprite(m.id, width: m.width) else { continue }
            s.position = m.pos
            s.zPosition = m.z
            addChild(s)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// World-space rod tip — follows bob and roll exactly.
    func rodTipWorldPosition(in scene: SKNode) -> CGPoint {
        scene.convert(rodTipNode.position, from: self)
    }

    private func addDeck(_ deckId: String) {
        guard let deck = Self.sprite(deckId, width: layout.size.width * 0.45) else { return }
        deck.position = layout.deckPosition
        deck.zPosition = 0.5
        addChild(deck)
    }

    private func addModule(texture: SKTexture, width: CGFloat, at p: CGPoint, z: CGFloat) {
        let node = SKSpriteNode(texture: texture)
        let scale = width / texture.size().width
        node.size = CGSize(width: width, height: texture.size().height * scale)
        node.position = p
        node.zPosition = z
        // sheet hulls are drawn bow-right; game convention is stern-right
        if layout.id == "flats" { node.xScale = -1 }
        addChild(node)
    }

    private static func sprite(_ name: String, width: CGFloat) -> SKSpriteNode? {
        guard let img = UIImage(named: name) else { return nil }
        let tex = SKTexture(image: img)
        let node = SKSpriteNode(texture: tex)
        let scale = width / tex.size().width
        node.size = CGSize(width: width, height: tex.size().height * scale)
        return node
    }

    // MARK: - Styled vector fallbacks (soft shading, per-tier silhouettes)

    private static let woodDark = SKColor(red: 0.34, green: 0.25, blue: 0.19, alpha: 1)
    private static let wood = SKColor(red: 0.48, green: 0.36, blue: 0.28, alpha: 1)
    private static let brass = SKColor(red: 0.78, green: 0.61, blue: 0.37, alpha: 1)
    private static let fiberglass = SKColor(red: 0.92, green: 0.93, blue: 0.94, alpha: 1)
    private static let navy = SKColor(red: 0.10, green: 0.18, blue: 0.21, alpha: 1)

    /// Distinct hull silhouette per tier — soft two-tone shading, not flat rectangles.
    static func fallbackHull(_ layout: HullLayout) -> SKNode {
        let node = SKNode()
        let w = layout.size.width
        let h = layout.size.height * 0.5
        let y = layout.waterlineOffset

        let path = CGMutablePath()
        switch layout.id {
        case "runabout", "console":
            // smooth fiberglass sheer line with raked bow
            path.move(to: CGPoint(x: -w / 2, y: y))
            path.addQuadCurve(to: CGPoint(x: w * 0.42, y: y + h * 0.28),
                              control: CGPoint(x: 0, y: y + h * 0.1))
            path.addLine(to: CGPoint(x: w / 2, y: y + h * 0.42))
            path.addLine(to: CGPoint(x: w * 0.36, y: y - h * 0.5))
            path.addQuadCurve(to: CGPoint(x: -w * 0.4, y: y - h * 0.5),
                              control: CGPoint(x: 0, y: y - h * 0.85))
            path.closeSubpath()
        case "longboat":
            // long low hull, both ends sweep up (carved prow)
            path.move(to: CGPoint(x: -w / 2, y: y + h * 0.55))
            path.addQuadCurve(to: CGPoint(x: 0, y: y - h * 0.1),
                              control: CGPoint(x: -w * 0.25, y: y - h * 0.05))
            path.addQuadCurve(to: CGPoint(x: w / 2, y: y + h * 0.7),
                              control: CGPoint(x: w * 0.25, y: y - h * 0.05))
            path.addLine(to: CGPoint(x: w * 0.4, y: y - h * 0.45))
            path.addQuadCurve(to: CGPoint(x: -w * 0.4, y: y - h * 0.45),
                              control: CGPoint(x: 0, y: y - h * 0.7))
            path.closeSubpath()
        default:
            // flat-bottom skiff / generic
            path.move(to: CGPoint(x: -w / 2, y: y + h * 0.2))
            path.addLine(to: CGPoint(x: w / 2, y: y + h * 0.25))
            path.addLine(to: CGPoint(x: w * 0.38, y: y - h * 0.4))
            path.addLine(to: CGPoint(x: -w * 0.38, y: y - h * 0.4))
            path.closeSubpath()
        }

        let isWood = layout.id == "skiff" || layout.id == "longboat"
        let hull = SKShapeNode(path: path)
        hull.fillColor = isWood ? wood : fiberglass
        hull.strokeColor = isWood ? woodDark : navy
        hull.lineWidth = 2.5
        node.addChild(hull)

        // soft shading band along the bottom (reads as curvature, not flat fill)
        let shade = SKShapeNode(path: path)
        shade.fillColor = .black
        shade.alpha = 0.16
        shade.strokeColor = .clear
        shade.yScale = 0.45
        shade.position = CGPoint(x: 0, y: y * -0.1)
        node.addChild(shade)

        // trim stripe: brass on wood, navy on fiberglass
        let trim = SKShapeNode(rectOf: CGSize(width: w * 0.86, height: 3))
        trim.fillColor = isWood ? brass : navy
        trim.strokeColor = .clear
        trim.position = CGPoint(x: 0, y: y + 2)
        node.addChild(trim)

        // wood grain lines for wooden tiers
        if isWood {
            for i in 0..<3 {
                let grain = SKShapeNode(rectOf: CGSize(width: w * 0.7, height: 1))
                grain.fillColor = woodDark.withAlphaComponent(0.45)
                grain.strokeColor = .clear
                grain.position = CGPoint(x: 0, y: y - CGFloat(6 + i * 7))
                node.addChild(grain)
            }
        }
        // dragon prow hint for the longboat
        if layout.id == "longboat" {
            let prow = SKShapeNode(circleOfRadius: w * 0.03)
            prow.fillColor = woodDark
            prow.strokeColor = brass
            prow.lineWidth = 1.5
            prow.position = CGPoint(x: w / 2, y: y + h * 0.78)
            node.addChild(prow)
        }
        return node
    }

    static func fallbackRod(width: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(color: .clear, size: CGSize(width: width, height: width * 1.4))
        let stick = SKShapeNode(rectOf: CGSize(width: width * 0.05, height: width * 1.35), cornerRadius: width * 0.02)
        stick.fillColor = brass
        stick.strokeColor = woodDark
        stick.lineWidth = 1
        stick.zRotation = -0.45
        node.addChild(stick)
        let reel = SKShapeNode(circleOfRadius: width * 0.07)
        reel.fillColor = navy
        reel.strokeColor = brass
        reel.lineWidth = 1.5
        reel.position = CGPoint(x: -width * 0.12, y: -width * 0.35)
        node.addChild(reel)
        return node
    }

    static func fallbackCaptain(width: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(color: .clear, size: CGSize(width: width, height: width * 1.6))
        let body = SKShapeNode(rectOf: CGSize(width: width * 0.7, height: width * 0.9), cornerRadius: width * 0.25)
        body.fillColor = navy
        body.strokeColor = woodDark
        body.lineWidth = 1
        body.position = CGPoint(x: 0, y: -width * 0.2)
        node.addChild(body)
        let head = SKShapeNode(circleOfRadius: width * 0.26)
        head.fillColor = SKColor(red: 0.85, green: 0.72, blue: 0.58, alpha: 1) // skin, not silhouette
        head.strokeColor = woodDark
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: width * 0.42)
        node.addChild(head)
        let hat = SKShapeNode(rectOf: CGSize(width: width * 0.55, height: width * 0.16), cornerRadius: width * 0.06)
        hat.fillColor = navy
        hat.strokeColor = brass
        hat.lineWidth = 1
        hat.position = CGPoint(x: 0, y: width * 0.62)
        node.addChild(hat)
        return node
    }
}
