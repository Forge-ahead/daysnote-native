import SwiftUI

// MARK: - 主题色

enum Theme {
    static func background(_ style: BackgroundStyle) -> Color {
        switch style {
        case .grid: return Color(uiColor: UIColor(patternImage: gridImage()))
        case .beige: return Color(hex: "#f3ead9")
        case .cream: return Color(hex: "#fbfaf7")
        case .gray: return Color(hex: "#eeece7")
        }
    }
    static let ink = Color(hex: "#3d3b3a")
    static let muted = Color(hex: "#8d857c")
    static let paper = Color(hex: "#fbfaf7")
    static let line = Color(hex: "#e6e1d8")
    static let accent = Color(hex: "#c2503c")

    private static func gridImage() -> UIImage {
        let size: CGFloat = 12
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: fmt).image { ctx in
            UIColor(hex: "#fbfaf7").setFill(); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            UIColor(hex: "#ece8df").setStroke()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: size, y: 0))
            p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 0, y: size))
            p.lineWidth = 0.5; p.stroke()
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
