import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var store: Store
    let onSelect: (EventItem) -> Void
    let onAdd: () -> Void

    @State private var yearOffset = 0
    @State private var showFestivals = true

    private var year: Int { Calendar(identifier: .gregorian).component(.year, from: Date()) + yearOffset }

    private var rows: [TimelineRow] {
        var out: [TimelineRow] = []
        if store.settings.showFestivals {
            for f in Festivals.forYear(year) {
                out.append(TimelineRow(date: f.date, icon: f.icon, title: f.name, subtitle: f.kind == "lunar" ? "农历" : "节日", color: "#eef0e6", festival: true))
            }
        }
        for ev in store.events where ev.showInTimeline != false {
            let target = targetFor(ev)
            out.append(TimelineRow(date: target, icon: ev.icon, title: ev.title,
                                   subtitle: DateUtils.lunarText(ev.date), color: ev.color, festival: false, event: ev))
        }
        return out.sorted { $0.date < $1.date }
    }

    private func targetFor(_ ev: EventItem) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let base = DateUtils.fromISO(ev.date)
        if ev.lunar, let d = LunarCalendar.solarFromLunar(year: year, month: LunarCalendar.lunarParts(base).month,
                                                          day: LunarCalendar.lunarParts(base).day,
                                                          leap: LunarCalendar.lunarParts(base).leap) { return d }
        return cal.date(from: DateComponents(year: year, month: cal.component(.month, from: base), day: cal.component(.day, from: base))) ?? base
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 16) {
                        Button(action: { yearOffset -= 1 }) { Image(systemName: "chevron.left") }
                        Text("\(year) 年").font(.system(size: 18, weight: .semibold))
                        Button(action: { yearOffset += 1 }) { Image(systemName: "chevron.right") }
                        Spacer()
                    }
                    .padding(.horizontal, 6).padding(.bottom, 12)

                    ForEach(rows, id: \.self) { row in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Text(DateFormatter().shortMonthSymbols[Calendar(identifier: .gregorian).component(.month, from: row.date) - 1])
                                    .font(.system(size: 10)).foregroundColor(Theme.muted)
                                Text("\(Calendar(identifier: .gregorian).component(.day, from: row.date))")
                                    .font(.system(size: 20, weight: .bold))
                                Spacer()
                            }
                            .frame(width: 38)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(row.icon).font(.system(size: 16))
                                    Text(row.title).font(.system(size: 15, weight: .semibold))
                                }
                                Text(row.subtitle).font(.system(size: 11)).foregroundColor(Theme.muted)
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: row.color))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                            .onTapGesture { if let ev = row.event { onSelect(ev) } }
                        }
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 90)
            }

            Button(action: onAdd) {
                Image(systemName: "plus").font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white).frame(width: 50, height: 50)
                    .background(Color(hex: "#6f8a6a")).clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.trailing, 20).padding(.bottom, 96)
        }
    }
}

struct TimelineRow: Hashable {
    let date: Date
    let icon: String
    let title: String
    let subtitle: String
    let color: String
    var festival: Bool = false
    var event: EventItem? = nil

    static func == (a: Self, b: Self) -> Bool { a.date == b.date && a.title == b.title && a.event?.id == b.event?.id }
    func hash(into h: inout Hasher) { h.combine(date); h.combine(title); h.combine(event?.id ?? "") }
}
