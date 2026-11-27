import WidgetKit
import SwiftUI

// Widget target 独立编译，需自带颜色扩展
private extension Color {
    init(hexW: String) {
        let s = hexW.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255, opacity: 1)
    }
}
private enum WTheme {
    static let muted = Color(hexW: "#8d857c")
}

// Widget 自带的数据模型（与主 App 的 Models.swift 结构一致，App 写入 App Group 供 Widget 读取）
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

// MARK: - Widget 时间线

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), payload: load()) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: Date(), payload: load())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        var entries: [Entry] = []
        // 每分钟刷新一次，保证倒数天数及时更新
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

struct Entry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
}

// MARK: - Widget Bundle（6 款）

@main
struct DaysNoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        HolidayMediumWidget()
        HolidayFreshWidget()
        GridMediumWidget()
        SimpleSmallWidget()
        PictureLargeWidget()
        ListLargeWidget()
    }
}

// MARK: - 共享渲染组件

struct WidgetRoot<Content: View>: View {
    @Environment(\.widgetFamily) var family
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { content.containerBackground(.clear, for: .widget) }
}

func daysText(_ e: WidgetEvent) -> String { e.days > 365 ? String(format: "%.2f年", Double(e.days) / 365) : "\(e.days)" }

// 假日组件（中）
struct HolidayMediumWidget: Widget {
    let kind = "holiday-official"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            HolidayWidgetView(entry: e, skin: .classic)
        }
        .configurationDisplayName("假日 · 法定节假日")
        .description("左侧法定节假日 + 右侧分类事件")
        .supportedFamilies([.systemMedium])
    }
}
struct HolidayFreshWidget: Widget {
    let kind = "holiday-fresh"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            HolidayWidgetView(entry: e, skin: .fresh)
        }
        .configurationDisplayName("假日 · 清新绿")
        .description("假日组件清新绿皮肤")
        .supportedFamilies([.systemMedium])
    }
}

enum WidgetSkinStyle { case classic, fresh, rose, minimal, teal, bluehead }

struct HolidayWidgetView: View {
    let entry: Entry
    let skin: WidgetSkinStyle
    private var bg: Color {
        switch skin { case .fresh: return Color(hexW: "#eef0e6"); default: return Color(hexW: "#fbfaf7") }
    }
    var body: some View {
        WidgetRoot {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    if let h = entry.payload.holiday {
                        Text(h.icon).font(.system(size: 18))
                        Text("\(h.daysLeft)").font(.system(size: 40, weight: .bold)).foregroundColor(Color(hexW: "#5b9bd5"))
                        Text(h.inProgress ? "假期中" : "天后").font(.system(size: 10))
                        Text(h.name).font(.system(size: 12, weight: .semibold))
                        Text(h.rangeText).font(.system(size: 9)).foregroundColor(WTheme.muted)
                    } else {
                        Text("🎉").font(.system(size: 20))
                        Text("假日").font(.system(size: 13, weight: .semibold))
                        Text("每月更新").font(.system(size: 9)).foregroundColor(WTheme.muted)
                    }
                }.frame(width: 120, alignment: .leading)
                Divider()
                VStack(spacing: 3) {
                    ForEach(entry.payload.events.prefix(4)) { ev in
                        HStack(spacing: 6) {
                            Text(ev.icon).font(.system(size: 12))
                            Text(ev.title).font(.system(size: 10)).lineLimit(1)
                            Spacer()
                            Text(daysText(ev)).font(.system(size: 12, weight: .bold))
                        }
                    }
                }
            }
            .padding(12).background(bg)
        }
    }
}

struct GridMediumWidget: Widget {
    let kind = "grid-rose"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(e.payload.events.prefix(4)) { ev in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack { Text(ev.icon).font(.system(size: 14)); Spacer() }
                            Text(ev.title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                            Text(ev.date).font(.system(size: 8)).foregroundColor(Color(hexW: "#c2949e"))
                            Text(daysText(ev)).font(.system(size: 20, weight: .bold)).foregroundColor(Color(hexW: "#b46876"))
                        }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hexW: "#f8d7de")).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }.padding(10).background(Color(hexW: "#fbedef"))
            }
        }
        .configurationDisplayName("四宫格面板 · 柔粉").description("2×2 卡片")
        .supportedFamilies([.systemMedium])
    }
}

struct SimpleSmallWidget: Widget {
    let kind = "simple-day"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(e.payload.events.prefix(3)) { ev in
                        HStack(spacing: 6) {
                            Text(ev.icon).font(.system(size: 12))
                            Text(ev.title).font(.system(size: 10)).lineLimit(1)
                            Spacer()
                            Text(daysText(ev)).font(.system(size: 15, weight: .bold))
                            Text("天").font(.system(size: 9)).foregroundColor(WTheme.muted)
                        }
                    }
                    if e.payload.events.isEmpty { Text("暂无事件").font(.system(size: 11)).foregroundColor(WTheme.muted) }
                }.padding(12).background(Color(hexW: "#f2f2f0"))
            }
        }
        .configurationDisplayName("简约列表 · 带天").description("2×2 紧凑三行")
        .supportedFamilies([.systemSmall])
    }
}

struct PictureLargeWidget: Widget {
    let kind = "picture-teal"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot {
                VStack(alignment: .leading, spacing: 8) {
                    Text("纪念日").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    ForEach(e.payload.events.prefix(5)) { ev in
                        HStack(spacing: 8) {
                            Text(ev.icon)
                            Text(ev.title).font(.system(size: 11)).foregroundColor(.white).lineLimit(1)
                            Spacer()
                            Text(daysText(ev)).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        }.padding(9).background(Color.white.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }.padding(12).background(Color(hexW: "#5c9e96"))
            }
        }
        .configurationDisplayName("图文列表 · 青绿").description("4×4 大号列表")
        .supportedFamilies([.systemLarge])
    }
}

struct ListLargeWidget: Widget {
    let kind = "list-bluehead"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { e in
            WidgetRoot {
                VStack(alignment: .leading, spacing: 8) {
                    Text("纪念日").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hexW: "#3b82d6"))
                    ForEach(e.payload.events.prefix(5)) { ev in
                        HStack(spacing: 8) {
                            Text(ev.icon)
                            Text(ev.title).font(.system(size: 11)).lineLimit(1)
                            Spacer()
                            Text(daysText(ev)).font(.system(size: 17, weight: .bold)).foregroundColor(Color(hexW: "#4a90d9"))
                            Text("天").font(.system(size: 9)).foregroundColor(WTheme.muted)
                        }.padding(9).background(Color(hexW: "#f5f6f8")).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }.padding(12).background(Color.white)
            }
        }
        .configurationDisplayName("简约列表 · 大号").description("4×4 白底蓝头")
        .supportedFamilies([.systemLarge])
    }
}
