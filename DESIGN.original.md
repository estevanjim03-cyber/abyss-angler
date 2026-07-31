# Fishing Game — Design Doc

Reference: "Fish to Feed" (screenshots IMG_4347–4358). We keep its proven dive-loop, cut the ad hell, add depth progression + aquarium economy.

## Pitch
Drop a claw-hook from your boat, steer it down through fish-filled water, snag a bagful, reel up, sell or keep. Big fish fight back. Coins upgrade your gear to reach deeper zones; your best fish live in an aquarium that earns money while you're away.

**Differentiator vs reference: zero forced ads, real depth progression, aquarium meta.**

## Platform / Tech
- iOS, landscape, cartoon-flat art (bold outlines, flat colors — reference style)
- SpriteKit (game scene) + SwiftUI (menus, shop, aquarium UI, dex)
- No third-party dependencies. Save = Codable JSON on disk.
- No monetization in v1. Economy designed so gems can become IAP later. Never forced ads.

## Core Loop
1. **Surface**: boat idles on water. Tap to drop hook.
2. **Dive**: virtual joystick steers hook. Line pays out; max depth = line-length upgrade.
3. **Catch**: touch small fish → auto-snag onto hook stack. Big/boss fish → tension fight.
4. **Return**: bag full or line maxed or player taps return → reel up (reel-speed upgrade).
5. **Surface**: catch goes to **inventory**. Sell fish for coins, keep/equip best in aquarium.
6. **Spend**: coins → gear upgrades. Gems → aquarium capacity, cosmetics, premium rods.
7. Deeper zone unlocks when line reaches it. Repeat.

## Tension Fight (big fish + bosses)
- Hold to reel in, release to give slack. Tension bar rises while holding + fish pulling.
- Redline too long → line snaps, fish escapes (keep rest of stack).
- Fish pulls in bursts (telegraphed). Fill catch-distance bar → caught.
- Hook-strength upgrade widens safe zone.

## Zones (v1: 3)
| Zone | Depth | Fish | Hazards | Boss (mythical, scales with depth) |
|------|-------|------|---------|------|
| Tropical Shallows | 0–50m | sergeant major, parrotfish, rainbow wrasse, butterflyfish, mahi-mahi (big), swordfish (legendary, big) | none (tutorial waters) | Hippocampus — giant mythical seahorse |
| Reef Drop-off | 50–150m | tuna, barracuda, lionfish, triggerfish, grouper, marlin (big) | jellyfish (stun, drop 1 fish) | Kraken — colossal squid of legend |
| The Deep | 150–400m | anglerfish, gulper eel, viperfish, oarfish, fangtooth, giant isopod, coelacanth (legendary) | jellyfish + mines (snap line if 2 hits) | Leviathan — abyssal sea serpent |

~20 fish + 3 bosses. Rarity: Common / Uncommon / Rare / Epic / Legendary.

## Art Direction
Semi-realistic cartoon: accurate fish anatomy and colors, NO cartoon faces/smiles, flat colors with bold dark outlines (reference-game rendering, realistic subjects). Zone 1 reads tropical (bright, warm). Bosses are mythical deep-sea creatures, more menacing with depth. Sprites: PNG, transparent background, side view. Generated with Nano Banana Pro (gemini-3-pro-image).

## Economy
- **Coins**: sell fish (price = rarity × size). Buy gear upgrades.
- **Gems**: from boss kills, dex milestones, daily quests. Buy aquarium capacity, cosmetics, premium rods.
- **Fish inventory**: every catch persists as an item (species, rarity, size). Browse anytime. Sell individually / sell-all-except-equipped.

## Upgrades (coins)
| Track | Effect |
|-------|--------|
| Line length | Max dive depth — the zone gate |
| Bag capacity | Fish per dive |
| Reel speed | Descent + return speed |
| Hook strength | Bigger fish grabbable, wider tension safe zone |

~10 tiers each, exponential cost curve.

## Aquarium
- Corner button on surface screen → aquarium scene, fish visibly swimming.
- Each placed fish earns coins/min by rarity. Slots limited; gems increase capacity.
- **Duplicates upgrade the fish**: catching a dupe of a placed species raises its earn multiplier (+0.5× per dupe common→epic; ×2 per dupe legendary).
- Equip All / Equip Best buttons from inventory.
- Offline earnings accrue, capped at 8h. Collect on open.

## Meta Systems (v1)
- **Fish dex**: silhouette collection book, milestone chests (coins/gems) at 5/12/20 species.
- **Daily quests**: 3/day ("catch 6 anglerfish"), gem rewards.
- **Boss per zone**: rare spawn, tension fight, big gem payout, dex entry.

## Screens
1. Surface (boat, HUD: coins/gems/bag, buttons: dive, shop, aquarium, dex, quests, settings)
2. Dive (joystick, line, bag counter, tap-to-return)
3. Tension fight overlay
4. Catch summary (haul list → sell / keep)
5. Shop (4 upgrade tracks)
6. Aquarium (swimming fish, slots, income collect, equip)
7. Inventory (all fish, sell/equip)
8. Dex, Quests, Settings (sound/music/haptics)

---

# Features List

## Prototype (build 1) — prove the fun
- [ ] Boat on water surface, cartoon placeholder art
- [ ] Tap to drop hook, joystick steering, line render
- [ ] 1 zone (Shallows), ~6 fish species swimming with simple AI
- [ ] Auto-snag on touch, fish stack on hook
- [ ] Bag limit + line-length limit + tap-to-return, reel up
- [ ] Catch summary → auto-sell for coins
- [ ] Shop with all 4 upgrade tracks (coins only)
- [ ] Save/load (JSON)

## Build 2 — fight + inventory
- [ ] Tension-fight minigame, big fish flagged per species
- [ ] Fish inventory (persist catches, sell individually)
- [ ] Gems currency (placeholder sources)

## Build 3 — meta
- [ ] Aquarium: scene, slots, income/min, offline earnings, dupes upgrade, equip all/best
- [ ] Zones 2–3, hazards (jellyfish, mines), ~20 fish
- [ ] Bosses ×3

## Build 4 — retention + polish
- [ ] Fish dex + milestone chests
- [ ] Daily quests
- [ ] Cosmetics/premium rods (gem sink)
- [ ] Sound, music, haptics, juice pass (particles, screen shake, catch pop)

## Cut / later (YAGNI)
- Multiplayer, events, ads, IAP wiring, cloud save, iPad layout, localization
