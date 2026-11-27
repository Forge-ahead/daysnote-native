import Foundation

// MARK: - 同步错误

enum SyncError: LocalizedError {
    case notConfigured, http(Int, String), invalidURL
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "请先在「更多 → 同步」启用并配置 CouchDB 或 WebDAV"
        case .http(let c, let m): return "请求失败 \(c)：\(m)"
        case .invalidURL: return "地址格式不正确"
        }
    }
}

// MARK: - HTTP 封装

struct HTTPResult { let ok: Bool; let status: Int; let data: Data; let headers: [AnyHashable: Any] }

struct Net {
    static func request(_ url: URL, method: String = "GET", headers: [String: String] = [:], body: Data? = nil) async throws -> HTTPResult {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        let h = http?.allHeaderFields ?? [:]
        let status = http?.statusCode ?? 0
        return HTTPResult(ok: (200..<300).contains(status), status: status, data: data, headers: h)
    }

    static func json(_ url: URL, method: String = "GET", headers: [String: String] = [:], body: Any? = nil) async throws -> HTTPResult {
        var data: Data? = nil
        if let b = body { data = try JSONSerialization.data(withJSONObject: b, options: []) }
        return try await request(url, method: method, headers: headers, body: data)
    }

    static func basic(_ user: String, _ pass: String) -> [String: String] {
        guard !user.isEmpty else { return [:] }
        let raw = "\(user):\(pass)".data(using: .utf8)?.base64EncodedString() ?? ""
        return ["Authorization": "Basic \(raw)"]
    }
}

// MARK: - 内容指纹（忽略元字段）

func docHash(_ doc: [String: Any]) -> String {
    let skip = Set(["_rev", "updatedAt", "_deleted", "deletedAt"])
    func stable(_ v: Any) -> Any {
        if let arr = v as? [Any] { return arr.map(stable) }
        if let dict = v as? [String: Any] {
            var o: [String: Any] = [:]
            for k in dict.keys.sorted() { o[k] = stable(dict[k]!) }
            return o
        }
        return v
    }
    var rest: [String: Any] = [:]
    for (k, v) in doc where !skip.contains(k) { rest[k] = stable(v) }
    let json = (try? JSONSerialization.data(withJSONObject: rest, options: [.sortedKeys])) ?? Data()
    let text = String(data: json, encoding: .utf8) ?? ""
    var h: Int64 = 0
    for c in text.utf8 { h = (h &* 31 &+ Int64(c)) & 0x7FFFFFFF }
    return "\(h):\(text.utf8.count)"
}

func ts(_ d: [String: Any]) -> Int64 {
    if let n = d["updatedAt"] as? NSNumber { return n.int64Value }
    if let n = d["updatedAt"] as? Int { return Int64(n) }
    return 0
}

// MARK: - 同步驱动

struct SyncEngine {
    let settings: AppSettings

    func enabled() -> [SyncBackend] {
        var list = settings.enabledBackends
        if list.isEmpty, let legacy = settings.syncBackend { list = [legacy] }
        return list.filter { configured($0) }
    }
    func configured(_ b: SyncBackend) -> Bool {
        b == .couchdb ? (!settings.couchUrl.isEmpty && !settings.couchDb.isEmpty) : !settings.webdavUrl.isEmpty
    }
    var isConfigured: Bool { !enabled().isEmpty }

    func couchBase() -> String { settings.couchUrl.trimmingCharacters(in: .init(charactersIn: "/")) + "/" + settings.couchDb.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)! }
    func couchHeaders() -> [String: String] { Net.basic(settings.couchUser, settings.couchPassword) }

    // ---- 远端读写 ----
    func couchRead() async throws -> [[String: Any]] {
        let r = try await Net.json(URL(string: couchBase() + "/_all_docs?include_docs=true")!, headers: couchHeaders())
        guard r.ok else { throw SyncError.http(r.status, "CouchDB 读取失败") }
        guard let root = (try? JSONSerialization.jsonObject(with: r.data)) as? [String: Any],
              let rows = root["rows"] as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            guard let doc = row["doc"] as? [String: Any], let id = row["id"] as? String,
                  !id.hasPrefix("_design/"), doc["_deleted"] == nil else { return nil }
            return doc
        }
    }

    func webdavRead() async throws -> (docs: [[String: Any]], token: String?) {
        let r = try await Net.json(URL(string: settings.webdavUrl)!, headers: Net.basic(settings.webdavUser, settings.webdavPassword))
        if r.status == 404 { return ([], nil) }
        guard r.ok else { throw SyncError.http(r.status, "WebDAV 读取失败") }
        guard let root = (try? JSONSerialization.jsonObject(with: r.data)) as? [String: Any],
              let docs = root["docs"] as? [[String: Any]] else { return ([], nil) }
        let token = r.headers["ETag"] as? String
        return (docs, token)
    }

    func couchWrite(_ docs: [[String: Any]]) async throws {
        guard !docs.isEmpty else { return }
        let r = try await Net.json(URL(string: couchBase() + "/_bulk_docs")!, method: "POST", headers: couchHeaders(), body: ["docs": docs])
        guard r.ok else { throw SyncError.http(r.status, String(String(data: r.data, encoding: .utf8)?.prefix(120) ?? "")) }
    }

    func webdavWrite(_ docs: [[String: Any]], token: String?) async throws {
        var h = Net.basic(settings.webdavUser, settings.webdavPassword)
        if let t = token { h["If-Match"] = t }
        let body: [String: Any] = ["docs": docs, "updatedAt": nowMs()]
        let r = try await Net.json(URL(string: settings.webdavUrl)!, method: "PUT", headers: h, body: body)
        guard r.ok else { throw SyncError.http(r.status, "WebDAV 写入失败") }
    }

    // ---- 连接测试 ----
    func testConnection() async -> String {
        var parts: [String] = []
        for b in enabled() {
            do {
                if b == .couchdb {
                    let r = try await Net.request(URL(string: couchBase())!, headers: couchHeaders())
                    parts.append("CouchDB：\(r.ok ? "连接成功" : "\(r.status)")")
                } else {
                    let r = try await Net.request(URL(string: settings.webdavUrl)!, headers: Net.basic(settings.webdavUser, settings.webdavPassword))
                    parts.append("WebDAV：\(r.ok ? "连接成功" : "\(r.status)")")
                }
            } catch { parts.append("\(b.rawValue)：\(error.localizedDescription)") }
        }
        return parts.joined(separator: "；")
    }

    func dbInfo() async -> (active: Int64, disk: Int64, docCount: Int64, delCount: Int64)? {
        guard configured(.couchdb) else { return nil }
        guard let r = try? await Net.request(URL(string: couchBase())!, headers: couchHeaders()), r.ok,
              let d = (try? JSONSerialization.jsonObject(with: r.data)) as? [String: Any] else { return nil }
        let sizes = d["sizes"] as? [String: Any]
        return (num(sizes?["active"]), num(sizes?["disk"]), num(d["doc_count"]), num(d["doc_del_count"]))
    }
    private func num(_ v: Any?) -> Int64 {
        if let n = v as? NSNumber { return n.int64Value }
        if let n = v as? Int { return Int64(n) }
        return 0
    }

    // ---- 云端删除列表 ----
    func listRemoteDeleted() async throws -> [[String: Any]] {
        guard configured(.couchdb) else { return [] }
        let r = try await Net.json(URL(string: couchBase() + "/_changes?since=0&style=all_docs")!, headers: couchHeaders())
        guard r.ok else { throw SyncError.http(r.status, "读取云端变更失败") }
        guard let root = (try? JSONSerialization.jsonObject(with: r.data)) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else { return [] }
        var out: [[String: Any]] = []
        for c in results where c["deleted"] as? Bool == true {
            guard let id = c["id"] as? String, !id.hasPrefix("_design/") else { continue }
            let changes = c["changes"] as? [[String: Any]]
            guard let rev = changes?.first?["rev"] as? String else { continue }
            var item: [String: Any] = ["id": id, "rev": rev]
            // 读取删除标记的 deletedAt
            if let rr = try? await Net.request(URL(string: "\(couchBase())/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)?rev=\(rev.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!, headers: couchHeaders()),
               rr.ok, let body = (try? JSONSerialization.jsonObject(with: rr.data)) as? [String: Any],
               let at = body["deletedAt"] as? NSNumber { item["deletedAt"] = at.int64Value }
            out.append(item)
        }
        return out
    }

    /// 从修订链回捞删除前的正文（只读）
    func fetchDeletedDetail(id: String, rev: String) async -> [String: Any] {
        var out: [String: Any] = ["id": id, "rev": rev]
        guard configured(.couchdb) else { out["error"] = "未配置 CouchDB"; return out }
        let enc = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        guard let metaR = try? await Net.request(URL(string: "\(couchBase())/\(enc)?rev=\(rev.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&revs=true")!, headers: couchHeaders()), metaR.ok,
              let meta = (try? JSONSerialization.jsonObject(with: metaR.data)) as? [String: Any] else {
            out["error"] = "读取修订链失败"; return out
        }
        if let at = meta["deletedAt"] as? NSNumber { out["deletedAt"] = at.int64Value }
        guard let revs = meta["_revisions"] as? [String: Any], let ids = revs["ids"] as? [String], !ids.isEmpty else {
            out["error"] = "旧版本已被压缩，无法读取详情"; return out
        }
        let start = (revs["start"] as? NSNumber)?.intValue ?? ids.count
        var found: [String: Any]? = nil
        var n = start - 1
        while n > max(start - 30, 0) {
            let rv = "\(n)-\(ids[start - n])"
            guard let rr = try? await Net.request(URL(string: "\(couchBase())/\(enc)?rev=\(rv.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&revs=true")!, headers: couchHeaders()), rr.ok,
                  let body = (try? JSONSerialization.jsonObject(with: rr.data)) as? [String: Any] else { break }
            if body["_deleted"] == nil { found = body; break }
            n -= 1
        }
        guard let f = found else { out["error"] = "旧版本已被压缩，无法读取详情"; return out }
        for k in ["title", "date", "icon", "note", "categoryId", "displayMode", "color", "repeat", "lunar"] {
            if let v = f[k] { out[k] = v }
        }
        return out
    }

    /// 修订链复活云端文档
    func restoreRemote(ids: [String], revs: [String: String]) async -> (restored: Int, failed: Int) {
        var batch: [[String: Any]] = []
        var failed = 0
        for id in ids {
            guard let rev = revs[id] else { failed += 1; continue }
            let enc = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
            guard let metaR = try? await Net.request(URL(string: "\(couchBase())/\(enc)?rev=\(rev.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&revs=true")!, headers: couchHeaders()), metaR.ok,
                  let meta = (try? JSONSerialization.jsonObject(with: metaR.data)) as? [String: Any],
                  let revsObj = meta["_revisions"] as? [String: Any], let chain = revsObj["ids"] as? [String], !chain.isEmpty else { failed += 1; continue }
            let start = (revsObj["start"] as? NSNumber)?.intValue ?? chain.count
            var found: [String: Any]? = nil
            var n = start - 1
            while n > max(start - 30, 0) {
                let rv = "\(n)-\(chain[start - n])"
                guard let rr = try? await Net.request(URL(string: "\(couchBase())/\(enc)?rev=\(rv.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&revs=true")!, headers: couchHeaders()), rr.ok,
                      let body = (try? JSONSerialization.jsonObject(with: rr.data)) as? [String: Any] else { break }
                if body["_deleted"] == nil { found = body; break }
                n -= 1
            }
            guard var f = found else { failed += 1; continue }
            var content: [String: Any] = [:]
            for (k, v) in f where !k.hasPrefix("_") { content[k] = v }
            let seed = id + (content.keys.sorted().compactMap { "\($0)=\(content[$0] ?? "")" }.joined())
            var h: Int64 = 0
            for c in seed.utf8 { h = (h &* 31 &+ Int64(c)) & 0x7FFFFFFF }
            let newHash = String(format: "%032llx", h)
            let newStart = start + 1
            var doc: [String: Any] = ["_id": id, "_rev": "\(newStart)-\(newHash)",
                                      "_revisions": ["start": newStart, "ids": [newHash] + chain]]
            for (k, v) in content { doc[k] = v }
            batch.append(doc)
        }
        if !batch.isEmpty {
            guard let r = try? await Net.json(URL(string: couchBase() + "/_bulk_docs")!, method: "POST",
                                              headers: couchHeaders().merging(["Content-Type": "application/json"]) { _, new in new },
                                              body: ["docs": batch, "new_edits": false]), r.ok else { return (0, ids.count) }
        }
        return (batch.count, failed)
    }

    /// 永久清除（_purge，不可逆，需管理员权限）
    func purgeRemote(ids: [String], revs: [String: String]) async -> (purged: [String], error: String?) {
        guard configured(.couchdb) else { return ([], "未配置 CouchDB") }
        var docs: [String: String] = [:]
        for id in ids { docs[id] = revs[id] ?? "" }
        guard let r = try? await Net.json(URL(string: couchBase() + "/_purge")!, method: "POST",
                                          headers: couchHeaders().merging(["Content-Type": "application/json"]) { _, new in new },
                                          body: ["docs": docs]) else { return ([], "网络错误") }
        if !r.ok { return ([], r.status == 401 || r.status == 403 ? "需要 CouchDB 管理员权限才能永久清除" : "永久清除失败 \(r.status)") }
        guard let root = (try? JSONSerialization.jsonObject(with: r.data)) as? [String: Any],
              let purged = root["purged"] as? [String: Any] else { return ([], nil) }
        return (Array(purged.keys), nil)
    }

    // ---- 三方合并同步 ----
    struct Outcome {
        var docs: [[String: Any]] = []
        var conflicts: [ConflictItem] = []
        var base: SyncBase = [:]
        var appliedDeletes: [String] = []
        var pushed = 0, pulled = 0, unchanged = 0, couchWins = 0
    }

    func syncAll(localDocs: [[String: Any]], oldBase: SyncBase, resolve: [String: String], tombstones: [String]) async throws -> Outcome {
        let backs = enabled()
        guard !backs.isEmpty else { throw SyncError.notConfigured }
        var couchMap: [String: [String: Any]] = [:]
        var davMap: [String: [String: Any]] = [:]
        var davToken: String? = nil
        // 串行读取两个后端，避免并发修改共享字典（CouchDB 数据最终会覆盖 WebDAV）
        if backs.contains(.couchdb) {
            let docs = try await couchRead()
            for d in docs { if let id = d["_id"] as? String { couchMap[id] = d } }
        }
        if backs.contains(.webdav) {
            let st = try await webdavRead()
            for d in st.docs { if let id = d["_id"] as? String { davMap[id] = d } }
            davToken = st.token
        }

        var localMap: [String: [String: Any]] = [:]
        for d in localDocs { if let id = d["_id"] as? String { localMap[id] = d } }
        let tombSet = Set(tombstones)
        var ids = Set(localMap.keys); ids.formUnion(couchMap.keys); ids.formUnion(davMap.keys)

        var out = Outcome()
        out.base = oldBase
        for id in ids {
            let l = localMap[id], c = couchMap[id], d = davMap[id]
            let base = oldBase[id]
            let baseTs = base?.updatedAt ?? 0

            if let pick = resolve[id] {
                let chosen = pick == "local" ? l : (c ?? d)
                if let chosen = chosen { out.docs.append(chosen); out.base[id] = SyncBaseItem(hash: docHash(chosen), updatedAt: ts(chosen) == 0 ? nowMs() : ts(chosen)) }
                out.pushed += 1; continue
            }

            if l == nil, (c != nil || d != nil), tombSet.contains(id) {
                out.appliedDeletes.append(id); out.base.removeValue(forKey: id); out.pushed += 1; continue
            }

            var remote = c ?? d
            if let c = c, let d = d, docHash(c) != docHash(d) { remote = c; out.couchWins += 1 }

            if l == nil, let remote = remote {
                out.docs.append(remote); out.base[id] = SyncBaseItem(hash: docHash(remote), updatedAt: ts(remote) == 0 ? nowMs() : ts(remote)); out.pulled += 1; continue
            }
            if let l = l, remote == nil {
                out.docs.append(l); out.base[id] = SyncBaseItem(hash: docHash(l), updatedAt: ts(l) == 0 ? nowMs() : ts(l)); out.pushed += 1; continue
            }
            guard let l = l, let remote = remote else { continue }

            let lNewer = ts(l) > ts(remote), rNewer = ts(remote) > ts(l)
            let lChanged = base == nil ? true : (ts(l) > baseTs || docHash(l) != base!.hash)
            let rChanged = base == nil ? true : (ts(remote) > baseTs || docHash(remote) != base!.hash)

            if docHash(l) == docHash(remote) {
                let winner = lNewer ? l : remote
                var w = winner
                if let rev = c?["_rev"] { w["_rev"] = rev }
                out.docs.append(w)
                out.base[id] = SyncBaseItem(hash: docHash(l), updatedAt: max(ts(l), ts(remote)) == 0 ? nowMs() : max(ts(l), ts(remote)))
                out.unchanged += 1
            } else if lChanged && !rChanged {
                var w = l; if let rev = c?["_rev"] { w["_rev"] = rev }
                out.docs.append(w); out.base[id] = SyncBaseItem(hash: docHash(l), updatedAt: ts(l) == 0 ? nowMs() : ts(l)); out.pushed += 1
            } else if rChanged && !lChanged {
                out.docs.append(remote); out.base[id] = SyncBaseItem(hash: docHash(remote), updatedAt: ts(remote) == 0 ? nowMs() : ts(remote)); out.pulled += 1
            } else if lNewer || rNewer {
                if lNewer {
                    var w = l; if let rev = c?["_rev"] { w["_rev"] = rev }
                    out.docs.append(w); out.base[id] = SyncBaseItem(hash: docHash(l), updatedAt: ts(l)); out.pushed += 1
                } else {
                    out.docs.append(remote); out.base[id] = SyncBaseItem(hash: docHash(remote), updatedAt: ts(remote)); out.pulled += 1
                }
            } else {
                out.conflicts.append(ConflictItem(id: id, kind: id.hasPrefix("category:") ? "category" : "event",
                                                   title: (l["title"] ?? l["name"] ?? remote["title"] ?? remote["name"] ?? id) as? String ?? id,
                                                   local: l, remote: remote, localTime: ts(l), remoteTime: ts(remote)))
                out.docs.append(l)
            }
        }

        let conflictIds = Set(out.conflicts.map { $0.id })
        let finalDocs = out.docs.filter { !conflictIds.contains(($0["_id"] as? String) ?? "") }

        if backs.contains(.couchdb) || !couchMap.isEmpty {
            var couchDocs: [[String: Any]] = []
            for var d in finalDocs {
                if let id = d["_id"] as? String, let rev = couchMap[id]?["_rev"] { d["_rev"] = rev }
                d.removeValue(forKey: "updatedAtLocal")
                couchDocs.append(d)
            }
            let finalIds = Set(finalDocs.compactMap { $0["_id"] as? String })
            for (id, doc) in couchMap where !finalIds.contains(id) && !conflictIds.contains(id) {
                couchDocs.append(["_id": id, "_rev": doc["_rev"] ?? "", "_deleted": true, "deletedAt": nowMs()])
            }
            for id in out.appliedDeletes where !couchDocs.contains(where: { ($0["_id"] as? String) == id && $0["_deleted"] != nil }) {
                couchDocs.append(["_id": id, "_rev": couchMap[id]?["_rev"] ?? "", "_deleted": true, "deletedAt": nowMs()])
            }
            try await couchWrite(couchDocs)
        }
        if backs.contains(.webdav) {
            let davDocs: [[String: Any]] = finalDocs.map { d in
                var x = d; x.removeValue(forKey: "_rev"); x.removeValue(forKey: "updatedAtLocal"); return x
            }
            try await webdavWrite(davDocs, token: davToken)
        }
        return out
    }

    // ---- 强制覆盖 ----
    func forcePush(localDocs: [[String: Any]]) async throws -> (pushed: Int, deletedRemote: Int) {
        guard isConfigured else { throw SyncError.notConfigured }
        var deletedRemote = 0
        if configured(.couchdb) {
            let remote = try await couchRead()
            var revMap: [String: String] = [:]
            for d in remote { if let id = d["_id"] as? String, let rev = d["_rev"] as? String { revMap[id] = rev } }
            var docs = localDocs.map { d -> [String: Any] in
                var x = d; if let id = d["_id"] as? String, let rev = revMap[id] { x["_rev"] = rev }; return x
            }
            let localIds = Set(localDocs.compactMap { $0["_id"] as? String })
            for (id, rev) in revMap where !localIds.contains(id) { docs.append(["_id": id, "_rev": rev, "_deleted": true, "deletedAt": nowMs()]); deletedRemote += 1 }
            try await couchWrite(docs)
        }
        if configured(.webdav) {
            let clean = localDocs.map { d -> [String: Any] in var x = d; x.removeValue(forKey: "_rev"); return x }
            try await webdavWrite(clean, token: nil)
        }
        return (localDocs.count, deletedRemote)
    }

    func forcePull() async throws -> (docs: [[String: Any]], deletedIds: [String]) {
        guard isConfigured else { throw SyncError.notConfigured }
        var docs: [[String: Any]] = []
        var deletedIds: [String] = []
        if configured(.couchdb) {
            docs.append(contentsOf: try await couchRead())
            if let dead = try? await listRemoteDeleted() { deletedIds.append(contentsOf: dead.compactMap { $0["id"] as? String }) }
        }
        if configured(.webdav) { let st = try await webdavRead(); docs.append(contentsOf: st.docs) }
        return (docs, deletedIds)
    }
}
