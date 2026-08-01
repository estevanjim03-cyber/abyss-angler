import Foundation
import Observation

// MARK: - Fish data

enum Rarity: Int, Codable, Comparable, CaseIterable {
    case common = 0, uncommon, rare, epic, legendary, mythic, boss
    static func < (l: Rarity, r: Rarity) -> Bool { l.rawValue < r.rawValue }

    var label: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        case .mythic: return "Mythic"
        case .boss: return "Boss"
        }
    }
    var stars: Int { rawValue + 1 }
    /// aquarium coins/min
    var incomePerMin: Int {
        switch self {
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 4
        case .epic: return 8
        case .legendary: return 20
        case .mythic: return 50
        case .boss: return 100
        }
    }
}

struct FishSpecies: Identifiable {
    let id: String       // also the sprite asset name
    let name: String
    let rarity: Rarity
    let value: Int       // coins when sold
    let hookReq: Int     // min hook-strength level to snag
    let minDepth: CGFloat // meters
    let maxDepth: CGFloat
    let speed: CGFloat   // points/sec swim speed
    let size: CGFloat    // sprite width in points
    var isBig = false    // triggers tension fight
    var gemReward = 0    // gems on winning the fight
    var isBoss = false
}

let allFish: [FishSpecies] = [
    // Zone 1 — Tropical Shallows 0–250m
    FishSpecies(id: "sergeantmajor", name: "Sergeant Major", rarity: .common,   value: 5,   hookReq: 1, minDepth: 12,  maxDepth: 65,  speed: 80,  size: 40),
    FishSpecies(id: "wrasse",        name: "Rainbow Wrasse", rarity: .common,   value: 7,   hookReq: 1, minDepth: 20,  maxDepth: 75,  speed: 70,  size: 42),
    FishSpecies(id: "butterflyfish", name: "Butterflyfish",  rarity: .uncommon, value: 12,  hookReq: 1, minDepth: 35,  maxDepth: 105, speed: 60,  size: 42),
    FishSpecies(id: "parrotfish",    name: "Parrotfish",     rarity: .uncommon, value: 15,  hookReq: 2, minDepth: 55,  maxDepth: 125, speed: 55,  size: 50),
    FishSpecies(id: "mahi",          name: "Mahi-Mahi",      rarity: .rare,     value: 40,  hookReq: 2, minDepth: 90,  maxDepth: 140, speed: 120, size: 74, isBig: true, gemReward: 1),
    FishSpecies(id: "swordfish",     name: "Swordfish",      rarity: .legendary, value: 120, hookReq: 3, minDepth: 115, maxDepth: 165, speed: 140, size: 95, isBig: true, gemReward: 3),
    FishSpecies(id: "koidragon",     name: "Koi Dragon",     rarity: .mythic,   value: 400, hookReq: 4, minDepth: 140, maxDepth: 240, speed: 160, size: 110, isBig: true, gemReward: 8),
    // Zone 2 — Reef Drop-off 250–600m
    FishSpecies(id: "tuna",          name: "Yellowfin Tuna", rarity: .uncommon, value: 25,  hookReq: 2, minDepth: 140, maxDepth: 275, speed: 110, size: 60),
    FishSpecies(id: "triggerfish",   name: "Triggerfish",    rarity: .uncommon, value: 22,  hookReq: 2, minDepth: 125, maxDepth: 250, speed: 65,  size: 48),
    FishSpecies(id: "barracuda",     name: "Barracuda",      rarity: .rare,     value: 35,  hookReq: 3, minDepth: 150, maxDepth: 325, speed: 130, size: 70),
    FishSpecies(id: "lionfish",      name: "Lionfish",       rarity: .epic,     value: 50,  hookReq: 4, minDepth: 140, maxDepth: 300, speed: 40,  size: 52),
    FishSpecies(id: "grouper",       name: "Goliath Grouper", rarity: .rare,    value: 60,  hookReq: 4, minDepth: 200, maxDepth: 375, speed: 45,  size: 80, isBig: true, gemReward: 1),
    FishSpecies(id: "marlin",        name: "Blue Marlin",    rarity: .epic,     value: 90,  hookReq: 5, minDepth: 225, maxDepth: 375, speed: 150, size: 100, isBig: true, gemReward: 2),
    FishSpecies(id: "ghostshark",    name: "Ghost Shark",    rarity: .mythic,   value: 700, hookReq: 6, minDepth: 380, maxDepth: 560, speed: 150, size: 120, isBig: true, gemReward: 12),
    // Zone 3 — The Deep 600–1000m
    FishSpecies(id: "fangtooth",     name: "Fangtooth",      rarity: .rare,     value: 45,  hookReq: 4, minDepth: 390, maxDepth: 625, speed: 50,  size: 44),
    FishSpecies(id: "viperfish",     name: "Viperfish",      rarity: .rare,     value: 55,  hookReq: 5, minDepth: 425, maxDepth: 750, speed: 70,  size: 52),
    FishSpecies(id: "isopod",        name: "Giant Isopod",   rarity: .epic,     value: 65,  hookReq: 5, minDepth: 500, maxDepth: 950, speed: 25,  size: 55),
    FishSpecies(id: "gulpereel",     name: "Gulper Eel",     rarity: .epic,     value: 70,  hookReq: 6, minDepth: 550, maxDepth: 900, speed: 55,  size: 80),
    FishSpecies(id: "anglerfish",    name: "Anglerfish",     rarity: .epic,     value: 80,  hookReq: 6, minDepth: 625, maxDepth: 1000, speed: 45,  size: 58),
    FishSpecies(id: "oarfish",       name: "Oarfish",        rarity: .legendary, value: 150, hookReq: 7, minDepth: 700, maxDepth: 1000, speed: 60,  size: 120, isBig: true, gemReward: 4),
    FishSpecies(id: "coelacanth",    name: "Coelacanth",     rarity: .legendary, value: 200, hookReq: 8, minDepth: 800, maxDepth: 1000, speed: 40,  size: 78, isBig: true, gemReward: 5),
    FishSpecies(id: "phoenixfish",   name: "Abyssal Phoenix", rarity: .mythic,  value: 1500, hookReq: 8, minDepth: 850, maxDepth: 1000, speed: 130, size: 130, isBig: true, gemReward: 20),
    // Mythical bosses — one may spawn per dive at its depth
    FishSpecies(id: "boss_hippocampus", name: "Hippocampus", rarity: .boss, value: 300, hookReq: 3, minDepth: 90,  maxDepth: 125, speed: 60, size: 120, isBig: true, gemReward: 10, isBoss: true),
    FishSpecies(id: "kraken",           name: "Kraken",      rarity: .boss, value: 600, hookReq: 5, minDepth: 300, maxDepth: 375, speed: 50, size: 160, isBig: true, gemReward: 20, isBoss: true),
    FishSpecies(id: "boss_leviathan",   name: "Leviathan",   rarity: .boss, value: 1200, hookReq: 8, minDepth: 900, maxDepth: 1000, speed: 70, size: 200, isBig: true, gemReward: 40, isBoss: true),
]

func species(for id: String) -> FishSpecies? {
    allFish.first { $0.id == id }
}

struct CaughtFish: Identifiable {
    let id = UUID()
    let species: FishSpecies
}

// MARK: - Boats

struct Boat: Identifiable {
    let id: String      // sprite asset name
    let name: String
    let gemCost: Int
}

let allBoats: [Boat] = [
    Boat(id: "boat_classic", name: "Classic Fisher", gemCost: 0),
    Boat(id: "boat_viking",  name: "Viking Yacht",   gemCost: 75),
]

struct HookSkin: Identifiable {
    let id: String      // sprite asset name
    let name: String
    let gemCost: Int
}

let allHooks: [HookSkin] = [
    HookSkin(id: "hook_classic", name: "Steel Hook",   gemCost: 0),
    HookSkin(id: "hook_gold",    name: "Golden Hook",  gemCost: 30),
    HookSkin(id: "hook_trident", name: "Rune Trident", gemCost: 60),
]

struct AquariumRoom: Identifiable {
    let id: String      // background asset name
    let name: String
    let gemCost: Int
}

let allRooms: [AquariumRoom] = [
    AquariumRoom(id: "room_cabin",  name: "Fisherman's Cabin", gemCost: 0),
    AquariumRoom(id: "room_living", name: "Modern Living Room", gemCost: 50),
    AquariumRoom(id: "room_ship",   name: "Ship Interior",     gemCost: 100),
]

// MARK: - Dex milestones & daily quests

struct DexMilestone {
    let species: Int
    let coins: Int
    let gems: Int
}

let dexMilestones: [DexMilestone] = [
    DexMilestone(species: 5,  coins: 150, gems: 0),
    DexMilestone(species: 12, coins: 0,   gems: 15),
    DexMilestone(species: 20, coins: 0,   gems: 40),
]

struct Quest: Codable, Identifiable {
    enum Kind: String, Codable { case catchSpecies, catchAny, winFights }
    var id: String
    var kind: Kind
    var speciesId: String?
    var target: Int
    var gemReward: Int
    var progress: Int = 0
    var claimed = false

    var done: Bool { progress >= target }
    var title: String {
        switch kind {
        case .catchSpecies: return "Catch \(target) \(species(for: speciesId ?? "")?.name ?? "?")"
        case .catchAny: return "Catch \(target) fish"
        case .winFights: return "Win \(target) fights"
        }
    }
}

/// Deterministic 3 quests for a given day string.
func makeQuests(for day: String) -> [Quest] {
    var seed = day.unicodeScalars.reduce(UInt64(5381)) { ($0 << 5) &+ $0 &+ UInt64($1.value) }
    func next(_ n: Int) -> Int {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Int((seed >> 33) % UInt64(n))
    }
    let pool = allFish.filter { !$0.isBoss && !$0.isBig && $0.rarity <= .rare }
    let sp = pool[next(pool.count)]
    return [
        Quest(id: "\(day)-1", kind: .catchSpecies, speciesId: sp.id, target: 3 + next(3), gemReward: 3),
        Quest(id: "\(day)-2", kind: .catchAny, target: 8 + next(8), gemReward: 2),
        Quest(id: "\(day)-3", kind: .winFights, target: 1 + next(2), gemReward: 5),
    ]
}

func dayString(_ date: Date = .now) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

// MARK: - Upgrades

enum UpgradeTrack: String, CaseIterable, Identifiable, Codable, CodingKeyRepresentable {
    case line, bag, reel, hook
    var id: String { rawValue }

    var title: String {
        switch self {
        case .line: return "Line Length"
        case .bag:  return "Bag Capacity"
        case .reel: return "Reel Speed"
        case .hook: return "Hook Strength"
        }
    }
    var icon: String {
        switch self {
        // SF Symbol names
        case .line: return "arrow.down.to.line"
        case .bag:  return "bag.fill"
        case .reel: return "arrow.triangle.2.circlepath"
        case .hook: return "anchor"
        }
    }
    func effectText(level: Int) -> String {
        switch self {
        case .line: return "\(Int(GameState.maxDepthMeters(level: level)))m depth"
        case .bag:  return "\(GameState.bagCapacity(level: level)) fish"
        case .reel: return "\(Int(GameState.reelSpeed(level: level))) speed"
        case .hook: return "Tier \(level) fish"
        }
    }
}

// MARK: - Persistent state

struct SaveData: Codable {
    var coins: Int
    var gems: Int = 0
    var levels: [UpgradeTrack: Int]
    var inventory: [String: Int] = [:]
    var aquarium: [String: Int] = [:]        // species id -> dupe count (1 = one fish)
    var aquariumLevel: Int = 1
    var lastCollect: Date = .now
    var ownedBoats: [String] = ["boat_classic"]
    var currentBoat: String = "boat_classic"
    var discovered: [String] = []
    var claimedChests: [Int] = []
    var questsDay: String = ""
    var quests: [Quest] = []
    var ownedHooks: [String] = ["hook_classic"]
    var currentHook: String = "hook_classic"
    var soundOn: Bool = true
    var hapticsOn: Bool = true
    // optional so pre-room saves still decode
    var ownedRooms: [String]?
    var currentRoom: String?
    var soundVolume: Double?
    // optional so pre-bait/retention saves still decode
    var baitCounts: [String: Int]?
    var equippedBait: String?
    var loginStreak: Int?
    var lastLoginDay: String?
    var claimedAchievements: [String]?
    var records: [String: Int]?
    // optional so pre-modular-boat saves still decode
    var currentHullId: String?
    var currentRodId: String?
    var currentCaptainId: String?
    var currentDeckId: String?
    var currentDetailId: String?
}

// MARK: - Bait

struct BaitType: Identifiable {
    let id: String       // asset name
    let name: String
    let cost: Int        // coins per bait; 0 = infinite default
    let desc: String
}

let allBaits: [BaitType] = [
    BaitType(id: "bait_worm",    name: "Worm",        cost: 0,   desc: "Trusty. Never runs out."),
    BaitType(id: "bait_shrimp",  name: "Shrimp",      cost: 25,  desc: "More uncommon fish"),
    BaitType(id: "bait_squid",   name: "Squid",       cost: 60,  desc: "More rare fish"),
    BaitType(id: "bait_glowbug", name: "Glowbug",     cost: 120, desc: "More deep-sea fish"),
    BaitType(id: "bait_golden",  name: "Golden Lure", cost: 300, desc: "Legendary & mythic odds up"),
]

// MARK: - Achievements

struct Achievement: Identifiable {
    let id: String
    let name: String
    let goal: Int
    let stat: String     // key into records
    let coinReward: Int
    let gemReward: Int
}

let allAchievements: [Achievement] = [
    Achievement(id: "catch10",   name: "First Haul",      goal: 10,   stat: "totalCatches", coinReward: 100,  gemReward: 0),
    Achievement(id: "catch100",  name: "Fishmonger",      goal: 100,  stat: "totalCatches", coinReward: 500,  gemReward: 5),
    Achievement(id: "catch500",  name: "Sea Legend",      goal: 500,  stat: "totalCatches", coinReward: 2000, gemReward: 20),
    Achievement(id: "depth250",  name: "Past the Reef",   goal: 250,  stat: "deepestDive",  coinReward: 150,  gemReward: 0),
    Achievement(id: "depth500",  name: "Into the Kelp",   goal: 500,  stat: "deepestDive",  coinReward: 400,  gemReward: 5),
    Achievement(id: "depth1000", name: "Trench Diver",    goal: 1000, stat: "deepestDive",  coinReward: 1500, gemReward: 15),
    Achievement(id: "mythic1",   name: "Myth Confirmed",  goal: 1,    stat: "mythicsCaught", coinReward: 500, gemReward: 10),
    Achievement(id: "mythic5",   name: "Mythkeeper",      goal: 5,    stat: "mythicsCaught", coinReward: 2500, gemReward: 30),
    Achievement(id: "coins10k",  name: "Salty Fortune",   goal: 10000, stat: "coinsEarned", coinReward: 1000, gemReward: 10),
    Achievement(id: "fights50",  name: "Rod Wrestler",    goal: 50,   stat: "fightsWon",    coinReward: 800,  gemReward: 8),
]

// MARK: - Daily login rewards (7-day streak)

let streakRewards: [(coins: Int, gems: Int)] = [
    (50, 0), (75, 0), (100, 1), (150, 1), (200, 2), (300, 3), (500, 5),
]

enum GamePhase {
    case surface, diving, fighting, reeling, summary
}

@Observable
final class GameState {
    var coins: Int = 0
    var gems: Int = 0
    var levels: [UpgradeTrack: Int] = [.line: 1, .bag: 1, .reel: 1, .hook: 1]
    /// species id -> count of fish kept from dives
    var inventory: [String: Int] = [:]
    /// species id -> stack count in the aquarium (dupes raise income)
    var aquarium: [String: Int] = [:]
    var aquariumLevel: Int = 1
    var lastCollect: Date = .now
    var ownedBoats: [String] = ["boat_classic"]
    var currentBoat: String = "boat_classic"
    var discovered: Set<String> = []
    var claimedChests: Set<Int> = []
    var questsDay: String = ""
    var quests: [Quest] = []
    var ownedHooks: [String] = ["hook_classic"]
    var currentHook: String = "hook_classic"
    var soundOn = true
    var hapticsOn = true
    var soundVolume: Double = 0.8

    // modular boat: nil = derive from the owned boat / reel tier
    var currentHullId: String? = nil
    var currentRodId: String? = nil
    var currentCaptainId: String? = nil
    var currentDeckId: String? = nil
    var currentDetailId: String? = nil

    /// Effective hull: explicit override, else mapped from the equipped shop boat.
    var effectiveHullId: String { currentHullId ?? hullId(forBoat: currentBoat) }

    func setHull(to id: String) { currentHullId = id; save() }
    func upgradeRod(to id: String) { currentRodId = id; save() }
    func setCaptain(to id: String) { currentCaptainId = id; save() }
    func setDeck(to id: String) { currentDeckId = id; save() }
    func setDetail(to id: String?) { currentDetailId = id; save() }

    // bait
    var baitCounts: [String: Int] = [:]
    var equippedBait = "bait_worm"

    // retention
    var loginStreak = 0
    var lastLoginDay = ""
    var pendingLoginReward: Int? = nil   // streak day index (0-6) awaiting claim
    var claimedAchievements: Set<String> = []
    var records: [String: Int] = [:]     // totalCatches, deepestDive, mythicsCaught, coinsEarned, fightsWon

    func buyBait(_ bait: BaitType) {
        guard bait.cost > 0, coins >= bait.cost else { return }
        coins -= bait.cost
        baitCounts[bait.id, default: 0] += 1
        save()
    }

    /// Consume the equipped bait at dive start; fall back to the infinite worm when out.
    func consumeBaitForDive() {
        guard equippedBait != "bait_worm" else { return }
        let left = baitCounts[equippedBait, default: 0]
        if left > 0 {
            baitCounts[equippedBait] = left - 1
        } else {
            equippedBait = "bait_worm"
        }
        save()
    }

    // records + achievements
    func bumpRecord(_ stat: String, by n: Int = 1) {
        records[stat, default: 0] += n
        save()
    }
    func maxRecord(_ stat: String, _ value: Int) {
        if value > records[stat, default: 0] {
            records[stat] = value
            save()
        }
    }
    var unclaimedAchievements: [Achievement] {
        allAchievements.filter { !claimedAchievements.contains($0.id) && records[$0.stat, default: 0] >= $0.goal }
    }
    func claimAchievement(_ a: Achievement) {
        guard !claimedAchievements.contains(a.id), records[a.stat, default: 0] >= a.goal else { return }
        claimedAchievements.insert(a.id)
        coins += a.coinReward
        gems += a.gemReward
        save()
    }

    /// Daily login: call once at launch. Sets pendingLoginReward for the UI to claim.
    func checkDailyLogin() {
        let today = dayString()
        guard today != lastLoginDay else { return }
        let yesterday = dayString(.now.addingTimeInterval(-86400))
        loginStreak = lastLoginDay == yesterday ? loginStreak + 1 : 1
        lastLoginDay = today
        pendingLoginReward = (loginStreak - 1) % 7
        save()
    }
    func claimLoginReward() {
        guard let day = pendingLoginReward else { return }
        let r = streakRewards[day]
        coins += r.coins
        gems += r.gems
        pendingLoginReward = nil
        save()
    }

    // bait crate gacha: 20 gems a crate — baits + coins, tiny golden jackpot
    func openCrate() -> [(String, Int)]? {
        guard gems >= 20 else { return nil }
        gems -= 20
        var drops: [(String, Int)] = []
        let roll = Int.random(in: 0..<100)
        switch roll {
        case ..<45:  drops = [("bait_shrimp", 3), ("coins", 50)]
        case ..<75:  drops = [("bait_squid", 2), ("coins", 100)]
        case ..<92:  drops = [("bait_glowbug", 2), ("coins", 150)]
        default:     drops = [("bait_golden", 1), ("coins", 400)]
        }
        for (id, n) in drops {
            if id == "coins" { coins += n } else { baitCounts[id, default: 0] += n }
        }
        save()
        return drops
    }
    var ownedRooms: [String] = ["room_cabin"]
    var currentRoom: String = "room_cabin"

    var phase: GamePhase = .surface
    var lastHaul: [CaughtFish] = []
    var lastGemsWon: Int = 0
    var bagCount: Int = 0
    var depthMeters: Int = 0

    // Tension fight (written by scene each frame, read by overlay)
    var fightTension: Double = 0
    var fightProgress: Double = 0
    var fightZoneCenter: Double = 0.5
    var fightZoneWidth: Double = 0.4
    var fightStamina: Double = 1
    var fightHolding = false
    var fightPulling = false
    var fightFishName = ""
    var fightIsBoss = false

    // Joystick input, -1...1 each axis (written by overlay, read by scene)
    var joyX: Double = 0
    var joyY: Double = 0
    /// bumped by the scene on every mine hit; UI shows a red edge flash
    var mineFlash = 0

    // "Added to bag" toast (id changes each catch so repeats retrigger)
    struct CatchToast: Identifiable, Equatable {
        let id = UUID()
        let speciesId: String
        let name: String
    }
    var catchToast: CatchToast?

    // MARK: derived stats (10 tiers each)
    static let maxLevel = 10
    static func maxDepthMeters(level: Int) -> CGFloat { 100 + CGFloat(level - 1) * 100 } // lvl10 = 1000m
    static func bagCapacity(level: Int) -> Int { 3 + level }
    static func reelSpeed(level: Int) -> CGFloat { 120 + CGFloat(level - 1) * 35 }

    var maxDepthMeters: CGFloat { Self.maxDepthMeters(level: levels[.line] ?? 1) }
    var bagCapacity: Int { Self.bagCapacity(level: levels[.bag] ?? 1) }
    var reelSpeed: CGFloat { Self.reelSpeed(level: levels[.reel] ?? 1) }
    var hookStrength: Int { levels[.hook] ?? 1 }

    func cost(_ track: UpgradeTrack) -> Int {
        let level = levels[track] ?? 1
        return Int(30 * pow(1.6, Double(level - 1)))
    }

    func canBuy(_ track: UpgradeTrack) -> Bool {
        (levels[track] ?? 1) < Self.maxLevel && coins >= cost(track)
    }

    func buy(_ track: UpgradeTrack) {
        guard canBuy(track) else { return }
        coins -= cost(track)
        levels[track, default: 1] += 1
        save()
    }

    // MARK: boats

    func buyBoat(_ boat: Boat) {
        guard !ownedBoats.contains(boat.id), gems >= boat.gemCost else { return }
        gems -= boat.gemCost
        ownedBoats.append(boat.id)
        currentBoat = boat.id
        save()
    }

    func selectBoat(_ boat: Boat) {
        guard ownedBoats.contains(boat.id) else { return }
        currentBoat = boat.id
        save()
    }

    func buyRoom(_ room: AquariumRoom) {
        guard !ownedRooms.contains(room.id), gems >= room.gemCost else { return }
        gems -= room.gemCost
        ownedRooms.append(room.id)
        currentRoom = room.id
        save()
    }

    func selectRoom(_ room: AquariumRoom) {
        guard ownedRooms.contains(room.id) else { return }
        currentRoom = room.id
        save()
    }

    // MARK: dive results & inventory

    func endDive(haul: [CaughtFish], gemsWon: Int, fightsWon: Int = 0) {
        lastHaul = haul
        lastGemsWon = gemsWon
        gems += gemsWon
        refreshQuests()
        for fish in haul {
            discovered.insert(fish.species.id)
            for i in quests.indices where !quests[i].claimed {
                switch quests[i].kind {
                case .catchSpecies where quests[i].speciesId == fish.species.id: quests[i].progress += 1
                case .catchAny: quests[i].progress += 1
                default: break
                }
            }
        }
        for i in quests.indices where quests[i].kind == .winFights && !quests[i].claimed {
            quests[i].progress += fightsWon
        }
        phase = .summary
        save()
    }

    // MARK: quests & dex

    func refreshQuests() {
        let today = dayString()
        if questsDay != today {
            questsDay = today
            quests = makeQuests(for: today)
        }
    }

    func claimQuest(_ id: String) {
        guard let i = quests.firstIndex(where: { $0.id == id }),
              quests[i].done, !quests[i].claimed else { return }
        quests[i].claimed = true
        gems += quests[i].gemReward
        save()
    }

    func canClaimChest(_ m: DexMilestone) -> Bool {
        discovered.count >= m.species && !claimedChests.contains(m.species)
    }

    func claimChest(_ m: DexMilestone) {
        guard canClaimChest(m) else { return }
        claimedChests.insert(m.species)
        coins += m.coins
        gems += m.gems
        save()
    }

    // MARK: hooks

    func buyHook(_ hook: HookSkin) {
        guard !ownedHooks.contains(hook.id), gems >= hook.gemCost else { return }
        gems -= hook.gemCost
        ownedHooks.append(hook.id)
        currentHook = hook.id
        save()
    }

    func selectHook(_ hook: HookSkin) {
        guard ownedHooks.contains(hook.id) else { return }
        currentHook = hook.id
        save()
    }

    func keepHaul() {
        for fish in lastHaul { inventory[fish.species.id, default: 0] += 1 }
        lastHaul = []
        phase = .surface
        save()
    }

    func sellHaul() {
        coins += lastHaul.reduce(0) { $0 + $1.species.value }
        lastHaul = []
        phase = .surface
        save()
    }

    func sellFromInventory(_ speciesId: String, count: Int = 1) {
        guard let sp = species(for: speciesId), let have = inventory[speciesId], have > 0 else { return }
        let n = min(count, have)
        coins += sp.value * n
        if have - n <= 0 { inventory[speciesId] = nil } else { inventory[speciesId] = have - n }
        save()
    }

    func sellAllInventory() {
        for (id, n) in inventory {
            if let sp = species(for: id) { coins += sp.value * n }
        }
        inventory = [:]
        save()
    }

    var inventoryTotalValue: Int {
        inventory.reduce(0) { sum, kv in sum + (species(for: kv.key)?.value ?? 0) * kv.value }
    }

    // MARK: aquarium

    var aquariumCapacity: Int { 3 + aquariumLevel }          // distinct species slots
    var aquariumUpgradeCost: Int { 10 * aquariumLevel }       // gems
    static let offlineCapHours: Double = 8

    /// income multiplier from dupes: +0.5x per dupe; legendary doubles per dupe
    func incomeMultiplier(_ sp: FishSpecies, count: Int) -> Double {
        let dupes = max(0, count - 1)
        return sp.rarity >= .legendary ? pow(2, Double(dupes)) : 1 + 0.5 * Double(dupes)
    }

    var aquariumIncomePerMin: Double {
        aquarium.reduce(0) { sum, kv in
            guard let sp = species(for: kv.key) else { return sum }
            return sum + Double(sp.rarity.incomePerMin) * incomeMultiplier(sp, count: kv.value)
        }
    }

    var pendingEarnings: Int {
        // clamp ≥ 0: a clock-skewed / corrupt lastCollect in the future must never charge the player
        let elapsed = max(0, min(Date.now.timeIntervalSince(lastCollect), Self.offlineCapHours * 3600))
        return Int(aquariumIncomePerMin * elapsed / 60)
    }

    func collectEarnings() {
        coins = max(0, coins + pendingEarnings)
        lastCollect = .now
        save()
    }

    func upgradeAquarium() {
        guard gems >= aquariumUpgradeCost else { return }
        gems -= aquariumUpgradeCost
        aquariumLevel += 1
        save()
    }

    /// Move one inventory fish into the aquarium (new slot or dupe).
    func equip(_ speciesId: String) {
        guard let have = inventory[speciesId], have > 0 else { return }
        if aquarium[speciesId] == nil && aquarium.count >= aquariumCapacity { return }
        collectBeforeMutation()
        inventory[speciesId] = have - 1 <= 0 ? nil : have - 1
        aquarium[speciesId, default: 0] += 1
        save()
    }

    /// Return one fish (or the whole stack) to inventory.
    func unequip(_ speciesId: String, all: Bool = false) {
        guard let n = aquarium[speciesId], n > 0 else { return }
        collectBeforeMutation()
        let moved = all ? n : 1
        aquarium[speciesId] = n - moved <= 0 ? nil : n - moved
        inventory[speciesId, default: 0] += moved
        save()
    }

    /// Fill the tank with the highest-income fish available in inventory.
    func equipBest() {
        collectBeforeMutation()
        let candidates = inventory
            .compactMap { id, n in species(for: id).map { ($0, n) } }
            .sorted { $0.0.rarity > $1.0.rarity }
        for (sp, n) in candidates {
            for _ in 0..<n {
                if aquarium[sp.id] == nil && aquarium.count >= aquariumCapacity { break }
                inventory[sp.id]! -= 1
                if inventory[sp.id]! <= 0 { inventory[sp.id] = nil }
                aquarium[sp.id, default: 0] += 1
                if inventory[sp.id] == nil { break }
            }
        }
        save()
    }

    /// Bank accrued income before income rate changes, so past time isn't re-priced.
    private func collectBeforeMutation() {
        coins = max(0, coins + pendingEarnings)
        lastCollect = .now
    }

    // MARK: save/load
    private static var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("save.json")
    }

    func save() {
        let data = SaveData(coins: coins, gems: gems, levels: levels, inventory: inventory,
                            aquarium: aquarium, aquariumLevel: aquariumLevel, lastCollect: lastCollect,
                            ownedBoats: ownedBoats, currentBoat: currentBoat,
                            discovered: Array(discovered), claimedChests: Array(claimedChests),
                            questsDay: questsDay, quests: quests,
                            ownedHooks: ownedHooks, currentHook: currentHook,
                            soundOn: soundOn, hapticsOn: hapticsOn,
                            ownedRooms: ownedRooms, currentRoom: currentRoom,
                            soundVolume: soundVolume,
                            baitCounts: baitCounts, equippedBait: equippedBait,
                            loginStreak: loginStreak, lastLoginDay: lastLoginDay,
                            claimedAchievements: Array(claimedAchievements), records: records,
                            currentHullId: currentHullId, currentRodId: currentRodId,
                            currentCaptainId: currentCaptainId, currentDeckId: currentDeckId,
                            currentDetailId: currentDetailId)
        try? JSONEncoder().encode(data).write(to: Self.saveURL)
    }

    func load() {
        guard let raw = try? Data(contentsOf: Self.saveURL),
              let data = try? JSONDecoder().decode(SaveData.self, from: raw) else { return }
        coins = data.coins
        gems = data.gems
        levels = data.levels
        inventory = data.inventory
        aquarium = data.aquarium
        aquariumLevel = data.aquariumLevel
        // heal corrupt saves: future timestamps and negative balances must not survive a load
        lastCollect = min(data.lastCollect, .now)
        coins = max(0, coins)
        ownedBoats = data.ownedBoats
        currentBoat = data.currentBoat
        discovered = Set(data.discovered)
        claimedChests = Set(data.claimedChests)
        questsDay = data.questsDay
        quests = data.quests
        ownedHooks = data.ownedHooks
        currentHook = data.currentHook
        soundOn = data.soundOn
        hapticsOn = data.hapticsOn
        ownedRooms = data.ownedRooms ?? ["room_cabin"]
        currentRoom = data.currentRoom ?? "room_cabin"
        soundVolume = data.soundVolume ?? 0.8
        baitCounts = data.baitCounts ?? [:]
        equippedBait = data.equippedBait ?? "bait_worm"
        loginStreak = data.loginStreak ?? 0
        lastLoginDay = data.lastLoginDay ?? ""
        claimedAchievements = Set(data.claimedAchievements ?? [])
        records = data.records ?? [:]
        currentHullId = data.currentHullId
        currentRodId = data.currentRodId
        currentCaptainId = data.currentCaptainId
        currentDeckId = data.currentDeckId
        currentDetailId = data.currentDetailId
        refreshQuests()
    }
}
