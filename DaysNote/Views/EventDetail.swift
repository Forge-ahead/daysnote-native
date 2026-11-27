import SwiftUI

struct EventDetail: View {
    @EnvironmentObject var store: Store
    let eventId: String
    let onBack: () -> Void
    let onEdit: () -> Void

    private var ev: EventItem? { store.events.first { $0.id == eventId } }

    var body: some View {
        ScrollView {
            if let ev = ev {
                VStack(alignment: .leading, spacing: 14) {
                    NavBar(title: "事件详情", back: onBack) {
                        Button(action: onEdit) { Text("编辑").font(.system(size: 14)) }
                    }
                    VStack(spacing: 8) {
                        Text(ev.icon).font(.system(size: 54))
                        Text(ev.title).font(.system(size: 24, weight: .bold))
                        Text(DateUtils.formatCN(ev.date)).font(.system(size: 13)).foregroundColor(Theme.muted)
                        if ev.lunar { Text("农历 " + LunarCalendar.lunarText(ev.date)).font(.system(size: 12)).foregroundColor(Theme.muted) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(hex: ev.color)).clipShape(RoundedRectangle(cornerRadius: 18))

                    HStack(spacing: 12) {
                        countCard("倒数", DateUtils.homeCounts(ev).countdown, "DAYS")
                        countCard("正数", DateUtils.homeCounts(ev).countup, "DAYS")
                    }

                    CardPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            infoRow("分类", store.categories.first { $0.id == ev.categoryId }?.name ?? "未分类")
                            infoRow("显示", DateUtils.inferMode(ev) == .both ? "正数 + 倒数" :
                                    (DateUtils.inferMode(ev) == .countdown ? "倒数" : "正数"))
                            infoRow("重复", ev.repeatMode == .yearly ? "每年" : "不重复")
                            infoRow("时间轴", ev.showInTimeline == false ? "否" : "是")
                            if !ev.note.isEmpty { infoRow("备注", ev.note) }
                        }
                    }

                    Button(action: { store.removeEvent(ev.id); onBack() }) {
                        Text("删除事件").font(.system(size: 15)).foregroundColor(Theme.accent)
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 14).padding(.bottom, 30)
            }
        }
    }

    @ViewBuilder
    private func countCard(_ title: String, _ days: Int?, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 12)).foregroundColor(Theme.muted)
            Text(days.map { DateUtils.formatDays($0) } ?? "—").font(.system(size: 28, weight: .bold))
            Text(days.map { $0 > 365 ? "YEARS" : unit } ?? "").font(.system(size: 9)).opacity(0.6)
        }
        .frame(maxWidth: .infinity).padding(14)
        .background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(.system(size: 13)).foregroundColor(Theme.muted).frame(width: 60, alignment: .leading)
            Text(v).font(.system(size: 14))
            Spacer()
        }
    }
}
