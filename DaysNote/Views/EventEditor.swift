import SwiftUI

struct EventEditor: View {
    @EnvironmentObject var store: Store
    let eventId: String?
    let onBack: () -> Void
    let onSaved: (String) -> Void

    @State private var title = ""
    @State private var date = Date()
    @State private var lunar = false
    @State private var icon = "📌"
    @State private var color = Constants.cardColors[0]
    @State private var note = ""
    @State private var categoryId = "cat:all"
    @State private var displayMode: CountMode = .countdown
    @State private var repeatMode: RepeatMode = .none
    @State private var showInTimeline = true
    @State private var showIconPicker = false

    private var isEdit: Bool { eventId != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavBar(title: isEdit ? "编辑事件" : "新增事件", back: onBack) { EmptyView() }

                // 日期区
                SectionTitle(text: "日期")
                CardPanel {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    RowSwitch(title: "农历日期", subtitle: lunar ? LunarCalendar.lunarText(DateUtils.toISO(date)) : nil, on: $lunar)
                }

                // 信息区
                SectionTitle(text: "信息")
                CardPanel {
                    HStack {
                        Text("图标").font(.system(size: 14)).frame(width: 68, alignment: .leading)
                        Button(action: { showIconPicker.toggle() }) {
                            Text(icon).font(.system(size: 24)).frame(width: 40, height: 40)
                                .background(Color(uiColor: .tertiarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Spacer()
                    }
                    if showIconPicker {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                            ForEach(["📌","❤️","🍒","🎂","💍","🧧","🎊","🏠","🐱","🐶","👶","🎓","💼","✈️","🌍","⭐️","🎉","🎁","🌹","☀️"], id: \.self) { e in
                                Button(action: { icon = e; showIconPicker = false }) { Text(e).font(.system(size: 22)) }
                            }
                        }
                    }
                    Divider()
                    HStack {
                        Text("名称").font(.system(size: 14)).frame(width: 68, alignment: .leading)
                        TextField("事件名称", text: $title).textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("分类").font(.system(size: 14)).frame(width: 68, alignment: .leading)
                        Picker("", selection: $categoryId) {
                            ForEach(store.categories) { c in Text(c.name).tag(c.id) }
                        }.pickerStyle(.menu)
                    }
                    HStack {
                        Text("颜色").font(.system(size: 14)).frame(width: 68, alignment: .leading)
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(Constants.cardColors, id: \.self) { c in
                                    Circle().fill(Color(hex: c)).frame(width: 26, height: 26)
                                        .overlay(Circle().stroke(color == c ? Theme.accent : Color.clear, lineWidth: 2))
                                        .onTapGesture { color = c }
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("备注").font(.system(size: 14))
                        TextEditor(text: $note).frame(height: 70)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    }
                }

                // 显示模式区
                SectionTitle(text: "首页显示")
                CardPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("显示为").font(.system(size: 13)).foregroundColor(Theme.muted)
                        Picker("", selection: $displayMode) {
                            Text("倒数").tag(CountMode.countdown)
                            Text("正数").tag(CountMode.countup)
                            Text("两者都显示").tag(CountMode.both)
                        }.pickerStyle(.segmented)
                        Divider()
                        Text("重复").font(.system(size: 13)).foregroundColor(Theme.muted)
                        Picker("", selection: $repeatMode) {
                            Text("不重复").tag(RepeatMode.none)
                            Text("每年").tag(RepeatMode.yearly)
                        }.pickerStyle(.segmented)
                        Divider()
                        RowSwitch(title: "显示到时间轴", subtitle: nil, on: $showInTimeline)
                    }
                }

                Button(action: save) {
                    Text(isEdit ? "保存修改" : "添加事件").font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundColor(.white).background(Color(hex: "#6f8a6a"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14).padding(.bottom, 30)
        }
        .onAppear { load() }
    }

    private func load() {
        guard let id = eventId, let ev = store.events.first(where: { $0.id == id }) else { return }
        title = ev.title
        date = DateUtils.fromISO(ev.date)
        lunar = ev.lunar
        icon = ev.icon
        color = ev.color
        note = ev.note
        categoryId = ev.categoryId
        displayMode = ev.displayMode ?? DateUtils.inferMode(ev)
        repeatMode = ev.repeatMode
        showInTimeline = ev.showInTimeline ?? true
    }

    private func save() {
        let iso = DateUtils.toISO(date)
        if let id = eventId, var ev = store.events.first(where: { $0.id == id }) {
            ev.title = title; ev.date = iso; ev.lunar = lunar; ev.icon = icon; ev.color = color
            ev.note = note; ev.categoryId = categoryId; ev.displayMode = displayMode
            ev.repeatMode = repeatMode; ev.showInTimeline = showInTimeline
            store.updateEvent(id, patch: ev)
            onSaved(id)
        } else {
            let ev = EventItem(id: "", title: title, date: iso, lunar: lunar, categoryId: categoryId,
                               icon: icon, color: color, note: note, order: nowMs(), repeatMode: repeatMode,
                               showInTimeline: showInTimeline, displayMode: displayMode, createdAt: 0, updatedAt: 0)
            let saved = store.addEvent(ev)
            onSaved(saved.id)
        }
    }
}
