# MovieHub

MovieHub 是一个面向 Windows 的本地私人影视库。它直接读取电脑中的电影、动画和电视剧文件，生成海报墙并记录观看进度；不需要部署服务器、NAS 或 Docker。

> 本项目目前以 Windows 桌面端为目标平台。

## 功能概览

- 支持添加多个本地影视目录，并扫描 `mp4`、`mkv`、`avi`、`mov`、`flv`、`ts`、`m2ts` 视频文件。
- 根据文件名识别电影及 `S01E01` / `1x01` 格式的剧集，自动按剧集归组。
- 使用 TMDB 获取片名、海报、背景图、简介、评分、类型、导演、演员和片长。
- 支持单项匹配、剧集整组匹配、批量匹配和手动搜索匹配。
- 海报和背景图会缓存在本机；扫描目录时会尽量保留已有的刮削信息、收藏状态和播放进度。
- 首页提供继续观看、最近加入、动画、电影、电视剧和收藏入口。
- 使用 `media_kit` 播放本地视频，支持暂停、进度拖动、音量、倍速、截图、全屏、字幕/音轨切换和自动下一集。
- 自动保存播放进度；未看完内容可从首页继续播放。
- 支持深色、浅色和跟随系统主题，可选本地背景图片。
- 支持 Windows 登录后自动启动。

## 首次使用

1. 启动应用后进入左侧导航的“设置”。
2. 在“媒体库”中点击“添加目录”，可重复添加多个影视文件夹。
3. 点击“重新扫描”，等待本地视频出现在首页或对应分类中。
4. 如需自动补全海报和资料，在“刮削”中填写 TMDB Read Access Token，然后点击“匹配未刮削条目”。
5. 点击海报进入详情页；电影可直接播放，电视剧可在详情页选择集数。

## TMDB 配置

MovieHub 不内置 TMDB 凭据。请自行在 [TMDB API 设置](https://www.themoviedb.org/settings/api) 创建并使用 **API Read Access Token**。

在应用内依次打开“设置” -> “刮削”，填写令牌并保存即可。令牌仅保存于当前 Windows 用户的本地应用数据目录，不会写入源代码或 Git 仓库。

如果 TMDB 请求超时，而浏览器已通过代理正常访问 TMDB，可在同一页面填写本机代理，例如：

```text
127.0.0.1:7890
```

请确认代理软件开启了本地 HTTP 代理端口；仅能在浏览器中访问并不一定代表桌面应用会自动使用该代理。

## 本地数据与截图

Windows 下，应用数据默认保存在：

```text
%APPDATA%\MovieHub
```

其中包含媒体库 SQLite 数据库、TMDB 设置和图片缓存。播放器截图默认保存到：

```text
%USERPROFILE%\Pictures\MovieHub
```

删除应用程序不会自动删除这些个人数据；需要重置资料时可手动删除上述 `MovieHub` 数据目录。

## 开发环境

- Flutter SDK：`3.44.6` 或兼容的 Flutter stable 版本
- Dart SDK：由 Flutter 自带
- Windows 10/11
- Visual Studio Community / Build Tools，并安装“使用 C++ 的桌面开发”工作负载
  - MSVC C++ x64/x86 生成工具
  - Windows SDK
  - CMake Tools for Windows

检查环境：

```powershell
flutter doctor
```

安装依赖并以 Windows 桌面端启动：

```powershell
flutter pub get
flutter run -d windows
```

常用质量检查：

```powershell
dart format lib test
dart analyze
flutter test
```

## 打包发布

构建 Windows Release：

```powershell
flutter build windows --release
```

生成文件位于：

```text
build\windows\x64\runner\Release
```

分发时请复制整个 `Release` 文件夹，不能只复制 `moviehub.exe`，因为播放器和 Flutter 运行时依赖其中的 DLL 文件。

项目还提供 Inno Setup 安装脚本：`installer/MovieHub.iss`。详细打包说明见 [BUILD_GUIDE.md](BUILD_GUIDE.md)。

## 当前限制与后续方向

- 目前只支持 Windows，本地媒体库不提供局域网或云端同步。
- 扫描需要手动触发，尚未实现目录实时监控。
- 已支持的本地视频格式以扫描器列表为准，暂不支持 ISO。
- AI 推荐、自动下载字幕、Trakt/豆瓣同步、Jellyfin/Plex 导入和移动端同步仍属于后续规划。

## 技术栈

- Flutter / Dart
- SQLite
- media_kit（基于 libmpv）
- TMDB API

## 隐私说明

MovieHub 的媒体索引、观看记录、收藏、TMDB 令牌和图片缓存均保存在本机。仅在你主动使用 TMDB 刮削或下载海报/背景图时，应用才会与 TMDB 通信。
