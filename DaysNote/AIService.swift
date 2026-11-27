import Foundation

/// AI 助手：调用 OpenAI 兼容 /chat/completions，用工具调用完成事件增删改
@MainActor
class AIService {
    static let shared = AIService()

    struct ChatMessage: Codable {
        var role: String
        var content: String?
        var tool_calls: [ToolCall]?
    }
    struct ToolCall: Codable {
        var id: String
        var type: String = "function"
        var function: Func
        struct Func: Codable { var name: String; var arguments: String }
    }
    /// 工具定义直接构造成字典，避免 [String: Any] 无法 Codable 的问题
    private var tools: [[String: Any]] {
        [
            ["type": "function", "function": [
                "name": "add_event", "description": "新增一个倒数/纪念日事件",
                "parameters": ["type": "object", "properties": [
                    "title": ["type": "string"], "date": ["type": "string", "description": "YYYY-MM-DD"],
                    "icon": ["type": "string"], "note": ["type": "string"],
                    "displayMode": ["type": "string", "enum": ["countdown", "countup", "both"]],
                    "repeat": ["type": "string", "enum": ["none", "yearly"]]
                ], "required": ["title", "date"]]
            ]],
            ["type": "function", "function": [
                "name": "update_event", "description": "修改已有事件",
                "parameters": ["type": "object", "properties": [
                    "id": ["type": "string"], "title": ["type": "string"], "date": ["type": "string"],
                    "note": ["type": "string"], "displayMode": ["type": "string"]
                ], "required": ["id"]]
            ]],
            ["type": "function", "function": [
                "name": "delete_event", "description": "删除事件",
                "parameters": ["type": "object", "properties": ["id": ["type": "string"]], "required": ["id"]]
            ]],
            ["type": "function", "function": [
                "name": "add_category", "description": "新增分类",
                "parameters": ["type": "object", "properties": ["name": ["type": "string"]], "required": ["name"]]
            ]],
        ]
    }

    func ask(_ text: String, settings: AppSettings, store: Store) async throws -> String {
        guard !settings.aiKey.isEmpty else { throw NSError(domain: "AI", code: 1, userInfo: [NSLocalizedDescriptionKey: "请先在「AI 助手」填写 API Key"]) }
        let base = settings.aiBaseUrl.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: base + "/chat/completions") else { throw NSError(domain: "AI", code: 2, userInfo: [NSLocalizedDescriptionKey: "地址格式不正确"]) }

        let context = """
        当前有 \(store.events.count) 个事件、\(store.categories.count) 个分类。
        事件列表：\(store.events.map { "\($0.id)|\($0.title)|\($0.date)|\($0.displayMode?.rawValue ?? "")" }.joined(separator: "\n"))
        分类列表：\(store.categories.map { "\($0.id)|\($0.name)" }.joined(separator: "\n"))
        """
        let body: [String: Any] = [
            "model": settings.aiModel,
            "messages": [
                ["role": "system", "content": "你是倒数日 App 的管理助手。用中文简短回复。需要增删改事件或分类时调用工具。\n" + context],
                ["role": "user", "content": text],
            ],
            "tools": tools,
            "tool_choice": "auto",
        ]
        let r = try await Net.json(url, method: "POST", headers: ["Authorization": "Bearer \(settings.aiKey)"], body: body)
        guard r.ok, let root = (try? JSONSerialization.jsonObject(with: r.data)) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]], let msg = choices.first?["message"] as? [String: Any] else {
            throw NSError(domain: "AI", code: 3, userInfo: [NSLocalizedDescriptionKey: "AI 返回格式错误 \(r.status)"])
        }

        var answer = msg["content"] as? String ?? ""
        if let calls = msg["tool_calls"] as? [[String: Any]] {
            for call in calls {
                guard let fn = call["function"] as? [String: Any], let name = fn["name"] as? String,
                      let argStr = fn["arguments"] as? String,
                      let args = (try? JSONSerialization.jsonObject(with: Data(argStr.utf8))) as? [String: Any] else { continue }
                let done = apply(name: name, args: args, store: store)
                answer += "\n" + done
            }
        }
        return answer.isEmpty ? "已完成" : answer
    }

    private func apply(name: String, args: [String: Any], store: Store) -> String {
        switch name {
        case "add_event":
            let title = args["title"] as? String ?? "新事件"
            let date = args["date"] as? String ?? DateUtils.toISO(Date())
            let mode = CountMode(rawValue: args["displayMode"] as? String ?? "") ?? .countup
            let rep = RepeatMode(rawValue: args["repeat"] as? String ?? "none") ?? .none
            let ev = EventItem(id: "", title: title, date: date, lunar: false,
                               categoryId: "cat:all", icon: args["icon"] as? String ?? "📌",
                               color: Constants.cardColors[Int.random(in: 0..<Constants.cardColors.count)],
                               note: args["note"] as? String ?? "", order: nowMs(), repeatMode: rep,
                               showInTimeline: true, displayMode: mode, createdAt: 0, updatedAt: 0)
            _ = store.addEvent(ev)
            return "已新增事件「\(title)」"
        case "update_event":
            guard let id = args["id"] as? String, var ev = store.events.first(where: { $0.id == id || $0.title == id }) else { return "未找到事件" }
            if let t = args["title"] as? String { ev.title = t }
            if let d = args["date"] as? String { ev.date = d }
            if let n = args["note"] as? String { ev.note = n }
            if let m = args["displayMode"] as? String, let mode = CountMode(rawValue: m) { ev.displayMode = mode }
            store.updateEvent(id, patch: ev); return "已修改「\(ev.title)」"
        case "delete_event":
            guard let id = args["id"] as? String,
                  let ev = store.events.first(where: { $0.id == id || $0.title == id }) else { return "未找到事件" }
            store.removeEvent(ev.id); return "已删除「\(ev.title)」"
        case "add_category":
            let name = args["name"] as? String ?? "新分类"
            _ = store.addCategory(name: name); return "已新增分类「\(name)」"
        default: return "未知操作"
        }
    }
}
