# MyTV

MyTV 是一个 SwiftUI 构建的 Trakt.tv 观影助手，提供 macOS 应用和 iPhone/iPad Universal iOS 应用。它可以浏览电影和剧集、查看详情、同步 Trakt 观看记录、观看清单、收藏、日历和评论等数据。

## 功能

- Trakt OAuth 登录，使用 PKCE 授权流程
- 首页推荐、趋势、继续观看和本月观影统计
- 电影、剧集、分类、搜索、日历等浏览入口
- 观看清单、观看历史、我的片库和待看进度
- 电影、剧集、季和单集详情页
- Trakt 评论读取与发布
- 媒体助手订阅、下载任务、消息和通知
- 图片和 API 响应缓存

## 环境要求

- macOS 15.0 或更高版本（macOS 版）
- iOS/iPadOS 18.0 或更高版本（iOS 版）
- Xcode 16 或更高版本
- XcodeGen

如果本机没有安装 XcodeGen，构建脚本会尝试通过 Homebrew 自动安装。

如果使用较新的 Xcode，请在 `Xcode -> Settings -> Components` 中安装对应的 iOS Platform / Simulator Runtime，例如 iOS 26.5；否则 iOS simulator build 可能找不到目的地。

## 使用自己的 Trakt Client ID

MyTV 需要一个 Trakt API 应用的 `client_id` 才能完成登录和 API 请求。你可以在 Trakt 的 API 应用管理页面创建应用，并把获得的 `client_id` 配置为 `TRAKT_CLIENT_ID`。

本地推荐使用 `.env.local`：

```bash
TRAKT_CLIENT_ID=your_client_id
DEVELOPMENT_TEAM=your_team_id # 可选，真机调试时用于固定签名 Team
```

`.env.local` 已被 `.gitignore` 忽略，适合放本机配置。请不要把 `client_secret`、access token 或 refresh token 提交到仓库。

如果直接从 Xcode GUI 运行，请先把 `.env.local` 同步成 Xcode 能读取的本地 xcconfig：

```bash
bash scripts/sync-local-xcconfig.sh
xcodegen generate
```

生成的 `MyTV/Config/Local.xcconfig` 会被 Git 忽略，XcodeGen 会通过 `MyTV/Config/MyTV.xcconfig` 自动引用它。

也可以在执行构建时临时传入：

```bash
TRAKT_CLIENT_ID=your_client_id bash scripts/build.sh
```

## 本地构建

生成 Xcode 项目并构建 macOS Release 包：

```bash
bash scripts/build.sh
```

脚本会生成：

- `build/Build/Products/Release/MyTV.app`
- `build/Build/Products/Release/MyTV-macOS.dmg`
- `build/Build/Products/Release/MyTV-macOS.zip`

`build/` 是构建产物目录，已被 Git 忽略。

直接构建 macOS app：

```bash
TRAKT_CLIENT_ID=your_client_id xcodebuild -project MyTV.xcodeproj -scheme MyTV -destination 'platform=macOS' build
```

构建 iOS Universal app 的 Simulator 版本：

```bash
TRAKT_CLIENT_ID=your_client_id xcodebuild -project MyTV.xcodeproj -scheme MyTViOS -destination 'generic/platform=iOS Simulator' build
```

## GitHub Actions

CI 构建需要配置仓库 Secret：

```text
TRAKT_CLIENT_ID
```

在 GitHub 仓库中进入 `Settings -> Secrets and variables -> Actions -> Secrets` 添加。不要放在 repository variables 里；workflow 只通过进程环境变量把它提供给 Xcode，避免 `xcodebuild` 命令行日志打印明文。

## 项目结构

```text
MyTV/
  API/          Trakt API 请求封装
  App/          共享入口、状态、路由和常量
  Components/   复用 UI 组件
  iOS/          iOS App 入口、Info.plist 和 iPhone/iPad 外壳
  Models/       SwiftData 模型和 DTO
  Services/     认证、缓存、图片和翻译服务
  Utilities/    窗口和视觉辅助工具
  ViewModels/   页面状态与业务逻辑
  Views/        SwiftUI 页面
scripts/
  build.sh      Release 构建、DMG 和 ZIP 打包脚本
project.yml     XcodeGen 项目配置
```

## 安全说明

- `client_id` 会在构建产物中出现，这是原生 OAuth 客户端的正常行为。
- 不要在 macOS app、源码或 CI 日志中放置 `client_secret`。
- CI 中的 `TRAKT_CLIENT_ID` 应配置为 GitHub Actions Secret，避免出现在执行日志中。
- 用户登录后的 access token 和 refresh token 不应提交到仓库。
- 本地配置文件使用 `.env.local`，并确保它保持在 Git 忽略列表中。
