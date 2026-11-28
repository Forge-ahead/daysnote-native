import SwiftUI

/// 时间轴（对齐 V31）：
/// 1. 年份标题 sticky 悬浮，点击可跳转年份
/// 2. 顶部浮动控件栏：全部节日 / 仅纪念日 + 分类
/// 3. 筛选与分类通过 @AppStorage 自动记忆
/// 4. 时间轴中插入「今天」标记行，控件栏有「今天」快捷定位按钮
struct TimelineView: View {
    @EnvironmentObject var store: Store
    let onSelect: (EventItem) -> Void
    let onAdd: () -> Void

    static let minYear = 1970
    static let maxYear = 2100

    // 与 V31 localStorage key 一致，筛选与分类记忆
    @AppStorage("daysnote.timeline.scope.v1") private var scope = "all"      // all / anniv
    @AppStorage("daysnote.timeline.cat.v1") private var selectedCat = "all"

    @State private var didInit = false
    // 筛选变化时强制重建列表（LazyVStack 会缓存行内容，@AppStorage 变更不会重算已渲染行）
    @State private var refreshID = UUID()

    private var thisYear: Int { Calendar(identifier: .gregorian).component(.year, from: Date()) }
    private var today: Date { DateUtils.startOfToday() }

    // 年份范围：当前年 ±10 + 事件年份，避免一次渲染 1970–2100 全部年份
    private var yearRange: ClosedRange<Int> {
        var lo = thisYear - 10
        var hi = thisYear + 10
        for e in store.events {
            if let y = Int(e.date.prefix(4)) {
                lo = min(lo, y - 1)
                hi = max(hi, y + 1)
            }
        }
        return max(Self.minYear, lo)...min(Self.maxYear, hi)
    }

    private var pickerYears: [Int] {
        var s = Set<Int>()
        for y in (thisYear - 8)...(thisYear + 8) { s.insert(y) }
        for e in store.events { if let y = Int(e.date.prefix(4)) { s.insert(y) } }
        for y in yearRange { s.insert(y) }
        return s.sorted()
    }

    struct Row: Identifiable, Hashable {
        let id: String
        let date: Date
        let title: String
        let icon: String
        let color: String
        let diff: Int
        let kind: String     // event / lunar / legal / today
        let eventId: String?
    }

    /// 连续时间轴：每年 = 年份标题（header）+ 该年事件与节日（按月日重排）
    private func rowsFor(_ y: Int) -> [Row] {
        var per: [Row] = []
        let cal = Calendar(identifier: .gregorian)
        for e in store.events {
            if e.showInTimeline == false { continue }
            if selectedCat != "all" && e.categoryId != selectedCat { continue }
            let base = DateUtils.fromISO(e.date)
            let parts = LunarCalendar.lunarParts(base)
            let date: Date
            if e.lunar, let d = LunarCalendar.solarFromLunar(year: y, month: parts.month, day: parts.day, leap: parts.leap) {
                date = d
            } else {
                date = cal.date(from: DateComponents(year: y, month: cal.component(.month, from: base), day: cal.component(.day, from: base))) ?? base
            }
            let diff = Int(round(date.timeIntervalSince(today) / 86400))
            per.append(Row(id: "\(e.id)-\(y)", date: date, title: e.title, icon: e.icon, color: e.color,
                           diff: diff, kind: "event", eventId: e.id))
        }
        if store.settings.showFestivals && scope == "all" {
            for f in Festivals.forYear(y) {
                let diff = Int(round(f.date.timeIntervalSince(today) / 86400))
                per.append(Row(id: "f-\(f.kind)-\(f.name)-\(y)", date: f.date, title: f.name, icon: f.icon,
                               color: f.kind == "lunar" ? "#c98a5b" : "#5b8f84", diff: diff, kind: f.kind, eventId: nil))
            }
        }
        // 「今天」标记：只在当前年份插入，按月日位置参与排序
        if y == thisYear {
            per.append(Row(id: "today-\(y)", date: today, title: "今天", icon: "", color: "",
                           diff: 0, kind: "today", eventId: nil))
        }
        per.sort { $0.date < $1.date }
        return per
    }

    private func diffLabel(_ d: Int) -> String { d == 0 ? "0天" : d > 0 ? "\(d)天后" : "\(-d)天前" }
    private func md(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "MM.dd"; return f.string(from: d) }
    private func week(_ d: Date) -> String {
        let symbols = Array("日一二三四五六")
        let idx = Calendar(identifier: .gregorian).component(.weekday, from: d) - 1
        return "周" + String(symbols[max(0, min(symbols.count - 1, idx))])
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    controlsBar(proxy: proxy)

                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(yearRange, id: \.self) { y in
                                Section(header: yearHeader(y, proxy: proxy)) {
                                    ForEach(rowsFor(y)) { r in rowView(r) }
                                }
                            }
                            Text("继续上下滑动，自动加载更多年份")
                                .font(.system(size: 11)).foregroundColor(Theme.muted)
                                .padding(.vertical, 22).frame(maxWidth: .infinity)
                        }
                        .padding(.top, 4)
                        .id(refreshID)
                    }
                    .onChange(of: scope) { _ in reload(proxy) }
                    .onChange(of: selectedCat) { _ in reload(proxy) }
                    .onAppear {
                        guard !didInit else { return }
                        didInit = true
                        // 打开即定位到「今天」所在行：无动画、不显示滚动过程
                        DispatchQueue.main.async {
                            proxy.scrollTo("today-\(self.thisYear)", anchor: .center)
                        }
                    }
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

    // 筛选/分类切换后立即重算列表并重新定位到今年
    private func reload(_ proxy: ScrollViewProxy) {
        refreshID = UUID()
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo("year-\(self.thisYear)", anchor: .top) }
        }
    }

    // 顶部浮动控件栏：不随滚动滚走，对齐 V31 .tl-controls
    private func controlsBar(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                segBtn("全部节日", scope == "all") { scope = "all" }
                segBtn("仅纪念日", scope == "anniv") { scope = "anniv" }
            }
            .background(Color(uiColor: .systemBackground))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

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

            Spacer(minLength: 0)

            Button {
                withAnimation { proxy.scrollTo("today-\(thisYear)", anchor: .center) }
            } label: {
                Text("今天").font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#5b7d55"))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(hex: "#eef0e6")).clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Theme.paper)
    }

    private func segBtn(_ text: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 12, weight: on ? .bold : .regular))
                .foregroundColor(on ? Color(hex: "#3d3b3a") : Color(hex: "#7d9b78"))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(on ? Color(hex: "#cfe0c6") : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    /// 年份标题：绿色胶囊，sticky 悬浮在控件栏下方，点击选择年份跳转
    @ViewBuilder
    private func yearHeader(_ y: Int, proxy: ScrollViewProxy) -> some View {
        Menu {
            ForEach(pickerYears, id: \.self) { yy in
                Button("\(yy)年") {
                    withAnimation { proxy.scrollTo("year-\(yy)", anchor: .top) }
                }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
        .background(Theme.paper)
    }

    @ViewBuilder
    private func rowView(_ r: Row) -> some View {
        if r.kind == "today" {
            HStack(spacing: 8) {
                Text("今天").font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Color(hex: "#5b8f84")).clipShape(Capsule())
                Text(md(r.date) + " " + week(r.date))
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#5b8f84"))
                Spacer()
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .background(Color(hex: "#eef4ef"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 14).padding(.vertical, 4)
            .id("today-\(thisYear)")
        } else {
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
                    if !r.icon.isEmpty { Text(r.icon).font(.system(size: 20)).opacity(0.7) }
                }
                .frame(minHeight: 86)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
        }
    }
}
