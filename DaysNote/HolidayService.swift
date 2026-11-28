import Foundation

/// 放假区间：数据来源 holiday-cn（国务院放假安排），失败时用农历推算兜底。
/// 每个节日都是「start ~ end」的完整区间，保证组件能显示「休 1/1-1/3」。
struct HolidayPeriod: Codable, Equatable {
    var name: String
    var start: String   // yyyy-MM-dd
    var end: String     // yyyy-MM-dd
    var days: Int
    var source: String  // official / estimated
}

/// 假日数据：每月联网获取一次，失败用缓存 / 农历推算兜底
@MainActor
class HolidayService {
    static let shared = HolidayService()
    private func dataURL(_ year: Int) -> String { "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json" }
    private let cacheKeyMonth = "holiday.month"
    private let cacheKeyPeriods = "holiday.periods.v2"

    // MARK: - 缓存

    private func readPeriods() -> [HolidayPeriod]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKeyPeriods),
              let list = try? JSONDecoder().decode([HolidayPeriod].self, from: data), !list.isEmpty else { return nil }
        return list
    }

    private func savePeriods(_ list: [HolidayPeriod]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: cacheKeyPeriods)
    }

    /// 兼容旧缓存：优先用新区间缓存算出倒计时，否则退回旧的 HolidayCountdown 文件
    func loadCache() -> HolidayCountdown? {
        if let periods = readPeriods(), let h = Self.nextHoliday(periods) { return h }
        return Persistence.load(HolidayCountdown.self, from: Persistence.holidayURL)
    }

    func refreshIfNeeded(force: Bool = false) async -> HolidayCountdown? {
        let fm = DateFormatter(); fm.dateFormat = "yyyy-MM"
        let month = fm.string(from: Date())
        let cachedMonth = UserDefaults.standard.string(forKey: cacheKeyMonth) ?? ""

        if !force, cachedMonth == month, let periods = readPeriods(), let h = Self.nextHoliday(periods) {
            return h
        }

        var periods = await fetchOfficialPeriods()
        if periods.isEmpty { periods = readPeriods() ?? [] }
        if periods.isEmpty { periods = estimatedPeriods() }

        // 下一年官方安排可能尚未发布，用推算补齐（按 name+start 去重）
        let nextYear = Calendar(identifier: .gregorian).component(.year, from: Date()) + 1
        for p in estimatedPeriods(for: nextYear) {
            if !periods.contains(where: { $0.name == p.name && $0.start == p.start }) { periods.append(p) }
        }
        periods.sort { $0.start < $1.start }

        savePeriods(periods)
        UserDefaults.standard.set(month, forKey: cacheKeyMonth)

        let best = Self.nextHoliday(periods)
        if let best = best { Persistence.save(best, to: Persistence.holidayURL) }
        return best
    }

    // MARK: - 官方数据

    /// 同时抓取当年与次年：临近年底时，下一个假期（元旦）在次年 JSON 里
    private func fetchOfficialPeriods() async -> [HolidayPeriod] {
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: Date())
        var out: [HolidayPeriod] = []
        for y in [year, year + 1] {
            guard let url = URL(string: dataURL(y)),
                  let r = try? await Net.request(url), r.ok,
                  let root = (try? JSONSerialization.jsonObject(with: r.data)) as? [String: Any],
                  let days = root["days"] as? [[String: Any]] else { continue }

            var groups: [String: [String]] = [:]
            for d in days {
                guard let date = d["date"] as? String, let name = d["name"] as? String,
                      d["isOffDay"] as? Bool == true else { continue }
                groups[name, default: []].append(date)
            }
            for (name, dates) in groups {
                let sorted = Array(Set(dates)).sorted()
                guard let s = sorted.first, let e = sorted.last else { continue }
                out.append(HolidayPeriod(name: name, start: s, end: e,
                                         days: sorted.count, source: "official"))
            }
        }
        return out
    }

    // MARK: - 农历推算兜底（完整区间）

    /// 国务院未公布时的常见放假区间：元旦 3 天、春节 9 天、清明 3 天、劳动 5 天、
    /// 端午 3 天、中秋 3 天、国庆 7 天。
    private func estimatedPeriods(for year: Int? = nil) -> [HolidayPeriod] {
        let cal = Calendar(identifier: .gregorian)
        let y = year ?? cal.component(.year, from: Date())

        func iso(_ y: Int, _ m: Int, _ d: Int) -> String {
            let dt = cal.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
            return DateUtils.toISO(dt)
        }
        func shifted(_ base: String, _ delta: Int) -> String {
            guard let dt = cal.date(byAdding: .day, value: delta, to: DateUtils.fromISO(base)) else { return base }
            return DateUtils.toISO(dt)
        }
        func days(_ start: String, _ end: String) -> Int {
            let s = DateUtils.fromISO(start), e = DateUtils.fromISO(end)
            return max(1, Int(round(e.timeIntervalSince(s) / 86400)) + 1)
        }
        func solar(_ lm: Int, _ ld: Int) -> String {
            guard let d = LunarCalendar.solarFromLunar(year: y, month: lm, day: ld) else { return iso(y, 1, 1) }
            return DateUtils.toISO(d)
        }

        let spring = solar(1, 1)        // 春节正月初一
        let dragon = solar(5, 5)        // 端午
        let midAutumn = solar(8, 15)    // 中秋
        let raw: [(String, String, String)] = [
            ("元旦", iso(y, 1, 1), iso(y, 1, 3)),
            ("春节", shifted(spring, -1), shifted(spring, 7)),
            ("清明节", iso(y, 4, 4), iso(y, 4, 6)),
            ("劳动节", iso(y, 5, 1), iso(y, 5, 5)),
            ("端午节", dragon, shifted(dragon, 2)),
            ("中秋节", midAutumn, shifted(midAutumn, 2)),
            ("国庆节", iso(y, 10, 1), iso(y, 10, 7)),
        ]
        return raw.map { HolidayPeriod(name: $0.0, start: $0.1, end: $0.2,
                                       days: days($0.1, $0.2), source: "estimated") }
    }

    // MARK: - 选取下一个假期并格式化

    static func nextHoliday(_ periods: [HolidayPeriod], now: Date = Date()) -> HolidayCountdown? {
        let today = DateUtils.toISO(DateUtils.startOfToday(now))
        let upcoming = periods.filter { $0.end >= today }.sorted { $0.start < $1.start }
        guard let p = upcoming.first else { return nil }
        let inProgress = p.start <= today
        let left = inProgress ? 0 : Int(round(DateUtils.fromISO(p.start).timeIntervalSince(DateUtils.fromISO(today)) / 86400))
        return HolidayCountdown(name: p.name,
                                icon: holidayIcon(p.name),
                                daysLeft: left,
                                inProgress: inProgress,
                                rangeText: shortRange(p.start, p.end),
                                holidayDays: p.days,
                                source: p.source)
    }

    /// 1/1-1/3 形式（跨年时带年份，避免 12/30-1/1 看不出范围）
    private static func shortRange(_ start: String, _ end: String) -> String {
        let sp = start.split(separator: "-").compactMap { Int($0) }
        let ep = end.split(separator: "-").compactMap { Int($0) }
        guard sp.count >= 3, ep.count >= 3 else { return start == end ? fmt(start) : "\(start)-\(end)" }
        let sameYear = sp[0] == ep[0]
        let s = sameYear ? "\(sp[1])/\(sp[2])" : "\(sp[0])/\(sp[1])/\(sp[2])"
        let e = sameYear ? "\(ep[1])/\(ep[2])" : "\(ep[0])/\(ep[1])/\(ep[2])"
        return s == e ? s : "\(s)-\(e)"
    }

    private static func fmt(_ iso: String) -> String {
        let p = iso.split(separator: "-")
        return p.count >= 3 ? "\(p[p.count - 2])/\(p[p.count - 1])" : iso
    }

    private static func holidayIcon(_ name: String) -> String {
        let map = ["元旦": "🎍", "春节": "🧧", "除夕": "🎊", "清明节": "🌿", "清明": "🌿",
                   "劳动节": "🛠️", "端午节": "🎋", "中秋": "🥮", "中秋节": "🥮",
                   "国庆节": "🇨🇳", "国庆": "🇨🇳"]
        return map[name] ?? "🎉"
    }
}
