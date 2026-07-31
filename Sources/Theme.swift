import SwiftUI

// MARK: - Design system: single source of truth for color, type, spacing.

enum Nautical {
    // palette
    static let navy = Color(red: 0.05, green: 0.12, blue: 0.19)        // #0B304D family
    static let navyLight = Color(red: 0.09, green: 0.19, blue: 0.29)
    static let brass = Color(red: 0.78, green: 0.62, blue: 0.28)
    static let brassBright = Color(red: 0.96, green: 0.82, blue: 0.47) // #F6D477 family
    static let cream = Color(red: 0.96, green: 0.93, blue: 0.86)
    static let danger = Color(red: 0.85, green: 0.25, blue: 0.2)
    static let success = Color(red: 0.15, green: 0.55, blue: 0.3)

    // gold/brass accents pulled from the reference art
    static let copper = Color(red: 0.82, green: 0.55, blue: 0.27)  // #D18D46
    static let sand   = Color(red: 0.98, green: 0.82, blue: 0.67)  // #F9D1AA
    static let tan    = Color(red: 0.65, green: 0.49, blue: 0.33)  // #A57E54
    static let bronze = Color(red: 0.73, green: 0.58, blue: 0.38)  // #BB9361

    static var brassStroke: LinearGradient {
        LinearGradient(colors: [brassBright, brass, brassBright.opacity(0.7)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var panelFill: LinearGradient {
        LinearGradient(colors: [navyLight, navy], startPoint: .top, endPoint: .bottom)
    }

    // 8pt spacing grid
    static let s1: CGFloat = 8
    static let s2: CGFloat = 16
    static let s3: CGFloat = 24
    static let s4: CGFloat = 32

    static let cornerRadius: CGFloat = 14
    static let panelRadius: CGFloat = 18
}

// MARK: - Game font (Fredoka, registered at runtime — no plist entry needed)

func fredoka(_ size: CGFloat, _ weight: String = "SemiBold") -> Font {
    .custom("Fredoka-\(weight)", size: size)
}

// MARK: - Outlined game text
// Real layered outline: 4 offset black copies behind the fill (no blurry shadow stack).

struct GameText: ViewModifier {
    var size: CGFloat
    var weight: String = "SemiBold"
    var color: Color = .white
    private var offsets: [CGSize] {
        let d: CGFloat = max(1, size / 14)
        return [CGSize(width: d, height: d), CGSize(width: -d, height: d),
                CGSize(width: d, height: -d), CGSize(width: -d, height: -d)]
    }
    func body(content: Content) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                content
                    .font(fredoka(size, weight))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .offset(offsets[i])
            }
            content
                .font(fredoka(size, weight))
                .foregroundStyle(color)
        }
    }
}
extension View {
    func gameText(_ size: CGFloat, weight: String = "SemiBold", color: Color = .white) -> some View {
        modifier(GameText(size: size, weight: weight, color: color))
    }
}

// MARK: - Shake (used for line-strain feedback in the fight HUD)

struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(shakes * .pi * 8) * 3, y: 0))
    }
}

// MARK: - Press feedback for every game button

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - Currency glyphs + themed image fallback

/// Themed navy fish silhouette drawn once — the fallback when an asset is missing (never an SF symbol).
let fallbackFishImage: UIImage = {
    let size = CGSize(width: 64, height: 40)
    return UIGraphicsImageRenderer(size: size).image { _ in
        let navy = UIColor(red: 0.09, green: 0.19, blue: 0.29, alpha: 1)
        navy.setFill()
        // body
        UIBezierPath(ovalIn: CGRect(x: 8, y: 8, width: 40, height: 24)).fill()
        // tail
        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: 46, y: 20))
        tail.addLine(to: CGPoint(x: 62, y: 6))
        tail.addLine(to: CGPoint(x: 62, y: 34))
        tail.close()
        tail.fill()
        // eye
        UIColor(red: 0.96, green: 0.82, blue: 0.47, alpha: 1).setFill()
        UIBezierPath(ovalIn: CGRect(x: 15, y: 15, width: 5, height: 5)).fill()
    }
}()

/// Bundle image with a themed silhouette fallback (never a random SF symbol).
func bundleImage(_ name: String) -> Image {
    Image(uiImage: UIImage(named: name) ?? fallbackFishImage)
}

/// Bundle image downscaled to text-glyph size for inline use in Text.
func glyphImage(_ name: String, pt: CGFloat = 18) -> Image {
    guard let ui = UIImage(named: name) else { return Image(uiImage: fallbackFishImage) }
    let scale = pt / max(ui.size.width, ui.size.height)
    let size = CGSize(width: ui.size.width * scale, height: ui.size.height * scale)
    let scaled = UIGraphicsImageRenderer(size: size).image { _ in
        ui.draw(in: CGRect(origin: .zero, size: size))
    }
    return Image(uiImage: scaled)
}
let sdT = Text(glyphImage("icon_sanddollar")).baselineOffset(-2)
let gemT = Text(glyphImage("icon_diamond")).baselineOffset(-2)

// MARK: - Currency badge with bevel

struct CurrencyBadge: View {
    let icon: String
    let amount: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            bundleImage(icon).resizable().scaledToFit().frame(width: 24, height: 24)
            Text("\(amount)").font(fredoka(19, "Bold")).foregroundStyle(tint)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Nautical.panelFill, in: Capsule())
        // bevel: bright top edge + dark bottom edge reads as an inset metal chip
        .overlay(
            Capsule().strokeBorder(
                LinearGradient(colors: [.white.opacity(0.45), Nautical.brass.opacity(0.6), .black.opacity(0.4)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1.5))
        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
    }
}

// MARK: - Sheet + row chrome

/// Navy sheet background + brass-tinted rows for every menu screen.
struct NauticalSheet: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Nautical.panelFill.ignoresSafeArea())
            .tint(Nautical.brassBright)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .environment(\.colorScheme, .dark)
    }
}
extension View {
    func nauticalSheet() -> some View { modifier(NauticalSheet()) }
    func nauticalRow() -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Nautical.brass.opacity(0.35), lineWidth: 1))
                .padding(.vertical, 3)
        )
    }
}
