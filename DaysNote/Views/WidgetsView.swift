import SwiftUI

// MARK: - V31 小组件数据

private func wc(_ s: String) -> Color {
    if s.hasPrefix("#") { return Color(hex: s) }
    if s.hasPrefix("rgba") {
        let body = s.replacingOccurrences(of: "rgba(", with: "").replacingOccurrences(of: ")", with: "")
        let parts = body.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count >= 4 {
            return Color(.sRGB, red: parts[0] / 255, green: parts[1] / 255, blue: parts[2] / 255, opacity: parts[3])
        }
    }
    return Color.clear
}

private struct BoundEvent {
    let title: String
    let date: String
    let days: Int
    let icon: String
    let weekday: Int
    let holiday: Bool
}

private struct WidgetSkin: Equatable {
    var bg: String
    var bgAccent: String
    var ink: String
    var inkSoft: String
    var brand: String
    var rowBg: String
    var hot: String
    var far: String
    var chipOn: String
    var chipOnInk: String

    /// 应用用户自定义主题：背景覆盖底色，字体色覆盖所有文字与品牌色。
    func overridden(by theme: WidgetTheme?) -> WidgetSkin {
        var s = self
        if let bg = theme?.bg, !bg.isEmpty {
            s.bg = bg; s.bgAccent = bg
        }
        if let ink = theme?.ink, !ink.isEmpty {
            s.ink = ink; s.inkSoft = ink; s.brand = ink; s.chipOn = ink
        }
        return s
    }
}

private struct WidgetTemplate: Identifiable, Equatable {
    var id: String
    var name: String
    var category: String      // 小 / 中 / 大
    var kind: String          // holiday / combo / simple / grid / picture / listLarge
    var size: String          // small / medium / large
    var slots: Int
    var desc: String
    var holiday: Bool = false
    var skin: WidgetSkin

    static let all: [WidgetTemplate] = [
        // ===== 小 2×2 =====
        // 图3左：简约倒计时列表 · 纯数字（右侧色块数字，无「天」）
        .init(id: "simple-number", name: "简约倒计时列表 · 纯数字", category: "小", kind: "simpleNumber", size: "small", slots: 3,
              desc: "图3左同款：2×2 紧凑三行，右侧蓝/橙色块数字（无「天」）",
              skin: .init(bg: "#f2f2f0", bgAccent: "#ffffff", ink: "#4a4844", inkSoft: "#a6a29a",
                          brand: "#4a4844", rowBg: "#ffffff", hot: "#4a90d9", far: "#f0a04b",
                          chipOn: "#4a4844", chipOnInk: "#ffffff")),
        // ===== 中 4×2 =====
        // 图4：节日 · 经典白
        .init(id: "holiday-official", name: "节日 · 经典白", category: "中", kind: "holiday", size: "medium", slots: 4,
              desc: "图4同款：左侧距离法定节假日 + 大数字 + 「休」放假区间 + 星期条；右侧 4 行节日清单",
              holiday: true,
              skin: .init(bg: "#fbfaf7", bgAccent: "#f2f0ea", ink: "#3a3835", inkSoft: "#a6a29a",
                          brand: "#4a4844", rowBg: "#ffffff", hot: "#5b9bd5", far: "#e79a45",
                          chipOn: "#4a4844", chipOnInk: "#ffffff")),
        // 图5：节日 · 清新绿
        .init(id: "holiday-fresh", name: "节日 · 清新绿", category: "中", kind: "holiday", size: "medium", slots: 4,
              desc: "图5同款：经典白的清新绿皮肤，左侧距离节假日 + 右侧 4 行节日清单",
              holiday: true,
              skin: .init(bg: "#eef0e6", bgAccent: "#e3e8d8", ink: "#4a6141", inkSoft: "#93a488",
                          brand: "#5c8a4a", rowBg: "#ffffff", hot: "#5b9bd5", far: "#e79a45",
                          chipOn: "#6f9a5d", chipOnInk: "#ffffff")),
        // 图3右：简约倒计时列表 · 带天（4×2，数字与天分格）
        .init(id: "simple-day", name: "简约倒计时列表 · 带天", category: "中", kind: "simple", size: "medium", slots: 3,
              desc: "图3右同款：4×2 三行，数字与「天」分色块显示",
              skin: .init(bg: "#f2f2f0", bgAccent: "#ffffff", ink: "#4a4844", inkSoft: "#a6a29a",
                          brand: "#4a4844", rowBg: "#ffffff", hot: "#4a90d9", far: "#f0a04b",
                          chipOn: "#4a4844", chipOnInk: "#ffffff")),
        // ===== 大 4×4 =====
        // 图2：倒计时面板（粉底 2×2 四大卡，实际是 4×2 中号）
        .init(id: "grid-rose", name: "倒计时面板", category: "中", kind: "grid", size: "medium", slots: 4,
              desc: "图2同款：4×2 中号粉底，2×2 四大卡，emoji + 标题 + 日期 + 大数字",
              skin: .init(bg: "#fbedef", bgAccent: "#f7dfe3", ink: "#a05a68", inkSoft: "#c2949e",
                          brand: "#b46876", rowBg: "#f8d7de", hot: "#d98a99", far: "#c9818e",
                          chipOn: "#b46876", chipOnInk: "#ffffff")),
        // 图1上：图文倒计时列表 · 大号
        .init(id: "picture-teal", name: "图文倒计时列表 · 大号", category: "大", kind: "picture", size: "large", slots: 5,
              desc: "图1上同款：4×4 青绿背景 + 顶部日期 + 5 行半透明卡片",
              skin: .init(bg: "#5c9e96", bgAccent: "#6aaba2", ink: "#ffffff", inkSoft: "#cfe6e1",
                          brand: "#ffffff", rowBg: "rgba(255,255,255,.20)", hot: "#4a90d9", far: "#f0a04b",
                          chipOn: "#ffffff", chipOnInk: "#5c9e96")),
        // 图1下：简约倒计时列表 · 大号
        .init(id: "list-bluehead", name: "简约倒计时列表 · 大号", category: "大", kind: "listLarge", size: "large", slots: 5,
              desc: "图1下同款：4×4 白底蓝头 + 5 行色块数字",
              skin: .init(bg: "#ffffff", bgAccent: "#3b82d6", ink: "#4a4844", inkSoft: "#a6a29a",
                          brand: "#4a4844", rowBg: "#f5f6f8", hot: "#4a90d9", far: "#f0a04b",
                          chipOn: "#3b82d6", chipOnInk: "#ffffff")),
    ]
}

private func sizeLabel(_ s: String) -> String { s == "small" ? "小" : (s == "medium" ? "中" : "大") }
private func gridLabel(_ s: String) -> String { s == "small" ? "2×2" : (s == "medium" ? "4×2" : "4×4") }
private func ptLabel(_ s: String) -> String { s == "small" ? "158×158" : (s == "medium" ? "338×158" : "338×338") }
/// 真实桌面 pt 基准：2×2=158²、4×2=338×158、4×4=338²
private func widgetBaseSize(_ s: String) -> CGSize {
    switch s {
    case "small":  return CGSize(width: 158, height: 158)
    case "medium": return CGSize(width: 338, height: 158)
    default:       return CGSize(width: 338, height: 338)
    }
}
/// 预览弹层：按真实 pt 等比缩放，宽度不超过可用宽度，绝不变形。
private func previewPointSize(_ s: String) -> CGSize {
    let base = widgetBaseSize(s)
    let maxW = UIScreen.main.bounds.width - 32 // 弹层左右各 16pt
    let w = min(maxW, base.width)
    return CGSize(width: w, height: base.height * w / base.width)
}
/// 软件内列表：中号单列铺满整行（与桌面 4×2 同比例），小/大号两列按单元格宽度等比。
private func listPreviewSize(_ s: String) -> CGSize {
    let screen = UIScreen.main.bounds.width
    let base = widgetBaseSize(s)
    let w = s == "medium" ? screen - 28 : (screen - 28 - 14) / 2
    return CGSize(width: w, height: base.height * w / base.width)
}
private func weekdayIndex(_ d: Date) -> Int {
    Calendar(identifier: .gregorian).component(.weekday, from: d) - 1
}
private func shortDate(_ iso: String) -> String {
    let p = iso.split(separator: "-")
    guard p.count >= 2 else { return iso }
    return "\(p[p.count - 2])/\(p[p.count - 1])"
}
private func daysText(_ n: Int) -> String { n > 365 ? String(format: "%.2f年", Double(n) / 365.0) : "\(n)" }
/// 与桌面小组件一致：大号数字 + 小号单位（近=天 / 远=年）。
/// useYear=false 时始终按「天」显示原始天数，供 2×2 纯数字款使用。
private func dayParts(_ n: Int, useYear: Bool = true) -> (num: String, unit: String) {
    if useYear && n > 365 { return (String(format: "%.2f", Double(n) / 365.0), "年") }
    return ("\(n)", "天")
}

@MainActor private func pickWidgetEvents(_ t: WidgetTemplate, store: Store) -> [EventItem] {
    let b = store.bindings[t.id] ?? .empty
    var picked: [EventItem]
    if b.mode == "events" && !b.eventIds.isEmpty {
        picked = store.events.filter { b.eventIds.contains($0.id) }
    } else if !b.categoryIds.isEmpty {
        let set = Set(b.categoryIds)
        picked = store.events.filter { set.contains($0.categoryId) }
    } else {
        picked = store.events
    }
    let now = DateUtils.startOfToday()
    return picked.sorted { a, c in
        let ai = DateUtils.dayInfo(a, now: now)
        let ci = DateUtils.dayInfo(c, now: now)
        if ai.dir == ci.dir { return ai.days < ci.days }
        return ai.dir == "future"
    }
}

private func demoBoundEvents(_ count: Int) -> [BoundEvent] {
    let demos = [
        (title: "元旦", date: "2026-01-01", days: 37, icon: "🎍"),
        (title: "生日", date: "2026-05-20", days: 296, icon: "🎂"),
        (title: "考试", date: "2026-06-07", days: 119, icon: "📚"),
        (title: "圣诞节", date: "2026-12-25", days: 344, icon: "🎄"),
        (title: "在一起", date: "2024-03-14", days: 2015, icon: "❤️"),
    ]
    return Array(demos.prefix(count)).map { d in
        BoundEvent(title: d.title, date: d.date, days: d.days, icon: d.icon,
                   weekday: weekdayIndex(DateUtils.fromISO(d.date)), holiday: false)
    }
}

@MainActor private func boundWidgetEvents(_ t: WidgetTemplate, store: Store) -> [BoundEvent] {
    let picked = pickWidgetEvents(t, store: store)
    if picked.isEmpty { return demoBoundEvents(t.slots) }
    let now = DateUtils.startOfToday()
    return Array(picked.prefix(t.slots)).map { ev in
        let info = DateUtils.dayInfo(ev, now: now)
        return BoundEvent(title: ev.title, date: DateUtils.toISO(info.target), days: info.days,
                          icon: ev.icon.isEmpty ? "📌" : ev.icon, weekday: weekdayIndex(info.target), holiday: t.holiday)
    }
}

// MARK: - 小组件页

struct WidgetsView: View {
    @EnvironmentObject var store: Store
    @State private var tab = "中"
    @State private var selected: WidgetTemplate? = nil
    private let tabs = ["小", "中", "大"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavBar(title: "小组件", back: nil) { EmptyView() }

                Text("按官方标准分 小 2×2 · 中 4×2 · 大 4×4。每个组件默认显示全部事件（按临近排序、过期顺延）；点「绑定事件」可改为多选分类或勾选指定事件。")
                    .font(.system(size: 12)).foregroundColor(Theme.muted).lineSpacing(5)
                    .padding(11).background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 14)

                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { c in
                        Button(action: { tab = c }) {
                            VStack(spacing: 0) {
                                Text(c).font(.system(size: 14, weight: tab == c ? .bold : .regular))
                                    .foregroundColor(tab == c ? Color(hex: "#5b7d55") : Color(hex: "#a19d97"))
                                    .padding(.bottom, 10)
                                Rectangle().fill(tab == c ? Color(hex: "#7fa87a") : Color.clear)
                                    .frame(height: 2).cornerRadius(2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .overlay(Rectangle().fill(Theme.line).frame(height: 1), alignment: .bottom)
                .padding(.horizontal, 14).padding(.top, 14)

                // 中号 4×2 组件用单列满宽预览，跟桌面实际比例一致；小/大号保持两列
                LazyVGrid(columns: tab == "中"
                            ? [GridItem(.flexible())]
                            : [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 18) {
                    ForEach(WidgetTemplate.all.filter { $0.category == tab }) { t in
                        VStack(spacing: 0) {
                            Button(action: { selected = t }) {
                                let ps = listPreviewSize(t.size)
                                WidgetPreviewView(t: t, evs: boundWidgetEvents(t, store: store), holiday: store.holiday, mini: true, theme: store.widgetThemes[t.id])
                                    .frame(width: ps.width, height: ps.height)
                                    .clipShape(RoundedRectangle(cornerRadius: t.size == "small" ? 26 : 22))
                                    .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
                            }
                            Text(t.name).font(.system(size: 12)).foregroundColor(Color(hex: "#8b8782")).padding(.top, 8)
                            Text("\(sizeLabel(t.size)) · \(gridLabel(t.size))")
                                .font(.system(size: 10)).foregroundColor(Color(hex: "#b0aca6")).padding(.top, 2)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.top, 22)

                Text("👑 6 款组件已全部做进 · 更多样式持续更新")
                    .font(.system(size: 13)).foregroundColor(Color(hex: "#8e8a84"))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Capsule())
                    .padding(.horizontal, 40).padding(.top, 30).padding(.bottom, 24)
            }
        }
        .sheet(item: $selected) { t in
            WidgetModal(t: t).environmentObject(store)
        }
    }
}

// MARK: - 组件预览（与 Web V31 同款布局）

private struct WidgetPreviewView: View {
    let t: WidgetTemplate
    let evs: [BoundEvent]
    let holiday: HolidayCountdown?
    let mini: Bool
    let theme: WidgetTheme?

    var body: some View {
        // 把用户配色合并进模板皮肤，App 内预览与桌面组件用同一套颜色
        let themed = themedTemplate()
        Group {
            switch themed.kind {
            case "holiday": HolidayPanel(t: themed, evs: evs, holiday: holiday, mini: mini)
            case "simpleNumber": SimplePanel(t: themed, evs: evs, mini: mini, withTian: false)
            case "simple": SimplePanel(t: themed, evs: evs, mini: mini, withTian: true)
            case "grid": GridPanel(t: themed, evs: evs, mini: mini)
            case "picture": PicturePanel(t: themed, evs: evs, mini: mini)
            default: ListLargePanel(t: themed, evs: evs, mini: mini)
            }
        }
        .background(wc(themed.skin.bg))
    }

    private func themedTemplate() -> WidgetTemplate {
        var x = t
        x.skin = x.skin.overridden(by: theme)
        return x
    }
}

private struct HolidayPanel: View {
    let t: WidgetTemplate
    let evs: [BoundEvent]
    let holiday: HolidayCountdown?
    let mini: Bool
    private let week = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        GeometryReader { g in
            // 所有字号按容器高度等比取值，与桌面真实组件同一套比例，填满空隙
            let H = g.size.height
            let titleF = H * 0.085
            let bigF = H * 0.28
            let chipF = H * 0.062
            let weekF = H * 0.062
            let rowF = H * 0.078
            let pad = H * 0.06
            let rows = max(1, min(t.slots, evs.count))
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: H * 0.022) {
                    Text(holiday != nil ? "距离\(holiday!.name)" : "距离下一个假期")
                        .font(.system(size: titleF, weight: .bold)).foregroundColor(wc(t.skin.brand)).lineLimit(1)
                    if let h = holiday {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            // 假期中显示整个假期天数，不再只显示剩余 1 天
                            Text("\(h.inProgress ? h.holidayDays : h.daysLeft)").font(.system(size: bigF, weight: .bold)).foregroundColor(wc(t.skin.brand))
                            Text("天").font(.system(size: titleF * 0.8)).foregroundColor(wc(t.skin.brand))
                        }
                        HStack(spacing: H * 0.02) {
                            Text("休").font(.system(size: chipF, weight: .bold))
                                .padding(.horizontal, H * 0.02).padding(.vertical, H * 0.008)
                                .background(wc(t.skin.chipOn)).foregroundColor(wc(t.skin.chipOnInk)).clipShape(Capsule())
                            Text(h.rangeText).font(.system(size: chipF * 1.1)).foregroundColor(wc(t.skin.ink))
                                .lineLimit(1)
                        }
                    } else {
                        Text("—").font(.system(size: bigF * 0.92, weight: .bold)).foregroundColor(wc(t.skin.brand))
                        Text("每月更新").font(.system(size: chipF)).foregroundColor(wc(t.skin.inkSoft))
                    }
                    Spacer(minLength: 1)
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            Text(week[i]).font(.system(size: weekF, weight: i == todayWeek ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, H * 0.018)
                                .background(i == todayWeek ? wc(t.skin.chipOn) : Color.clear)
                                .foregroundColor(i == todayWeek ? wc(t.skin.chipOnInk) : wc(t.skin.inkSoft))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(pad)
                .frame(width: g.size.width * 0.42, alignment: .leading)
                .background(LinearGradient(gradient: Gradient(colors: [wc(t.skin.bgAccent), wc(t.skin.bg)]), startPoint: .topLeading, endPoint: .bottomTrailing))

                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { i in
                        let e = evs[i]
                        HStack(spacing: H * 0.025) {
                            Text(e.title + "  " + shortDate(e.date)).font(.system(size: rowF)).foregroundColor(wc(t.skin.ink)).lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(e.days)天").font(.system(size: rowF, weight: .bold)).foregroundColor(wc(t.skin.brand))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: (H - pad * 2) / CGFloat(rows))
                        .overlay(Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1), alignment: .bottom)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, pad)
                .frame(width: g.size.width * 0.58)
                .background(wc(t.skin.rowBg))
            }
        }
    }
    private var todayWeek: Int { weekdayIndex(Date()) }
}

private struct ComboPanel: View {
    let t: WidgetTemplate
    let evs: [BoundEvent]
    let mini: Bool

    var body: some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    let hero = evs.first ?? BoundEvent(title: "纪念日", date: "2026-01-01", days: 0, icon: "📌", weekday: 0, holiday: false)
                    Text("距离\(hero.title)").font(.system(size: mini ? 8 : 12, weight: .bold)).foregroundColor(wc(t.skin.brand))
                    Spacer(minLength: 2)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(daysText(hero.days)).font(.system(size: mini ? 20 : 42, weight: .bold)).foregroundColor(wc(t.skin.brand))
                        Text("天").font(.system(size: mini ? 7 : 12)).foregroundColor(wc(t.skin.brand))
                    }
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            Text(["日","一","二","三","四","五","六"][i]).font(.system(size: mini ? 5 : 9))
                                .frame(maxWidth: .infinity).padding(.vertical, mini ? 1 : 3)
                                .background(i == hero.weekday ? wc(t.skin.chipOn) : Color.clear)
                                .foregroundColor(i == hero.weekday ? wc(t.skin.chipOnInk) : wc(t.skin.inkSoft))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(mini ? 5 : 10).frame(width: g.size.width * 0.42, alignment: .leading)
                .background(LinearGradient(gradient: Gradient(colors: [wc(t.skin.bgAccent), wc(t.skin.bg)]), startPoint: .topLeading, endPoint: .bottomTrailing))

                VStack(spacing: 0) {
                    ForEach(1..<min(t.slots + 1, evs.count), id: \.self) { i in
                        let e = evs[i]
                        HStack {
                            Text(e.title + " " + shortDate(e.date)).font(.system(size: mini ? 7 : 10)).foregroundColor(wc(t.skin.ink)).lineLimit(1)
                            Spacer()
                            Text("\(e.days)天").font(.system(size: mini ? 7 : 11, weight: .bold)).foregroundColor(wc(t.skin.brand))
                        }.padding(.vertical, mini ? 3 : 7)
                    }
                    Spacer(minLength: 0)
                }.padding(.horizontal, mini ? 5 : 10).frame(width: g.size.width * 0.58).background(wc(t.skin.rowBg))
            }
        }
    }
}

private struct SimplePanel: View {
    let t: WidgetTemplate
    let evs: [BoundEvent]
    let mini: Bool
    let withTian: Bool

    var body: some View {
        // 按容器高度等比缩放，跟桌面小组件同一套比例，避免列表里显得偏小
        GeometryReader { g in
            let count = min(3, evs.count)
            let rows = max(1, count)
            let pad = g.size.height * 0.055
            let spacing = g.size.height * 0.045
            let rowH = (g.size.height - pad * 2 - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            let blockH = rowH * 0.62
            VStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    let e = evs[i]
                    let base = i < 2 ? wc(t.skin.hot) : wc(t.skin.far)
                    HStack(spacing: 4) {
                        HStack(spacing: 3) {
                            // 2×2 纯数字款（withTian=false）：缩小标题字号，不显示图标
                            Text(e.title).font(.system(size: rowH * (withTian ? 0.34 : 0.26), weight: .semibold)).foregroundColor(wc(t.skin.ink)).lineLimit(1)
                            if withTian && !e.icon.isEmpty { Text(e.icon).font(.system(size: rowH * 0.30)) }
                        }
                        Spacer(minLength: 2)
                        // 纯数字款始终按「天」计数，不换算成年；带天款蓝色显示天、橘红（超一年）显示年
                        let p = dayParts(e.days, useYear: withTian)
                        HStack(alignment: .bottom, spacing: 1) {
                            Text(p.num).font(.system(size: rowH * (withTian ? 0.42 : 0.36), weight: .bold)).foregroundColor(.white).lineLimit(1)
                            if withTian {
                                Text(p.unit).font(.system(size: rowH * 0.20, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.94)).padding(.bottom, rowH * 0.05)
                            }
                        }
                        .frame(height: blockH)
                        .padding(.horizontal, rowH * 0.2)
                        .background(base)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .padding(.horizontal, g.size.height * 0.05)
                    .frame(height: rowH)
                    .background(wc(t.skin.rowBg))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
            .padding(pad)
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}

private struct GridPanel: View {
    let t: WidgetTemplate
    let evs: [BoundEvent]
    let mini: Bool

    var body: some View {
        // 用 GeometryReader 撑满容器，字号按卡高等比，跟桌面 GridRoseView 同一比例
        GeometryReader { g in
            let h = g.size.height
            let outerPad = h * 0.055
            let spacing = h * 0.04
            let cardH = (h - outerPad * 2 - spacing) / 2
            VStack(spacing: spacing) {
                HStack(spacing: spacing) { card(0, cardH: cardH); card(1, cardH: cardH) }
                HStack(spacing: spacing) { card(2, cardH: cardH); card(3, cardH: cardH) }
            }
            .padding(outerPad)
            .frame(width: g.size.width, height: g.size.height)
        }
    }
    @ViewBuilder
    private func card(_ i: Int, cardH: CGFloat) -> some View {
        if i < evs.count {
            let e = evs[i]
            VStack(alignment: .leading, spacing: cardH * 0.02) {
                HStack(spacing: cardH * 0.04) {
                    Text(e.icon).font(.system(size: cardH * 0.24))
                    Text(e.title).font(.system(size: cardH * 0.24, weight: .bold)).foregroundColor(wc(t.skin.ink)).lineLimit(1)
                }
                Text("\(e.date.replacingOccurrences(of: "-", with: ".")) \(weekName(e.weekday))")
                    .font(.system(size: cardH * 0.20)).foregroundColor(wc(t.skin.inkSoft)).lineLimit(1)
                Spacer(minLength: 1)
                HStack { Spacer(); Text(daysText(e.days)).font(.system(size: cardH * 0.30, weight: .bold)).foregroundColor(wc(t.skin.brand)) }
            }
            .padding(cardH * 0.10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(wc(t.skin.rowBg)).clipShape(RoundedRectangle(cornerRadius: cardH * 0.14))
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private func weekName(_ i: Int) -> String { ["星期日","星期一","星期二","星期三","星期四","星期五","星期六"][max(0, min(6, i))] }
}

private struct PicturePanel: View {
    let t: WidgetTemplate
    let evs: [BoundEvent]
    let mini: Bool

    var body: some View {
        // 与桌面 PictureTealLargeView 同比例：字号按容器高度等比缩放
        GeometryReader { g in
            let h = g.size.height
            let pad = h * 0.075
            let headerH = h * 0.115
            let spacing = h * 0.018
            let rows = max(1, min(5, evs.count))
            let rowH = (h - pad * 2 - headerH - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            VStack(spacing: spacing) {
                let now = Date()
                Text("\(Calendar(identifier: .gregorian).component(.month, from: now))月\(Calendar(identifier: .gregorian).component(.day, from: now))日 \(weekName(weekdayIndex(now)))")
                    .font(.system(size: h * 0.072, weight: .medium)).foregroundColor(wc(t.skin.inkSoft))
                    .frame(height: headerH)
                VStack(spacing: spacing) {
                    ForEach(0..<rows, id: \.self) { i in
                        let e = evs[i]
                        HStack(spacing: h * 0.02) {
                            Text(e.title).font(.system(size: rowH * 0.34)).foregroundColor(wc(t.skin.ink)).lineLimit(1)
                            if !e.icon.isEmpty { Text(e.icon).font(.system(size: rowH * 0.30)) }
                            Spacer(minLength: 2)
                            let p = dayParts(e.days)
                            Text(p.num).font(.system(size: rowH * 0.44, weight: .bold)).foregroundColor(wc(t.skin.brand))
                            Text(p.unit).font(.system(size: rowH * 0.22)).foregroundColor(wc(t.skin.brand).opacity(0.95))
                        }
                        .padding(.horizontal, h * 0.03)
                        .frame(height: rowH)
                        .background(wc(t.skin.rowBg)).clipShape(RoundedRectangle(cornerRadius: rowH * 0.2))
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(pad)
            .frame(width: g.size.width, height: g.size.height)
            .background(LinearGradient(gradient: Gradient(colors: [wc(t.skin.bg), wc(t.skin.bgAccent)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
    private func weekName(_ i: Int) -> String { ["星期日","星期一","星期二","星期三","星期四","星期五","星期六"][max(0, min(6, i))] }
}

private struct ListLargePanel: View {
    let t: WidgetTemplate
    let evs: [BoundEvent]
    let mini: Bool

    var body: some View {
        GeometryReader { g in
            let count = min(5, evs.count)
            let rows = max(1, count)
            let pad = g.size.height * 0.06
            let headerH = g.size.height * 0.135
            let spacing = g.size.height * 0.02
            let rowH = (g.size.height - pad * 2 - headerH - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            VStack(spacing: spacing) {
                let now = Date()
                Text("\(Calendar(identifier: .gregorian).component(.month, from: now))月\(Calendar(identifier: .gregorian).component(.day, from: now))日 \(weekName(weekdayIndex(now)))")
                    .font(.system(size: headerH * 0.46, weight: .semibold)).foregroundColor(wc(t.skin.chipOnInk))
                    .frame(maxWidth: .infinity).frame(height: headerH)
                    .background(wc(t.skin.bgAccent)).clipShape(RoundedRectangle(cornerRadius: 8))
                ForEach(0..<count, id: \.self) { i in
                    let e = evs[i]
                    HStack(spacing: 6) {
                        Text("\(e.title) \(e.icon)").font(.system(size: rowH * 0.32, weight: .semibold)).foregroundColor(wc(t.skin.ink)).lineLimit(1)
                        Spacer(minLength: 2)
                        let p = dayParts(e.days)
                        HStack(alignment: .bottom, spacing: 1) {
                            Text(p.num).font(.system(size: rowH * 0.36, weight: .bold)).foregroundColor(.white).lineLimit(1)
                            Text(p.unit).font(.system(size: rowH * 0.18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.94)).padding(.bottom, rowH * 0.04)
                        }
                        .frame(height: rowH * 0.62)
                        .padding(.horizontal, rowH * 0.25)
                        .background(i < 3 ? wc(t.skin.hot) : wc(t.skin.far))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.horizontal, g.size.height * 0.04)
                    .frame(height: rowH)
                    .background(wc(t.skin.rowBg)).clipShape(RoundedRectangle(cornerRadius: rowH * 0.2))
                }
            }
            .padding(pad)
            .frame(width: g.size.width, height: g.size.height)
        }
    }
    private func weekName(_ i: Int) -> String { ["星期日","星期一","星期二","星期三","星期四","星期五","星期六"][max(0, min(6, i))] }
}

// MARK: - 模板详情弹层（先预览，再绑定）

private struct WidgetModal: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let t: WidgetTemplate
    @State private var setting = false
    @State private var showStyle = false

    /// 外观调色板：空 hex 表示沿用组件默认色
    private struct PaletteColor: Identifiable {
        let name: String
        let hex: String
        var id: String { name }
    }
    private let colorPalette: [PaletteColor] = [
        .init(name: "默认", hex: ""), .init(name: "暖白", hex: "#FBFAF7"), .init(name: "米色", hex: "#F3EAD9"),
        .init(name: "浅粉", hex: "#FBEDF0"), .init(name: "薄荷", hex: "#EEF0E6"), .init(name: "天蓝", hex: "#DBE7F1"),
        .init(name: "青绿", hex: "#5C9E96"), .init(name: "深灰", hex: "#3A3835"), .init(name: "纯白", hex: "#FFFFFF")
    ]

    @MainActor private var binding: WidgetBinding { store.bindings[t.id] ?? .empty }
    @MainActor private var count: Int { pickWidgetEvents(t, store: store).count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button("返回") { dismiss() }.foregroundColor(Color(hex: "#8d8984"))
                Spacer()
                Text(t.name).font(.system(size: 16, weight: .bold))
                Spacer()
                Button(setting ? "收起" : "绑定事件") { setting.toggle() }
                    .foregroundColor(Color(hex: "#5b7d55"))
            }
            .padding(.bottom, 8)

            if setting {
                settingView
            } else {
                previewView
            }
        }
        .padding(16)
        .background(Theme.paper)
    }

    private var previewView: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text(sizeLabel(t.size)).font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: "#eef0e6")).clipShape(Capsule())
                    Text("固定 \(gridLabel(t.size)) · \(ptLabel(t.size)) pt（此组件仅有该规格）")
                        .font(.system(size: 11)).foregroundColor(Color(hex: "#a19d97"))
                }
                let ps = previewPointSize(t.size)
                WidgetPreviewView(t: t, evs: boundWidgetEvents(t, store: store), holiday: store.holiday, mini: false, theme: store.widgetThemes[t.id])
                    .frame(width: ps.width, height: ps.height)
                    .clipShape(RoundedRectangle(cornerRadius: t.size == "small" ? 26 : 22))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                styleSection
                Text("在系统桌面长按空白处添加「纪念日」小组件，即可看到本页同款组件。组件数据随事件增删改自动更新。")
                    .font(.system(size: 11)).foregroundColor(Theme.muted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// 外观设置：每款组件独立保存背景色与字体色，实时作用于 App 预览与桌面组件
    private var styleSection: some View {
        let theme = store.widgetThemes[t.id] ?? .default
        return VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation { showStyle.toggle() } } label: {
                HStack {
                    Text("🎨 外观设置（背景 / 字体颜色）")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.ink)
                    Spacer()
                    Image(systemName: showStyle ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12)).foregroundColor(Theme.muted)
                }
            }
            .buttonStyle(.plain)

            if showStyle {
                colorRow(title: "背景颜色", current: theme.bg) { v in
                    var th = store.widgetThemes[t.id] ?? .default
                    th.bg = v
                    store.saveWidgetTheme(th, for: t.id)
                }
                colorRow(title: "字体颜色", current: theme.ink) { v in
                    var th = store.widgetThemes[t.id] ?? .default
                    th.ink = v
                    store.saveWidgetTheme(th, for: t.id)
                }
                Text("浅色背景建议搭配深色字体；选择「默认」可恢复该组件的原始配色。")
                    .font(.system(size: 10)).foregroundColor(Theme.muted)
                Button("恢复默认配色") { store.saveWidgetTheme(.default, for: t.id) }
                    .font(.system(size: 12)).foregroundColor(Theme.accent)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func colorRow(title: String, current: String?, choose: @escaping (String?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(colorPalette, id: \.name) { item in
                        let on = (current ?? "") == item.hex
                        Button { choose(item.hex.isEmpty ? nil : item.hex) } label: {
                            VStack(spacing: 3) {
                                Circle()
                                    .fill(item.hex.isEmpty ? Color(uiColor: .systemBackground) : Color(hex: item.hex))
                                    .frame(width: 26, height: 26)
                                    .overlay(Circle().stroke(on ? Theme.accent : Theme.line, lineWidth: on ? 2 : 1))
                                Text(item.name).font(.system(size: 9)).foregroundColor(on ? Theme.ink : Theme.muted)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var settingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(t.desc).font(.system(size: 12)).foregroundColor(Theme.muted)

                if t.holiday {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("左侧法定节假日（自动获取）").font(.system(size: 12, weight: .bold))
                        if let h = store.holiday {
                            Text("当前：\(h.icon) 距离\(h.name)\(h.inProgress ? " · 假期中" : "还有 \(h.daysLeft) 天") · 休 \(h.rangeText)")
                                .font(.system(size: 11))
                        } else {
                            Text("正在获取…").font(.system(size: 11)).foregroundColor(Theme.muted)
                        }
                        Text("数据来自国务院放假安排，每月自动联网更新一次；离线时使用上次缓存或农历推算。")
                            .font(.system(size: 10)).foregroundColor(Theme.muted)
                    }
                    .padding(10).background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 0) {
                    modeButton("① 指定事件", binding.mode == "events") { update { $0.mode = "events" } }
                    modeButton("② 选分类", binding.mode != "events") { update { $0.mode = "category" } }
                }
                .background(Color(uiColor: .secondarySystemBackground)).clipShape(Capsule())

                if binding.mode == "events" {
                    Text("勾选特定事件（可多选，按临近日期排序）。已选 \(binding.eventIds.count) 个。")
                        .font(.system(size: 11)).foregroundColor(Theme.muted)
                    ForEach(store.events) { ev in
                        let on = binding.eventIds.contains(ev.id)
                        let info = DateUtils.dayInfo(ev)
                        checkRow(color: Color(hex: ev.color), label: "\(ev.icon) \(ev.title)",
                                 sub: info.dir == "future" ? "还有\(info.days)天" : "\(info.days)天前", on: on) {
                            var ids = binding.eventIds
                            if let i = ids.firstIndex(of: ev.id) { ids.remove(at: i) } else { ids.append(ev.id) }
                            update { $0.eventIds = ids; $0.mode = "events" }
                        }
                    }
                } else {
                    Text("可多选分类。不选任何分类则默认显示全部事件。")
                        .font(.system(size: 11)).foregroundColor(Theme.muted)
                    ForEach(store.categories) { c in
                        let on = binding.categoryIds.contains(c.id)
                        let cnt = c.id == "cat:all" ? store.events.count : store.events.filter { $0.categoryId == c.id }.count
                        checkRow(color: Color(hex: c.color), label: c.name, sub: "\(cnt) 个事件", on: on) {
                            var ids = binding.categoryIds
                            if let i = ids.firstIndex(of: c.id) { ids.remove(at: i) } else { ids.append(c.id) }
                            update { $0.categoryIds = ids; $0.mode = "category" }
                        }
                    }
                }

                Text("当前显示：\(count) 个事件")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: "#5b7d55"))
                    .padding(.top, 4)
                Button("完成") { setting = false; store.save() }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color(hex: "#eef0e6")).foregroundColor(Color(hex: "#5b7d55"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func update(_ patch: (inout WidgetBinding) -> Void) {
        var b = binding
        patch(&b)
        store.bindings[t.id] = b
        store.save()
    }

    private func modeButton(_ text: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 12, weight: on ? .bold : .regular))
                .foregroundColor(on ? Color(hex: "#5b7d55") : Theme.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(on ? Color.white : Color.clear).clipShape(Capsule())
        }
    }

    private func checkRow(color: Color, label: String, sub: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5).fill(color).frame(width: 16, height: 16)
                Text(label).font(.system(size: 13)).foregroundColor(Theme.ink).lineLimit(1)
                Spacer()
                Text(sub).font(.system(size: 10)).foregroundColor(Theme.muted)
                Text(on ? "✓" : "").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "#5b7d55"))
                    .frame(width: 20, height: 20)
                    .background(on ? Color(hex: "#eef0e6") : Color.clear).clipShape(Circle())
            }
            .padding(.vertical, 6)
        }.buttonStyle(.plain)
    }
}
