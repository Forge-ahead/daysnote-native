import SwiftUI

// MARK: - 主题色

enum Theme {
    static func background(_ style: BackgroundStyle) -> Color {
        backgroundColor(style, dark: false)
    }

    /// 设置页缩略图用：仍是 pattern color，但按 V31 的 22pt 网格与更明显的线重新绘制
    static func backgroundColor(_ style: BackgroundStyle, dark: Bool) -> Color {
        switch style {
        case .grid:
            if dark { return Color(hex: "#202024") }
            return Color(uiColor: UIColor(patternImage: gridImage()))
        case .beige: return Color(hex: dark ? "#2a2620" : "#f3ead9")
        case .cream: return Color(hex: dark ? "#202024" : "#fbfaf7")
        case .gray: return Color(hex: dark ? "#26262a" : "#eeece7")
        }
    }
    /// 随系统/App 外观动态解析：夜间模式用浅色字，避免深色字压在深色背景上看不清。
    private static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    static let ink = adaptive(light: "#3d3b3a", dark: "#f3f0ea")
    static let muted = adaptive(light: "#8d857c", dark: "#bdb5a9")
    static let subtle = adaptive(light: "#a39f99", dark: "#a79f94")
    static let paper = adaptive(light: "#fbfaf7", dark: "#212125")
    static let line = adaptive(light: "#e6e1d8", dark: "#4a463f")
    static let accent = adaptive(light: "#c2503c", dark: "#ef856c")
    /// 时间轴里作为前景文字的绿色：夜间模式提亮。
    static let greenText = adaptive(light: "#5b8f84", dark: "#8ed2bf")
    /// 固定浅色卡片上的前景文字：卡片颜色是写死的浅色，不随夜间模式变深。
    /// 若这里用自适应浅色字，夜间会出现「浅字压浅底」导致首页日期/倒数日看不清。
    static let inkOnLightCard = Color(hex: "#3d3b3a")
    static let mutedOnLightCard = Color(hex: "#6f675e")

    private static func gridImage() -> UIImage {
        // 与 Web V31 一致：22pt 方格，线色 rgba(214,211,202,.42)
        let size: CGFloat = 22
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: fmt).image { ctx in
            UIColor(hex: "#fbfaf7").setFill(); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            UIColor(hex: "#d6d3ca").withAlphaComponent(0.42).setStroke()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 0.5, y: 0)); p.addLine(to: CGPoint(x: 0.5, y: size))
            p.move(to: CGPoint(x: 0, y: 0.5)); p.addLine(to: CGPoint(x: size, y: 0.5))
            p.lineWidth = 1; p.stroke()
        }
    }
}

/// 主界面背景：格纹必须用真实 Path 绘制，SwiftUI 的 Color(patternImage:) 有些场景会被当成纯色
struct GridBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let style: BackgroundStyle

    var body: some View {
        ZStack {
            Theme.backgroundColor(style, dark: colorScheme == .dark)
            if style == .grid {
                GeometryReader { geo in
                    Path { p in
                        let step: CGFloat = 22
                        var x: CGFloat = 0
                        while x <= geo.size.width {
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: geo.size.height))
                            x += step
                        }
                        var y: CGFloat = 0
                        while y <= geo.size.height {
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                            y += step
                        }
                    }
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.055) : Color(hex: "#d6d3ca").opacity(0.42),
                            lineWidth: 1)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
extension UIColor {
    convenience init(hex: String) {
        let s = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0; Scanner(string: s).scanHexInt64(&rgb)
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - 通用控件

struct SectionTitle: View {
    let text: String
    var body: some View {
        HStack { Text(text).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.muted); Spacer() }
        .padding(.horizontal, 4).padding(.top, 14).padding(.bottom, 6)
    }
}

struct CardPanel<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(10).background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct PrimaryButton: View {
    let title: String
    var danger = false
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .disabled(disabled)
        .foregroundColor(danger ? Theme.accent : Theme.ink)
        .background(Color(uiColor: .tertiarySystemBackground))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(danger ? Color(hex: "#f0d5cd") : Theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(disabled ? 0.5 : 1)
    }
}

struct RowSwitch: View {
    let title: String
    let subtitle: String?
    @Binding var on: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .medium))
                if let s = subtitle { Text(s).font(.system(size: 11)).foregroundColor(Theme.muted) }
            }
            Spacer()
            Toggle("", isOn: $on).labelsHidden().tint(Color(hex: "#6f8a6a"))
        }
    }
}

struct NavBar<Trailing: View>: View {
    let title: String
    let back: (() -> Void)?
    @ViewBuilder let trailing: Trailing
    var body: some View {
        HStack(spacing: 10) {
            if let back = back {
                Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 18, weight: .medium)) }
                    .frame(width: 34, height: 34)
            }
            Spacer()
            Text(title).font(.system(size: 16, weight: .semibold))
            Spacer()
            trailing.frame(width: 40)
        }
        .frame(height: 44).foregroundColor(Theme.ink)
    }
}

// MARK: - Toast

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if let m = message {
                    VStack {
                        Spacer()
                        Text(m).font(.system(size: 13)).foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color.black.opacity(0.78)).clipShape(Capsule())
                            .padding(.bottom, 90)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.easeOut, value: m)
                }
            }, alignment: .center
        )
    }
}
