import Foundation
import SwiftUI

// MARK: - 持久化（JSON 文件放 App Group 容器，供 Widget 与 App 共用）

struct PersistedData: Codable {
    var schema: Int
    var appVersion: String
    var savedAt: Int64
    var categories: [Category]
    var events: [EventItem]
    var settings: AppSettings
    var widgetBindings: [String: WidgetBinding]
    enum CodingKeys: String, CodingKey {
        case schema = "_schema", appVersion = "_appVersion", savedAt = "_savedAt"
        case categories, events, settings, widgetBindings
    }
}

enum Persistence {
    static let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroup)
    static var dataURL: URL {
        (groupURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
            .appendingPathComponent("daysnote-data.json")
    }
    static var syncBaseURL: URL {
        (groupURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
            .appendingPathComponent("daysnote-syncbase.json")
    }
    static var tombURL: URL {
        (groupURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
            .appendingPathComponent("daysnote-tombstones.json")
    }
    static var trashURL: URL {
        (groupURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
            .appendingPathComponent("daysnote-trash.json")
    }
    static var holidayURL: URL {
        (groupURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
            .appendingPathComponent("daysnote-holiday.json")
    }
    static var widgetURL: URL {
        (groupURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
            .appendingPathComponent("daysnote-widget.json")
    }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    static func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
    static func loadJSON(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return obj
    }
    static func saveJSON(_ obj: [String: Any], to url: URL) {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - 种子数据

enum Seed {
    static func categories() -> [Category] {
        let now = nowMs()
        return [
            Category(id: "cat:all", name: "全部", color: "#f3b8c2", order: 0, builtin: true, updatedAt: now),
            Category(id: "cat:misc", name: "杂事", color: Constants.categoryColors[1], order: 1, updatedAt: now),
            Category(id: "cat:anniv", name: "周年纪念", color: Constants.categoryColors[2], order: 2, updatedAt: now),
            Category(id: "cat:record", name: "事件记录", color: Constants.categoryColors[3], order: 3, updatedAt: now),
        ]
    }
    static func events() -> [EventItem] {
        [EventItem(id: "event:bi:together", title: "在一起", date: "2019-11-04", lunar: false,
                   categoryId: "cat:anniv", icon: "🍒", color: "#8ad0c5", note: "", order: 0,
                   repeatMode: .none, showInTimeline: true, displayMode: .countup,
                   createdAt: 1700000000000, updatedAt: 1700000000000)]
    }
    static func uid(_ prefix: String) -> String {
        "\(prefix):\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(7))"
    }
}

// MARK: - 全局 Store

@MainActor
class Store: ObservableObject {
    @Published var categories: [Category] = []
    @Published var events: [EventItem] = []
    @Published var settings: AppSettings = .default
    @Published var bindings: [String: WidgetBinding] = [:]
    @Published var trash: [TrashItem] = []
    @Published var remoteTrash: [[String: Any]] = []
    @Published var remoteDetails: [String: [String: Any]] = [:]
    @Published var loadingRemoteTrash = false
    @Published var conflicts: [ConflictItem] = []
    @Published var syncing = false
    @Published var lastSync = "尚未同步"
    @Published var lastSyncDetail = ""
    @Published var dbSize: (active: Int64, disk: Int64, docCount: Int64, delCount: Int64)? = nil
    @Published var holiday: HolidayCountdown? = nil
    @Published var toast: String? = nil

    var syncBase: SyncBase = [:]
    var tombstones: [String] = []
    private var engine: SyncEngine { SyncEngine(settings: settings) }

    init() {
        loadAll()
        HolidayService.shared.loadCache().map { self.holiday = $0 }
    }

    func loadAll() {
        if let data = Persistence.load(PersistedData.self, from: Persistence.dataURL) {
            categories = data.categories
            events = data.events
            settings = data.settings
            bindings = data.widgetBindings
        } else {
            categories = Seed.categories()
            events = Seed.events()
            save()
        }
        if let base = Persistence.loadJSON(Persistence.syncBaseURL) {
            syncBase = base.compactMapValues { v -> SyncBaseItem? in
                guard let d = v as? [String: Any], let h = d["hash"] as? String else { return nil }
                let t = (d["updatedAt"] as? NSNumber)?.int64Value ?? 0
                return SyncBaseItem(hash: h, updatedAt: t)
            }
        }
        tombstones = (Persistence.loadJSON(Persistence.tombURL)?["ids"] as? [String]) ?? []
        trash = Persistence.load([TrashItem].self, from: Persistence.trashURL) ?? []
        // 清理 v28 遗留的内置事件删除标记，但保留伪事件 yearleft
        let cleaned = tombstones.filter { !["event:bi:birthday", "event:bi:marriage", "event:bi:joinlianjia"].contains($0) }
        var final = cleaned
        if !final.contains("event:bi:yearleft") { final.append("event:bi:yearleft") }
        if final != tombstones { tombstones = final; saveTombstones() }
    }

    func save() {
        let data = PersistedData(schema: Constants.schemaVersion, appVersion: Constants.appVersion,
                                 savedAt: nowMs(), categories: categories, events: events,
                                 settings: settings, widgetBindings: bindings)
        Persistence.save(data, to: Persistence.dataURL)
        syncWidgetData()
    }
    func saveTombstones() { Persistence.saveJSON(["ids": tombstones], to: Persistence.tombURL) }
    func saveBase() {
        let obj: [String: Any] = syncBase.mapValues { ["hash": $0.hash, "updatedAt": $0.updatedAt] }
        Persistence.saveJSON(obj, to: Persistence.syncBaseURL)
    }
    func saveTrash() { Persistence.save(trash, to: Persistence.trashURL) }

    func show(_ text: String) { toast = text }

    // ---- CRUD ----
    func addEvent(_ input: EventItem) -> EventItem {
        var ev = input
        ev.id = Seed.uid("event"); ev.createdAt = nowMs(); ev.updatedAt = ev.createdAt
        if ev.displayMode == nil { ev.displayMode = ev.repeatMode == .yearly ? .countdown : .countup }
        events.append(ev); save(); autoSync()
        return ev
    }
    func updateEvent(_ id: String, patch: EventItem) {
        guard let i = events.firstIndex(where: { $0.id == id }) else { return }
        var ev = patch; ev.id = id; ev.createdAt = events[i].createdAt; ev.updatedAt = nowMs()
        events[i] = ev; save(); autoSync()
    }
    func removeEvent(_ id: String) {
        guard let ev = events.firstIndex(where: { $0.id == id }).map({ events[$0] }) else { return }
        let item = TrashItem(id: ev.id, kind: "event", title: ev.title, icon: ev.icon, date: ev.date,
                             color: ev.color, deletedAt: nowMs(), source: "local", payload: ev)
        trash.insert(item, at: 0); saveTrash()
        if !tombstones.contains(id) { tombstones.append(id); saveTombstones() }
        events.removeAll { $0.id == id }; save(); autoSync()
    }

    func addCategory(name: String, color: String? = nil) -> Category {
        let c = Category(id: Seed.uid("cat"), name: name,
                         color: color ?? Constants.categoryColors[Int.random(in: 0..<Constants.categoryColors.count)],
                         order: Int(nowMs()), updatedAt: nowMs())
        categories.append(c); save(); autoSync(); return c
    }
    func updateCategory(_ id: String, name: String, color: String) {
        guard let i = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[i].name = name; categories[i].color = color; categories[i].updatedAt = nowMs()
        save(); autoSync()
    }
    func removeCategory(_ id: String) {
        guard let c = categories.firstIndex(where: { $0.id == id }).map({ categories[$0] }) else { return }
        trash.insert(TrashItem(id: c.id, kind: "category", title: c.name, color: c.color,
                               deletedAt: nowMs(), source: "local", payload: nil), at: 0)
        saveTrash()
        if !tombstones.contains(id) { tombstones.append(id); saveTombstones() }
        categories.removeAll { $0.id == id }
        events.removeAll { $0.categoryId == id }
        save(); autoSync()
    }

    func updateSettings(_ patch: inout AppSettings) { settings = patch; save() }

    // ---- 回收站 ----
    func restoreTrash(ids: [String]) async -> Int {
        var n = 0
        for id in ids {
            guard let item = trash.first(where: { $0.id == id }), let ev = item.payload else { continue }
            var restored = ev; restored.updatedAt = nowMs()
            if !events.contains(where: { $0.id == ev.id }) { events.append(restored) }
            tombstones.removeAll { $0 == id }
            n += 1
        }
        trash.removeAll { ids.contains($0.id) }
        saveTrash(); saveTombstones(); save()
        if n > 0 { await doSync() }
        return n
    }
    func purgeLocalTrash(ids: [String]) { trash.removeAll { ids.contains($0.id) }; saveTrash() }

    func refreshRemoteTrash() async {
        guard engine.isConfigured else { remoteTrash = []; remoteDetails = [:]; return }
        loadingRemoteTrash = true
        defer { loadingRemoteTrash = false }
        do { remoteTrash = try await engine.listRemoteDeleted(); remoteDetails = [:] }
        catch { show(error.localizedDescription) }
    }
    func detailFor(_ id: String) async {
        guard let item = remoteTrash.first(where: { ($0["id"] as? String) == id }), remoteDetails[id] == nil else { return }
        let rev = item["rev"] as? String ?? ""
        let d = await engine.fetchDeletedDetail(id: id, rev: rev)
        remoteDetails[id] = d
    }
    func restoreRemote(ids: [String]) async -> (restored: Int, failed: Int) {
        var revs: [String: String] = [:]
        for item in remoteTrash {
            if let id = item["id"] as? String, let rev = item["rev"] as? String { revs[id] = rev }
        }
        let r = await engine.restoreRemote(ids: ids, revs: revs)
        if r.restored > 0 {
            remoteTrash.removeAll { ids.contains(($0["id"] as? String) ?? "") }
            try? await doSync()
        }
        return r
    }
    func purgeRemote(ids: [String]) async -> (purged: Int, error: String?) {
        var revs: [String: String] = [:]
        for item in remoteTrash {
            if let id = item["id"] as? String, let rev = item["rev"] as? String { revs[id] = rev }
        }
        let r = await engine.purgeRemote(ids: ids, revs: revs)
        if !r.purged.isEmpty { remoteTrash.removeAll { r.purged.contains(($0["id"] as? String) ?? "") } }
        return (r.purged.count, r.error)
    }

    // ---- 同步 ----
    func allDocs() -> [[String: Any]] {
        let enc = JSONEncoder()
        var out: [[String: Any]] = []
        func toDict<T: Encodable>(_ v: T) -> [String: Any]? {
            guard let data = try? enc.encode(v),
                  let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
            return obj as? [String: Any]
        }
        for c in categories {
            guard var dict = toDict(c) else { continue }
            dict["_id"] = c.id
            if dict["updatedAt"] == nil { dict["updatedAt"] = nowMs() }
            out.append(dict)
        }
        for e in events {
            guard var dict = toDict(e) else { continue }
            dict["_id"] = e.id
            if dict["updatedAt"] == nil { dict["updatedAt"] = nowMs() }
            out.append(dict)
        }
        return out
    }
    func replaceFromRemote(_ docs: [[String: Any]]) {
        var cats: [Category] = [], evs: [EventItem] = []
        let dec = JSONDecoder()
        var seq = 0
        for d in docs {
            var dict = d
            let id = (dict["_id"] as? String) ?? (dict["id"] as? String) ?? ""
            if id.hasPrefix("category:") || (dict["name"] is String && dict["date"] == nil) {
                dict["id"] = id
                if let data = try? JSONSerialization.data(withJSONObject: dict),
                   let c = try? dec.decode(Category.self, from: data) { cats.append(c) }
            } else if id.hasPrefix("event:") || (dict["date"] is String && dict["title"] is String) {
                dict["id"] = id.isEmpty ? "event:remote:\(seq)" : id
                fixEventDict(&dict)
                if let data = try? JSONSerialization.data(withJSONObject: dict),
                   let e = try? dec.decode(EventItem.self, from: data) { evs.append(e) }
            }
            seq += 1
        }
        if !cats.isEmpty {
            let all = cats.first { $0.id == "cat:all" }
            categories = (all.map { [$0] } ?? []) + cats.filter { $0.id != "cat:all" }.sorted { $0.order < $1.order }
        }
        if !evs.isEmpty { events = evs }
    }
    private func fixEventDict(_ d: inout [String: Any]) {
        if d["repeat"] == nil { d["repeat"] = "none" }
        if d["lunar"] == nil { d["lunar"] = false }
        if d["icon"] == nil { d["icon"] = "📌" }
        if d["color"] == nil { d["color"] = Constants.cardColors[0] }
        if d["categoryId"] == nil { d["categoryId"] = "cat:all" }
        if d["note"] == nil { d["note"] = "" }
        if d["order"] == nil { d["order"] = nowMs() }
        if d["createdAt"] == nil { d["createdAt"] = nowMs() }
        if d["updatedAt"] == nil { d["updatedAt"] = nowMs() }
        if d["showInTimeline"] == nil { d["showInTimeline"] = true }
        if d["displayMode"] == nil {
            d["displayMode"] = (d["repeat"] as? String) == "yearly" ? "countdown" : "countup"
        }
    }

    func doSync(resolve: [String: String] = [:]) async {
        guard engine.isConfigured else { show(SyncError.notConfigured.localizedDescription); return }
        syncing = true; defer { syncing = false }
        do {
            let outcome = try await engine.syncAll(localDocs: allDocs(), oldBase: syncBase,
                                                    resolve: resolve, tombstones: tombstones)
            syncBase = outcome.base; saveBase()
            if !outcome.appliedDeletes.isEmpty {
                tombstones.removeAll { outcome.appliedDeletes.contains($0) }; saveTombstones()
            }
            replaceFromRemote(outcome.docs)
            conflicts = outcome.conflicts
            lastSyncDetail = "拉取 \(outcome.pulled) · 推送 \(outcome.pushed) · 未变 \(outcome.unchanged) · 共 \(outcome.docs.count) 条"
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            lastSync = f.string(from: Date())
            if let info = await engine.dbInfo() { dbSize = info }
            show("同步完成")
        } catch { show(error.localizedDescription) }
    }
    func autoSync() { if settings.autoSync { Task { await doSync() } } }

    func resolveConflict(id: String, choice: String) async { await doSync(resolve: [id: choice]) }

    func pushAllToRemote() async {
        do {
            let r = try await engine.forcePush(localDocs: allDocs())
            show("已用本地覆盖云端：写入 \(r.pushed) 条\(r.deletedRemote > 0 ? "，云端多出 \(r.deletedRemote) 条已删除" : "")")
        } catch { show(error.localizedDescription) }
    }
    func pullAllFromRemote() async {
        do {
            let r = try await engine.forcePull()
            replaceAllFromRemote(r.docs, deletedIds: r.deletedIds)
            show("已用云端覆盖本地：共 \(r.docs.count) 条")
        } catch { show(error.localizedDescription) }
    }
    func replaceAllFromRemote(_ docs: [[String: Any]], deletedIds: [String] = []) {
        let dead = Set(deletedIds)
        var cats: [Category] = [], evs: [EventItem] = []
        let dec = JSONDecoder()
        for d in docs {
            guard let id = (d["_id"] as? String) ?? (d["id"] as? String), !dead.contains(id) else { continue }
            var dict = d; dict["id"] = id
            if id.hasPrefix("event:") || (dict["date"] is String && dict["title"] is String) {
                fixEventDict(&dict)
                if let data = try? JSONSerialization.data(withJSONObject: dict), let e = try? dec.decode(EventItem.self, from: data) { evs.append(e) }
            } else if id.hasPrefix("category:") || dict["name"] is String {
                if let data = try? JSONSerialization.data(withJSONObject: dict), let c = try? dec.decode(Category.self, from: data) { cats.append(c) }
            }
        }
        let all = cats.first { $0.id == "cat:all" }
        categories = (all.map { [$0] } ?? []) + cats.filter { $0.id != "cat:all" }.sorted { $0.order < $1.order }
        events = evs; save()
    }

    func testConnection() async { show(await engine.testConnection()) }

    // ---- 备份导出/导入 ----
    func exportJSON() -> URL {
        let data = PersistedData(schema: Constants.schemaVersion, appVersion: Constants.appVersion,
                                 savedAt: nowMs(), categories: categories, events: events,
                                 settings: settings, widgetBindings: bindings)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("daysnote-\(DateUtils.toISO(Date())).json")
        if let d = try? JSONEncoder().encode(data) { try? d.write(to: url, options: .atomic) }
        return url
    }
    func importJSON(_ url: URL) {
        guard let data = try? Data(contentsOf: url),
              let d = try? JSONDecoder().decode(PersistedData.self, from: data) else { show("导入失败：格式不正确"); return }
        categories = d.categories; events = d.events; settings = d.settings; bindings = d.widgetBindings
        save(); show("导入成功（数据版本 \(d.schema)）")
    }

    // ---- 组件数据同步 ----
    func syncWidgetData() {
        let sorted = WidgetResolver.resolve(bindings: bindings, events: events, categories: categories)
        let payload = WidgetPayload(events: sorted.prefix(8).map { ev in
            let info = DateUtils.dayInfo(ev)
            return WidgetEvent(title: ev.title, icon: ev.icon, date: ev.date,
                               days: info.days, dir: info.dir, color: ev.color)
        }, holiday: holiday, updatedAt: Date().timeIntervalSince1970)
        Persistence.save(payload, to: Persistence.widgetURL)
    }
}

// MARK: - 组件事件解析（与 Web 版规则一致）

enum WidgetResolver {
    static func resolve(bindings: [String: WidgetBinding], events: [EventItem], categories: [Category]) -> [EventItem] {
        let all = bindings.values.first
        let unbound = all == nil || (all!.eventIds.isEmpty && all!.categoryIds.isEmpty)
        var picked: [EventItem]
        if unbound || (all?.mode ?? "category") == "category" {
            let ids = all?.categoryIds ?? []
            if ids.isEmpty || ids.contains("cat:all") { picked = events }
            else { let set = Set(ids); picked = events.filter { set.contains($0.categoryId) } }
        } else {
            let set = Set(all?.eventIds ?? [])
            picked = events.filter { set.contains($0.id) }
        }
        var seen = Set<String>()
        picked = picked.filter { seen.insert($0.id).inserted }
        return picked.sorted {
            let a = DateUtils.dayInfo($0), b = DateUtils.dayInfo($1)
            if a.dir == b.dir { return a.days < b.days }
            return a.dir == "future" ? true : false
        }
    }
}
