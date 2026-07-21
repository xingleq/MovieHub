---
name: architecture
description: >-
  MovieHub 架构与编码规范。涉及以下改动前必读：新增或修改媒体源（NAS/WebDAV/网盘，
  core/media/sources）、平台能力或平台适配（core/system、Windows/Android/TV 专属行为）、
  新增页面/组件/控制器/Store、播放器相关改动。规定 MediaSource 与 PlatformServices
  的接口契约、实现清单、控制器/Store/UI 标准，以及 Android/TV/网盘的既定路线。
---

# MovieHub 架构规范

## 分层与依赖方向

```
lib/
├ app/                  控制器（ChangeNotifier）与 Scope（InheritedWidget）
├ core/                 领域逻辑；禁止 import Flutter widgets（flutter/services 通道除外）
│   ├ media/            媒体库：扫描、文件名解析、分组、持久化
│   │   └ sources/      媒体源抽象（MediaSource）与实现
│   ├ system/           平台服务接口 + 各平台实现（windows/ …）
│   ├ tmdb/  images/  settings/  gacha/
├ ui/                   页面（pages）、组件（widgets）、播放器（player）
└ theme/                AppTokens / AppSpacing / AppRadius / AppDurations
```

依赖只能向下：ui → app → core。core 内部不得反向依赖 app 或 ui。

## 1. 媒体源规范（MediaSource）

接口在 `lib/core/media/sources/media_source.dart`。"影视文件从哪来"的一切差异都必须在这个接口后面。

### 接口契约

| 成员 | 语义 |
|---|---|
| `id` | 稳定标识，随 `MediaItem.sourceId` 持久化，永不改名；`'local'` 为内置本地源保留 |
| `listVideos(root)` | 枚举 root 下全部视频；**不抛异常**——读不到的根/文件进 `skippedPaths` |
| `playbackUriOf(path)` | 播放器实际打开的地址；必须廉价且同步，鉴权握手放在实现自身的生命周期里 |
| `identityKeyOf(path)` | 源内路径身份键；大小写敏感源必须原样返回，大小写不敏感源可折叠大小写 |

### 数据契约

- `MediaSourceEntry` / `MediaSourceListing` 保持纯数据（String/int/DateTime/List），listing 会跨 isolate 传递。
- 路径是源原生格式，`/` 与 `\` 都可能出现；统一用 media_source.dart 里的
  `fileNameOf` / `fileExtensionOf` / `parentPathOf` / `isVideoFilePath`，不要自己写字符串切割。
- 阻塞 I/O 是源的实现细节（`LocalFileSource` 自己开 isolate）；`MediaScanner` 只做纯计算。

### 新增一个源（如 WebDAV）

1. `sources/` 下新建 `xxx_source.dart` 实现 `MediaSource`；
2. id 唯一且稳定——可配置的源在配置创建时生成 id 并持久化到设置；
3. 扫描路径与播放地址分离：不假设能 stat 每个文件，`playbackUriOf` 返回流地址；
4. **不改 MediaScanner**——剧集推断/移动检测/元数据继承是源无关的。若发现改不动，
   说明抽象漏了，先回头改接口，不要在 scanner 里加 if；
5. 同步完成下面"第二源三件事"。

### 第二个源落地时必须同时完成（单源期欠下的债，代码注释处有标记）

- `MediaItem.identity`、分组、导航、更新与 SQLite items 行键统一使用 `(sourceId, path)`；
- `LibraryController.playbackUriOf` / `openItemLocation`：按 `item.sourceId` 查找源；
  "打开文件位置"仅对 local 源的条目显示；
- 设置页增加源管理 UI。

### 禁止

- core/media 与 ui 层禁止对 `item.path` 使用 `File()` / `Directory()`——
  本地文件语义只存在于 `LocalFileSource` 与 `ShellIntegration`；
- 禁止给 `MediaItem` 新增仅对某一种源有意义的字段。

## 2. 平台服务规范（PlatformServices）

接口在 `lib/core/system/platform_services.dart`：`WindowControls` / `SessionEvents` /
`StartupService` / `AppPaths` / `ShellIntegration` + `PlatformServices` 聚合。

### 铁律

- 全仓库唯一允许按 OS 分支的位置是 `PlatformServices.forCurrentPlatform()`。
  业务代码不写 `Platform.isXxx`、不开 `MethodChannel`、不 `Process.run`、不读平台专属环境变量。
- 例外：与 OS 无关的 dart:io 用法（如 HttpClient 的系统代理解析）不算平台耦合。

### 新增一项平台能力

1. platform_services.dart 加接口 + 通用回退实现（No-op / Unsupported / Generic 三选一，回退实现写在同文件，作为每个移植目标的最低契约）；
2. `windows/` 下加 `WindowsXxx` 实现；
3. `PlatformServices` 加字段，`forCurrentPlatform` 两个分支各接一个实现。

### 新增一个平台（Android/TV）

1. `core/system/android/` 放实现；
2. `forCurrentPlatform` 加分支；
3. 路径需异步解析时（path_provider）：在 main() bootstrap 阶段 await 一次，
   把解析结果传进实现的构造函数——`AppPaths` 接口保持同步，不把 Future 传染给 store。

### 注入约定

- 控制器：构造函数可选参数注入接口，默认 `?? PlatformServices.instance.xxx`
  （参照 `SettingsController` 的 `startupService`）；测试传 fake。
- Widget：直接读 `PlatformServices.instance`；测试可整体替换 `instance`。

### 自检

改完跑（预期只命中 platform_services.dart 与 windows/）：

```
grep -rn "Platform\.is\|MethodChannel\|Process\.run\|Process\.start" lib --include="*.dart"
```

## 3. 控制器 / Store / UI 标准

### 控制器（app/）

- `ChangeNotifier`；UI 无关——永不持有 BuildContext，导航留在 widget 层；
- `_disposed` 标记 + 重写 `notifyListeners()` 守卫（参照 LibraryController）；
- 错误面：`_error` 字段 + `clearError()`；消息格式 `'动作失败：$error'`，中文；
- 依赖注入统一 `Xxx? dep` 可选参数 + `?? 默认实现`。

### Store（core/）

- 构造统一 `Directory? storageDirectory`，默认 `PlatformServices.instance.paths.appDataDirectory`；
- 写粒度：整库替换（save）只用于扫描/迁移；日常单条变更走 upsertItems，禁止为改一条重写全库；
- 大批量写入在后台 isolate 开独立连接（参照 `MediaLibrarySqliteStore.save`）。

### UI（ui/）

- 颜色只取 `AppTokens.of(context)`（dark/light 各一套），间距 `AppSpacing`、圆角 `AppRadius`、
  动画时长 `AppDurations`；禁止新增硬编码颜色（播放器纯黑底除外）；
- 文案、tooltip 全中文；
- 悬停交互用 `Hoverable`，按钮用 `JellyButton`，错误提示用 `MessageBanner`；
  造新组件前先确认 ui/widgets 没有等价物；
- rebuild 边界：MaterialApp 只由 SettingsController 驱动；库数据变更（扫描/匹配/进度）
  不得触达根；页面通过 `LibraryScope` / `SettingsScope` 取控制器。

### 播放器

- 引擎只有 media_kit 的 `Player` 一份，任何平台不得再造播放器类；
- 平台/形态差异只进**控件层**（现为 MaterialDesktopVideoControls；TV/触摸做新的 controls 变体，
  不动引擎与会话逻辑）；
- 打开地址必须走 `playbackUriOf` 回调（由 LibraryController 按源解析），不得直接用 `item.path`。

## 4. 既定路线（动工时按此执行，不再重新论证）

- **Android 动工时**：从 PlayerPage 抽出平台无关的 PlayerSession
  （轨道偏好、进度保存、自动连播、锁屏暂停）；pubspec 加 `media_kit_libs_android_video`；
  `AppPaths` 出 Android 实现（path_provider，bootstrap 解析）。
- **TV**：焦点/D-pad 是 ui/ 层的形态变体（focus traversal + 10-foot 布局），
  不是 platform 文件夹能解决的问题。
- **WebDAV/网盘源**：接口已按"第二实现是 HTTP 流"设计——按第 1 节新增源清单执行。

## 5. 验证

- `flutter analyze` / `flutter test` 生成命令交给用户执行并等待反馈结果，不要自动运行；
- 动过 scanner / source / store 的改动，提醒用户手动重扫媒体库验证
  （旧库条目的 sourceId 自动回填 `'local'`，无需迁移）。
