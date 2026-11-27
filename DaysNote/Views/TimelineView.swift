import SwiftUI

/// 时间轴（对齐 Web v31 样式）：
/// 左列天数差 + 竖线圆点 + 右侧日期标题；年份标签可下拉跳转；
/// 控件栏（全部/仅纪念日 + 分类）固定在顶部；今天高亮。
struct TimelineView: View {
    @EnvironmentObject var store: Store
    let onSelect: (EventItem) -> Void
    let onAdd: () -> Void

    static let minYear = 1970
    static let maxYear = 2100

    @AppStorage("daysnote.timeline.scope") private var scope = "all"        // all / anniv
    @AppStorage("daysnote.timeline.cat") private var selectedCat = "all"

    @State private var didInit = false

    private var thisYear: Int { Calendar(identifier: .gregorian).component(.year, from: Date()) }
    private var today: Date { DateUtils.startOfToday() }

    // 年份下拉候选：当前年 ±8 + 事件里出现的年份
    private var pickerYears: [Int] {
        var s = Set<Int>()
        for y in (thisYear - 8)...(thisYear + 8) { s.insert(y) }
        for e in store.events { if let y = Int(e.date.prefix(4)) { s.insert(y) } }
        return s.sorted()
    }

    struct Row: Identifiable, Hashable {
        let id: String
        let date: Date
        let title: String
        let icon: String
        let color: String
        let diff: Int
        let kind: String     // event / lunar / legal / year
        let eventId: String?
        let year: Int?
    }

    // 连续时间轴：每年 = 年份标题 + 该年事件与节日（按月日重排）
    private func rowsFor(_ y: Int) -> [Row] {
        var per: [Row] = []
        let cal = Calendar(identifier: .gregorian)
        for e in store.events {
            if e.showInTimeline == false { continue }
            if selectedCat != "all" && e.categoryId != selectedCat { continue }
            let base = DateUtils.fromISO(e.date)
            let date: Date
            if e.lunar, let d = LunarCalendar.solarFromLunar(year: y, month: LunarCalendar.lunarParts(base).month,
                                                             day: LunarCalendar.lunarParts(base).day,
                                                             leap: LunarCalendar.lunarParts(base).leap) {
                date = d
            } else {
                date = cal.date(from: DateComponents(year: y, month: cal.component(.month, from: base), day: cal.component(.day, from: base))) ?? base
            }
            let diff = Int(round(date.timeIntervalSince(today) / 86400))
            per.append(Row(id: "\(e.id)-\(y)", date: date, title: e.title, icon: e.icon, color: e.color, diff: diff, kind: "event", eventId: e.id, year: nil))
        }
        if store.settings.showFestivals && scope == "all" {
            for f in Festivals.forYear(y) {
                let diff = Int(round(f.date.timeIntervalSince(today) / 86400))
                per.append(Row(id: "f-\(f.kind)-\(f.name)-\(y)", date: f.date, title: f.name, icon: f.icon,
                               color: f.kind == "lunar" ? "#c98a5b" : "#5b8f84", diff: diff, kind: f.kind, eventId: nil, year: nil))
            }
        }
        per.sort { $0.date < $1.date }
        var out = [Row(id: "year-\(y)", date: cal.date(from: DateComponents(year: y, month: 1, day: 1)) ?? today,
                       title: "\(y)年", icon: "", color: "", diff: 0, kind: "year", eventId: nil, year: y)]
        out.append(contentsOf: per)
        return out
    }

    private func diffLabel(_ d: Int) -> String { d == 0 ? "0天" : d > 0 ? "\(d)天后" : "\(-d)天前" }
    private func md(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MM.dd"; return f.string(from: d)
    }
    private func week(_ d: Date) -> String {
        let symbols = Array("日一二三四五六")
        let idx = Calendar(identifier: .gregorian).component(.weekday, from: d) - 1
        return "周" + String(symbols[max(0, min(symbols.count - 1, idx))])
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        // 控件栏：segment + 分类（浮动在时间轴顶部）
                        HStack(spacing: 10) {
                            HStack(spacing: 0) {
                                segBtn("全部", scope == "all") { scope = "all" }
                                segBtn("仅纪念日", scope == "anniv") { scope = "anniv" }
                            }
                            .background(Color(hex: "#e3ecdf")).clipShape(Capsule())
                            Menu {
                                Picker("", selection: $selectedCat) {
                                    Text("所有分类").tag("all")
                                    ForEach(store.categories.filter { $0.id != "cat:all" }) { c in
                                        Text(c.name).tag(c.id)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(selectedCat == "all" ? "所有分类" : (store.categories.first { $0.id == selectedCat }?.name ?? "分类"))
                                    Image(systemName: "chevron.down").font(.system(size: 9))
                                }
                                .font(.system(size: 12)).foregroundColor(Color(hex: "#7d9b78"))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color(uiColor: .secondarySystemBackground)).clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 6)

                        ForEach(Self.minYear...Self.maxYear, id: \.self) { y in
                            yearHeader(y) { yy in withAnimation { proxy.scrollTo("year-\(yy)", anchor: .top) } }
                            ForEach(rowsFor(y)) { r in
                                rowView(r)
                            }
                        }

                        Text("继续上下滑动，自动加载更多年份")
                            .font(.system(size: 11)).foregroundColor(Theme.muted)
                            .padding(.vertical, 22).frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
                }
                .onAppear {
                    guard !didInit else { return }
                    didInit = true
                    DispatchQueue.main.async { proxy.scrollTo("year-\(thisYear)", anchor: .top) }
                }
            }
            .navigationTitle("时刻")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onAdd) { Image(systemName: "plus").font(.system(size: 16, weight: .semibold)) }
                }
            }
        }
    }

    @ViewBuilder
    private func segBtn(_ text: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 12, weight: on ? .bold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundColor(on ? Color(hex: "#43684c") : Color(hex: "#7d9b78"))
        }
    }

    // 年份分隔标题：绿色胶囊，点击弹出年份选择
    @ViewBuilder
    private func yearHeader(_ y: Int, jump: @escaping (Int) -> Void) -> some View {
        Menu {
            ForEach(pickerYears, id: \.self) { yy in
                Button("\(yy)年") { jump(yy) }
            }
        } label: {
            HStack(spacing: 2) {
                Text("\(y)年")
                Image(systemName: "chevron.down").font(.system(size: 10))
            }
            .font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "#5b7d55"))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(hex: "#eef0e6")).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        }
        .id("year-\(y)")
        .padding(.leading, 14).padding(.top, 18).padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 时间轴行：diff + 竖线圆点 + 内容 + 图标
    @ViewBuilder
    private func rowView(_ r: Row) -> some View {
        if r.kind == "year" { EmptyView() } else {
            let isToday = r.diff == 0
            let isFestival = r.kind != "event"
            Button {
                if let id = r.eventId, let ev = store.events.first(where: { $0.id == id }) { onSelect(ev) }
            } label: {
                HStack(alignment: .center, spacing: 0) {
                    Text(diffLabel(r.diff))
                        .font(.system(size: 14)).foregroundColor(isToday ? Color(hex: "#5b8f84") : Theme.muted)
                        .frame(width: 74, alignment: .trailing)
                    ZStack {
                        Rectangle().fill(Color(hex: "#e4e0d8")).frame(width: 1)
                        Circle()
                            .fill(Color(hex: isToday ? "#5b8f84" : (isFestival ? "#d3a778" : "#c9bfb3")))
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Theme.paper, lineWidth: 5))
                    }.frame(width: 38)
                    VStack(alignment: .leading, spacing: 5) {
                        Text((isToday ? "今天 · " : "") + md(r.date) + " " + week(r.date) + (isFestival ? (r.kind == "lunar" ? " · 农历" : " · 节日") : ""))
                            .font(.system(size: 12)).foregroundColor(isToday ? Color(hex: "#5b8f84") : Color(hex: "#a39f99"))
                        Text(r.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isToday ? Color(hex: "#5b8f84") : Theme.ink)
                    }
                    Spacer(minLength: 4)
                    if !r.icon.isEmpty {
                        Text(r.icon).font(.system(size: 20)).opacity(0.7)
                    }
                }
                .frame(minHeight: 86)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
        }
    }
}
