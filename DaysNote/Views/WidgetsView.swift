import SwiftUI

/// 组件配置页：展示 6 款模板、分类多选绑定，数据写入 App Group 供 Widget 读取
struct WidgetsView: View {
    @EnvironmentObject var store: Store
    @State private var selectedTemplate: WidgetTemplate? = nil
    @State private var bindingMode = "category"
    @State private var pickedEvents: [String] = []
    @State private var pickedCats: [String] = []

    private let templates: [WidgetTemplate] = WidgetTemplate.all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavBar(title: "小组件", back: nil) { EmptyView() }
                Text("选择模板并绑定事件或分类，然后在系统桌面长按添加「纪念日」小组件。")
                    .font(.system(size: 12)).foregroundColor(Theme.muted)

                ForEach(["小", "中", "大"], id: \.self) { group in
                    SectionTitle(text: "\(group) 组件")
                    ForEach(templates.filter { $0.category == group }) { t in
                        Button(action: { openBinding(t) }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(Color(hex: t.skin.bg))
                                    VStack(spacing: 2) {
                                        Text(t.icon).font(.system(size: 20))
                                        Text("\(t.slots) 条").font(.system(size: 9)).foregroundColor(Color(hex: t.skin.inkSoft))
                                    }
                                }.frame(width: 56, height: 56)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t.name).font(.system(size: 14, weight: .semibold))
                                    Text(t.desc).font(.system(size: 10)).foregroundColor(Theme.muted).lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Theme.muted)
                            }
                            .padding(10).background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14)).foregroundColor(Theme.ink)
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 30)
        }
        .sheet(item: $selectedTemplate) { t in bindingSheet(t) }
    }

    private func openBinding(_ t: WidgetTemplate) {
        selectedTemplate = t
        let b = store.bindings[t.id] ?? .empty
        bindingMode = b.mode
        pickedEvents = b.eventIds
        pickedCats = b.categoryIds
    }

    @ViewBuilder
    private func bindingSheet(_ t: WidgetTemplate) -> some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("绑定「\(t.name)」的事件来源").font(.system(size: 15, weight: .semibold))
                    Picker("来源", selection: $bindingMode) {
                        Text("选分类（可多选）").tag("category")
                        Text("指定事件").tag("events")
                    }.pickerStyle(.segmented)

                    if bindingMode == "category" {
                        ForEach(store.categories) { c in
                            Button(action: {
                                if pickedCats.contains(c.id) { pickedCats.removeAll { $0 == c.id } }
                                else { pickedCats.append(c.id) }
                            }) {
                                HStack {
                                    Circle().fill(Color(hex: c.color)).frame(width: 14, height: 14)
                                    Text(c.name).foregroundColor(Theme.ink)
                                    Spacer()
                                    if pickedCats.contains(c.id) { Image(systemName: "checkmark").foregroundColor(Theme.accent) }
                                }.padding(.vertical, 6)
                            }
                        }
                        Text("未选任何分类 = 加载全部事件").font(.system(size: 11)).foregroundColor(Theme.muted)
                    } else {
                        ForEach(store.events) { ev in
                            Button(action: {
                                if pickedEvents.contains(ev.id) { pickedEvents.removeAll { $0 == ev.id } }
                                else { pickedEvents.append(ev.id) }
                            }) {
                                HStack {
                                    Text(ev.icon)
                                    Text(ev.title).foregroundColor(Theme.ink)
                                    Spacer()
                                    if pickedEvents.contains(ev.id) { Image(systemName: "checkmark").foregroundColor(Theme.accent) }
                                }.padding(.vertical, 6)
                            }
                        }
                    }
                }.padding()
            }
            .navigationTitle("绑定设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        store.bindings[t.id] = WidgetBinding(mode: bindingMode, eventIds: pickedEvents, categoryIds: pickedCats)
                        store.save()
                        selectedTemplate = nil
                    }
                }
            }
        }
    }
}

struct WidgetTemplate: Identifiable, Equatable {
    var id: String
    var name: String
    var category: String
    var icon: String
    var slots: Int
    var desc: String
    var skin: Skin
    struct Skin: Equatable { var bg: String; var inkSoft: String }
    static let all: [WidgetTemplate] = [
        .init(id: "holiday-official", name: "假日 · 法定节假日", category: "中", icon: "🎉", slots: 4,
              desc: "左侧法定节假日倒计时 + 右侧分类事件（每月联网更新）",
              skin: .init(bg: "#fbfaf7", inkSoft: "#a6a29a")),
        .init(id: "holiday-fresh", name: "假日 · 清新绿", category: "中", icon: "🌿", slots: 4,
              desc: "假日组件的清新绿皮肤", skin: .init(bg: "#eef0e6", inkSoft: "#93a488")),
        .init(id: "grid-rose", name: "四宫格面板 · 柔粉", category: "中", icon: "🌸", slots: 4,
              desc: "2×2 卡片，emoji + 标题 + 日期 + 大数字", skin: .init(bg: "#fbedef", inkSoft: "#c2949e")),
        .init(id: "simple-day", name: "简约列表 · 带天", category: "小", icon: "📋", slots: 3,
              desc: "2×2 紧凑三行，数字与「天」分格", skin: .init(bg: "#f2f2f0", inkSoft: "#a6a29a")),
        .init(id: "picture-teal", name: "图文列表 · 青绿", category: "大", icon: "🖼️", slots: 5,
              desc: "青绿背景 + 顶部日期 + 5 行半透明卡片", skin: .init(bg: "#5c9e96", inkSoft: "#cfe6e1")),
        .init(id: "list-bluehead", name: "简约列表 · 大号", category: "大", icon: "📃", slots: 5,
              desc: "白底蓝头 + 5 行色块数字", skin: .init(bg: "#ffffff", inkSoft: "#a6a29a")),
    ]
}
