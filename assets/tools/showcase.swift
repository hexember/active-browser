// showcase.swift -- renders the ActiveBrowser showcase video shown at the top of
// README.md (media/showcase.mp4) and its poster frame. Every frame is drawn with
// CoreGraphics/AppKit and encoded to H.264 MP4 (faststart) with AVFoundation.
// Developer tool only: it lives under assets/, so SwiftPM never compiles it and
// the Pages site never publishes it. See assets/README.md, "Showcase video".
//
// Usage (run from the repo root):
//   OUT_SCALE=0.6666667 BITRATE=1400000 swift assets/tools/showcase.swift <repo-root> <out.mp4> <poster.png> [preview-seconds…]
//
// Environment:
//   OUT_SCALE     scale of the encoded video relative to 1920x1080 (default 1;
//                 0.6666667 gives the shipped 1280x720). The poster and preview
//                 PNGs are always 1920x1080.
//   BITRATE       average H.264 bit rate in bits/s (default 3500000; shipped 1400000).
//   PREVIEW_ONLY  if set and preview seconds are given, write the poster and the
//                 preview PNGs (<poster>-<seconds>.png) and exit without encoding.
//
// Inputs:
//   /Applications/Arc.app, /Applications/Brave Browser.app, /Applications/Safari.app
//     (their icons, via NSWorkspace; a missing app renders a generic icon)
//   <repo-root>/assets/icon-1024.png
//   <repo-root>/assets/menubar-icon.svg (falls back to assets/menubar/MenuBarIconTemplate.png)
//
// Guardrails: this script imports only AppKit and AVFoundation, so it meets the
// zero-third-party-dependencies rule. The MainActor-only / no-GCD rule governs
// the app's runtime state, not a one-shot command-line script, so the
// DispatchSemaphore and Thread.sleep used below to wait on AVAssetWriter are
// acceptable here and must not be copied into Sources/.
import AppKit
import AVFoundation

let args = CommandLine.arguments
let usage = "usage: OUT_SCALE=0.6666667 BITRATE=1400000 swift assets/tools/showcase.swift <repo-root> <out.mp4> <poster.png> [preview-seconds…]\n"
guard args.count >= 4 else { fputs(usage, stderr); exit(2) }
let repo = args[1], outPath = args[2], posterPath = args[3]
let W = 1920, H = 1080
let OUT_SCALE = Double(ProcessInfo.processInfo.environment["OUT_SCALE"] ?? "1")!
let OW = Int(Double(W) * OUT_SCALE), OH = Int(Double(H) * OUT_SCALE)
let BITRATE = Int(ProcessInfo.processInfo.environment["BITRATE"] ?? "3500000")!
let FPS: Int32 = 30
let DURATION = 31.0
let POSTER_T = 13.2

// MARK: - Assets
func appIcon(_ name: String) -> NSImage {
    NSWorkspace.shared.icon(forFile: URL(fileURLWithPath: "/Applications/\(name).app").resolvingSymlinksInPath().path)
}
let abIcon = NSImage(contentsOfFile: "\(repo)/assets/icon-1024.png")!
let menuIcon = NSImage(contentsOfFile: "\(repo)/assets/menubar-icon.svg")
    ?? NSImage(contentsOfFile: "\(repo)/assets/menubar/MenuBarIconTemplate.png")!
let arcIcon = appIcon("Arc"), braveIcon = appIcon("Brave Browser"), safariIcon = appIcon("Safari")

// MARK: - Helpers
func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
func ease(_ x: Double) -> Double { let t = clamp(x); return t < 0.5 ? 4*t*t*t : 1 - pow(-2*t + 2, 3)/2 }
func easeOut(_ x: Double) -> Double { let t = clamp(x); return 1 - pow(1 - t, 3) }
func prog(_ t: Double, _ a: Double, _ b: Double) -> Double { ease((t - a) / (b - a)) }
/// Fade in over [a, a+f], hold, fade out over [b-f, b].
func window(_ t: Double, _ a: Double, _ b: Double, _ f: Double = 0.4) -> Double {
    min(clamp((t - a) / f), clamp((b - t) / f))
}
func lerp(_ a: CGFloat, _ b: CGFloat, _ p: Double) -> CGFloat { a + (b - a) * CGFloat(p) }
func lerp(_ a: CGPoint, _ b: CGPoint, _ p: Double) -> CGPoint { CGPoint(x: lerp(a.x, b.x, p), y: lerp(a.y, b.y, p)) }
func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff)/255, green: CGFloat((v >> 8) & 0xff)/255, blue: CGFloat(v & 0xff)/255, alpha: a)
}

var ctx: CGContext!

func withAlpha(_ a: Double, _ body: () -> Void) {
    guard a > 0.001 else { return }
    ctx.saveGState(); ctx.setAlpha(CGFloat(a)); ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    ctx.endTransparencyLayer(); ctx.restoreGState()
}
func withTransform(scale s: CGFloat, about c: CGPoint, _ body: () -> Void) {
    ctx.saveGState()
    ctx.translateBy(x: c.x, y: c.y); ctx.scaleBy(x: s, y: s); ctx.translateBy(x: -c.x, y: -c.y)
    body()
    ctx.restoreGState()
}
func rrect(_ r: CGRect, _ rad: CGFloat, _ color: NSColor) {
    color.setFill(); NSBezierPath(roundedRect: r, xRadius: rad, yRadius: rad).fill()
}
func shadowed(blur: CGFloat, dy: CGFloat, alpha: CGFloat, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow(); s.shadowBlurRadius = blur; s.shadowOffset = NSSize(width: 0, height: -dy)
    s.shadowColor = NSColor.black.withAlphaComponent(alpha); s.set()
    body()
    NSGraphicsContext.restoreGraphicsState()
}
enum Align { case left, center, right }
@discardableResult
func text(_ s: String, _ font: NSFont, _ color: NSColor, _ p: CGPoint, _ align: Align = .left,
          underline: Bool = false, kern: CGFloat = 0) -> CGSize {
    var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: kern]
    if underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
    let a = NSAttributedString(string: s, attributes: attrs)
    let sz = a.size()
    let x: CGFloat = align == .left ? p.x : align == .center ? p.x - sz.width/2 : p.x - sz.width
    a.draw(at: CGPoint(x: x, y: p.y))
    return sz
}
func image(_ img: NSImage, _ r: CGRect, _ a: CGFloat = 1) {
    img.draw(in: r, from: .zero, operation: .sourceOver, fraction: a, respectFlipped: true, hints: nil)
}
func tinted(_ img: NSImage, _ r: CGRect, _ color: NSColor) {
    ctx.saveGState(); ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    image(img, r)
    color.setFill(); r.fill(using: .sourceAtop)
    ctx.endTransparencyLayer(); ctx.restoreGState()
}
func sys(_ size: CGFloat, _ w: NSFont.Weight = .regular) -> NSFont { .systemFont(ofSize: size, weight: w) }
func mono(_ size: CGFloat, _ w: NSFont.Weight = .regular) -> NSFont { .monospacedSystemFont(ofSize: size, weight: w) }
func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat = 14, _ c: NSColor = hex(0xe3e5ea)) {
    rrect(CGRect(x: x, y: y, width: w, height: h), h/2, c)
}

// MARK: - Background
func wallpaper() {
    let g = NSGradient(colors: [hex(0x14183a), hex(0x2a2266), hex(0x5a2a7e)], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
    g.draw(in: CGRect(x: 0, y: 0, width: W, height: H), angle: -70)
    for (c, x, y, r) in [(hex(0x7b5cff, 0.35), 380.0, 260.0, 700.0), (hex(0xff6ab0, 0.22), 1600.0, 900.0, 800.0)] {
        let rg = NSGradient(colors: [c, c.withAlphaComponent(0)])!
        rg.draw(fromCenter: CGPoint(x: x, y: y), radius: 0, toCenter: CGPoint(x: x, y: y), radius: r, options: [])
    }
}

// MARK: - Scene 1: title
func titleScene(_ t: Double) {
    let c = CGPoint(x: CGFloat(W)/2, y: 390)
    let s = 0.6 + 0.4 * easeOut(t / 0.7)
    withAlpha(clamp(t / 0.4)) {
        withTransform(scale: CGFloat(s), about: c) {
            shadowed(blur: 40, dy: 16, alpha: 0.45) { image(abIcon, CGRect(x: c.x - 130, y: c.y - 130, width: 260, height: 260)) }
        }
    }
    withAlpha(prog(t, 0.35, 0.95)) {
        text("ActiveBrowser", sys(104, .bold), .white, CGPoint(x: c.x, y: 560 + 20 * (1 - prog(t, 0.35, 0.95))), .center, kern: -1)
    }
    withAlpha(prog(t, 0.8, 1.4)) {
        text("Every link opens in the browser you were just using.", sys(44, .medium), hex(0xffffff, 0.82),
             CGPoint(x: c.x, y: 700), .center)
    }
}

// MARK: - Scene 2: the problem
func problemScene(_ t: Double) {
    let cx = CGFloat(W)/2
    let swap = prog(t, 2.3, 2.8)
    withAlpha(1 - swap) {
        text("macOS lets you pick one default browser.", sys(60, .bold), .white, CGPoint(x: cx, y: 180), .center)
    }
    withAlpha(swap) {
        text("ActiveBrowser follows your focus instead.", sys(60, .bold), .white, CGPoint(x: cx, y: 180), .center)
    }
    let icons: [(NSImage, String)] = [(arcIcon, "Arc"), (braveIcon, "Brave"), (safariIcon, "Safari")]
    let dim = prog(t, 1.1, 1.6) * (1 - swap)
    for (i, (img, name)) in icons.enumerated() {
        let x = cx + CGFloat(i - 1) * 340
        let appear = easeOut((t - 0.3 - Double(i) * 0.15) / 0.5)
        let alpha = appear * (i == 0 ? 1 : 1 - 0.72 * dim)
        withAlpha(alpha) {
            let r = CGRect(x: x - 110, y: 380 + 30 * (1 - appear), width: 220, height: 220)
            shadowed(blur: 30, dy: 12, alpha: 0.4) { image(img, r) }
            text(name, sys(36, .semibold), .white, CGPoint(x: x, y: 620), .center)
        }
    }
    // "Default" badge on Arc during the problem beat
    withAlpha(dim) {
        let r = CGRect(x: cx - 340 - 80, y: 350, width: 160, height: 48)
        rrect(r, 24, hex(0xffffff))
        text("Default", sys(26, .bold), hex(0x2a2266), CGPoint(x: r.midX, y: r.minY + 8), .center)
    }
    withAlpha(dim) {
        text("Every link goes there — even while you're working in another browser.", sys(38), hex(0xffffff, 0.8),
             CGPoint(x: cx, y: 740), .center)
    }
    withAlpha(swap) {
        text("No rules to write. No picker to click.", sys(38), hex(0xffffff, 0.8), CGPoint(x: cx, y: 740), .center)
    }
}

// MARK: - Desktop scene model
enum Win: String { case safari, brave, arc, chat }
struct BrowserStyle { let name: String; let icon: NSImage; let toolbar: NSColor; let toolbarText: NSColor; let accent: NSColor; let urlBar: NSColor; let tabActive: NSColor }
let styles: [Win: BrowserStyle] = [
    .arc: BrowserStyle(name: "Arc", icon: arcIcon, toolbar: hex(0xf1e3ff), toolbarText: hex(0x3b2360), accent: hex(0xa24cf5), urlBar: hex(0xffffff, 0.8), tabActive: hex(0xffffff)),
    .brave: BrowserStyle(name: "Brave Browser", icon: braveIcon, toolbar: hex(0x2b2d33), toolbarText: hex(0xf2f2f4), accent: hex(0xfb542b), urlBar: hex(0x3d4048), tabActive: hex(0x44474f)),
    .safari: BrowserStyle(name: "Safari", icon: safariIcon, toolbar: hex(0xeceef1), toolbarText: hex(0x333333), accent: hex(0x1a7cf5), urlBar: hex(0xffffff), tabActive: hex(0xffffff)),
]
let rects: [Win: CGRect] = [
    .safari: CGRect(x: 60, y: 180, width: 940, height: 640),
    .brave: CGRect(x: 110, y: 250, width: 960, height: 660),
    .arc: CGRect(x: 250, y: 110, width: 980, height: 680),
    .chat: CGRect(x: 1150, y: 330, width: 680, height: 540),
]
let D0 = 7.5, D1 = 26.8                     // desktop scene span (global seconds)
// Local-time events in the desktop scene
let focusEvents: [(Double, Win)] = [(2.3, .chat), (4.5, .arc), (8.0, .brave), (9.0, .chat), (11.2, .brave)]
let click1 = 3.3, click2 = 10.0, menuClick = 14.2
let msg2Arrive = 6.6

func zOrder(_ u: Double) -> [Win] {
    var order: [Win] = [.safari, .brave, .chat, .arc]
    for (t, w) in focusEvents where u >= t { order.removeAll { $0 == w }; order.append(w) }
    return order
}

// Link geometry inside the chat window
let link1 = CGPoint(x: rects[.chat]!.minX + 290, y: rects[.chat]!.minY + 176)
let link2 = CGPoint(x: rects[.chat]!.minX + 300, y: rects[.chat]!.minY + 330)
let menuIconCenter = CGPoint(x: 1618, y: 20)

func trafficLights(_ r: CGRect, _ focused: Bool, dark: Bool = false) {
    let cols: [NSColor] = focused ? [hex(0xff5f57), hex(0xfebc2e), hex(0x28c840)]
                                  : Array(repeating: dark ? hex(0x55575e) : hex(0xcfd1d6), count: 3)
    for (i, c) in cols.enumerated() {
        c.setFill(); NSBezierPath(ovalIn: CGRect(x: r.minX + 20 + CGFloat(i) * 24, y: r.minY + 16, width: 15, height: 15)).fill()
    }
}

enum Page { case guide, plan, localhost, login, start }

func drawPage(_ p: Page, _ r: CGRect, _ accent: NSColor) {
    let x = r.minX + 60, y = r.minY + 50
    switch p {
    case .guide:
        text("Getting Started", sys(40, .bold), hex(0x1d1d1f), CGPoint(x: x, y: y))
        for (i, w) in [720, 640, 690, 520].enumerated() { bar(x, y + 90 + CGFloat(i) * 34, CGFloat(w)) }
        rrect(CGRect(x: x, y: y + 250, width: 760, height: 150), 12, hex(0xf4f5f7))
        for (i, w) in [420, 520, 360].enumerated() { bar(x + 30, y + 285 + CGFloat(i) * 32, CGFloat(w), 12, hex(0xd4d7de)) }
    case .plan:
        text("Q3 Plan", sys(44, .bold), hex(0x1d1d1f), CGPoint(x: x, y: y))
        text("Shared by Maya · Design team", sys(22), hex(0x6e6e73), CGPoint(x: x, y: y + 64))
        let cols = [hex(0x7b5cff), hex(0xff6ab0), hex(0x2ec4b6)]
        for i in 0..<3 {
            let cr = CGRect(x: x + CGFloat(i) * 270, y: y + 130, width: 245, height: 230)
            rrect(cr, 16, hex(0xf6f6f9))
            rrect(CGRect(x: cr.minX, y: cr.minY, width: cr.width, height: 10), 5, cols[i])
            text(["Goals", "Milestones", "Owners"][i], sys(26, .semibold), hex(0x1d1d1f), CGPoint(x: cr.minX + 22, y: cr.minY + 34))
            for j in 0..<3 { bar(cr.minX + 22, cr.minY + 96 + CGFloat(j) * 36, CGFloat([180, 140, 160][j]), 12) }
        }
    case .localhost:
        rrect(CGRect(x: r.minX, y: r.minY, width: r.width, height: 70), 0, hex(0x1e2027))
        text("my-app", mono(24, .bold), .white, CGPoint(x: x, y: r.minY + 20))
        text("Welcome back", sys(46, .bold), hex(0x1d1d1f), CGPoint(x: x, y: y + 80))
        for i in 0..<3 { rrect(CGRect(x: x + CGFloat(i) * 270, y: y + 170, width: 245, height: 180), 14, hex(0xf2f3f5)) }
    case .login:
        let card = CGRect(x: r.midX - 230, y: r.minY + 60, width: 460, height: 400)
        shadowed(blur: 24, dy: 6, alpha: 0.12) { rrect(card, 18, .white) }
        text("Sign in", sys(38, .bold), hex(0x1d1d1f), CGPoint(x: card.midX, y: card.minY + 40), .center)
        text("staging", mono(20), hex(0x86868b), CGPoint(x: card.midX, y: card.minY + 96), .center)
        for i in 0..<2 {
            let f = CGRect(x: card.minX + 40, y: card.minY + 150 + CGFloat(i) * 76, width: card.width - 80, height: 56)
            rrect(f, 10, hex(0xd9dbe0)); rrect(f.insetBy(dx: 2, dy: 2), 9, .white)
            text(["Email", "Password"][i], sys(22), hex(0xa1a1a6), CGPoint(x: f.minX + 18, y: f.minY + 14))
        }
        let b = CGRect(x: card.minX + 40, y: card.minY + 314, width: card.width - 80, height: 56)
        rrect(b, 10, accent)
        text("Continue", sys(24, .semibold), .white, CGPoint(x: b.midX, y: b.minY + 13), .center)
    case .start:
        text("Favorites", sys(34, .bold), hex(0x1d1d1f), CGPoint(x: x, y: y))
        for i in 0..<8 {
            let cr = CGRect(x: x + CGFloat(i % 4) * 150, y: y + 80 + CGFloat(i / 4) * 160, width: 110, height: 110)
            rrect(cr, 22, [hex(0xdfe7ff), hex(0xffe3ef), hex(0xe2f7f1), hex(0xfff1d6)][i % 4])
        }
    }
}

struct BrowserState { var tabs: [String]; var url: String; var page: Page; var newTab: Double; var oldPage: Page; var oldURL: String }

func browserState(_ w: Win, _ u: Double) -> BrowserState {
    switch w {
    case .arc:
        let p = prog(u, 4.5, 5.0)
        return BrowserState(tabs: ["Getting Started", "Q3 Plan"], url: "docs.example.com/q3-plan", page: .plan, newTab: u < 4.5 ? 0 : p, oldPage: .guide, oldURL: "reference.example.dev/guide")
    case .brave:
        let p = prog(u, 11.2, 11.7)
        return BrowserState(tabs: ["localhost:3000", "Sign in · Staging"], url: "staging.example.com/login", page: .login, newTab: u < 11.2 ? 0 : p, oldPage: .localhost, oldURL: "localhost:3000")
    default:
        return BrowserState(tabs: ["Favorites"], url: "Search or enter website name", page: .start, newTab: 1, oldPage: .start, oldURL: "")
    }
}

func drawBrowser(_ w: Win, _ u: Double, focused: Bool) {
    let r = rects[w]!, st = styles[w]!, s = browserState(w, u)
    let dark = w == .brave
    shadowed(blur: focused ? 60 : 30, dy: focused ? 24 : 10, alpha: focused ? 0.55 : 0.35) { rrect(r, 14, .white) }
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: r, xRadius: 14, yRadius: 14).addClip()
    rrect(CGRect(x: r.minX, y: r.minY, width: r.width, height: 104), 0, st.toolbar)
    trafficLights(r, focused, dark: dark)
    // Tabs
    let showNew = s.newTab > 0 && s.tabs.count > 1
    let tabCount = showNew ? s.tabs.count : 1
    var tx = r.minX + 110
    for i in 0..<tabCount {
        let isNew = i == 1
        let tw: CGFloat = isNew ? 230 * CGFloat(easeOut(s.newTab)) : 230
        let active = showNew ? isNew : true
        let tr = CGRect(x: tx, y: r.minY + 8, width: tw, height: 38)
        if active { rrect(tr, 9, st.tabActive) }
        if tw > 60 {
            NSGraphicsContext.saveGraphicsState(); NSBezierPath(rect: tr).addClip()
            image(st.icon, CGRect(x: tr.minX + 12, y: tr.minY + 9, width: 20, height: 20))
            text(s.tabs[i], sys(18, active ? .medium : .regular), st.toolbarText.withAlphaComponent(active ? 1 : 0.65),
                 CGPoint(x: tr.minX + 40, y: tr.minY + 8))
            NSGraphicsContext.restoreGraphicsState()
        }
        tx += tw + 6
    }
    // Browser identity, top right
    image(st.icon, CGRect(x: r.maxX - 48, y: r.minY + 9, width: 34, height: 34))
    // URL bar
    let ub = CGRect(x: r.minX + 16, y: r.minY + 54, width: r.width - 32, height: 40)
    rrect(ub, 10, st.urlBar)
    let urlColor = dark ? hex(0xe8e8ea) : hex(0x3a3a3c)
    let urlFont = sys(20)
    if showNew {
        withAlpha(1 - s.newTab) { text(s.oldURL, urlFont, urlColor, CGPoint(x: ub.minX + 18, y: ub.minY + 9)) }
        withAlpha(s.newTab) { text(s.url, urlFont, urlColor, CGPoint(x: ub.minX + 18, y: ub.minY + 9)) }
    } else {
        text(s.oldURL.isEmpty ? s.url : s.oldURL, urlFont, urlColor.withAlphaComponent(s.oldURL.isEmpty ? 0.5 : 1), CGPoint(x: ub.minX + 18, y: ub.minY + 9))
    }
    // Page
    let pr = CGRect(x: r.minX, y: r.minY + 104, width: r.width, height: r.height - 104)
    rrect(pr, 0, .white)
    if showNew {
        withAlpha(1 - s.newTab) { drawPage(s.oldPage, pr, st.accent) }
        withAlpha(s.newTab) { drawPage(s.page, pr, st.accent) }
    } else {
        drawPage(s.oldPage, pr, st.accent)
    }
    NSGraphicsContext.restoreGraphicsState()
}

func drawChat(_ u: Double, focused: Bool) {
    let r = rects[.chat]!
    shadowed(blur: focused ? 60 : 30, dy: focused ? 24 : 10, alpha: focused ? 0.55 : 0.35) { rrect(r, 14, .white) }
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: r, xRadius: 14, yRadius: 14).addClip()
    rrect(CGRect(x: r.minX, y: r.minY, width: 170, height: r.height), 0, hex(0x3f1d4f))
    trafficLights(r, focused, dark: true)
    for (i, ch) in ["# general", "# design", "# dev", "# random"].enumerated() {
        let y = r.minY + 70 + CGFloat(i) * 40
        if i == 1 { rrect(CGRect(x: r.minX + 10, y: y - 4, width: 150, height: 34), 6, hex(0xffffff, 0.18)) }
        text(ch, sys(19, i == 1 ? .semibold : .regular), hex(0xffffff, i == 1 ? 1 : 0.6), CGPoint(x: r.minX + 22, y: y))
    }
    let mx = r.minX + 170
    rrect(CGRect(x: mx, y: r.minY, width: r.width - 170, height: 56), 0, hex(0xffffff))
    text("# design", sys(22, .bold), hex(0x1d1d1f), CGPoint(x: mx + 24, y: r.minY + 15))
    hex(0xe6e6ea).setFill(); CGRect(x: mx, y: r.minY + 56, width: r.width - 170, height: 1).fill()

    func message(_ y: CGFloat, _ name: String, _ color: NSColor, _ body: String, _ link: String, _ linkPt: CGPoint, clickT: Double) {
        color.setFill(); NSBezierPath(roundedRect: CGRect(x: mx + 22, y: y, width: 48, height: 48), xRadius: 10, yRadius: 10).fill()
        text(String(name.prefix(1)), sys(24, .bold), .white, CGPoint(x: mx + 46, y: y + 10), .center)
        text(name, sys(20, .bold), hex(0x1d1d1f), CGPoint(x: mx + 86, y: y - 2))
        text(body, sys(20), hex(0x3a3a3c), CGPoint(x: mx + 86, y: y + 26))
        let flash = u >= clickT ? 1 - clamp((u - clickT) / 0.6) : 0
        let lsz = NSAttributedString(string: link, attributes: [.font: sys(20)]).size()
        let lr = CGRect(x: mx + 86 - 4, y: linkPt.y - lsz.height/2 - 2, width: lsz.width + 8, height: lsz.height + 4)
        if flash > 0 { rrect(lr, 5, hex(0x1a7cf5, 0.25 * flash)) }
        text(link, sys(20), hex(0x1264a3), CGPoint(x: mx + 86, y: linkPt.y - lsz.height/2), underline: true)
    }
    message(r.minY + 90, "Maya", hex(0xe0457b), "Here's the plan for next quarter:", "docs.example.com/q3-plan", link1, clickT: click1)
    let a2 = easeOut((u - msg2Arrive) / 0.5)
    if a2 > 0 {
        withAlpha(a2) {
            ctx.saveGState(); ctx.translateBy(x: 0, y: 20 * CGFloat(1 - a2))
            message(r.minY + 244, "Leo", hex(0x2e9e6b), "Staging is up — can you check sign-in?", "staging.example.com/login", link2, clickT: click2)
            ctx.restoreGState()
        }
    }
    // Composer
    let cb = CGRect(x: mx + 22, y: r.maxY - 76, width: r.width - 170 - 44, height: 52)
    rrect(cb, 10, hex(0xc9c9cf)); rrect(cb.insetBy(dx: 1.5, dy: 1.5), 9, .white)
    text("Message #design", sys(19), hex(0xa1a1a6), CGPoint(x: cb.minX + 16, y: cb.minY + 14))
    NSGraphicsContext.restoreGraphicsState()
}

func menuBar(_ u: Double, front: Win) {
    rrect(CGRect(x: 0, y: 0, width: W, height: 40), 0, hex(0x000000, 0.28))
    let appName = front == .chat ? "Chat" : styles[front]!.name
    text(appName, sys(20, .bold), .white, CGPoint(x: 28, y: 8))
    var x: CGFloat = 28 + NSAttributedString(string: appName, attributes: [.font: sys(20, .bold)]).size().width + 30
    for item in ["File", "Edit", "View", "Window", "Help"] {
        x += text(item, sys(20), hex(0xffffff, 0.92), CGPoint(x: x, y: 8)).width + 26
    }
    text("Sat Sep 26   9:41 AM", sys(20, .medium), .white, CGPoint(x: CGFloat(W) - 28, y: 8), .right)
    // ActiveBrowser status item, with pulse when a link passes through it
    var pulse = 0.0
    for c in [click1, click2] {
        let p = (u - (c + 0.5)) / 0.6
        if p >= 0 && p <= 1 { pulse = max(pulse, sin(p * .pi)) }
    }
    if u >= menuClick { pulse = 1 }
    if pulse > 0 {
        rrect(CGRect(x: menuIconCenter.x - 24, y: 3, width: 48, height: 34), 7, hex(0xffffff, 0.3 * pulse))
    }
    tinted(menuIcon, CGRect(x: menuIconCenter.x - 13, y: menuIconCenter.y - 13, width: 26, height: 26), .white)
}

func dropdownMenu(_ u: Double) {
    let a = clamp((u - menuClick) / 0.18)
    guard a > 0 else { return }
    withAlpha(a) {
        let r = CGRect(x: CGFloat(W) - 560 - 18, y: 44, width: 560, height: 372)
        shadowed(blur: 40, dy: 14, alpha: 0.45) { rrect(r, 12, hex(0xf3f3f6, 0.98)) }
        var y = r.minY + 14
        func row(_ s: String, _ bold: Bool = false, check: Bool = false, trailing: String? = nil, highlight: Bool = false) {
            let rr = CGRect(x: r.minX + 8, y: y, width: r.width - 16, height: 42)
            if highlight { rrect(rr, 7, hex(0x7b5cff, 0.14)) }
            if check { text("✓", sys(21, .semibold), hex(0x1d1d1f), CGPoint(x: rr.minX + 14, y: y + 8)) }
            text(s, sys(21, bold ? .semibold : .regular), hex(0x1d1d1f), CGPoint(x: rr.minX + 42, y: y + 8))
            if let t = trailing { text(t, sys(21), hex(0x6e6e73), CGPoint(x: rr.maxX - 16, y: y + 8), .right) }
            y += 44
        }
        func sep() { hex(0x000000, 0.1).setFill(); CGRect(x: r.minX + 16, y: y + 5, width: r.width - 32, height: 1).fill(); y += 12 }
        row("Routing to: Brave Browser", true, highlight: true)
        row("Recent: Brave Browser › Arc")
        sep()
        row("Browsers", trailing: "▸")
        row("Fallback Browser", trailing: "▸")
        sep()
        row("Default Browser", check: true)
        row("Launch at Login", check: true)
        sep()
        row("Quit ActiveBrowser", trailing: "⌘Q")
    }
}

func cursor(_ p: CGPoint, pressed: Bool) {
    let path = NSBezierPath()
    let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 36), (9, 27), (15, 41), (21, 38.5), (15, 25), (26, 25)]
    path.move(to: CGPoint(x: p.x + pts[0].0, y: p.y + pts[0].1))
    for q in pts.dropFirst() { path.line(to: CGPoint(x: p.x + q.0, y: p.y + q.1)) }
    path.close()
    withTransform(scale: pressed ? 0.88 : 1, about: p) {
        shadowed(blur: 6, dy: 2, alpha: 0.4) { NSColor.black.setFill(); path.fill() }
        NSColor.white.setStroke(); path.lineWidth = 2.5; path.lineJoinStyle = .round; path.stroke()
    }
}

let cursorKeys: [(Double, CGPoint)] = [
    (0.0, CGPoint(x: 720, y: 560)), (1.4, CGPoint(x: 780, y: 520)),
    (2.2, CGPoint(x: 1560, y: 640)),               // focus chat
    (3.2, link1),                                    // click link 1
    (4.6, CGPoint(x: link1.x + 30, y: link1.y + 60)),
    (7.9, CGPoint(x: 170, y: 860)),                 // click Brave's exposed corner
    (8.9, CGPoint(x: 1560, y: 720)),                // focus chat
    (9.9, link2),                                    // click link 2
    (11.4, CGPoint(x: link2.x + 30, y: link2.y + 60)),
    (13.4, CGPoint(x: 1300, y: 300)),
    (14.1, CGPoint(x: menuIconCenter.x + 2, y: menuIconCenter.y + 2)),
]
let clicks: [Double] = [2.3, click1, 8.0, 9.0, click2, menuClick]

func cursorPos(_ u: Double) -> CGPoint {
    if u <= cursorKeys[0].0 { return cursorKeys[0].1 }
    for i in 1..<cursorKeys.count where u <= cursorKeys[i].0 {
        let (t0, p0) = cursorKeys[i - 1], (t1, p1) = cursorKeys[i]
        // travel in the last 0.8s before each keyframe, hold otherwise
        let start = max(t0, t1 - 0.8)
        return lerp(p0, p1, prog(u, start, t1))
    }
    return cursorKeys.last!.1
}

func flight(_ u: Double, from: CGPoint, to: CGPoint, start: Double, label: String) {
    let t1 = start + 0.15, mid = start + 0.65, t2 = start + 1.2
    guard u >= t1 && u <= t2 + 0.1 else { return }
    let p: CGPoint
    if u < mid {
        let k = prog(u, t1, mid)
        let ctrl = CGPoint(x: (from.x + menuIconCenter.x)/2 + 80, y: 60)
        let a = lerp(from, ctrl, k), b = lerp(ctrl, menuIconCenter, k)
        p = lerp(a, b, k)
    } else {
        let k = prog(u, mid, t2)
        let ctrl = CGPoint(x: (to.x + menuIconCenter.x)/2, y: 40)
        let a = lerp(menuIconCenter, ctrl, k), b = lerp(ctrl, to, k)
        p = lerp(a, b, k)
    }
    let alpha = min(clamp((u - t1) / 0.12), clamp((t2 + 0.1 - u) / 0.15))
    withAlpha(alpha) {
        let f = sys(20, .semibold)
        let sz = NSAttributedString(string: label, attributes: [.font: f]).size()
        let r = CGRect(x: p.x - sz.width/2 - 44, y: p.y - 22, width: sz.width + 64, height: 44)
        shadowed(blur: 18, dy: 6, alpha: 0.4) { rrect(r, 22, .white) }
        rrect(CGRect(x: r.minX + 8, y: r.minY + 8, width: 28, height: 28), 14, hex(0x7b5cff))
        text("↗", sys(18, .bold), .white, CGPoint(x: r.minX + 22, y: r.minY + 9), .center)
        text(label, f, hex(0x1264a3), CGPoint(x: r.minX + 44, y: r.minY + 11))
    }
}

let captions: [(Double, Double, String, NSImage?)] = [
    (0.3, 2.2, "You're reading docs in Arc…", arcIcon),
    (2.4, 4.4, "…then a link arrives in chat.", nil),
    (4.6, 7.6, "It opens in Arc — the browser you were just using.", arcIcon),
    (7.8, 10.9, "Now you switch to testing in Brave…", braveIcon),
    (11.2, 13.9, "…and the next link opens in Brave.", braveIcon),
    (14.4, 19.3, "No rules. No picker. Just your recent focus.", abIcon),
]

func caption(_ u: Double) {
    for (a, b, s, icon) in captions {
        let al = window(u, a, b, 0.3)
        guard al > 0 else { continue }
        withAlpha(al) {
            let f = sys(34, .semibold)
            let sz = NSAttributedString(string: s, attributes: [.font: f]).size()
            let iw: CGFloat = icon == nil ? 0 : 52
            let r = CGRect(x: CGFloat(W)/2 - (sz.width + iw)/2 - 36, y: 962 + 8 * CGFloat(1 - al), width: sz.width + iw + 72, height: 76)
            shadowed(blur: 24, dy: 8, alpha: 0.35) { rrect(r, 38, hex(0x111322, 0.86)) }
            if let icon { image(icon, CGRect(x: r.minX + 30, y: r.minY + 16, width: 44, height: 44)) }
            text(s, f, .white, CGPoint(x: r.minX + 36 + iw, y: r.minY + 17))
        }
    }
}

func desktopScene(_ u: Double) {
    let order = zOrder(u)
    for w in order {
        let focused = w == order.last
        if w == .chat { drawChat(u, focused: focused) } else { drawBrowser(w, u, focused: focused) }
    }
    menuBar(u, front: order.last!)
    flight(u, from: link1, to: CGPoint(x: rects[.arc]!.minX + 300, y: rects[.arc]!.minY + 27), start: click1, label: "docs.example.com/q3-plan")
    flight(u, from: link2, to: CGPoint(x: rects[.brave]!.minX + 300, y: rects[.brave]!.minY + 27), start: click2, label: "staging.example.com/login")
    dropdownMenu(u)
    // click ripples
    for c in clicks where u >= c && u < c + 0.45 {
        let k = easeOut((u - c) / 0.45)
        let p = cursorKeys.first { abs($0.0 - (c - 0.1)) < 0.25 || abs($0.0 - c) < 0.15 }?.1 ?? cursorPos(c)
        hex(0xffffff, 0.7 * (1 - k)).setStroke()
        let rad = 10 + 26 * CGFloat(k)
        let path = NSBezierPath(ovalIn: CGRect(x: p.x - rad, y: p.y - rad, width: rad*2, height: rad*2)); path.lineWidth = 3; path.stroke()
    }
    let pressed = clicks.contains { u >= $0 && u < $0 + 0.12 }
    cursor(cursorPos(u), pressed: pressed)
    caption(u)
}

// MARK: - Outro
func outroScene(_ t: Double) {
    let cx = CGFloat(W)/2
    withAlpha(prog(t, 0, 0.5)) {
        shadowed(blur: 30, dy: 12, alpha: 0.45) { image(abIcon, CGRect(x: cx - 90, y: 150, width: 180, height: 180)) }
        text("ActiveBrowser", sys(80, .bold), .white, CGPoint(x: cx, y: 350), .center, kern: -0.5)
        text("Set it as your default browser once. It handles the rest.", sys(36), hex(0xffffff, 0.8), CGPoint(x: cx, y: 460), .center)
    }
    withAlpha(prog(t, 0.5, 1.0)) {
        let cmd = "curl -fsSL https://raw.githubusercontent.com/hexember/active-browser/main/install.sh | sh"
        let f = mono(27, .medium)
        let sz = NSAttributedString(string: cmd, attributes: [.font: f]).size()
        let r = CGRect(x: cx - sz.width/2 - 44, y: 580, width: sz.width + 88, height: 84)
        rrect(r, 16, hex(0x0b0c18, 0.72))
        text("$", f, hex(0x9d8cff), CGPoint(x: r.minX + 22, y: r.minY + 26))
        text(cmd, f, hex(0xf2f2f7), CGPoint(x: r.minX + 52, y: r.minY + 26))
    }
    withAlpha(prog(t, 0.9, 1.4)) {
        text("macOS 13+  ·  Apple silicon  ·  Free & open source", sys(30, .medium), hex(0xffffff, 0.75), CGPoint(x: cx, y: 730), .center)
        text("github.com/hexember/active-browser", sys(32, .semibold), hex(0xc9bcff), CGPoint(x: cx, y: 790), .center)
    }
}

// MARK: - Frame composition
func drawFrame(_ t: Double) {
    wallpaper()
    withAlpha(window(t, -1, 3.7, 0.5)) { titleScene(t) }
    withAlpha(window(t, 3.3, D0 + 0.2, 0.45)) { problemScene(t - 3.3) }
    withAlpha(window(t, D0 - 0.2, D1, 0.5)) { desktopScene(t - D0) }
    withAlpha(window(t, D1 - 0.3, DURATION + 1, 0.5)) { outroScene(t - (D1 - 0.3)) }
    // fade from/to black at the very ends
    let edge = min(clamp(t / 0.3), clamp((DURATION - t) / 0.5))
    if edge < 1 { hex(0x000000, CGFloat(1 - edge)).setFill(); CGRect(x: 0, y: 0, width: W, height: H).fill() }
}

func render(into data: UnsafeMutableRawPointer, bytesPerRow: Int, t: Double, scale: Double = 1) {
    let pw = Int(Double(W) * scale), ph = Int(Double(H) * scale)
    ctx = CGContext(data: data, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(ph)); ctx.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
    ctx.interpolationQuality = .high
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    drawFrame(t)
    NSGraphicsContext.current = nil
}

// MARK: - Poster
do {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: W * 4, bitsPerPixel: 32)!
    var buf = [UInt8](repeating: 0, count: W * H * 4)
    buf.withUnsafeMutableBytes { render(into: $0.baseAddress!, bytesPerRow: W * 4, t: POSTER_T) }
    // BGRA -> RGBA
    for i in stride(from: 0, to: buf.count, by: 4) { buf.swapAt(i, i + 2) }
    memcpy(rep.bitmapData!, buf, buf.count)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: posterPath))
}
if args.count > 4 {   // extra args: preview timestamps -> PNGs next to the poster
    for s in args[4...] {
        let t = Double(s)!
        var buf = [UInt8](repeating: 0, count: W * H * 4)
        buf.withUnsafeMutableBytes { render(into: $0.baseAddress!, bytesPerRow: W * 4, t: t) }
        for i in stride(from: 0, to: buf.count, by: 4) { buf.swapAt(i, i + 2) }
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: W * 4, bitsPerPixel: 32)!
        memcpy(rep.bitmapData!, buf, buf.count)
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: posterPath.replacingOccurrences(of: ".png", with: "-\(s).png")))
    }
    if ProcessInfo.processInfo.environment["PREVIEW_ONLY"] != nil { exit(0) }
}

// MARK: - Encode
let url = URL(fileURLWithPath: outPath)
try? FileManager.default.removeItem(at: url)
let writer = try! AVAssetWriter(outputURL: url, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: OW, AVVideoHeightKey: OH,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: BITRATE, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                      AVVideoMaxKeyFrameIntervalKey: 60],
    AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: OW, kCVPixelBufferHeightKey as String: OH,
])
writer.shouldOptimizeForNetworkUse = true   // moov atom first, so browsers start playing before the full download
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
let total = Int(DURATION * Double(FPS))
for f in 0..<total {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
    CVPixelBufferLockBaseAddress(pb!, [])
    autoreleasepool {
        render(into: CVPixelBufferGetBaseAddress(pb!)!, bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), t: Double(f) / Double(FPS), scale: OUT_SCALE)
    }
    CVPixelBufferUnlockBaseAddress(pb!, [])
    adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: FPS))
    if f % 90 == 0 { print("frame \(f)/\(total)") }
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print(writer.status == .completed ? "done: \(outPath)" : "failed: \(String(describing: writer.error))")
