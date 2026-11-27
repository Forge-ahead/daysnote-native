import SwiftUI

@main
struct DaysNoteApp: App {
    @StateObject private var store = Store()

    init() {
        // 首次启动拉取节假日数据（每月一次，失败静默）
        Task { _ = await HolidayService.shared.refreshIfNeeded() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onAppear {
                    store.holiday = HolidayService.shared.loadCache()
                    Task {
                        let h = await HolidayService.shared.refreshIfNeeded()
                        store.holiday = h
                        store.syncWidgetData()
                    }
                }
        }
    }
}
