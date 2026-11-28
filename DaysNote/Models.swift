import Foundation

// MARK: - 基础类型

enum SyncBackend: String, Codable, CaseIterable { case couchdb, webdav }
enum ThemeMode: String, Codable, CaseIterable { case light, dark, auto }
enum BackgroundStyle: String, Codable, CaseIterable { case grid, beige, cream, gray }
enum CountMode: String, Codable, CaseIterable { case countdown, countup, both }
enum RepeatMode: String, Codable { case none, yearly }

struct Category: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var color: String
    var order: Int
    var builtin: Bool?
    var updatedAt: Int64?
    var rev: String?
    enum CodingKeys: String, CodingKey { case id, name, color, order, builtin, updatedAt, rev = "_rev" }
}

struct EventItem: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var date: String
    var lunar: Bool
    var categoryId: String
    var icon: String
    var color: String
    var note: String
    var order: Int64
    var repeatMode: RepeatMode
    var showInTimeline: Bool?
    var displayMode: CountMode?
    var createdAt: Int64
    var updatedAt: Int64
    var rev: String?
    enum CodingKeys: String, CodingKey {
        case id, title, date, lunar, categoryId, icon, color, note, order
        case repeatMode = "repeat"
        case showInTimeline, displayMode, createdAt, updatedAt
        case rev = "_rev"
    }
}

struct TrashItem: Codable, Identifiable, Equatable {
    var id: String
    var kind: String          // event / category
    var title: String
    var icon: String?
    var date: String?
    var color: String?
    var deletedAt: Int64
    var source: String        // local / remote
    var payload: EventItem?
}

struct AppSettings: Codable, Equatable {
    var enabledBackends: [SyncBackend]
    var syncBackend: SyncBackend?
    var couchUrl: String
    var couchDb: String
    var couchUser: String
    var couchPassword: String
    var webdavUrl: String
    var webdavUser: String
    var webdavPassword: String
    var backupFolder: String
    var autoBackup: Bool
    var aiBaseUrl: String
    var aiKey: String
    var aiModel: String
    var autoSync: Bool
    var showFestivals: Bool
    var themeMode: ThemeMode
    var backgroundStyle: BackgroundStyle
    var icloudSync: Bool

    static let `default` = AppSettings(
        enabledBackends: [.couchdb], syncBackend: .couchdb,
        couchUrl: "", couchDb: "daysnote", couchUser: "", couchPassword: "",
        webdavUrl: "", webdavUser: "", webdavPassword: "", backupFolder: "",
        autoBackup: true, aiBaseUrl: "https://api.openai.com/v1", aiKey: "",
        aiModel: "gpt-4o-mini", autoSync: true, showFestivals: true,
        themeMode: .light, backgroundStyle: .grid, icloudSync: false
    )
}

struct SyncBaseItem: Codable { var hash: String; var updatedAt: Int64 }
typealias SyncBase = [String: SyncBaseItem]

struct ConflictItem: Identifiable, Equatable {
    var id: String
    var kind: String
    var title: String
    var local: [String: Any]
    var remote: [String: Any]
    var localTime: Int64
    var remoteTime: Int64
    static func == (a: Self, b: Self) -> Bool { a.id == b.id && a.localTime == b.localTime && a.remoteTime == b.remoteTime }
}

struct WidgetBinding: Codable, Equatable {
    var mode: String          // events / category
    var eventIds: [String]
    var categoryIds: [String]
    static let empty = WidgetBinding(mode: "category", eventIds: [], categoryIds: [])
}

// MARK: - 组件共享数据结构（App ↔ Widget，写在 App Group）

struct WidgetEvent: Codable, Equatable {
    var title: String
    var icon: String
    var date: String
    var days: Int
    var dir: String           // past / future
    var color: String
}

struct WidgetPayload: Codable {
    var events: [WidgetEvent]
    var holiday: HolidayCountdown?
    var updatedAt: TimeInterval
}

struct HolidayCountdown: Codable, Equatable {
    var name: String
    var icon: String
    var daysLeft: Int
    var inProgress: Bool
    var rangeText: String
    var holidayDays: Int
    var source: String
}

// MARK: - 常量

enum Constants {
    static let appGroup = "group.com.daysnote.app"
    static let schemaVersion = 7
    static let appVersion = "3.1.8"
    static let build = 31
    static let cardColors = ["#e3e9d5", "#dbe7f1", "#fbe0b8", "#f0c8c4", "#dfc8d1", "#c7ddd9", "#d7d2c4"]
    static let categoryColors = ["#f3b8c2", "#a8d3d2", "#e8786d", "#5bb894", "#f6cd6e", "#9fb8e8", "#c7a9dc"]
    static let trashTTL: TimeInterval = 180 * 86400   // 6 个月
}

func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
