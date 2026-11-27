import SwiftUI

struct TrashView: View {
    @EnvironmentObject var store: Store
    let onBack: () -> Void
    @State private var localSel: [String] = []
    @State private var remoteSel: [String] = []
    @State private var expanded: String? = nil
    @State private var confirmPurge: String? = nil

    private var expiredIds: [String] {
        store.remoteTrash.filter { item in
            guard let at = (item["deletedAt"] as? NSNumber)?.int64Value else { return false }
            return Date().timeIntervalSince1970 - Double(at) / 1000 > Constants.trashTTL
        }.compactMap { $0["id"] as? String }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                NavBar(title: "回收站", back: onBack) {
                    Button(action: { Task { await store.refreshRemoteTrash() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                Text("删除的事件会先放进这里，随时可以恢复。云端删除标记保留 6 个月；超过期限可永久清除（不可恢复）。")
                    .font(.system(size: 12)).foregroundColor(Theme.muted).padding(.horizontal, 4)

                // 本机已删除
                SectionTitle(text: "本机已删除 · \(store.trash.count)")
                if store.trash.isEmpty {
                    emptyText("本机没有可恢复的事件")
                } else {
                    CardPanel {
                        ForEach(store.trash) { item in
                            Button(action: { toggle(&localSel, item.id) }) {
                                HStack(spacing: 10) {
                                    checkMark(localSel.contains(item.id))
                                    Text(item.icon ?? "📌").font(.system(size: 18))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title).font(.system(size: 14, weight: .medium))
                                        Text("\(item.date.map { DateUtils.formatCN($0) } ?? "—") · \(deletedTime(item.deletedAt))")
                                            .font(.system(size: 11)).foregroundColor(Theme.muted)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider()
                        }
                        HStack(spacing: 8) {
                            PrimaryButton(title: "恢复选中（\(localSel.count)）", disabled: localSel.isEmpty) {
                                Task {
                                    let n = await store.restoreTrash(ids: localSel)
                                    localSel = []; store.show("已恢复 \(n) 条事件")
                                }
                            }
                            PrimaryButton(title: "彻底删除", danger: true, disabled: localSel.isEmpty) {
                                store.purgeLocalTrash(ids: localSel); localSel = []; store.show("已从回收站彻底移除")
                            }
                        }
                    }
                }

                // 云端已删除
                SectionTitle(text: "云端已删除 · \(store.loadingRemoteTrash ? "读取中…" : String(store.remoteTrash.count))")
                if store.remoteTrash.isEmpty && !store.loadingRemoteTrash {
                    emptyText("云端没有已删除的记录（未配置 CouchDB 时为空）")
                } else {
                    CardPanel {
                        ForEach(store.remoteTrash, id: \.self) { item in
                            let id = (item["id"] as? String) ?? ""
                            let detail = store.remoteDetails[id]
                            let open = expanded == id
                            let expired = expiredIds.contains(id)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 9) {
                                    Button(action: { toggle(&remoteSel, id) }) { checkMark(remoteSel.contains(id)) }
                                    Button(action: {
                                        expanded = open ? nil : id
                                        if !open { Task { await store.detailFor(id) } }
                                    }) {
                                        HStack(spacing: 9) {
                                            Text(detail?["icon"] as? String ?? "☁️").font(.system(size: 18))
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(detail?["title"] as? String ?? "云端记录").font(.system(size: 14, weight: .medium))
                                                Text(deletedTime((item["deletedAt"] as? NSNumber)?.int64Value) + (expired ? " · 已超过 6 个月" : ""))
                                                    .font(.system(size: 11)).foregroundColor(Theme.muted)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0)).font(.system(size: 14))
                                        }.contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                }
                                if open {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if let d = detail {
                                            if let err = d["error"] as? String {
                                                Text("⚠️ \(err)").font(.system(size: 12)).foregroundColor(Theme.muted)
                                            } else {
                                                detailGrid(d, id: id)
                                                HStack(spacing: 8) {
                                                    PrimaryButton(title: "恢复此条") {
                                                        Task {
                                                            let r = await store.restoreRemote(ids: [id])
                                                            store.show("已恢复 \(r.restored) 条")
                                                        }
                                                    }
                                                    PrimaryButton(title: "永久清除", danger: true) { confirmPurge = id }
                                                }
                                            }
                                        } else {
                                            Text("正在从云端旧版本读取事件内容…").font(.system(size: 12)).foregroundColor(Theme.muted)
                                        }
                                        if confirmPurge == id { confirmBar(ids: [id]) }
                                    }
                                    .padding(10).background(Color(uiColor: .tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.leading, 30)
                                }
                            }
                            Divider()
                        }
                        HStack(spacing: 8) {
                            PrimaryButton(title: "恢复选中（\(remoteSel.count)）", disabled: remoteSel.isEmpty) {
                                Task {
                                    let r = await store.restoreRemote(ids: remoteSel)
                                    remoteSel = []
                                    store.show("已恢复 \(r.restored) 条")
                                }
                            }
                            PrimaryButton(title: "永久清除选中（\(remoteSel.count)）", danger: true, disabled: remoteSel.isEmpty) {
                                confirmPurge = "selected"
                            }
                        }
                        if !expiredIds.isEmpty {
                            HStack {
                                Text("有 \(expiredIds.count) 条云端记录已超过 6 个月保留期")
                                    .font(.system(size: 12)).foregroundColor(Theme.accent)
                                Spacer()
                                Button("清理过期项") { confirmPurge = "expired" }
                                    .font(.system(size: 12)).foregroundColor(Theme.accent)
                            }
                            .padding(10).background(Color(hex: "#faece8")).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        if confirmPurge == "selected" { confirmBar(ids: remoteSel) }
                        if confirmPurge == "expired" { confirmBar(ids: expiredIds) }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 30)
        }
        .onAppear { Task { await store.refreshRemoteTrash() } }
    }

    private func toggle(_ sel: inout [String], _ id: String) {
        if sel.contains(id) { sel.removeAll { $0 == id } } else { sel.append(id) }
    }
    @ViewBuilder private func checkMark(_ on: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).stroke(on ? Theme.accent : Color(hex: "#d5cfc4"), lineWidth: 1.5)
                .frame(width: 20, height: 20)
            if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white) }
        }.background(on ? Theme.accent : Color.clear).clipShape(RoundedRectangle(cornerRadius: 7))
    }
    @ViewBuilder private func emptyText(_ t: String) -> some View {
        Text(t).font(.system(size: 13)).foregroundColor(Theme.muted).frame(maxWidth: .infinity)
            .padding(22).background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private func deletedTime(_ at: Int64?) -> String {
        guard let at = at else { return "删除时间未知（旧版未记录）" }
        let d = Date(timeIntervalSince1970: Double(at) / 1000)
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: d)
    }
    @ViewBuilder private func detailGrid(_ d: [String: Any], id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow("标题", d["title"] as? String ?? "（无标题）")
            detailRow("日期", d["date"].map { DateUtils.formatCN($0 as? String ?? "") } ?? "—")
            detailRow("备注", d["note"] as? String ?? "—")
            detailRow("文档 ID", id)
        }
    }
    @ViewBuilder private func detailRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(.system(size: 11)).foregroundColor(Theme.muted).frame(width: 56, alignment: .leading)
            Text(v).font(.system(size: 12)).lineLimit(2)
            Spacer()
        }
    }
    @ViewBuilder private func confirmBar(ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("将永久清除 \(ids.count) 条云端记录，无法恢复。").font(.system(size: 12))
            HStack(spacing: 8) {
                PrimaryButton(title: "确认清除", danger: true) {
                    Task {
                        let r = await store.purgeRemote(ids: ids)
                        confirmPurge = nil
                        store.show(r.error ?? "已永久清除 \(r.purged) 条（不可恢复）")
                    }
                }
                PrimaryButton(title: "取消") { confirmPurge = nil }
            }
        }
        .padding(10).background(Color(hex: "#faece8")).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
