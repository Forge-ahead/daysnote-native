import WidgetKit
import SwiftUI

// Widget target 独立编译，需自带颜色扩展
private extension Color {
    init(hexW: String) {
        let s = hexW.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
    init(rgbaW: String) {
        if rgbaW.hasPrefix("rgba"), let a = rgbaW.range(of: "(")?.upperBound, let b = rgbaW.range(of: ")")?.lowerBound {
            let body = rgbaW[a..<b]
            let parts = body.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count >= 4 {
                self.init(.sRGB, red: parts[0] / 255, green: parts[1] / 255, blue: parts[2] / 255, opacity: parts[3]); return
            }
        }
        self = Color(hexW: rgbaW)
    }
}

// Widget 自带的数据模型（与主 App 的 Models.swift 结构一致）
struct WidgetEvent: Codable, Equatable, Identifiable {
    var id: String { "\(title)|\(date)|\(icon)" }
    var title: String
    var icon: String
    var date: String
    var days: Int
    var dir: String
    var color: String
}
struct WidgetPayload: Codable {
    var events: [WidgetEvent]
    var holiday: HolidayCountdown?
    var updatedAt: TimeInterval
}
struct HolidayCountdown: Codable, Equatable {
    var name: String
    var icon: String
    var daysLeft: Int
    var inProgress: Bool
    var rangeText: String
    var holidayDays: Int
    var source: String
}

// MARK: - 公共工具
private func daysText(_ e: WidgetEvent) -> String { daysText(e.days) }
private func daysText(_ n: Int) -> String { n > 365 ? String(format: "%.2f年", Double(n) / 365) : "\(n)" }
/// 数字与单位拆分：useYear=true 时大于一年换算成「年」，否则一律按「天」显示原始天数。
/// 蓝色块（近）显示天数配「天」；橘红色块（远，超过一年）显示年数配「年」。
/// 2×2 纯数字款传 useYear=false，始终用天数计数，不出现「年」。
private func dayParts(_ n: Int, useYear: Bool = true) -> (num: String, unit: String) {
    if useYear && n > 365 { return (String(format: "%.2f", Double(n) / 365), "年") }
    return ("\(n)", "天")
}
private func shortDate(_ iso: String) -> String {
    let p = iso.split(separator: "-")
    return p.count >= 2 ? "\(p[p.count - 2])/\(p[p.count - 1])" : iso
}
private func weekIndex(_ iso: String) -> Int {
    let p = iso.split(separator: "-").compactMap { Int($0) }
    guard p.count >= 3, let d = Calendar(identifier: .gregorian).date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { return 0 }
    return Calendar(identifier: .gregorian).component(.weekday, from: d) - 1
}
private func weekName(_ i: Int) -> String { ["日", "一", "二", "三", "四", "五", "六"][max(0, min(6, i))] }
private let weekChars = ["日", "一", "二", "三", "四", "五", "六"]
private func todayTitle() -> String {
    let d = Date(); let c = Calendar(identifier: .gregorian)
    return "\(c.component(.month, from: d))月\(c.component(.day, from: d))日 星期\(weekName(c.component(.weekday, from: d) - 1))"
}
private func todayWeek() -> Int { Calendar(identifier: .gregorian).component(.weekday, from: Date()) - 1 }

// 空数据兜底：即使 App Group 数据未同步，桌面组件也一定有图形可显示
private func demoEvents() -> [WidgetEvent] {
    [
        WidgetEvent(title: "生日", icon: "🎂", date: "2026-12-01", days: 6, dir: "future", color: ""),
        WidgetEvent(title: "考试", icon: "📚", date: "2026-06-07", days: 194, dir: "future", color: ""),
        WidgetEvent(title: "元旦", icon: "⏰", date: "2026-01-01", days: 37, dir: "future", color: ""),
        WidgetEvent(title: "在一起", icon: "❤️", date: "2020-06-01", days: 2015, dir: "past", color: ""),
        WidgetEvent(title: "出生", icon: "👶", date: "2006-01-01", days: 7939, dir: "past", color: ""),
    ]
}
// WidgetKit 快照渲染不支持 Lazy 容器；统一在此取渲染用事件
private func effectiveEvents(_ p: WidgetPayload, limit: Int) -> [WidgetEvent] {
    let src = p.events.isEmpty ? demoEvents() : p.events
    return Array(src.prefix(limit))
}

// 节日组件右侧兜底示例（无绑定时按原图显示节日清单）
private func holidayDemos() -> [WidgetEvent] {
    [
        WidgetEvent(title: "情人节", icon: "", date: "2026-02-14", days: 6, dir: "future", color: ""),
        WidgetEvent(title: "除夕", icon: "", date: "2026-02-16", days: 8, dir: "future", color: ""),
        WidgetEvent(title: "春节", icon: "", date: "2026-02-17", days: 9, dir: "future", color: ""),
        WidgetEvent(title: "元宵节", icon: "", date: "2026-03-03", days: 23, dir: "future", color: ""),
    ]
}

/// 数字色块：大号数字 + 右下角小号单位（近=天 / 远=年）
private struct DayBadge: View {
    let days: Int
    let showUnit: Bool
    var useYear: Bool = true
    let base: Color
    let numSize: CGFloat
    let unitSize: CGFloat
    let height: CGFloat
    let radius: CGFloat
    var body: some View {
        let p = dayParts(days, useYear: useYear)
        return HStack(alignment: .bottom, spacing: 1) {
            Text(p.num).font(.system(size: numSize, weight: .bold)).foregroundColor(.white).lineLimit(1)
            if showUnit {
                Text(p.unit).font(.system(size: unitSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
                    .padding(.bottom, numSize * 0.12)
            }
        }
        .frame(height: height)
        .padding(.horizontal, numSize * 0.45)
        .background(base)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - 时间线
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), payload: load()) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: Date(), payload: load())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        var entries: [Entry] = []
        for i in 0..<12 {
            if let d = Calendar.current.date(byAdding: .minute, value: i, to: now) {
                entries.append(Entry(date: d, payload: load()))
            }
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(600))))
    }
    private func load() -> WidgetPayload {
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.daysnote.app")?
            .appendingPathComponent("daysnote-widget.json")
        guard let u = url, let data = try? Data(contentsOf: u),
              let p = try? JSONDecoder().decode(WidgetPayload.self, from: data) else {
            return WidgetPayload(events: [], holiday: nil, updatedAt: 0)
        }
        return p
    }
}
struct Entry: TimelineEntry { let date: Date; let payload: WidgetPayload }

struct WidgetRoot<Content: View>: View {
    @Environment(\.widgetFamily) var family
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if #available(iOS 17.0, *) { content.containerBackground(.clear, for: .widget) }
        else { content }
    }
}

// MARK: - Widget Bundle（按原始样板 7 款）
@main
struct DaysNoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        PictureTealLargeWidget()
        ListBlueheadLargeWidget()
        GridRoseWidget()
        SimpleNumberSmallWidget()
        SimpleDayMediumWidget()
        HolidayOfficialWidget()
        HolidayFreshWidget()
    }
}

// ============================================================
// 图1上：图文倒计时列表 · 大号（4×4）青绿底 + 顶部日期 + 5 行半透明条
// ============================================================
struct PictureTealLargeWidget: Widget {
    let kind = "picture-teal"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot { PictureTealLargeView(entry: e) }
        }
        .configurationDisplayName("图文倒计时列表 · 大号")
        .description("青绿底 · 顶部日期 · 5 行半透明卡片")
        .supportedFamilies([.systemLarge])
    }
}
private struct PictureTealLargeView: View {
    let entry: Entry
    var body: some View {
        GeometryReader { g in
            let evs = effectiveEvents(entry.payload, limit: 5)
            let pad: CGFloat = g.size.height * 0.075
            let headerH: CGFloat = g.size.height * 0.115
            let spacing: CGFloat = g.size.height * 0.018
            let n = max(1, evs.count)
            let rowH = (g.size.height - pad * 2 - headerH - spacing * CGFloat(n - 1)) / CGFloat(n)
            VStack(spacing: spacing) {
                Text(todayTitle()).font(.system(size: g.size.height * 0.072, weight: .medium)).foregroundColor(.white)
                    .frame(height: headerH)
                ForEach(Array(evs.enumerated()), id: \.element.id) { i, ev in
                    HStack(spacing: 6) {
                        Text(ev.title).font(.system(size: rowH * 0.34)).foregroundColor(Color(hexW: "#3a3835")).lineLimit(1)
                        if !ev.icon.isEmpty { Text(ev.icon).font(.system(size: rowH * 0.30)) }
                        Spacer(minLength: 2)
                        let p = dayParts(ev.days)
                        Text(p.num).font(.system(size: rowH * 0.44, weight: .bold)).foregroundColor(.white)
                        Text(p.unit).font(.system(size: rowH * 0.22)).foregroundColor(.white.opacity(0.95))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: rowH)
                    .background(Color.white.opacity(0.26)).clipShape(RoundedRectangle(cornerRadius: rowH * 0.2))
                }
            }
            .padding(pad)
            .frame(width: g.size.width, height: g.size.height)
            .background(LinearGradient(gradient: Gradient(colors: [Color(hexW: "#5c9e96"), Color(hexW: "#6aaba2")]), startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

// ============================================================
// 图1下：简约倒计时列表 · 大号（4×4）白底 + 蓝色日期头 + 5 行色块数字
// ============================================================
struct ListBlueheadLargeWidget: Widget {
    let kind = "list-bluehead"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot { ListBlueheadLargeView(entry: e) }
        }
        .configurationDisplayName("简约倒计时列表 · 大号")
        .description("白底蓝头 · 5 行色块数字")
        .supportedFamilies([.systemLarge])
    }
}
private struct ListBlueheadLargeView: View {
    let entry: Entry
    var body: some View {
        GeometryReader { g in
            let evs = effectiveEvents(entry.payload, limit: 5)
            let pad: CGFloat = g.size.height * 0.06
            let headerH: CGFloat = g.size.height * 0.135
            let spacing: CGFloat = g.size.height * 0.02
            let n = max(1, evs.count)
            let rowH = (g.size.height - pad * 2 - headerH - g.size.height * 0.02 - spacing * CGFloat(n - 1)) / CGFloat(n)
            VStack(spacing: spacing) {
                Text(todayTitle()).font(.system(size: g.size.height * 0.062, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: headerH)
                    .background(Color(hexW: "#3b82d6")).clipShape(RoundedRectangle(cornerRadius: 8))
                ForEach(Array(evs.enumerated()), id: \.element.id) { i, ev in
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Text(ev.title).font(.system(size: rowH * 0.32, weight: .semibold)).foregroundColor(Color(hexW: "#4a4844")).lineLimit(1)
                            if !ev.icon.isEmpty { Text(ev.icon).font(.system(size: rowH * 0.28)) }
                        }
                        Spacer(minLength: 2)
                        DayBadge(days: ev.days, showUnit: true,
                                 base: i < 3 ? Color(hexW: "#4a90d9") : Color(hexW: "#f0a04b"),
                                 numSize: rowH * 0.36, unitSize: rowH * 0.18,
                                 height: rowH * 0.62, radius: 6)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: rowH)
                    .background(Color(hexW: "#f5f6f8")).clipShape(RoundedRectangle(cornerRadius: rowH * 0.2))
                }
            }
            .padding(pad)
            .frame(width: g.size.width, height: g.size.height)
            .background(Color.white)
        }
    }
}

// ============================================================
// 图2：倒计时面板（4×4）粉色底 + 2×2 四大卡（emoji+标题+日期+大数字）
// ============================================================
struct GridRoseWidget: Widget {
    let kind = "grid-rose"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot { GridRoseView(entry: e) }
        }
        .configurationDisplayName("倒计时面板")
        .description("粉底 · 2×2 四大卡 · 4×2 中号")
        .supportedFamilies([.systemMedium])
    }
}
private struct GridRoseView: View {
    let entry: Entry
    private func card(_ ev: WidgetEvent) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 2) {
                if !ev.icon.isEmpty { Text(ev.icon).font(.system(size: 11)) }
                Text(ev.title).font(.system(size: 10, weight: .semibold)).foregroundColor(.white).lineLimit(1)
            }
            Text("\(shortDate(ev.date)) \(weekName(weekIndex(ev.date)))").font(.system(size: 8)).foregroundColor(.white.opacity(0.9))
            Spacer(minLength: 1)
            HStack { Spacer(); Text(daysText(ev)).font(.system(size: 20, weight: .bold)).foregroundColor(.white) }
        }
        .padding(7).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(LinearGradient(gradient: Gradient(colors: [Color(hexW: "#f0a8b8"), Color(hexW: "#e896ab")]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
    var body: some View {
        // 注意：Widget 快照渲染不支持 Lazy 容器，必须用普通 HStack/VStack
        // 事件不足 4 条时用示例事件补位，绝不能越界（越界会导致扩展崩溃 → 黑块）
        let evs = effectiveEvents(entry.payload, limit: 4)
        let demo = demoEvents()
        let padded = (0..<4).map { i in i < evs.count ? evs[i] : demo[i % demo.count] }
        return VStack(spacing: 6) {
            HStack(spacing: 6) { card(padded[0]); card(padded[1]) }
            HStack(spacing: 6) { card(padded[2]); card(padded[3]) }
        }
        .padding(9).background(Color(hexW: "#fbedef"))
    }
}

// ============================================================
// 图3左：简约倒计时列表 · 纯数字（2×2）3 行色块数字，无「天」
// ============================================================
struct SimpleNumberSmallWidget: Widget {
    let kind = "simple-number"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot { SimpleListView(entry: e, withTian: false, medium: false) }
        }
        .configurationDisplayName("简约倒计时列表 · 纯数字")
        .description("2×2 · 3 行色块数字")
        .supportedFamilies([.systemSmall])
    }
}

// ============================================================
// 图3右：简约倒计时列表 · 带天（4×2）3 行色块数字 + 「天」
// ============================================================
struct SimpleDayMediumWidget: Widget {
    let kind = "simple-day"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot { SimpleListView(entry: e, withTian: true, medium: true) }
        }
        .configurationDisplayName("简约倒计时列表 · 带天")
        .description("4×2 · 3 行数字+天")
        .supportedFamilies([.systemMedium])
    }
}
private struct SimpleListView: View {
    let entry: Entry
    let withTian: Bool
    let medium: Bool
    var body: some View {
        GeometryReader { g in
            let evs = effectiveEvents(entry.payload, limit: 3)
            let pad: CGFloat = medium ? g.size.height * 0.055 : g.size.height * 0.05
            let spacing: CGFloat = medium ? g.size.height * 0.045 : g.size.height * 0.04
            let n = max(1, evs.count)
            let rowH = (g.size.height - pad * 2 - spacing * CGFloat(n - 1)) / CGFloat(n)
            let blockH = rowH * (medium ? 0.62 : 0.66)
            VStack(spacing: spacing) {
                ForEach(Array(evs.enumerated()), id: \.element.id) { i, ev in
                    let base = i < 2 ? Color(hexW: "#4a90d9") : Color(hexW: "#f0a04b")
                    HStack(spacing: 4) {
                        HStack(spacing: 3) {
                            // 2×2 纯数字款：缩小标题字号，不显示图标，给数字留足空间
                            Text(ev.title).font(.system(size: rowH * (medium ? 0.34 : 0.26), weight: .semibold)).foregroundColor(Color(hexW: "#4a4844")).lineLimit(1)
                            if medium && !ev.icon.isEmpty { Text(ev.icon).font(.system(size: rowH * 0.30)) }
                        }
                        Spacer(minLength: 2)
                        // 2×2 纯数字款不换算成年：始终按「天」显示原始天数
                        DayBadge(days: ev.days, showUnit: withTian, useYear: medium, base: base,
                                 numSize: rowH * (medium ? 0.42 : 0.36), unitSize: rowH * 0.20,
                                 height: blockH, radius: medium ? 7 : 6)
                    }
                    .padding(.horizontal, medium ? 10 : 8)
                    .frame(height: rowH)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius: medium ? 9 : 8))
                }
            }
            .padding(pad)
            .frame(width: g.size.width, height: g.size.height)
            .background(Color(hexW: "#f2f2f0"))
        }
    }
}

// ============================================================
// 图4/5：节日（4×2）左侧距离+大数字+休区间+星期条 + 右侧 4 行节日
// ============================================================
struct HolidayOfficialWidget: Widget {
    let kind = "holiday-official"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot { HolidayView(entry: e, fresh: false) }
        }
        .configurationDisplayName("节日 · 经典白")
        .description("4×2 · 距离节假日 + 放假区间")
        .supportedFamilies([.systemMedium])
    }
}
struct HolidayFreshWidget: Widget {
    let kind = "holiday-fresh"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot { HolidayView(entry: e, fresh: true) }
        }
        .configurationDisplayName("节日 · 清新绿")
        .description("4×2 · 距离节假日（绿）")
        .supportedFamilies([.systemMedium])
    }
}
private struct HolidayView: View {
    let entry: Entry
    let fresh: Bool
    private let week = ["日", "一", "二", "三", "四", "五", "六"]
    private var brand: Color { fresh ? Color(hexW: "#5c8a4a") : Color(hexW: "#4a4844") }
    private var ink: Color { fresh ? Color(hexW: "#4a6141") : Color(hexW: "#3a3835") }
    private var inkSoft: Color { fresh ? Color(hexW: "#93a488") : Color(hexW: "#a6a29a") }
    private var bg: Color { fresh ? Color(hexW: "#eef0e6") : Color(hexW: "#fbfaf7") }
    private var bgAccent: Color { fresh ? Color(hexW: "#e3e8d8") : Color(hexW: "#f2f0ea") }
    private var chipOn: Color { fresh ? Color(hexW: "#6f9a5d") : Color(hexW: "#4a4844") }

    var body: some View {
        GeometryReader { g in
            // 字号按容器高度等比，填满组件空隙（与 App 内预览同一套比例）
            let H = g.size.height
            let titleF = H * 0.085
            let bigF = H * 0.28
            let chipF = H * 0.065
            let weekF = H * 0.065
            let rowF = H * 0.078
            let pad = H * 0.06
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: H * 0.022) {
                    if let h = entry.payload.holiday {
                        Text(h.inProgress ? "\(h.name) · 假期中" : "距离\(h.name)")
                            .font(.system(size: titleF, weight: .bold)).foregroundColor(brand).lineLimit(1)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            // 假期中显示整个假期天数，不再只显示剩余 1 天
                            Text(h.inProgress ? "\(h.holidayDays)" : "\(h.daysLeft)").font(.system(size: bigF, weight: .bold)).foregroundColor(brand)
                            Text("天").font(.system(size: titleF * 0.8)).foregroundColor(brand)
                        }
                        if !h.rangeText.isEmpty {
                            HStack(spacing: H * 0.02) {
                                Text("休").font(.system(size: chipF, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, H * 0.02).padding(.vertical, H * 0.008).background(chipOn).clipShape(Capsule())
                                // 显示完整放假区间（如 01/01 - 01/03）
                                Text(h.rangeText).font(.system(size: chipF * 1.1)).foregroundColor(ink).lineLimit(1)
                            }
                        }
                    } else {
                        Text("距离下一个假期").font(.system(size: titleF, weight: .bold)).foregroundColor(brand)
                        Text("—").font(.system(size: bigF * 0.92, weight: .bold)).foregroundColor(brand)
                        Text("每月更新").font(.system(size: chipF)).foregroundColor(inkSoft)
                    }
                    Spacer(minLength: 1)
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            Text(week[i]).font(.system(size: weekF, weight: i == todayWeek() ? .bold : .regular))
                                .frame(maxWidth: .infinity).padding(.vertical, H * 0.018)
                                .background(i == todayWeek() ? chipOn : Color.clear)
                                .foregroundColor(i == todayWeek() ? Color.white : inkSoft)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(pad).frame(width: g.size.width * 0.42, alignment: .leading)
                .background(LinearGradient(gradient: Gradient(colors: [bgAccent, bg]), startPoint: .topLeading, endPoint: .bottomTrailing))

                VStack(spacing: 0) {
                    // 优先用户绑定事件；为空时显示节日示例清单（与原图一致）
                    let evs = entry.payload.events.isEmpty ? holidayDemos() : Array(entry.payload.events.prefix(4))
                    let rows = max(1, min(4, evs.count))
                    ForEach(0..<rows, id: \.self) { i in
                        let ev = evs[i]
                        HStack(spacing: H * 0.025) {
                            Text(ev.title + "  " + shortDate(ev.date)).font(.system(size: rowF)).foregroundColor(ink).lineLimit(1)
                            if ev.title == "春节" || ev.title == "除夕" {
                                Text("休").font(.system(size: chipF * 0.85, weight: .bold)).foregroundColor(Color(hexW: "#5c8a4a"))
                                    .padding(.horizontal, H * 0.015).background(Color(hexW: "#e3ecdf")).clipShape(Capsule())
                            }
                            Spacer(minLength: 2)
                            Text("\(ev.days)天").font(.system(size: rowF, weight: .bold)).foregroundColor(ink)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: (H - pad * 2) / CGFloat(rows))
                        .overlay(Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1), alignment: .bottom)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, pad).frame(width: g.size.width * 0.58)
                .background(Color.white)
            }
        }
    }
}
