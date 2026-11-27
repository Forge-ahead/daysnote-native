import SwiftUI

struct Drawer: View {
    @EnvironmentObject var store: Store
    @Binding var open: Bool
    @Binding var currentCat: String
    let onPickCategory: (String) -> Void
    let onOpenTrash: () -> Void
    let onSelectEvent: (EventItem) -> Void

    @State private var query = ""

    private var results: [EventItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return store.events.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.note.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if open {
                Color.black.opacity(0.28).ignoresSafeArea()
                    .onTapGesture { open = false }
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("分类与搜索").font(.system(size: 17, weight: .bold))
                            Spacer()
                            Button(action: { open = false }) { Image(systemName: "xmark").font(.system(size: 18)) }
                        }
                        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 12)

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundColor(Theme.muted)
                            TextField("搜索事件名称、备注或日期", text: $query)
                                .textFieldStyle(.plain)
                            if !query.isEmpty {
                                Button(action: { query = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(Theme.muted) }
                            }
                        }
                        .padding(10).background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 16)

                        if !query.isEmpty {
                            SectionTitle(text: "搜索结果 · \(results.count)")
                            ScrollView {
                                ForEach(results) { ev in
                                    Button(action: { onSelectEvent(ev) }) {
                                        HStack(spacing: 11) {
                                            Text(ev.icon).font(.system(size: 20)).frame(width: 24)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(ev.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                                Text(ev.date).font(.system(size: 11)).foregroundColor(Theme.muted)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Theme.muted)
                                        }
                                        .frame(minHeight: 50).padding(.horizontal, 10)
                                    }
                                }
                                .padding(.horizontal, 10)
                            }
                        } else {
                            SectionTitle(text: "全部分类")
                            ScrollView {
                                VStack(spacing: 2) {
                                    ForEach(store.categories) { c in
                                        Button(action: { onPickCategory(c.id) }) {
                                            HStack(spacing: 11) {
                                                RoundedRectangle(cornerRadius: 7).fill(Color(hex: c.color))
                                                    .frame(width: 20, height: 20)
                                                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                                Text(c.name).font(.system(size: 15)).foregroundColor(Theme.ink).lineLimit(1)
                                                Spacer()
                                                Text("\(store.events.filter { c.id == "cat:all" || $0.categoryId == c.id }.count)")
                                                    .font(.system(size: 13)).foregroundColor(Theme.muted).frame(minWidth: 24, alignment: .trailing)
                                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Theme.muted)
                                            }
                                            .frame(minHeight: 50).padding(.horizontal, 10).padding(.vertical, 8)
                                            .background(currentCat == c.id ? Color(uiColor: .secondarySystemBackground) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 10)
                            }
                        }

                        Spacer()

                        // 回收站：独立底部分区
                        VStack(spacing: 0) {
                            Divider()
                            Button(action: onOpenTrash) {
                                HStack(spacing: 11) {
                                    Image(systemName: "trash").font(.system(size: 16))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("回收站").font(.system(size: 14, weight: .semibold))
                                        Text("已删除的事件可恢复").font(.system(size: 11)).foregroundColor(Theme.muted)
                                    }
                                    Spacer()
                                    if !store.trash.isEmpty {
                                        Text("\(store.trash.count)").font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white).frame(minWidth: 22, minHeight: 22)
                                            .background(Theme.accent).clipShape(Capsule())
                                    }
                                }
                                .padding(10).background(Color(uiColor: .tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .foregroundColor(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 56)
                        }
                    }
                    .frame(width: min(UIScreen.main.bounds.width * 0.82, 340))
                    .background(Theme.paper)
                    Spacer()
                }
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeOut(duration: 0.22), value: open)
    }
}
