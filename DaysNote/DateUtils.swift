import Foundation

// MARK: - 日期计算（纯 Foundation，无第三方依赖）

enum DateUtils {
    static let day: TimeInterval = 86400

    static func startOfToday(_ d: Date = Date()) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.startOfDay(for: d)
    }

    static func toISO(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.string(from: d)
    }

    static func fromISO(_ s: String) -> Date {
        let parts = s.split(separator: "-").compactMap { Int($0) }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        if parts.count == 2 { return f.date(from: "\(Calendar.current.component(.year, from: Date()))-\(s)") ?? Date() }
        return f.date(from: s) ?? Date()
    }

    static let weekShort = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    static let weekFull = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]

    static func formatCN(_ iso: String, withWeek: Bool = true) -> String {
        let d = fromISO(iso)
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"; f.timeZone = .current
        var text = f.string(from: d)
        if withWeek {
            let w = Calendar(identifier: .gregorian).component(.weekday, from: d) - 1
            text += " " + weekShort[max(0, min(6, w))]
        }
        return text
    }

    static func formatDays(_ days: Int) -> String {
        days > 365 ? String(format: "%.2f年", Double(days) / 365.0) : String(days)
    }

    /// 目标日期：yearly 且 lunar 走农历滚动，yearly 公历按当前年滚动
    static func targetDate(_ ev: EventItem, now: Date = startOfToday()) -> Date {
        let base = fromISO(ev.date)
        guard ev.repeatMode == .yearly else { return base }
        if ev.lunar, let solar = LunarCalendar.nextLunarOccurrence(date: base, from: now) { return solar }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        var candidate = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: cal.component(.month, from: base), day: cal.component(.day, from: base))) ?? base
        if candidate < now { candidate = cal.date(from: DateComponents(year: cal.component(.year, from: now) + 1, month: cal.component(.month, from: base), day: cal.component(.day, from: base))) ?? candidate }
        return candidate
    }

    static func dayInfo(_ ev: EventItem, now: Date = startOfToday()) -> (days: Int, dir: String, target: Date) {
        let target = targetDate(ev, now: now)
        let diff = Int(round(target.timeIntervalSince(now) / day))
        return diff >= 0 ? (diff, "future", target) : (-diff, "past", target)
    }

    /// 首页分组天数：倒数用滚动目标，正数从真实日期算起
    static func homeCounts(_ ev: EventItem, now: Date = startOfToday()) -> (countdown: Int?, countup: Int?) {
        let mode = inferMode(ev, now: now)
        let real = fromISO(ev.date)
        var countdown: Int? = nil
        var countup: Int? = nil
        if mode == .countdown || mode == .both {
            let info = dayInfo(ev, now: now)
            if info.dir == "future" { countdown = info.days }
            else {
                var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
                let next = cal.date(from: DateComponents(year: cal.component(.year, from: now) + 1, month: cal.component(.month, from: real), day: cal.component(.day, from: real))) ?? real
                countdown = max(0, Int(round(next.timeIntervalSince(now) / day)))
            }
        }
        if mode == .countup || mode == .both {
            countup = max(0, Int(round(now.timeIntervalSince(real) / day)))
        }
        return (countdown, countup)
    }

    static func inferMode(_ ev: EventItem, now: Date = startOfToday()) -> CountMode {
        if let m = ev.displayMode { return m }
        return dayInfo(ev, now: now).dir == "future" ? .countdown : .countup
    }

    static func yearRemaining(now: Date = startOfToday()) -> Int {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let end = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: 12, day: 31)) ?? now
        return Int(round(end.timeIntervalSince(now) / day))
    }
}

// MARK: - 农历（使用系统 Chinese Calendar）

enum LunarCalendar {
    static var chineseCalendar: Calendar {
        var c = Calendar(identifier: .chinese); c.timeZone = .current; return c
    }

    static func lunarParts(_ date: Date) -> (year: Int, month: Int, day: Int, leap: Bool) {
        let c = chineseCalendar
        let comps = c.dateComponents([.year, .month, .day], from: date)
        let leap = (comps.month ?? 0) < 0
        return (comps.year ?? 0, abs(comps.month ?? 0), comps.day ?? 0, leap)
    }

    static func lunarText(_ iso: String) -> String {
        let p = lunarParts(DateUtils.fromISO(iso))
        let cn = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
        let monthName = p.month >= 1 && p.month <= 12 ? cn[p.month - 1] : "\(p.month)"
        let dayName: String
        switch p.day {
        case 1: dayName = "初一"
        case 10: dayName = "初十"
        case 20: dayName = "二十"
        case 30: dayName = "三十"
        default:
            let nums = ["初", "十", "廿", "三"]
            let tens = p.day / 10, ones = p.day % 10
            let digit = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
            dayName = nums[tens] + (ones == 0 ? "" : digit[ones])
        }
        return (p.leap ? "闰" : "") + monthName + "月" + dayName
    }

    /// 公历年 → 系统农历的 (era, year)。
    /// 注意：Chinese Calendar 的 .year 是六十甲子纪年里的序号，不是公历年。
    /// 直接把 2026 塞进 .year 会得到约 4009 年，时间轴就会出现几十万天。
    private static func chineseEraYear(forGregorianYear year: Int) -> (era: Int?, year: Int?) {
        var g = Calendar(identifier: .gregorian)
        g.timeZone = .current
        // 7 月 1 日一定已过春节，落在对应农历年内
        let anchor = g.date(from: DateComponents(year: year, month: 7, day: 1)) ?? Date()
        let p = chineseCalendar.dateComponents([.era, .year], from: anchor)
        return (p.era, p.year)
    }

    /// 农历日期每年下一次对应的公历日期
    static func nextLunarOccurrence(date base: Date, from now: Date) -> Date? {
        let p = lunarParts(base)
        let c = chineseCalendar
        var g = Calendar(identifier: .gregorian); g.timeZone = .current
        var gregorianYear = g.component(.year, from: now)
        for _ in 0..<4 {
            let ey = chineseEraYear(forGregorianYear: gregorianYear)
            var comps = DateComponents()
            comps.era = ey.era
            comps.year = ey.year
            comps.month = p.leap ? -p.month : p.month
            comps.day = p.day
            if let d = c.date(from: comps), d >= now { return d }
            gregorianYear += 1
        }
        return nil
    }

    static func solarFromLunar(year: Int, month: Int, day: Int, leap: Bool = false) -> Date? {
        let c = chineseCalendar
        let ey = chineseEraYear(forGregorianYear: year)
        var comps = DateComponents()
        comps.era = ey.era
        comps.year = ey.year
        comps.month = leap ? -month : month
        comps.day = day
        return c.date(from: comps)
    }
}

// MARK: - 节日（时间轴）

struct Festival: Identifiable, Equatable {
    var id: String { name + "-" + DateUtils.toISO(date) }
    var name: String
    var date: Date
    var kind: String       // lunar / legal
    var icon: String
}

enum Festivals {
    static let lunarList: [(String, Int, Int, String)] = [
        ("春节", 1, 1, "🧧"), ("元宵节", 1, 15, "🏮"), ("龙抬头", 2, 2, "🐉"),
        ("端午节", 5, 5, "🎋"), ("七夕节", 7, 7, "💝"), ("中元节", 7, 15, "🏮"),
        ("中秋节", 8, 15, "🥮"), ("重阳节", 9, 9, "🍂"), ("腊八节", 12, 8, "🥣"),
    ]
    static let legalList: [(String, Int, Int, String)] = [
        ("元旦", 1, 1, "🎍"), ("情人节", 2, 14, "❤️"), ("妇女节", 3, 8, "🌸"),
        ("植树节", 3, 12, "🌳"), ("清明节", 4, 4, "🌿"), ("劳动节", 5, 1, "🛠️"),
        ("儿童节", 6, 1, "🎈"), ("国庆节", 10, 1, "🇨🇳"), ("圣诞节", 12, 25, "🎄"),
    ]

    /// 内置节日分类 id：作为虚拟事件供组件绑定，不写入用户事件列表。
    static let categoryId = "cat:festivals"

    /// 生成当年与次年的节日虚拟事件，供组件「绑定事件 / 选分类」使用。
    static func festivalEvents() -> [EventItem] {
        let cal = Calendar(identifier: .gregorian)
        let thisYear = cal.component(.year, from: Date())
        var out: [EventItem] = []
        for y in thisYear...(thisYear + 1) {
            for (i, f) in forYear(y).enumerated() {
                out.append(EventItem(
                    id: "festival:\(y):\(f.name)",
                    title: f.name,
                    date: DateUtils.toISO(f.date),
                    lunar: f.kind == "lunar",
                    categoryId: categoryId,
                    icon: f.icon,
                    color: f.kind == "lunar" ? "#c98a5b" : "#5b8f84",
                    note: "", order: Int64(y * 1000 + i), repeatMode: .none,
                    showInTimeline: false, displayMode: .countdown,
                    createdAt: 0, updatedAt: 0
                ))
            }
        }
        return out
    }

    static func forYear(_ year: Int) -> [Festival] {
        var out: [Festival] = []
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        for (name, m, d, icon) in lunarList {
            if let date = LunarCalendar.solarFromLunar(year: year, month: m, day: d) {
                out.append(Festival(name: name, date: date, kind: "lunar", icon: icon))
            }
        }
        // 除夕 = 春节前一天
        if let spring = LunarCalendar.solarFromLunar(year: year, month: 1, day: 1),
           let eve = cal.date(byAdding: .day, value: -1, to: spring) {
            out.append(Festival(name: "除夕", date: eve, kind: "lunar", icon: "🎊"))
        }
        for (name, m, d, icon) in legalList {
            if let date = cal.date(from: DateComponents(year: year, month: m, day: d)) {
                out.append(Festival(name: name, date: date, kind: "legal", icon: icon))
            }
        }
        return out.sorted { $0.date < $1.date }
    }
}
