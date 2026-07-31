# Fishing Game — Design Doc

Reference: "Fish to Feed" (screenshots IMG_4347–4358). Keep proven dive-loop, cut ad hell, add depth progression + aquarium economy.

## Pitch
Drop claw-hook from boat, steer down through fish, snag bagful, reel up, sell or keep. Big fish fight back. Coins upgrade gear → reach deeper zones. Best fish live in aquarium, earn money while away.

**Differentiator vs reference: zero forced ads, real depth progression, aquarium meta.**

## Platform / Tech
- iOS, landscape, cartoon-flat art (bold outlines, flat colors)
- SpriteKit (game scene) + SwiftUI (menus, shop, aquarium UI, dex)
- No third-party deps. Save = Codable JSON on disk.
- No monetization v1. Gems can become IAP later. Never forced ads.

## Core Loop
1. **Surface**: boat idle. Tap to drop hook.
2. **Dive**: joystick steer. Line pays out; max depth = line upgrade.
3. **Catch**: touch small fish → auto-snag. Big/boss fish → tension fight.
4. **Return**: bag full or line max or tap return → reel up (reel upgrade).
5. **Surface**: catch → **inventory**. Sell for coins or keep/equip in aquarium.
6. **Spend**: coins → gear. Gems → aquarium capacity, cosmetics, premium rods.
7. Deeper zone unlock when line reach it. Repeat.

## Tension Fight (big fish + bosses)
- Hold to reel, release for slack. Tension rise while holding + fish pulling.
- Redline too long → line snap, fish escape (keep rest of stack).
- Fish pull in telegraphed bursts. Fill catch bar → caught.
- Hook-strength upgrade widen safe zone.

## Zones (v1: 3)
| Zone | Depth | Fish | Hazards | Boss (mythical, scales with depth) |
|------|-------|------|---------|------|
| Tropical Shallows | 0–50m | sergeant major, parrotfish, rainbow wrasse, butterflyfish, mahi-mahi (big), swordfish (legendary, big) | none (tutorial waters) | Hippocampus — giant mythical seahorse |
| Reef Drop-off | 50–150m | tuna, barracuda, lionfish, triggerfish, grouper, marlin (big) | jellyfish (stun, drop 1 fish) | Kraken — colossal squid of legend |
| The Deep | 150–400m | anglerfish, gulper eel, viperfish, oarfish, fangtooth, giant isopod, coelacanth (legendary) | jellyfish + mines (snap line if 2 hits) | Leviathan — abyssal sea serpent |

~20 fish + 3 bosses. Rarity: Common / Uncommon / Rare / Epic / Legendary.

## Art Direction
Semi-realistic cartoon: accurate fish anatomy + colors, NO cartoon faces/smiles, flat colors, bold dark outlines. Zone 1 tropical (bright, warm). Bosses = mythical deep-sea creatures, more menacing with depth. Sprites: PNG, transparent bg, side view. Generated with Nano Banana Pro (gemini-3-pro-image).

## Economy
- **Coins (sand dollars)**: sell fish (price = rarity × size). Buy gear upgrades.
- **Gems (diamonds)**: from boss kills, dex milestones, daily quests. Buy aquarium capacity, cosmetics, premium rods, boats.
- **Fish inventory**: every catch persist (species, rarity). Sell individually / sell-all-except-equipped.

## Upgrades (coins)
| Track | Effect |
|-------|--------|
| Line length | Max depth — zone gate |
| Bag capacity | Fish per dive |
| Reel speed | Descent + return speed |
| Hook strength | Bigger fish grabbable, wider tension safe zone |

~10 tiers each, exponential cost.

## Aquarium
- Corner button → aquarium scene, fish swim visibly.
- Each fish earn coins/min by rarity. Slots limited; gems add slots.
- **Dupes upgrade fish**: +0.5× per dupe common→epic; ×2 per dupe legendary.
- Equip All / Equip Best from inventory.
- Offline earnings, cap 8h. Collect on open.

## Meta Systems (v1)
- **Fish dex**: silhouette book, milestone chests (coins/gems) at 5/12/20 species.
- **Daily quests**: 3/day, gem rewards.
- **Boss per zone**: rare spawn, tension fight, big gem payout, dex entry.

## Screens
1. Surface (boat, HUD, buttons: dive/shop/aquarium/dex/quests/settings)
2. Dive (joystick, line, bag counter, tap-to-return)
3. Tension fight overlay
4. Catch summary (haul → sell / keep)
5. Shop (4 gear tracks + boats + hooks)
6. Aquarium (fish, slots, income, equip)
7. Inventory (sell/equip)
8. Dex, Quests, Settings (sound/haptics)

---

# Features List

## Prototype (build 1) — DONE
- [x] Boat, tap-drop hook, joystick steer, line render
- [x] 1 zone, ~6 fish, auto-snag, stack on hook
- [x] Bag + line limits + tap-return, reel
- [x] Catch summary → coins
- [x] Shop 4 tracks
- [x] Save/load JSON

## Build 2 — DONE
- [x] Tension fight, big fish flagged
- [x] Fish inventory (persist, sell individually)
- [x] Gems currency

## Build 3 — DONE
- [x] Real art: 26 sprites (fish, bosses, boats, hazards) via Nano Banana Pro
- [x] Aquarium: income, offline, dupes, equip best
- [x] Zones 2–3, hazards, ~20 fish, 3 bosses
- [x] Boats: Classic free, Viking Yacht 75 gems

## Build 4 — DONE
- [x] Fish dex + milestone chests
- [x] Daily quests (3/day, deterministic)
- [x] Sound (synth wavs) + haptics + settings toggles
- [x] Hook skins: Steel free, Gold 30, Trident 60 gems
- [x] Fish AI: wander + flee hook; spread spawns; premium fight UI; sand dollar + diamond icons

## Cut / later (YAGNI)
- Multiplayer, events, ads, IAP wiring, cloud save, iPad layout, localization

## Pre-ship TODO
- Remove `SPAWN_BIG_SHALLOW` test hook (GameScene.swift)
- Real-device pass (haptics no-op in simulator)
