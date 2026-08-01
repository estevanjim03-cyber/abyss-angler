import SwiftUI
import SpriteKit

@main
struct FishingGameApp: App {
    init() {
        if let url = Bundle.main.url(forResource: "Fredoka", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
    var body: some Scene {
        WindowGroup {
            GameView()
        }
    }
}

struct JoystickView: View {
    let state: GameState
    @State private var knob = CGSize.zero
    private let radius: CGFloat = 52

    @State private var pressed = false

    var body: some View {
        ZStack {
            // brass ring base over a dark inner well
            Circle()
                .fill(RadialGradient(colors: [Nautical.navyLight.opacity(0.85), Nautical.navy.opacity(0.9)],
                                     center: .center, startRadius: 4, endRadius: radius + 12))
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(colors: [Nautical.sand, Nautical.copper, Nautical.tan],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 6))
                .frame(width: radius * 2 + 24, height: radius * 2 + 24)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            // glass knob: glows + swells slightly while held
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.95), Nautical.sand.opacity(0.8), Nautical.copper.opacity(0.7)],
                                     center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: 34))
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                .frame(width: 52, height: 52)
                .scaleEffect(pressed ? 1.1 : 1)
                .shadow(color: pressed ? Nautical.sand.opacity(0.8) : .black.opacity(0.35),
                        radius: pressed ? 10 : 4, y: 2)
                .animation(.spring(duration: 0.2), value: pressed)
                .offset(knob)
        }
        .contentShape(Circle())
        // view vanishes mid-drag when a fight starts; onEnded never fires, so reset here
        .onDisappear {
            state.joyX = 0
            state.joyY = 0
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    pressed = true
                    let dx = g.translation.width, dy = g.translation.height
                    let mag = max(hypot(dx, dy), 1)
                    let clamped = min(mag, radius)
                    knob = CGSize(width: dx / mag * clamped, height: dy / mag * clamped)
                    state.joyX = Double(dx / mag * clamped / radius)
                    state.joyY = Double(-dy / mag * clamped / radius) // screen down = world down
                }
                .onEnded { _ in
                    pressed = false
                    knob = .zero
                    state.joyX = 0
                    state.joyY = 0
                }
        )
    }
}

/// Red edge vignette that flashes when a mine goes off.
struct MineFlashOverlay: View {
    let trigger: Int
    @State private var opacity: Double = 0

    var body: some View {
        RadialGradient(colors: [.clear, .clear, .red.opacity(0.75)],
                       center: .center, startRadius: 100, endRadius: 500)
            .ignoresSafeArea()
            .opacity(opacity)
            .allowsHitTesting(false)
            .onChange(of: trigger) {
                opacity = 1
                withAnimation(.easeOut(duration: 0.7)) { opacity = 0 }
            }
    }
}

struct GameView: View {
    @State private var state = GameState()
    @State private var scene: GameScene = {
        let s = GameScene()
        // fixed logical canvas + aspectFill: identical composition on every device,
        // slight edge crop instead of stretch/squish
        s.size = GameScene.designSize
        s.scaleMode = .aspectFill
        return s
    }()
    @State private var showSplash = true
    @State private var showShop = false
    @State private var showInventory = false
    @State private var showAquarium = false
    @State private var showDex = false
    @State private var showQuests = false
    @State private var showSettings = false
    @State private var showBaitPicker = false
    @State private var showTrophies = false
    @State private var crateDrops: [(String, Int)]? = nil

    enum Drawer { case left, right }
    @State private var openDrawer: Drawer? = nil

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            // heavy vignette, weighted toward the bottom for that deep-sea mood
            RadialGradient(colors: [.clear, .clear, .black.opacity(0.45)],
                           center: .center, startRadius: 160, endRadius: 540)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            LinearGradient(colors: [.clear, .clear, .black.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            hud
                .buttonStyle(PressButtonStyle())
            if state.phase == .diving {
                VStack {
                    Spacer()
                    HStack {
                        JoystickView(state: state)
                        Spacer()
                    }
                }
                .padding(.leading, 28)
                .padding(.bottom, 24)
            }
            if state.phase == .fighting {
                fightOverlay
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            if state.phase == .summary {
                summaryOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            MineFlashOverlay(trigger: state.mineFlash)
            if showSettings { settingsOverlay }
            if showBaitPicker { baitPickerOverlay }
            if showTrophies { trophiesOverlay }
            if state.pendingLoginReward != nil { loginRewardOverlay }
            if showSplash {
                ZStack {
                    Nautical.panelFill.ignoresSafeArea()
                    VStack(spacing: Nautical.s3) {
                        bundleImage("logo").resizable().scaledToFit()
                            .frame(maxWidth: 460)
                            .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
                        ProgressView()
                            .tint(Nautical.brassBright)
                            .scaleEffect(1.4)
                    }
                }
                .transition(.opacity)
                .task {
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
                }
            }
            if let toast = state.catchToast {
                VStack {
                    HStack(spacing: 8) {
                        if let img = UIImage(named: toast.speciesId) {
                            Image(uiImage: img)
                                .resizable().scaledToFit().frame(height: 30)
                        }
                        Text(toast.name)
                            .font(fredoka(15, "Bold")).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .background(Nautical.navy.opacity(0.6), in: Capsule())
                    .overlay(Capsule().strokeBorder(Nautical.brassStroke, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
                    .padding(.top, 52)
                    Spacer()
                }
                .id(toast.id)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(1))
                    withAnimation(.easeOut(duration: 0.4)) {
                        if state.catchToast?.id == toast.id { state.catchToast = nil }
                    }
                }
            }
        }
        .onAppear {
            state.load()
            state.refreshQuests()
            state.checkDailyLogin()
            scene.state = state
            scene.rebuildBoat()
            scene.rebuildHook()
        }
        .animation(.spring(duration: 0.35), value: state.phase)
        // full-scene screens get no system chrome; list sheets lose the grabber
        .fullScreenCover(isPresented: $showShop) { ShopView(state: state, scene: scene) }
        .fullScreenCover(isPresented: $showAquarium) { AquariumView(state: state) }
        .fullScreenCover(isPresented: $showInventory) { InventoryView(state: state) }
        .fullScreenCover(isPresented: $showDex) { DexView(state: state) }
        .statusBarHidden()
    }

    // MARK: settings overlay (small box, not a screen)

    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { showSettings = false }
            VStack(spacing: 14) {
                Text("SETTINGS").gameText(20, weight: "Bold").kerning(2)
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(Nautical.brassBright)
                    Slider(value: Binding(
                        get: { state.soundVolume },
                        set: { state.soundVolume = $0; state.save() }), in: 0...1)
                        .tint(Nautical.brassBright)
                    Text("\(Int(state.soundVolume * 100))%")
                        .font(fredoka(13, "Medium")).foregroundStyle(.white)
                        .frame(width: 42, alignment: .trailing)
                }
                Toggle(isOn: Binding(
                    get: { state.hapticsOn },
                    set: { state.hapticsOn = $0; state.save() })) {
                    HStack {
                        Image(systemName: "iphone.radiowaves.left.and.right").foregroundStyle(Nautical.brassBright)
                        Text("Haptics").font(fredoka(15, "Medium")).foregroundStyle(.white)
                    }
                }
                .tint(Nautical.brass)
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(Nautical.panelFill, in: RoundedRectangle(cornerRadius: Nautical.panelRadius))
            .overlay(RoundedRectangle(cornerRadius: Nautical.panelRadius).strokeBorder(Nautical.brassStroke, lineWidth: 2))
            .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
        }
    }

    // MARK: quest chip (one active quest on the main screen)

    private var activeQuest: Quest? {
        state.quests.first { !$0.claimed }
    }

    @ViewBuilder
    private var questChip: some View {
        if let q = activeQuest {
            Button {
                if q.done {
                    state.claimQuest(q.id)
                    state.catchToast = .init(speciesId: "icon_diamond", name: "Quest reward +\(q.gemReward) gems")
                }
            } label: {
                HStack(spacing: 8) {
                    bundleImage("icon_quests").resizable().scaledToFit().frame(height: 20)
                    Text(q.title).font(fredoka(13, "Medium")).foregroundStyle(.white)
                    Text(q.done ? "CLAIM!" : "\(min(q.progress, q.target))/\(q.target)")
                        .font(fredoka(13, "Bold"))
                        .foregroundStyle(q.done ? Nautical.brassBright : .white.opacity(0.8))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Nautical.panelFill, in: Capsule())
                .overlay(Capsule().strokeBorder(
                    q.done ? AnyShapeStyle(Nautical.brassStroke) : AnyShapeStyle(Color.white.opacity(0.25)),
                    lineWidth: q.done ? 2 : 1))
                .shadow(color: q.done ? Nautical.brassBright.opacity(0.5) : .clear, radius: 6)
            }
            .animation(.spring(duration: 0.3), value: q.done)
        }
    }

    // MARK: open-scene HUD with side drawers

    private var hud: some View {
        ZStack {
            VStack(spacing: 0) {
                // corner currency plaques only — scene stays open
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        CurrencyBadge(icon: "icon_sanddollar", amount: state.coins, tint: Nautical.brassBright)
                        if state.phase == .surface { questChip }
                    }
                    Spacer()
                    if state.phase == .diving || state.phase == .reeling || state.phase == .fighting {
                        diveGauge
                    }
                    Spacer()
                    CurrencyBadge(icon: "icon_diamond", amount: state.gems, tint: Nautical.teal)
                }
                Spacer()
                switch state.phase {
                case .surface:
                    ZStack {
                        diveCapstan
                        HStack {
                            Spacer()
                            bottomDock
                        }
                    }
                case .diving:
                    HStack {
                        Spacer()
                        Button { scene.startReel() } label: {
                            VStack(spacing: 2) {
                                bundleImage("reel_crank")
                                    .resizable().scaledToFit().frame(height: 74)
                                    .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
                                Text("REEL IN")
                                    .font(fredoka(12, "Bold")).kerning(1)
                                    .foregroundStyle(Nautical.cream)
                                    .shadow(color: .black.opacity(0.6), radius: 2)
                            }
                        }
                    }
                case .fighting, .reeling, .summary:
                    EmptyView()
                }
            }
            .padding()
            if state.phase == .surface { drawerLayer }
        }
    }

    /// Center-top cluster while diving: bag, biome chip, depth gauge.
    private var diveGauge: some View {
        HStack(spacing: Nautical.s2) {
            Label("\(state.bagCount)/\(state.bagCapacity)", systemImage: "bag.fill")
                .font(fredoka(15, "Bold")).foregroundStyle(Nautical.cream)
                .contentTransition(.numericText())
                .symbolEffect(.bounce, value: state.bagCount)
                .animation(.spring(duration: 0.3), value: state.bagCount)
            Text(biomeName(state.depthMeters).0)
                .font(fredoka(11, "Bold"))
                .foregroundStyle(biomeName(state.depthMeters).1)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(biomeName(state.depthMeters).1.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(biomeName(state.depthMeters).1.opacity(0.5), lineWidth: 1))
                .animation(.easeInOut(duration: 0.4), value: biomeName(state.depthMeters).0)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(state.depthMeters)")
                    .font(fredoka(24, "Bold")).foregroundStyle(Nautical.cream)
                    .contentTransition(.numericText())
                Text("m").font(fredoka(12)).foregroundStyle(Nautical.cream.opacity(0.6))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Nautical.navy.opacity(0.6), in: Capsule())
        .overlay(Capsule().strokeBorder(Nautical.brassStroke, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
    }

    /// Thin bottom-right dock: quick actions only.
    private var bottomDock: some View {
        HStack(spacing: Nautical.s1) {
            baitChip
            instrumentToggle("icon_catch", "Catch") { showInventory = true }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Nautical.navy.opacity(0.55), in: Capsule())
        .overlay(Capsule().strokeBorder(Nautical.brassStroke, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
    }

    // MARK: side drawers

    private var drawerLayer: some View {
        ZStack {
            // scrim closes the open drawer
            if openDrawer != nil {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring(duration: 0.3)) { openDrawer = nil } }
            }
            HStack(spacing: 0) {
                drawer(.left)
                Spacer()
                drawer(.right)
            }
            .ignoresSafeArea() // anchor drawers to the physical screen edges, not the safe area
        }
        // edge swipes open/close; one drawer at a time by construction
        .gesture(
            DragGesture(minimumDistance: 25)
                .onEnded { g in
                    withAnimation(.spring(duration: 0.3)) {
                        if g.translation.width > 40 {
                            openDrawer = g.startLocation.x < 80 ? .left : (openDrawer == .right ? nil : openDrawer)
                        } else if g.translation.width < -40 {
                            openDrawer = g.startLocation.x > UIScreen.main.bounds.width - 80 ? .right : (openDrawer == .left ? nil : openDrawer)
                        }
                    }
                }
        )
    }

    private func drawer(_ side: Drawer) -> some View {
        let isOpen = openDrawer == side
        let width: CGFloat = 210 // < 30% of landscape width
        return HStack(spacing: 0) {
            if side == .right { drawerHandle(side) }
            VStack(spacing: Nautical.s1) {
                if side == .left {
                    Text("Captain's Log").gameText(16, weight: "Bold")
                    drawerRow("crate", "Trophies", badge: !state.unclaimedAchievements.isEmpty) { showTrophies = true }
                    drawerRow("icon_dex", "Fish Dex", badge: dexMilestones.contains(where: { state.canClaimChest($0) })) { showDex = true }
                    drawerRow("icon_settings", "Settings") { showSettings = true }
                } else {
                    Text("Harbor").gameText(16, weight: "Bold")
                    drawerRow("icon_shop", "Shop") { showShop = true }
                    drawerRow("icon_aquarium", "Aquarium") { showAquarium = true }
                }
                Spacer()
            }
            .padding(Nautical.s2)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .background(Nautical.navy.opacity(0.94)) // deep navy glass, not washed grey
            .overlay(Rectangle().frame(width: 2)
                .foregroundStyle(Nautical.brassStroke),
                alignment: side == .left ? .trailing : .leading)
            .shadow(color: .black.opacity(0.6), radius: 16)
            if side == .left { drawerHandle(side) }
        }
        .offset(x: isOpen ? 0 : (side == .left ? -width : width))
        .animation(.spring(duration: 0.3), value: openDrawer)
        .ignoresSafeArea(edges: .vertical)
    }

    /// Brass tab on the drawer edge — tap to toggle.
    private func drawerHandle(_ side: Drawer) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                openDrawer = openDrawer == side ? nil : side
            }
        } label: {
            Image(systemName: side == .left ? "chevron.right" : "chevron.left")
                .rotationEffect(.degrees(openDrawer == side ? 180 : 0))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Nautical.navy)
                .frame(width: 24, height: 64)
                .background(
                    UnevenRoundedRectangle(
                        cornerRadii: side == .left
                            ? .init(topLeading: 0, bottomLeading: 0, bottomTrailing: 12, topTrailing: 12)
                            : .init(topLeading: 12, bottomLeading: 12, bottomTrailing: 0, topTrailing: 0))
                        .fill(LinearGradient(colors: [Nautical.brassBright, Nautical.brass],
                                             startPoint: .top, endPoint: .bottom)))
                .shadow(color: .black.opacity(0.4), radius: 5)
        }
    }

    private func drawerRow(_ icon: String, _ title: String, badge: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { openDrawer = nil }
            action()
        } label: {
            HStack(spacing: 10) {
                bundleImage(icon).resizable().scaledToFit().frame(width: 30, height: 30)
                Text(title).font(fredoka(14, "Bold")).foregroundStyle(Nautical.cream)
                Spacer()
                if badge { Circle().fill(Nautical.danger).frame(width: 10, height: 10) }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Nautical.navyLight, Nautical.navy], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .center))))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Nautical.brass.opacity(0.5), lineWidth: 1.2))
        }
    }

    /// Square instrument toggle: icon on an inset navy well with brass rim.
    private func instrumentToggle(_ icon: String, _ title: String, badge: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                bundleImage(icon)
                    .resizable().scaledToFit().frame(height: title.isEmpty ? 30 : 32)
                if !title.isEmpty {
                    Text(title).font(fredoka(10, "Bold")).foregroundStyle(Nautical.cream.opacity(0.85))
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .frame(minWidth: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Nautical.navyLight, Nautical.navy], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center))))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(LinearGradient(colors: [Nautical.brassBright.opacity(0.8), Nautical.brass.opacity(0.6), .black.opacity(0.4)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            .overlay(alignment: .topTrailing) {
                if badge { Circle().fill(Nautical.danger).frame(width: 11, height: 11).offset(x: 2, y: -2) }
            }
        }
    }

    /// Round brass capstan DIVE button.
    private var diveCapstan: some View {
        Button { scene.startDive() } label: {
            Text("DIVE")
                .gameText(22, weight: "Bold")
                .kerning(1.5)
                .frame(width: 88, height: 88)
                .background(
                    Circle().fill(RadialGradient(colors: [Nautical.brassBright, Nautical.brass, Nautical.wood],
                                                 center: .init(x: 0.4, y: 0.3), startRadius: 4, endRadius: 60)))
                .overlay(Circle().strokeBorder(Nautical.brassStroke, lineWidth: 3))
                // rope groove ring
                .overlay(Circle().inset(by: 7)
                    .stroke(Nautical.navy.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                .shadow(color: Nautical.brass.opacity(0.5), radius: 12, y: 4)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 5)
        }
    }

    // MARK: tension fight

    /// Tension mini-game HUD: vertical strain bar with a drifting green zone.
    /// Hold anywhere to raise the needle, release to drop it; keep it in the green.
    // MARK: bait

    private var baitChip: some View {
        Button { showBaitPicker = true } label: {
            HStack(spacing: 5) {
                bundleImage(state.equippedBait).resizable().scaledToFit().frame(width: 26, height: 26)
                if state.equippedBait != "bait_worm" {
                    Text("\(state.baitCounts[state.equippedBait, default: 0])")
                        .font(fredoka(14, "Bold")).foregroundStyle(Nautical.cream)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Nautical.panelFill, in: Capsule())
            .overlay(Capsule().strokeBorder(Nautical.brassStroke, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        }
    }

    private var baitPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { showBaitPicker = false }
            VStack(spacing: Nautical.s1) {
                Text("Bait").gameText(22, weight: "Bold")
                ForEach(allBaits) { bait in
                    let owned = bait.cost == 0 ? Int.max : state.baitCounts[bait.id, default: 0]
                    HStack(spacing: 10) {
                        bundleImage(bait.id).resizable().scaledToFit().frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(bait.name).font(fredoka(15, "SemiBold")).foregroundStyle(Nautical.cream)
                            Text(bait.desc).font(fredoka(11)).foregroundStyle(Nautical.cream.opacity(0.6))
                        }
                        Spacer()
                        if bait.cost == 0 {
                            Text("∞").font(fredoka(16, "Bold")).foregroundStyle(Nautical.brassBright)
                        } else {
                            Text("×\(owned)").font(fredoka(14, "Bold")).foregroundStyle(Nautical.cream)
                            Button {
                                state.buyBait(bait)
                            } label: {
                                (Text("\(bait.cost) ") + sdT)
                                    .font(fredoka(12, "Bold")).foregroundStyle(Nautical.brassBright)
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .background(Nautical.navy, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Nautical.brass.opacity(0.6), lineWidth: 1))
                            }
                            .disabled(state.coins < bait.cost)
                            .opacity(state.coins < bait.cost ? 0.4 : 1)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(state.equippedBait == bait.id ? Nautical.brass.opacity(0.25) : .white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(state.equippedBait == bait.id ? Nautical.brassBright : .clear, lineWidth: 1.5))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // equip if we own one (or it's the worm)
                        if bait.cost == 0 || owned > 0 { state.equippedBait = bait.id; state.save() }
                    }
                }
            }
            .padding(Nautical.s2)
            .frame(maxWidth: 380)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Nautical.panelRadius))
            .background(RoundedRectangle(cornerRadius: Nautical.panelRadius).fill(Nautical.panelFill.opacity(0.85)))
            .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
            .overlay(RoundedRectangle(cornerRadius: Nautical.panelRadius).strokeBorder(Nautical.brassStroke, lineWidth: 2))
        }
    }

    // MARK: trophies (achievements + records + crates)

    private var trophiesOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { showTrophies = false; crateDrops = nil }
            VStack(spacing: Nautical.s1) {
                Text("Trophies").gameText(22, weight: "Bold")
                ScrollView {
                    VStack(spacing: 8) {
                        // records
                        HStack {
                            recordCell("Catches", state.records["totalCatches", default: 0])
                            recordCell("Deepest", state.records["deepestDive", default: 0], suffix: "m")
                            recordCell("Mythics", state.records["mythicsCaught", default: 0])
                            recordCell("Fights", state.records["fightsWon", default: 0])
                        }
                        // bait crate gacha
                        HStack(spacing: 10) {
                            bundleImage("crate").resizable().scaledToFit().frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Bait Crate").font(fredoka(15, "SemiBold")).foregroundStyle(Nautical.cream)
                                if let drops = crateDrops {
                                    Text(drops.map { $0.0 == "coins" ? "+\($0.1) coins" : "\($0.1)× \($0.0.replacingOccurrences(of: "bait_", with: ""))" }
                                        .joined(separator: ", "))
                                        .font(fredoka(11)).foregroundStyle(Nautical.brassBright)
                                } else {
                                    Text("Random baits + coins").font(fredoka(11)).foregroundStyle(Nautical.cream.opacity(0.6))
                                }
                            }
                            Spacer()
                            Button {
                                withAnimation(.spring(duration: 0.4)) { crateDrops = state.openCrate() }
                            } label: {
                                (Text("20 ") + gemT).font(fredoka(13, "Bold")).foregroundStyle(Nautical.teal)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Nautical.navy, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Nautical.brass.opacity(0.6), lineWidth: 1))
                            }
                            .disabled(state.gems < 20)
                            .opacity(state.gems < 20 ? 0.4 : 1)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.05)))
                        // achievements
                        ForEach(allAchievements) { a in
                            let progress = state.records[a.stat, default: 0]
                            let claimed = state.claimedAchievements.contains(a.id)
                            let ready = !claimed && progress >= a.goal
                            HStack(spacing: 10) {
                                Text(claimed ? "✅" : "🏅").font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(a.name).font(fredoka(14, "SemiBold")).foregroundStyle(Nautical.cream)
                                    Text("\(min(progress, a.goal))/\(a.goal)")
                                        .font(fredoka(11)).foregroundStyle(Nautical.cream.opacity(0.6))
                                }
                                Spacer()
                                if ready {
                                    Button { state.claimAchievement(a) } label: {
                                        Text("CLAIM").font(fredoka(12, "Bold")).foregroundStyle(.black)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(Nautical.brassBright, in: Capsule())
                                    }
                                } else if !claimed {
                                    (Text("\(a.coinReward) ") + sdT + Text(a.gemReward > 0 ? " \(a.gemReward) " : "") + (a.gemReward > 0 ? gemT : Text("")))
                                        .font(fredoka(11, "Bold")).foregroundStyle(Nautical.cream.opacity(0.5))
                                }
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(ready ? Nautical.brass.opacity(0.2) : .white.opacity(0.05)))
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .padding(Nautical.s2)
            .frame(maxWidth: 420)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Nautical.panelRadius))
            .background(RoundedRectangle(cornerRadius: Nautical.panelRadius).fill(Nautical.panelFill.opacity(0.85)))
            .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
            .overlay(RoundedRectangle(cornerRadius: Nautical.panelRadius).strokeBorder(Nautical.brassStroke, lineWidth: 2))
        }
    }

    private func recordCell(_ label: String, _ value: Int, suffix: String = "") -> some View {
        VStack(spacing: 2) {
            Text("\(value)\(suffix)").font(fredoka(16, "Bold")).foregroundStyle(Nautical.brassBright)
            Text(label).font(fredoka(10)).foregroundStyle(Nautical.cream.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
    }

    // MARK: daily login

    private var loginRewardOverlay: some View {
        let day = state.pendingLoginReward ?? 0
        let r = streakRewards[day]
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: Nautical.s2) {
                Text("Daily Reward").gameText(24, weight: "Bold")
                Text("Day \(day + 1) of 7 — streak \(state.loginStreak)")
                    .font(fredoka(13)).foregroundStyle(Nautical.cream.opacity(0.7))
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        Circle()
                            .fill(i <= day ? Nautical.brassBright : .white.opacity(0.15))
                            .frame(width: 14, height: 14)
                    }
                }
                (Text("+\(r.coins) ") + sdT + Text(r.gems > 0 ? "   +\(r.gems) " : "") + (r.gems > 0 ? gemT : Text("")))
                    .font(fredoka(20, "Bold")).foregroundStyle(Nautical.brassBright)
                Button { withAnimation { state.claimLoginReward() } } label: {
                    Text("CLAIM").gameText(18, weight: "Bold")
                        .padding(.horizontal, 44).padding(.vertical, 12)
                        .background(Capsule().fill(LinearGradient(colors: [Nautical.brassBright, Nautical.brass],
                                                                  startPoint: .top, endPoint: .bottom)))
                }
            }
            .padding(Nautical.s3)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Nautical.panelRadius))
            .background(RoundedRectangle(cornerRadius: Nautical.panelRadius).fill(Nautical.panelFill.opacity(0.85)))
            .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
            .overlay(RoundedRectangle(cornerRadius: Nautical.panelRadius).strokeBorder(Nautical.brassStroke, lineWidth: 2))
        }
    }

    /// Depth-band biome name + tint for the HUD.
    private func biomeName(_ m: Int) -> (String, Color) {
        switch m {
        case ..<250: return ("REEF", Nautical.sand)
        case ..<500: return ("KELP FOREST", .green)
        case ..<800: return ("ABYSS", Nautical.teal)
        default:     return ("TRENCH", Nautical.danger)
        }
    }

    private var fightOverlay: some View {
        let strained = state.fightTension > 0.85
        let barH: CGFloat = 190
        return ZStack(alignment: .bottomTrailing) {
            // line-strain vignette when tension pegs
            RadialGradient(colors: [.clear, .clear, Nautical.danger.opacity(strained ? 0.5 : 0)],
                           center: .center, startRadius: 160, endRadius: 520)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.15), value: strained)
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    if state.fightIsBoss { Text("👑") }
                    Text(state.fightFishName).gameText(17, color: state.fightIsBoss ? .orange : .white)
                }
                HStack(spacing: 12) {
                    // catch progress column
                    VStack(spacing: 4) {
                        Text("\(Int(state.fightProgress * 100))%").gameText(13, color: Nautical.teal)
                        GeometryReader { _ in
                            ZStack(alignment: .bottom) {
                                Capsule().fill(.white.opacity(0.12))
                                Capsule().fill(LinearGradient(colors: [Nautical.teal, Nautical.navyLight], startPoint: .bottom, endPoint: .top))
                                    .frame(height: max(6, barH * state.fightProgress))
                                    .animation(.linear(duration: 0.08), value: state.fightProgress)
                            }
                        }
                        .frame(width: 14, height: barH)
                        // fish stamina
                        Text(state.fightStamina <= 0 ? "TIRED" : "💪")
                            .gameText(11, color: state.fightStamina <= 0 ? .green : .white)
                    }
                    // tension bar with green zone + needle
                    ZStack(alignment: .bottom) {
                        Capsule().fill(
                            LinearGradient(colors: [Nautical.success.opacity(0.25), .yellow.opacity(0.25), Nautical.danger.opacity(0.4)],
                                           startPoint: .bottom, endPoint: .top))
                        // drifting green zone
                        Capsule()
                            .fill(Nautical.success.opacity(0.75))
                            .frame(width: 34, height: barH * state.fightZoneWidth)
                            .offset(y: -barH * (state.fightZoneCenter - state.fightZoneWidth / 2))
                            .animation(.linear(duration: 0.1), value: state.fightZoneCenter)
                        // needle
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white)
                            .frame(width: 42, height: 5)
                            .shadow(color: strained ? Nautical.danger : .black.opacity(0.5), radius: 4)
                            .offset(y: -barH * min(state.fightTension, 1))
                            .animation(.linear(duration: 0.05), value: state.fightTension)
                    }
                    .frame(width: 34, height: barH)
                    .modifier(ShakeEffect(shakes: state.fightPulling ? 2 : 0))
                    .animation(.easeInOut(duration: 0.5), value: state.fightPulling)
                }
                Text(state.fightPulling ? "SURGE — LET GO!" : (state.fightHolding ? "REELING" : "HOLD"))
                    .gameText(13, color: state.fightPulling ? Nautical.danger : .white)
                    .animation(.spring(duration: 0.25), value: state.fightPulling)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Nautical.panelRadius)
                .fill(.black.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: Nautical.panelRadius)
                    .strokeBorder(strained ? Nautical.danger.opacity(0.8) : .white.opacity(0.25), lineWidth: 1.5)))
            .shadow(color: strained ? Nautical.danger.opacity(0.6) : .black.opacity(0.4),
                    radius: strained ? 18 : 10)
            .padding(.trailing, 30)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in state.fightHolding = true }
                .onEnded { _ in state.fightHolding = false }
        )
    }

    // MARK: haul summary

    private var summaryOverlay: some View {
        VStack(spacing: 12) {
            Text("Haul!").font(.largeTitle.bold())
            if state.lastGemsWon > 0 {
                (Text("+\(state.lastGemsWon) ") + gemT).font(.title2.bold()).foregroundStyle(Nautical.teal)
            }
            if state.lastHaul.isEmpty {
                Text("Nothing this time…").foregroundStyle(.secondary)
                Button { state.phase = .surface } label: {
                    Text("Continue").font(.title2.bold()).padding(.horizontal, 40).padding(.vertical, 10)
                        .background(.blue, in: Capsule()).foregroundStyle(.white)
                }
            } else {
                ForEach(groupedHaul, id: \.0) { name, count, total in
                    HStack {
                        Text("\(name) ×\(count)")
                        Spacer()
                        (Text("\(total) ") + sdT).bold()
                    }
                    .font(.title3)
                }
                Divider()
                HStack(spacing: 14) {
                    Button { state.sellHaul() } label: {
                        (Text("Sell +\(state.lastHaul.reduce(0) { $0 + $1.species.value }) ") + sdT)
                            .font(.title3.bold()).padding(.horizontal, 22).padding(.vertical, 10)
                            .background(.green, in: Capsule()).foregroundStyle(.white)
                    }
                    Button { state.keepHaul() } label: {
                        Label("Keep", systemImage: "fish.fill").font(.title3.bold()).padding(.horizontal, 22).padding(.vertical, 10)
                            .background(.blue, in: Capsule()).foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var groupedHaul: [(String, Int, Int)] {
        Dictionary(grouping: state.lastHaul, by: { $0.species.id }).values.map { group in
            let s = group[0].species
            return (s.name, group.count, s.value * group.count)
        }
        .sorted { $0.2 > $1.2 }
    }
}

// MARK: - Sprite thumbnail

struct SpriteImage: View {
    let assetName: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let ui = UIImage(named: assetName) {
                Image(uiImage: ui).resizable().scaledToFit()
            } else {
                Image(uiImage: fallbackFishImage).resizable().scaledToFit().opacity(0.6)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Inventory

struct InventoryView: View {
    @Bindable var state: GameState
    @Environment(\.dismiss) private var dismiss

    private var rows: [(FishSpecies, Int)] {
        state.inventory.compactMap { id, n in species(for: id).map { ($0, n) } }
            .sorted { $0.0.value > $1.0.value }
    }

    var body: some View {
        NavigationStack {
            Group {
                if rows.isEmpty {
                    ContentUnavailableView("No fish kept", systemImage: "fish",
                        description: Text("Catch fish and tap Keep to store them here."))
                } else {
                    List(rows, id: \.0.id) { sp, n in
                        HStack {
                            SpriteImage(assetName: sp.id)
                            VStack(alignment: .leading) {
                                Text("\(sp.name) ×\(n)").font(.headline)
                                (Text("\(sp.rarity.label) — \(sp.value) ") + sdT + Text(" each"))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Sell 1") { state.sellFromInventory(sp.id) }
                                .buttonStyle(.bordered)
                            Button("Sell All") { state.sellFromInventory(sp.id, count: n) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle("Fish — \(state.coins)")
            .nauticalSheet()
            .toolbar {
                if !rows.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button { state.sellAllInventory() } label: { Text("Sell Everything (+\(state.inventoryTotalValue) ") + sdT + Text(")") }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Aquarium

struct AquariumView: View {
    @Bindable var state: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var tank: AquariumScene = {
        let s = AquariumScene()
        s.scaleMode = .resizeFill
        return s
    }()

    private var placed: [(FishSpecies, Int)] {
        state.aquarium.compactMap { id, n in species(for: id).map { ($0, n) } }
            .sorted { $0.0.rarity > $1.0.rarity }
    }
    private var equippable: [(FishSpecies, Int)] {
        state.inventory.compactMap { id, n in species(for: id).map { ($0, n) } }
            .sorted { $0.0.rarity > $1.0.rarity }
    }

    var body: some View {
        ZStack {
            // room fills the screen
            bundleImage(state.currentRoom)
                .resizable().scaledToFill()
                .ignoresSafeArea()

            // glass tank, big and center
            SpriteView(scene: tank, options: [.allowsTransparency])
                .frame(width: 560, height: 210)
                .background(Color(red: 0.16, green: 0.45, blue: 0.6).opacity(0.6))
                .overlay(alignment: .top) {
                    Rectangle().fill(.white.opacity(0.35)).frame(height: 5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.25)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
                .offset(y: -34)
                .onAppear { tank.populate(state.aquarium) }
                .onChange(of: state.aquarium) { _, new in tank.populate(new) }

            VStack {
                // floating top bar
                HStack(spacing: 10) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline.bold()).foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Nautical.panelFill, in: Circle())
                            .overlay(Circle().strokeBorder(Nautical.brassStroke, lineWidth: 1.5))
                    }
                    aquaPanel {
                        (Text("\(String(format: "%.1f", state.aquariumIncomePerMin)) ") + sdT + Text("/min"))
                            .font(fredoka(15, "Bold")).foregroundStyle(.white)
                    }
                    aquaPanel {
                        Text("Slots \(state.aquarium.count)/\(state.aquariumCapacity)")
                            .font(fredoka(15, "Bold")).foregroundStyle(.white)
                    }
                    Spacer()
                    Button { state.collectEarnings() } label: {
                        aquaPanel(highlight: state.pendingEarnings > 0) {
                            (Text("Collect +\(state.pendingEarnings) ") + sdT)
                                .font(fredoka(15, "Bold")).foregroundStyle(.white)
                        }
                    }
                    .disabled(state.pendingEarnings == 0)
                    Button { state.upgradeAquarium() } label: {
                        aquaPanel {
                            (Text("+Slot \(state.aquariumUpgradeCost) ") + gemT)
                                .font(fredoka(15, "Bold")).foregroundStyle(Nautical.teal)
                        }
                    }
                    .disabled(state.gems < state.aquariumUpgradeCost)
                    Button { state.equipBest() } label: {
                        aquaPanel { Text("Equip Best").font(fredoka(15, "Bold")).foregroundStyle(Nautical.brassBright) }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)

                Spacer()

                // fish management strip: tank residents then inventory
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(placed, id: \.0.id) { sp, n in
                            fishCard(sp, n, inTank: true)
                        }
                        ForEach(equippable, id: \.0.id) { sp, n in
                            fishCard(sp, n, inTank: false)
                        }
                        if placed.isEmpty && equippable.isEmpty {
                            Text("Catch fish and tap Keep to fill your tank")
                                .font(fredoka(15)).foregroundStyle(.white.opacity(0.9))
                                .padding(14)
                                .background(Nautical.panelFill, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 10)
            }
        }
        .statusBarHidden()
        .buttonStyle(PressButtonStyle())
    }

    private func aquaPanel(highlight: Bool = false, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Nautical.panelFill, in: Capsule())
            .overlay(Capsule().strokeBorder(
                highlight ? AnyShapeStyle(Color.green) : AnyShapeStyle(Nautical.brassStroke), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
    }

    private func fishCard(_ sp: FishSpecies, _ n: Int, inTank: Bool) -> some View {
        VStack(spacing: 4) {
            SpriteImage(assetName: sp.id, size: 42)
            Text("\(sp.name) ×\(n)")
                .font(fredoka(11, "Medium")).foregroundStyle(.white)
                .lineLimit(1)
            if inTank {
                (Text("\(String(format: "%.1f", Double(sp.rarity.incomePerMin) * state.incomeMultiplier(sp, count: n))) ") + sdT + Text("/m"))
                    .font(fredoka(10)).foregroundStyle(Nautical.brassBright)
            }
            Button {
                inTank ? state.unequip(sp.id) : state.equip(sp.id)
            } label: {
                Text(inTank ? "Remove" : "Add")
                    .font(fredoka(12, "Bold")).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(inTank ? Color(red: 0.6, green: 0.25, blue: 0.2)
                                                      : Color(red: 0.15, green: 0.55, blue: 0.3)))
            }
            .disabled(!inTank && state.aquarium[sp.id] == nil && state.aquarium.count >= state.aquariumCapacity)
        }
        .padding(8)
        .frame(width: 116)
        .background(Nautical.panelFill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(inTank ? AnyShapeStyle(Nautical.brassStroke) : AnyShapeStyle(Color.white.opacity(0.3)), lineWidth: 1.5))
    }
}

/// Small SpriteKit tank with the placed fish swimming.
final class AquariumScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = .clear // room art shows through the glass
    }

    func populate(_ aquarium: [String: Int]) {
        removeAllChildren()
        var i = 0
        for (id, count) in aquarium {
            guard let sp = species(for: id) else { continue }
            for _ in 0..<min(count, 4) {
                let tex = SKTexture(imageNamed: sp.id)
                guard tex.size().width > 1 else { continue }
                let node = SKSpriteNode(texture: tex)
                let w = min(sp.size, 60)
                node.size = CGSize(width: w, height: tex.size().height * w / tex.size().width)
                let y = CGFloat.random(in: 25...170)
                node.position = CGPoint(x: .random(in: 20...520), y: y)
                addChild(node)
                let dur = Double.random(in: 5...9)
                let flipL = SKAction.run { node.xScale = abs(node.xScale) }
                let flipR = SKAction.run { node.xScale = -abs(node.xScale) }
                node.run(.repeatForever(.sequence([
                    flipR, .moveTo(x: 540, duration: dur),
                    flipL, .moveTo(x: 15, duration: dur),
                ])))
                i += 1
            }
        }
    }
}

// MARK: - Dex

struct DexView: View {
    @Bindable var state: GameState
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]
    private var catchable: [FishSpecies] { allFish }

    private func rarityColor(_ r: Rarity) -> Color {
        switch r {
        case .common: return Color(red: 0.62, green: 0.65, blue: 0.66)
        case .uncommon: return Color(red: 0.42, green: 0.72, blue: 0.42)
        case .rare: return Color(red: 0.32, green: 0.56, blue: 0.85)
        case .epic: return Color(red: 0.63, green: 0.4, blue: 0.85)
        case .legendary: return Color(red: 0.93, green: 0.7, blue: 0.25)
        case .mythic: return Color(red: 0.9, green: 0.35, blue: 0.45)
        case .boss: return Color(red: 0.25, green: 0.85, blue: 0.85)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                // chest progress track — star count fills toward each milestone chest
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text(" \(state.discovered.count)").font(.headline.bold()).foregroundStyle(.white)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.15)).frame(height: 10)
                                Capsule().fill(
                                    LinearGradient(colors: [.green, Nautical.brassBright],
                                                   startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width
                                        * min(CGFloat(state.discovered.count) / CGFloat(dexMilestones.last!.species), 1),
                                        height: 10)
                            }
                            .frame(maxHeight: .infinity)
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 44)
                    HStack {
                        Spacer()
                        ForEach(dexMilestones, id: \.species) { m in
                            let claimed = state.claimedChests.contains(m.species)
                            Button { state.claimChest(m) } label: {
                                VStack(spacing: 2) {
                                    bundleImage("chest")
                                        .resizable().scaledToFit().frame(height: 34)
                                        .saturation(claimed ? 0.2 : 1)
                                        .overlay {
                                            if state.canClaimChest(m) {
                                                Circle().fill(.red).frame(width: 10, height: 10)
                                                    .offset(x: 14, y: -14)
                                            }
                                        }
                                    Text("\(m.species)").font(.caption.bold())
                                        .foregroundStyle(state.discovered.count >= m.species ? Nautical.brassBright : .white.opacity(0.5))
                                }
                            }
                            .disabled(!state.canClaimChest(m))
                            .buttonStyle(.plain)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(catchable) { sp in
                        let found = state.discovered.contains(sp.id)
                        let frame = rarityColor(sp.rarity)
                        VStack(spacing: 0) {
                            HStack(spacing: 1) {
                                ForEach(0..<sp.rarity.stars, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(found ? .yellow : .white.opacity(0.3))
                                }
                            }
                            .padding(.top, 6)
                            SpriteImage(assetName: sp.id, size: 58)
                                .silhouette(!found)
                                .frame(height: 62)
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(colors: [Color(red: 0.16, green: 0.42, blue: 0.52),
                                                            Color(red: 0.1, green: 0.28, blue: 0.4)],
                                                   startPoint: .top, endPoint: .bottom))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(.horizontal, 6)
                                .padding(.top, 4)
                            Text(found ? sp.name : "???")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.vertical, 5)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [frame, frame.opacity(0.65)],
                                                     startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.black.opacity(0.45), lineWidth: 2))
                        .opacity(found ? 1 : 0.75)
                    }
                }
                .padding()
            }
            .navigationTitle("Collection — \(state.discovered.count)/\(allFish.count)")
            .nauticalSheet()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func silhouette(_ on: Bool) -> some View {
        if on {
            self.colorMultiply(.black).opacity(0.55)
        } else {
            self
        }
    }
}

// MARK: - Quests

struct QuestsView: View {
    @Bindable var state: GameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(state.quests) { q in
                HStack {
                    VStack(alignment: .leading) {
                        Text(q.title).font(.headline)
                        ProgressView(value: Double(min(q.progress, q.target)), total: Double(q.target))
                        Text("\(min(q.progress, q.target))/\(q.target)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if q.claimed {
                        Text("✅").font(.title2)
                    } else {
                        Button { state.claimQuest(q.id) } label: { Text("+\(q.gemReward) ") + gemT }
                            .buttonStyle(.borderedProminent)
                            .disabled(!q.done)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Daily Quests")
            .nauticalSheet()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { state.refreshQuests() }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Bindable var state: GameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Sound", isOn: Binding(
                    get: { state.soundOn },
                    set: { state.soundOn = $0; state.save() }))
                Toggle("Haptics", isOn: Binding(
                    get: { state.hapticsOn },
                    set: { state.hapticsOn = $0; state.save() }))
            }
            .navigationTitle("Settings")
            .nauticalSheet()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Shop

struct ShopView: View {
    @Bindable var state: GameState
    var scene: GameScene?
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable, Identifiable {
        case reel, line, bag, hook, boats, skins, rooms
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .reel: return "icon_reel"
            case .line: return "icon_line"
            case .bag: return "icon_bag"
            case .hook: return "icon_hooktab"
            case .boats: return "icon_boat"
            case .skins: return "hook_trident"
            case .rooms: return "icon_room"
            }
        }
        var track: UpgradeTrack? {
            switch self {
            case .reel: return .reel
            case .line: return .line
            case .bag: return .bag
            case .hook: return .hook
            default: return nil
            }
        }
    }
    @State private var tab: Tab = .reel

    var body: some View {
        ZStack {
            Nautical.panelFill.ignoresSafeArea()
            VStack(spacing: 8) {
                // header: title + currencies + close
                HStack {
                    CurrencyBadge(icon: "icon_sanddollar", amount: state.coins, tint: Color(red: 0.96, green: 0.87, blue: 0.6))
                    CurrencyBadge(icon: "icon_diamond", amount: state.gems, tint: Nautical.teal)
                    Spacer()
                    Text("SHOP").gameText(30, weight: "Bold").kerning(3)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline.bold()).foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.12), in: Circle())
                            .overlay(Circle().strokeBorder(Nautical.brassStroke, lineWidth: 1.5))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                HStack(spacing: 12) {
                    // tab rail
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Tab.allCases) { t in
                                Button { tab = t } label: {
                                    bundleImage(t.icon)
                                        .resizable().scaledToFit()
                                        .padding(7)
                                        .frame(width: 56, height: 56)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(tab == t ? AnyShapeStyle(Nautical.brassStroke)
                                                               : AnyShapeStyle(Color.white.opacity(0.08))))
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Nautical.brass.opacity(tab == t ? 1 : 0.4), lineWidth: 2))
                                }
                            }
                        }
                    }
                    .frame(width: 68)

                    // item panel
                    Group {
                        if let track = tab.track {
                            gearPanel(track)
                        } else if tab == .boats {
                            cardList(allBoats.map { ($0.id, $0.name, $0.gemCost) },
                                     owned: state.ownedBoats, current: state.currentBoat,
                                     select: { id in if let b = allBoats.first(where: { $0.id == id }) { state.selectBoat(b); scene?.rebuildBoat() } },
                                     buy: { id in if let b = allBoats.first(where: { $0.id == id }) { state.buyBoat(b); scene?.rebuildBoat() } })
                        } else if tab == .skins {
                            cardList(allHooks.map { ($0.id, $0.name, $0.gemCost) },
                                     owned: state.ownedHooks, current: state.currentHook,
                                     select: { id in if let h = allHooks.first(where: { $0.id == id }) { state.selectHook(h); scene?.rebuildHook() } },
                                     buy: { id in if let h = allHooks.first(where: { $0.id == id }) { state.buyHook(h); scene?.rebuildHook() } })
                        } else {
                            cardList(allRooms.map { ($0.id, $0.name, $0.gemCost) },
                                     owned: state.ownedRooms, current: state.currentRoom,
                                     select: { id in if let r = allRooms.first(where: { $0.id == id }) { state.selectRoom(r) } },
                                     buy: { id in if let r = allRooms.first(where: { $0.id == id }) { state.buyRoom(r) } })
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Nautical.brassStroke, lineWidth: 2)))
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
        }
        .buttonStyle(PressButtonStyle())
    }

    /// Big single-item panel like the reference: name plate, art, pips, price.
    private func gearPanel(_ track: UpgradeTrack) -> some View {
        let level = state.levels[track] ?? 1
        let art: String = {
            switch track {
            case .reel: return "rod_\(level)"
            case .line: return "icon_line"
            case .bag: return "icon_bag"
            case .hook: return state.currentHook
            }
        }()
        return VStack(spacing: 10) {
            Text(track == .reel ? "Rod & Reel — Tier \(level)" : track.title)
                .gameText(20, weight: "Bold")
                .padding(.horizontal, 18).padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.1)))
                .overlay(Capsule().strokeBorder(Nautical.brassStroke, lineWidth: 1.5))
            bundleImage(art)
                .resizable().scaledToFit()
                .frame(maxHeight: 150)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            Text(track.effectText(level: level))
                .gameText(15, weight: "Medium", color: .white.opacity(0.9))
            // level pips
            HStack(spacing: 4) {
                ForEach(1...GameState.maxLevel, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i <= level ? AnyShapeStyle(LinearGradient(colors: [.green, Nautical.brassBright], startPoint: .top, endPoint: .bottom))
                                         : AnyShapeStyle(Color.white.opacity(0.15)))
                        .frame(width: 22, height: 12)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.4), lineWidth: 1))
                }
            }
            if level >= GameState.maxLevel {
                Text("MAX").gameText(22, weight: "Bold", color: .green)
            } else {
                Button {
                    state.buy(track)
                    if track == .reel { scene?.rebuildBoat() } // rod art on the boat upgrades too
                } label: {
                    (Text("Upgrade  \(state.cost(track)) ") + sdT)
                        .font(fredoka(18, "Bold"))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 26).padding(.vertical, 10)
                        .background(Capsule().fill(
                            state.canBuy(track)
                                ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.2, green: 0.65, blue: 0.3), Color(red: 0.1, green: 0.5, blue: 0.25)], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.gray.opacity(0.4))))
                        .overlay(Capsule().strokeBorder(Nautical.brassStroke, lineWidth: 2))
                }
                .disabled(!state.canBuy(track))
            }
        }
        .padding(12)
    }

    /// Vertical cards for boats / hook skins / rooms.
    private func cardList(_ items: [(id: String, name: String, cost: Int)],
                          owned: [String], current: String,
                          select: @escaping (String) -> Void,
                          buy: @escaping (String) -> Void) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(items, id: \.id) { item in
                    HStack(spacing: 12) {
                        bundleImage(item.id)
                            .resizable().scaledToFit()
                            .frame(width: 110, height: 62)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name).gameText(16, weight: "Bold")
                            if item.cost > 0 && !owned.contains(item.id) {
                                (Text("\(item.cost) ") + gemT).font(fredoka(14)).foregroundStyle(Nautical.teal)
                            }
                        }
                        Spacer()
                        if current == item.id {
                            Text("ACTIVE").gameText(14, weight: "Bold", color: .green)
                        } else if owned.contains(item.id) {
                            shopButton("Select", enabled: true) { select(item.id) }
                        } else {
                            shopButton("Buy", enabled: state.gems >= item.cost) { buy(item.id) }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Nautical.brass.opacity(current == item.id ? 1 : 0.35), lineWidth: 1.5))
                }
            }
            .padding(10)
        }
    }

    private func shopButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(fredoka(15, "Bold")).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 7)
                .background(Capsule().fill(enabled ? Color(red: 0.15, green: 0.55, blue: 0.3) : .gray.opacity(0.4)))
                .overlay(Capsule().strokeBorder(Nautical.brassStroke, lineWidth: 1.5))
        }
        .disabled(!enabled)
    }
}
