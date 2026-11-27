# DaysNote 原生 iOS 版（SwiftUI）

这是**完整原生重写版本**：纯 Swift + SwiftUI，没有 WebView、WKWebView 或任何 Web 界面。
所有 UI 用 SwiftUI 绘制，数据用 Foundation 持久化到 App Group 容器，系统小组件用 WidgetKit 原生实现。

## 功能（与 Web 版逐项对齐）

- 事件：新增 / 编辑 / 删除，图标（emoji）、颜色、分类、备注、农历、每年重复、首页显示模式（倒数 / 正数 / 两者）
- 首页：「今年剩余」动态卡片（跨年自动切换）、按显示模式分组的倒数 / 正数列表
- 时间轴：按年份浏览，农历 / 法定节日（可关），事件无限滚动
- 侧边栏：搜索、分类筛选、底部独立回收站入口
- 回收站：本机已删除 + 云端已删除（点开从 CouchDB 修订链回捞删除前正文）、勾选恢复、6 个月保留期、永久清除（`_purge`）
- 同步：CouchDB / WebDAV 双后端、三方合并、版本控制、冲突裁决、CouchDB 优先
- 强制覆盖：本地覆盖服务器 / 服务器覆盖本地（带风险确认弹窗）
- 设置：白天 / 夜间 / 自动、四种背景、iCloud 开关、自动同步、每月备份、JSON 导入导出、AI 助手（工具调用增删改）
- 系统小组件：6 款模板（小 / 中 / 大），分类多选 / 指定事件绑定，假日组件每月联网更新国务院放假安排
- 升级无损：App Group 内 JSON 持久化，覆盖安装数据保留；schema 7 迁移

## 编译（必须 macOS + Xcode 16）

Linux 环境无法编译 Swift / SwiftUI（没有 Xcode、没有 iOS SDK），因此这里只交付**完整工程源码**。
在 Mac 上：

```bash
cd DaysNoteNative
chmod +x build_native_ipa.sh
./build_native_ipa.sh          # 产出 DaysNote-native-unsigned.ipa
```

脚本会归档、拆出 `.app`、移除签名、打包未签名 IPA 并校验 Widget 扩展。
安装前需用你自己的证书重签（`codesign` 或 AltStore / 爱思助手等）。

也可以在 Xcode 里打开 `DaysNote.xcodeproj`，选择 `DaysNote` scheme，直接 Run 到模拟器或真机。

## 目录结构

```
DaysNoteNative/
  DaysNote.xcodeproj/project.pbxproj    Xcode 工程（App + Widget 两个 target）
  DaysNote/
    DaysNoteApp.swift                    App 入口
    Models.swift                         数据模型与常量
    DateUtils.swift                      日期/农历/节日（系统 Chinese Calendar）
    SyncEngine.swift                     CouchDB/WebDAV 同步、冲突、覆盖、回收站
    Store.swift                          全局状态、持久化、CRUD、备份
    HolidayService.swift                 假日数据（每月联网 + 缓存 + 农历兜底）
    AIService.swift                      AI 助手（OpenAI 兼容工具调用）
    Views/                               全部 SwiftUI 页面
    Assets.xcassets                       App 图标
  DaysNoteWidget/
    DaysNoteWidget.swift                 6 款 WidgetKit 组件
  build_native_ipa.sh                    一键编译脚本
  README.md                               本说明
```

## 工程说明

- Bundle ID：`com.daysnote.app`，Widget：`com.daysnote.app.DaysNoteWidget`
- App Group：`group.com.daysnote.app`（App 与 Widget 共享数据）
- 最低系统：iOS 17.0
- 版本：3.0.0（build 31）
