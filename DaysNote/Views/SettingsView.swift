import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0
    @State private var confirm: String? = nil
    @State private var aiText = ""
    @State private var aiLog: [(role: String, text: String)] = []
    @State private var aiBusy = false
    @State private var importing = false

    private let tabs = ["外观", "同步", "AI 助手", "数据"]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("🌿").font(.system(size: 44))
                Text("纪念日").font(.system(size: 20, weight: .bold))
                Text("手绘风 · 多端同步 · AI 管理").font(.system(size: 11)).foregroundColor(Theme.muted)

                Picker("", selection: $tab) {
                    ForEach(0..<tabs.count, id: \.self) { Text(tabs[$0]).tag($0) }
                }.pickerStyle(.segmented)

                switch tab {
                case 0: appearanceTab
                case 1: syncTab
                case 2: aiTab
                default: dataTab
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 30)
        }
    }

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "显示模式")
            CardPanel {
                Picker("", selection: Binding(
                    get: { store.settings.themeMode },
                    set: { store.settings.themeMode = $0; store.save() }
                )) {
                    Text("白天").tag(ThemeMode.light)
                    Text("夜间").tag(ThemeMode.dark)
                    Text("自动").tag(ThemeMode.auto)
                }.pickerStyle(.segmented)
                Text("自动模式跟随系统深色/浅色设置。").font(.system(size: 11)).foregroundColor(Theme.muted)
            }
            SectionTitle(text: "背景样式")
            CardPanel {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(BackgroundStyle.allCases, id: \.self) { s in
                        Button(action: { store.settings.backgroundStyle = s; store.save() }) {
                            VStack(spacing: 6) {
                                Rectangle().fill(Theme.background(s)).frame(height: 34)
                                    .overlay(RoundedRectangle(cornerRadius: 8)
                                        .stroke(store.settings.backgroundStyle == s ? Color(hex: "#6f8a6a") : Theme.line, lineWidth: 1))
                                Text(labelFor(s)).font(.system(size: 13)).foregroundColor(Theme.ink)
                            }
                            .padding(8).background(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            SectionTitle(text: "关于")
            CardPanel {
                Text("版本 \(Constants.appVersion)（build \(Constants.build)）").font(.system(size: 13))
                Text("数据 schema \(Constants.schemaVersion) · 原生 iOS 版").font(.system(size: 11)).foregroundColor(Theme.muted)
            }
        }
    }

    private func labelFor(_ s: BackgroundStyle) -> String {
        switch s { case .grid: return "格纹"; case .beige: return "米色"; case .cream: return "暖白"; case .gray: return "浅灰" }
    }

    private var syncTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardPanel {
                RowSwitch(title: "iCloud 同步", subtitle: "同一 Apple ID 设备间 · 默认关闭", on: Binding(
                    get: { store.settings.icloudSync }, set: { store.settings.icloudSync = $0; store.save() }))
                RowSwitch(title: "自动同步", subtitle: "打开应用与增删改后自动同步", on: Binding(
                    get: { store.settings.autoSync }, set: { store.settings.autoSync = $0; store.save() }))
            }

            SectionTitle(text: "同步后端")
            CardPanel {
                ForEach(SyncBackend.allCases, id: \.self) { b in
                    RowSwitch(title: b == .couchdb ? "CouchDB" : "WebDAV", subtitle: nil, on: Binding(
                        get: { store.settings.enabledBackends.contains(b) },
                        set: { on in
                            if on { if !store.settings.enabledBackends.contains(b) { store.settings.enabledBackends.append(b) } }
                            else { store.settings.enabledBackends.removeAll { $0 == b } }
                            store.save()
                        }))
                    if store.settings.enabledBackends.contains(b) {
                        if b == .couchdb {
                            TextField("服务器地址 https://…", text: Binding(get: { store.settings.couchUrl }, set: { store.settings.couchUrl = $0; store.save() }))
                                .textFieldStyle(.roundedBorder).autocapitalization(.none).keyboardType(.URL)
                            TextField("数据库名", text: Binding(get: { store.settings.couchDb }, set: { store.settings.couchDb = $0; store.save() }))
                                .textFieldStyle(.roundedBorder)
                            TextField("用户名", text: Binding(get: { store.settings.couchUser }, set: { store.settings.couchUser = $0; store.save() }))
                                .textFieldStyle(.roundedBorder).autocapitalization(.none)
                            SecureField("密码", text: Binding(get: { store.settings.couchPassword }, set: { store.settings.couchPassword = $0; store.save() }))
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextField("WebDAV 文件 URL", text: Binding(get: { store.settings.webdavUrl }, set: { store.settings.webdavUrl = $0; store.save() }))
                                .textFieldStyle(.roundedBorder).autocapitalization(.none).keyboardType(.URL)
                            TextField("用户名", text: Binding(get: { store.settings.webdavUser }, set: { store.settings.webdavUser = $0; store.save() }))
                                .textFieldStyle(.roundedBorder).autocapitalization(.none)
                            SecureField("密码", text: Binding(get: { store.settings.webdavPassword }, set: { store.settings.webdavPassword = $0; store.save() }))
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    Divider()
                }
                PrimaryButton(title: "测试连接") { Task { await store.testConnection() } }
            }

            SectionTitle(text: "同步")
            CardPanel {
                Text("最近同步：\(store.lastSync)").font(.system(size: 13))
                Text(store.lastSyncDetail.isEmpty ? "尚未同步" : store.lastSyncDetail).font(.system(size: 11)).foregroundColor(Theme.muted)
                if let size = store.dbSize {
                    Text("云端库：\(formatBytes(size.active))（磁盘 \(formatBytes(size.disk))）· \(size.docCount) 篇 · 已删除 \(size.delCount)")
                        .font(.system(size: 11)).foregroundColor(Theme.muted)
                }
                Text("同步是双向的：云端有、手机没有的记录会拉下来；手机有、云端没有的会推上去。")
                    .font(.system(size: 11)).foregroundColor(Theme.muted)
                PrimaryButton(title: store.syncing ? "同步中…" : "立即同步", disabled: store.syncing) {
                    Task { await store.doSync() }
                }
            }

            SectionTitle(text: "强制单向覆盖")
            CardPanel {
                HStack(spacing: 8) {
                    PrimaryButton(title: "本地覆盖服务器") { confirm = "push" }
                    PrimaryButton(title: "服务器覆盖本地") { confirm = "pull" }
                }
                Text("普通同步是双向合并。以上操作会彻底重置某一端，不可撤销。")
                    .font(.system(size: 11)).foregroundColor(Theme.muted)
            }

            if let c = confirm { riskDialog(c) }

            if !store.conflicts.isEmpty {
                SectionTitle(text: "同步冲突 · \(store.conflicts.count)")
                CardPanel {
                    ForEach(store.conflicts) { c in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(c.title).font(.system(size: 14, weight: .semibold))
                            Text("本地时间 \(c.localTime) · 云端时间 \(c.remoteTime)").font(.system(size: 11)).foregroundColor(Theme.muted)
                            HStack(spacing: 8) {
                                PrimaryButton(title: "用本地版本") { Task { await store.resolveConflict(id: c.id, choice: "local") } }
                                PrimaryButton(title: "用云端版本") { Task { await store.resolveConflict(id: c.id, choice: "remote") } }
                            }
                        }.padding(.vertical, 6)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func riskDialog(_ kind: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind == "push" ? "本地覆盖服务器" : "服务器覆盖本地")
                .font(.system(size: 16, weight: .bold))
            Text(kind == "push"
                 ? "会把手机上当前的全部事件和分类整体写入云端，云端多出来的记录会被删除。其他设备下次同步后会变成手机上这份数据；如果云端有你手机上没同步下来的旧记录，那些记录会消失。此操作不可撤销，也不会进回收站。"
                 : "会把云端的全部事件和分类整体写回手机，手机上多出来的记录会被移除。手机上没同步到云端的修改会消失。此操作不可撤销，也不会进回收站。")
                .font(.system(size: 12)).foregroundColor(Theme.accent)
            HStack(spacing: 8) {
                PrimaryButton(title: "取消") { confirm = nil }
                PrimaryButton(title: "确认覆盖", danger: true) {
                    let k = confirm; confirm = nil
                    Task { if k == "push" { await store.pushAllToRemote() } else { await store.pullAllFromRemote() } }
                }
            }
        }
        .padding(14).background(Color(hex: "#faece8")).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var aiTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardPanel {
                TextField("API 地址", text: Binding(get: { store.settings.aiBaseUrl }, set: { store.settings.aiBaseUrl = $0; store.save() }))
                    .textFieldStyle(.roundedBorder).autocapitalization(.none).keyboardType(.URL)
                SecureField("API Key", text: Binding(get: { store.settings.aiKey }, set: { store.settings.aiKey = $0; store.save() }))
                    .textFieldStyle(.roundedBorder)
                TextField("模型", text: Binding(get: { store.settings.aiModel }, set: { store.settings.aiModel = $0; store.save() }))
                    .textFieldStyle(.roundedBorder)
            }
            ScrollView {
                ForEach(aiLog.indices, id: \.self) { i in
                    HStack {
                        if aiLog[i].role == "ai" { Spacer() }
                        Text(aiLog[i].text).font(.system(size: 13)).padding(10)
                            .background(aiLog[i].role == "user" ? Color(hex: "#eef0e6") : Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        if aiLog[i].role == "user" { Spacer() }
                    }
                }
            }.frame(height: 220)
            HStack {
                TextField("说一句话管理事件，例如：新增生日 1993-09-14", text: $aiText)
                    .textFieldStyle(.roundedBorder)
                Button(aiBusy ? "…" : "发送") {
                    let q = aiText; guard !q.isEmpty, !aiBusy else { return }
                    aiText = ""; aiLog.append((role: "user", text: q)); aiBusy = true
                    Task {
                        do {
                            let ans = try await AIService.shared.ask(q, settings: store.settings, store: store)
                            aiLog.append((role: "ai", text: ans))
                        } catch { aiLog.append((role: "ai", text: error.localizedDescription)) }
                        aiBusy = false
                    }
                }.disabled(aiBusy)
            }
        }
    }

    private var dataTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "备份与恢复")
            CardPanel {
                RowSwitch(title: "每月自动备份", subtitle: nil, on: Binding(
                    get: { store.settings.autoBackup }, set: { store.settings.autoBackup = $0; store.save() }))
                TextField("备份文件夹（WebDAV URL，可选）", text: Binding(get: { store.settings.backupFolder }, set: { store.settings.backupFolder = $0; store.save() }))
                    .textFieldStyle(.roundedBorder).autocapitalization(.none)
                PrimaryButton(title: "导出完整备份（含配置）") {
                    let url = store.exportJSON()
                    store.show("已导出到：\(url.lastPathComponent)")
                }
                PrimaryButton(title: "从备份导入") { importing = true }
            }
            SectionTitle(text: "组件")
            CardPanel {
                Text("在系统桌面长按 → 编辑主屏幕 → 添加小组件，选择「纪念日」即可。组件数据随事件增删改自动更新。")
                    .font(.system(size: 12)).foregroundColor(Theme.muted)
            }
        }
        .sheet(isPresented: $importing) {
            DocumentPicker { url in store.importJSON(url) }
        }
    }

    private func formatBytes(_ n: Int64) -> String {
        guard n > 0 else { return "0 B" }
        let units = ["B", "KB", "MB", "GB"]
        let i = min(units.count - 1, Int(log(Double(n)) / log(1024)))
        let v = Double(n) / pow(1024, Double(i))
        return "\(v >= 100 || i == 0 ? Int(v) : String(format: "%.1f", v)) \(units[i])"
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ pc: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let u = urls.first { onPick(u) }
        }
    }
}
