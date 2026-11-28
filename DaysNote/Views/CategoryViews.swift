import SwiftUI

struct CategoryGrid: View {
    @EnvironmentObject var store: Store
    @Binding var current: String
    let onManage: () -> Void
    let onPick: (String) -> Void

    private var columns: [GridItem] { [GridItem(.flexible()), GridItem(.flexible())] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavBar(title: "选择分类", back: nil) {
                    Button(action: onManage) { Text("管理").font(.system(size: 14)) }
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.categories) { c in
                        Button(action: { onPick(c.id) }) {
                            VStack(alignment: .leading, spacing: 10) {
                                Circle().fill(Color(hex: c.color)).frame(width: 30, height: 30)
                                Text(c.name).font(.system(size: 16, weight: .semibold))
                                Text("\(c.id == Festivals.categoryId ? Festivals.festivalEvents().count : store.events.filter { c.id == "cat:all" || $0.categoryId == c.id }.count) 个事件")
                                    .font(.system(size: 11)).foregroundColor(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(current == c.id ? Color(hex: "#6f8a6a") : Color.clear, lineWidth: 2))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .foregroundColor(Theme.ink)
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 30)
        }
    }
}

struct CategoryList: View {
    @EnvironmentObject var store: Store
    let onDone: () -> Void
    @State private var newName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavBar(title: "管理分类", back: nil) {
                    Button(action: onDone) { Text("完成").font(.system(size: 14)) }
                }
                SectionTitle(text: "现有分类")
                CardPanel {
                    ForEach(store.categories) { c in
                        HStack(spacing: 10) {
                            Circle().fill(Color(hex: c.color)).frame(width: 18, height: 18)
                            TextField("名称", text: Binding(
                                get: { c.name },
                                set: { store.updateCategory(c.id, name: $0, color: c.color) }
                            )).textFieldStyle(.plain).font(.system(size: 15))
                            if c.builtin != true {
                                Button(action: { store.removeCategory(c.id) }) {
                                    Image(systemName: "trash").font(.system(size: 14)).foregroundColor(Theme.accent)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                    HStack {
                        TextField("新分类名称", text: $newName).textFieldStyle(.roundedBorder)
                        Button("添加") {
                            if !newName.isEmpty { _ = store.addCategory(name: newName); newName = "" }
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 30)
        }
    }
}
