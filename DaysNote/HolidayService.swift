import Foundation

/// 假日数据：holiday-cn（国务院放假安排），每月联网获取一次，失败用缓存 / 农历推算兜底
@MainActor
class HolidayService {
    static let shared = HolidayService()
    private func dataURL(_ year: Int) -> String { "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json" }
    private let cacheKeyMonth = "holiday.month"

    func loadCache() -> HolidayCountdown? { Persistence.load(HolidayCountdown.self, from: Persistence.holidayURL) }

    func refreshIfNeeded(force: Bool = false) async -> HolidayCountdown? {
        let fm = DateFormatter(); fm.dateFormat = "yyyy-MM"
        let month = fm.string(from: Date())
        let cachedMonth = UserDefaults.standard.string(forKey: cacheKeyMonth) ?? ""
        if !force, cachedMonth == month, let c = loadCache() { return c }
        if let found = await fetchOfficial() {
            Persistence.save(found, to: Persistence.holidayURL)
            UserDefaults.standard.set(month, forKey: cacheKeyMonth)
            return found
        }
        if let c = loadCache() { return c }
        let est = estimated()
        Persistence.save(est, to: Persistence.holidayURL)
        UserDefaults.standard.set(month, forKey: cacheKeyMonth)
        return est
    }

    private func fetchOfficial() async -> HolidayCountdown? {
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: Date())
        guard let url = URL(string: dataURL(year)) else { return nil }
        guard let r = try? await Net.request(url), r.ok,
              let root = (try? JSONSerialization.jsonObject(with: r.data)) as? [String: Any],
              let days = root["days"] as? [[String: Any]] else { return nil }

        var groups: [String: [String]] = [:]
        var workdays: [String: [String]] = [:]
        for d in days {
            guard let date = d["date"] as? String, let name = d["name"] as? String else { continue }
            if d["isOffDay"] as? Bool == true { groups[name, default: []].append(date) }
            else { workdays[name, default: []].append(date) }
        }
        struct Period { let name: String; let start: String; let end: String; let days: Int }
        var periods: [Period] = []
        for (name, ds) in groups {
            let sorted = ds.sorted()
            guard let s = sorted.first, let e = sorted.last else { continue }
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            let sd = fmt.date(from: s) ?? Date(), ed = fmt.date(from: e) ?? Date()
            let n = Int(round(ed.timeIntervalSince(sd) / 86400)) + 1
            periods.append(Period(name: name, start: s, end: e, days: n))
        }
        let today = DateUtils.startOfToday()
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        var best: (p: Period, left: Int, inProgress: Bool)? = nil
        for p in periods {
            guard let sd = fmt.date(from: p.start), let ed = fmt.date(from: p.end) else { continue }
            let s = DateUtils.startOfToday(sd), e = DateUtils.startOfToday(ed)
            let left = Int(round(s.timeIntervalSince(today) / 86400))
            let inProgress = today >= s && today <= e
            if inProgress { best = (p, 0, true); break }
            if left >= 0, best == nil || left < best!.left { best = (p, left, false) }
        }
        guard let b = best else { return nil }
        let range = shortRange(b.p.start, b.p.end)
        return HolidayCountdown(name: b.p.name, icon: holidayIcon(b.p.name), daysLeft: b.left,
                                inProgress: b.inProgress, rangeText: range,
                                holidayDays: b.p.days, source: "official")
    }

    private func shortRange(_ start: String, _ end: String) -> String {
        let f = DateFormatter(); f.dateFormat = "MM/dd"
        let sd = f.string(from: DateUtils.fromISO(start)), ed = f.string(from: DateUtils.fromISO(end))
        return sd == ed ? sd : "\(sd) - \(ed)"
    }

    private func holidayIcon(_ name: String) -> String {
        let map = ["元旦": "🎍", "春节": "🧧", "除夕": "🎊", "清明节": "🌿", "清明": "🌿",
                   "劳动节": "🛠️", "端午节": "🎋", "中秋": "🥮", "中秋节": "🥮",
                   "国庆节": "🇨🇳", "国庆": "🇨🇳"]
        return map[name] ?? "🎉"
    }

    /// 农历推算兜底：从农历节日表里找下一个
    private func estimated() -> HolidayCountdown {
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: Date())
        let table: [(String, Int, Int, Int, String)] = [
            ("元旦", 1, 1, 1, "🎍"), ("春节", 1, 1, 0, "🧧"), ("清明节", 4, 4, 1, "🌿"),
            ("劳动节", 5, 1, 1, "🛠️"), ("端午节", 5, 5, 0, "🎋"),
            ("中秋节", 8, 15, 0, "🥮"), ("国庆节", 10, 1, 1, "🇨🇳"),
        ]
        let today = DateUtils.startOfToday()
        var best: (String, Int, Int, String, Date)? = nil
        for y in [year, year + 1] {
            for (name, m, d, isLunar, icon) in table {
                guard let date = isLunar == 1
                        ? cal.date(from: DateComponents(year: y, month: m, day: d))
                        : LunarCalendar.solarFromLunar(year: y, month: m, day: d) else { continue }
                let s = DateUtils.startOfToday(date)
                let left = Int(round(s.timeIntervalSince(today) / 86400))
                if left < 0 { continue }
                if best == nil || left < best!.1 { best = (name, left, 3, icon, s) }
            }
        }
        guard let b = best else {
            return HolidayCountdown(name: "元旦", icon: "🎍", daysLeft: 0, inProgress: false,
                                    rangeText: "", holidayDays: 1, source: "estimated")
        }
        let f = DateFormatter(); f.dateFormat = "MM/dd"
        return HolidayCountdown(name: b.0, icon: b.3, daysLeft: b.1, inProgress: b.1 == 0,
                                rangeText: f.string(from: b.4), holidayDays: b.2, source: "estimated")
    }
}
