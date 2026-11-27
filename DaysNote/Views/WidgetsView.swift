import SwiftUI

/// 组件配置页（对齐 Web v31 样式）：
/// 顶部 tab 分类 + 按真实比例的预览卡网格 + 点开绑定设置弹层
struct WidgetsView: View {
    @EnvironmentObject var store: Store
    @State private var selectedTemplate: WidgetTemplate? = nil
    @State private var tab = "中"

    private let tabs = ["小", "中", "大"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavBar(title: "小组件", back: nil) { EmptyView() }

                Text("选择模板并绑定事件或分类，然后在系统桌面长按空白处添加「纪念日」小组件。")
                    .font(.system(size: 12)).foregroundColor(Theme.muted).lineSpacing(5)
                    .padding(11).background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 14)

                // 顶部 tab：下划线风格
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { c in
                        Button(action: { tab = c }) {
                            VStack(spacing: 6) {
                                Text(c).font(.system(size: 14, weight: tab == c ? .bold : .regular))
                                    .foregroundColor(tab == c ? Color(hex: "#5b7d55") : Theme.muted)
                                Rectangle().fill(tab == c ? Color(hex: "#7fa87a") : Color.clear)
                                    .frame(height: 2).cornerRadius(2)
                            }.padding(.horizontal, 20).padding(.top, 14)
                        }.frame(maxWidth: .infinity)
                    }
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                .padding(.top, 12)

                // 预览卡网格：按组件真实比例
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 16) {
                    ForEach(WidgetTemplate.all.filter { $0.category == tab }) { t in
                        Button(action: { selectedTemplate = t }) {
                            VStack(spacing: 0) {
                                WidgetCardPreview(t: t)
                                    .aspectRatio(t.category == "中" ? 338/158 : 1, contentMode: .fit)
                                Text(t.name).font(.system(size: 12)).foregroundColor(Color(hex: "#8b8782")).padding(.top, 8)
                                Text(t.slots >= 5 ? "大组件" : (t.category == "中" ? "中组件" : "小组件"))
                                    .font(.system(size: 10)).foregroundColor(Color(hex: "#b0aca6")).padding(.top, 2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.top, 22)

                Button(action: {}) {
                    Text("👑 6 款组件已全部做进 · 更多样式持续更新")
                        .font(.system(size: 12)).foregroundColor(Color(hex: "#8b6f3e"))
                        .padding(.vertical, 10).frame(maxWidth: .infinity)
                        .background(Color(hex: "#faf3e3")).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(true)
                .padding(.horizontal, 14).padding(.top, 20).padding(.bottom, 30)
            }
        }
        .sheet(item: $selectedTemplate) { t in bindingSheet(t) }
    }

    // 模板缩略预览：模拟真实组件布局
    @ViewBuilder
    private func WidgetCardPreview(t: WidgetTemplate) -> some View {
        let bg = Color(hex: t.skin.bg)
        Group {
            if t.id.hasPrefix("holiday") {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("🎉").font(.system(size: 14))
                        Text("28").font(.system(size: 22, weight: .bold)).foregroundColor(Color(hex: "#5b9bd5"))
                        Text("天后").font(.system(size: 8))
                        Text("元旦").font(.system(size: 10, weight: .semibold))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            HStack {
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.6)).frame(width: 10, height: 10)
                                RoundedRectangle(cornerRadius: 4).fill(Color(hex: t.skin.inkSoft).opacity(0.35)).frame(height: 8)
                            }
                        }
                    }.frame(maxWidth: .infinity)
                }.padding(9).background(bg)
            } else if t.id == "grid-rose" {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 3) {
                            RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#f8d7de")).frame(height: 26)
                        }
                    }
                }.padding(8).background(Color(hex: "#fbedef"))
            } else if t.id == "simple-day" {
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack {
                            RoundedRectangle(cornerRadius: 4).fill(Color(hex: t.skin.inkSoft).opacity(0.3)).frame(width: 40, height: 8)
                            Spacer()
                            RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#3d3b3a").opacity(0.5)).frame(width: 22, height: 12)
                        }
                    }
                }.padding(10).background(bg)
            } else if t.id == "picture-teal" {
                VStack(alignment: .leading, spacing: 5) {
                    Text("纪念日").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.2)).frame(height: 16)
                    }
                }.padding(9).background(Color(hex: "#5c9e96"))
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("纪念日").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "#3b82d6"))
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#f5f6f8")).frame(height: 16)
                    }
                }.padding(9).background(Color.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
    }

    // 绑定设置弹层
    @ViewBuilder
    private func bindingSheet(_ t: WidgetTemplate) -> some View {
        BindingSheet(t: t)
            .environmentObject(store)
    }
}

struct BindingSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let t: WidgetTemplate
    @State private var mode = "category"
    @State private var events: [String] = []
    @State private var cats: [String] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t.desc).font(.system(size: 12)).foregroundColor(Theme.muted)

                    HStack(spacing: 0) {
                        modeBtn("① 指定事件", mode == "events") { mode = "events" }
                        modeBtn("② 选分类", mode == "category") { mode = "category" }
                    }
                    .background(Color(uiColor: .secondarySystemBackground)).clipShape(Capsule())

                    if mode == "category" {
                        Text("可多选分类。不选任何分类则默认显示全部事件。")
                            .font(.system(size: 11)).foregroundColor(Theme.muted)
                        ForEach(store.categories.filter { $0.id != "cat:all" }) { c in
                            checkRow(color: Color(hex: c.color), label: c.name, on: cats.contains(c.id)) {
                                if let i = cats.firstIndex(of: c.id) { cats.remove(at: i) } else { cats.append(c.id) }
                            }
                        }
                    } else {
                        Text("勾选特定事件（可多选，按临近日期排序）。已选 \(events.count) 个。")
                            .font(.system(size: 11)).foregroundColor(Theme.muted)
                        ForEach(store.events) { ev in
                            checkRow(color: Color(hex: ev.color), label: ev.icon + " " + ev.title, on: events.contains(ev.id)) {
                                if let i = events.firstIndex(of: ev.id) { events.remove(at: i) } else { events.append(ev.id) }
                            }
                        }
                    }
                }.padding()
            }
            .navigationTitle(t.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let b = store.bindings[t.id] ?? .empty
                mode = b.mode
                events = b.eventIds
                cats = b.categoryIds
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        store.bindings[t.id] = WidgetBinding(mode: mode, eventIds: events, categoryIds: cats)
                        store.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func modeBtn(_ text: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 12, weight: on ? .bold : .regular))
                .foregroundColor(on ? Color(hex: "#5b7d55") : Theme.muted)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(on ? Color.white : Color.clear).clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func checkRow(color: Color, label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5).fill(color).frame(width: 18, height: 18)
                Text(label).font(.system(size: 14)).foregroundColor(Theme.ink).lineLimit(1)
                Spacer()
                Text(on ? "✓" : "").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.accent)
                    .frame(width: 22, height: 22)
                    .background(on ? Theme.accent.opacity(0.12) : Color.clear).clipShape(Circle())
            }.padding(.vertical, 7)
        }.buttonStyle(.plain)
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
