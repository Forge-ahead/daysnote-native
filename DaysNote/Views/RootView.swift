import SwiftUI

enum AppView: String { case home, timeline, widgets, more, detail, edit, catGrid, catList, trash }

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var view: AppView = .home
    @State private var eventId: String? = nil
    @State private var catId = "cat:all"
    @State private var drawerOpen = false

    private var tab: AppView {
        switch view {
        case .more: return .more
        case .widgets: return .widgets
        case .timeline: return .timeline
        default: return .home
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            GridBackground(style: store.settings.backgroundStyle).ignoresSafeArea()

            Group {
                switch view {
                case .home:
                    HomeView(catId: $catId, onMenu: { drawerOpen = true },
                             onAdd: { eventId = nil; view = .edit },
                             onCategoryGrid: { view = .catGrid },
                             onSelect: { eventId = $0.id; view = .detail })
                case .timeline:
                    TimelineView(onSelect: { eventId = $0.id; view = .detail },
                                 onAdd: { eventId = nil; view = .edit })
                case .widgets:
                    WidgetsView()
                case .more:
                    SettingsView()
                case .detail:
                    if let id = eventId {
                        EventDetail(eventId: id, onBack: { view = .home }, onEdit: { view = .edit })
                    }
                case .edit:
                    EventEditor(eventId: eventId, onBack: {
                        view = eventId != nil ? .detail : .home
                    }, onSaved: { id in eventId = id; view = .detail })
                case .catGrid:
                    CategoryGrid(current: $catId, onManage: { view = .catList }, onPick: { catId = $0; view = .home })
                case .catList:
                    CategoryList(onDone: { view = .home })
                case .trash:
                    TrashView(onBack: { view = .home })
                }
            }
            .environmentObject(store)
            .padding(.bottom, 64)

            // TabBar
            HStack(spacing: 0) {
                tabButton("🗳️", "事件", .home)
                tabButton("📆", "时间轴", .timeline)
                tabButton("🏠", "组件", .widgets)
                tabButton("🌱", "更多", .more)
            }
            .frame(height: 58)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .top)
        }
        .overlay(
            Drawer(open: $drawerOpen, currentCat: $catId,
                   onPickCategory: { catId = $0; view = .home; drawerOpen = false },
                   onOpenTrash: { drawerOpen = false; view = .trash },
                   onSelectEvent: { eventId = $0.id; view = .detail; drawerOpen = false })
                .environmentObject(store)
        )
        .modifier(ToastModifier(message: Binding(
            get: { store.toast },
            set: { store.toast = $0 }
        )))
        .onChange(of: store.toast) { _ in
            if store.toast != nil {
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    store.toast = nil
                }
            }
        }
        .onAppear {
            if store.settings.autoSync { Task { await store.doSync(silentIfUnconfigured: true) } }
            store.autoBackupIfNeeded()
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch store.settings.themeMode {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }

    @ViewBuilder
    private func tabButton(_ emoji: String, _ label: String, _ v: AppView) -> some View {
        Button(action: { view = v }) {
            VStack(spacing: 2) {
                Text(emoji).font(.system(size: 20))
                Text(label).font(.system(size: 10, weight: tab == v ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(tab == v ? Theme.ink : Theme.muted)
        }
    }
}
