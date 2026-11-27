import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @Binding var catId: String
    let onMenu: () -> Void
    let onAdd: () -> Void
    let onCategoryGrid: () -> Void
    let onSelect: (EventItem) -> Void

    @State private var foldFuture = false
    @State private var foldPast = false

    private var cat: Category? { store.categories.first { $0.id == catId } ?? store.categories.first }
    private var filtered: [EventItem] { catId == "cat:all" ? store.events : store.events.filter { $0.categoryId == catId } }

    private var future: [(EventItem, Int)] {
        filtered.compactMap { ev in DateUtils.homeCounts(ev).countdown.map { (ev, $0) } }
            .sorted { $0.1 < $1.1 }
    }
    private var past: [(EventItem, Int)] {
        filtered.compactMap { ev in DateUtils.homeCounts(ev).countup.map { (ev, $0) } }
            .sorted { $0.1 < $1.1 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(action: onMenu) { Image(systemName: "line.3.horizontal").font(.system(size: 20)) }
                        .frame(width: 34, height: 34)
                    Spacer()
                    Button(action: onCategoryGrid) {
                        HStack(spacing: 4) {
                            Text(cat?.name ?? "纪念日").font(.system(size: 16, weight: .semibold))
                            Image(systemName: "chevron.down").font(.system(size: 12))
                        }
                    }
                    Spacer()
                    Button(action: onAdd) { Image(systemName: "plus").font(.system(size: 18, weight: .semibold)) }
                        .frame(width: 34, height: 34)
                }
                .padding(.horizontal, 4)

                // 今年剩余：动态 hero，跨年自动切换
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DateUtils.formatDays(DateUtils.yearRemaining())).font(.system(size: 42, weight: .bold))
                        Text("DAYS").font(.system(size: 10, weight: .semibold)).opacity(0.7)
                    }
                    .frame(width: 88)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今年剩余").font(.system(size: 18, weight: .semibold))
                        Text(DateUtils.formatCN("\(Calendar(identifier: .gregorian).component(.year, from: Date()))-12-31"))
                            .font(.system(size: 11)).opacity(0.75)
                    }
                    Spacer()
                    Text("🎆").font(.system(size: 34))
                }
                .padding(18)
                .background(Color(hex: "#f3b8c2"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .foregroundColor(Theme.ink)

                group("倒数 · \(future.count)", items: future, folded: $foldFuture)
                group("正数 · \(past.count)", items: past, folded: $foldPast)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func group(_ title: String, items: [(EventItem, Int)], folded: Binding<Bool>) -> some View {
        SectionTitle(text: title)
        HStack {
            Spacer()
            Button(action: { folded.wrappedValue.toggle() }) {
                Image(systemName: folded.wrappedValue ? "chevron.down" : "chevron.up").font(.system(size: 16))
            }
        }
        if !folded.wrappedValue {
            ForEach(items, id: \.0.id) { ev, days in eventRow(ev, days: days) }
        }
    }

    @ViewBuilder
    private func eventRow(_ ev: EventItem, days: Int) -> some View {
        Button(action: { onSelect(ev) }) {
            HStack(spacing: 12) {
                Text(ev.icon).font(.system(size: 26)).frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ev.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Text(DateUtils.formatCN(ev.date)).font(.system(size: 11)).foregroundColor(Theme.muted).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(days > 365 ? "YEARS" : "DAYS").font(.system(size: 9, weight: .semibold)).opacity(0.6)
                    Text(DateUtils.formatDays(days)).font(.system(size: 26, weight: .bold))
                }
            }
            .padding(14)
            .background(Color(hex: ev.color))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .foregroundColor(Theme.ink)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(ev.note.isEmpty ? "暂无备注" : ev.note) { }.disabled(ev.note.isEmpty)
        }
    }
}
