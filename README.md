# MacExplorer

MacExplorer 是一个面向 macOS 的 Windows Explorer 风格文件管理器。项目目标不是 MVP 或演示程序，而是一个可以长期日常使用、界面美观、操作习惯接近 Windows 文件资源管理器的原生 macOS 应用。

## 当前能力

- 原生 SwiftUI + AppKit macOS 应用。
- 真实目录读取，支持详情列表和图标网格视图。
- 返回、前进、上一级、刷新、可编辑地址栏和面包屑路径。
- 标签页、标签页恢复、标签页拖拽排序和右键管理。
- 支持新窗口，窗口尺寸和位置会自动恢复。
- 快速访问、收藏夹、最近访问、系统位置、动态外接卷和可拖拽宽度侧边栏。
- 收藏夹持久化、右键管理、拖入目录添加和拖拽排序。
- 显示隐藏文件、显示/隐藏文件扩展名、排序菜单、文件夹优先、目录级视图/排序偏好和搜索筛选。
- 当前目录搜索和递归搜索。
- 新建文件夹、新建空文件、复制、剪切、粘贴、重命名、移到废纸篓、永久删除和打开方式选择。
- 文件操作冲突处理、进度状态、操作中心和取消复制/移动任务。
- Quick Look、右侧详情/预览面板和异步文件夹统计。
- 文件拖拽导出和中央文件区拖放接收。
- 中文默认界面，支持 English 切换。
- 自定义应用图标和本地 `.app` 打包脚本。

## 和同类工具的区别

MacExplorer 的定位不是替代所有专业文件管理器，也不是做一个 Finder 换皮。它更聚焦一个具体人群：从 Windows 转到 macOS、但仍希望保留 Windows Explorer 操作习惯的用户。

和 Finder 相比：

- 更强调 Windows Explorer 风格的信息结构：标签栏、地址栏、侧边栏、详情列表、图标网格、状态栏和右侧详情/预览面板组成一个完整工作台。
- 默认交互更靠近 Windows 习惯，例如 `F2` 重命名、`Delete` 移到废纸篓、路径输入、上一级、刷新、文件区快捷键和更直观的列表操作。
- 最近访问、收藏夹、系统位置、外接卷和标签页被放在同一个文件工作流里，而不是分散在多个系统入口中。

和双栏/专业文件管理器相比：

- 不以双栏、批量同步、FTP/SFTP、压缩包管理等重型能力为核心，而是优先把日常浏览、搜索、复制、移动、预览和标签页体验做顺。
- 使用 SwiftUI + AppKit 构建，尽量保持 macOS 原生性能、图标、Quick Look 和系统文件能力。
- 默认中文界面，同时支持英文切换，适合中文 macOS 用户直接上手。

和轻量脚本或 Demo 相比：

- 项目已经包含真实文件操作、冲突处理、递归搜索、操作中心、拖放、Quick Look、目录监听、多窗口、发布脚本和开源协作模板。
- 发布流程保留本地构建、校验、DMG、SHA256 和仓库卫生检查，方便持续迭代。

完整计划和进度见 [DEVELOPMENT_PLAN.md](./DEVELOPMENT_PLAN.md)。

版本变更记录见 [CHANGELOG.md](./CHANGELOG.md)。

当前版本发布说明见 [docs/releases/v0.1.0.md](./docs/releases/v0.1.0.md)。

发布收尾标准见 [docs/RELEASE_CHECKLIST.md](./docs/RELEASE_CHECKLIST.md)。

完整发版流程见 [docs/RELEASE_PROCESS.md](./docs/RELEASE_PROCESS.md)。

## 下载最新安装包

开源仓库仅保留当前最新 DMG 安装包和对应 SHA256 校验文件：

| 目标设备 | 安装包 | 校验文件 |
| --- | --- | --- |
| Apple Silicon | [MacExplorer-0.1.0-25-macos.dmg](./release-artifacts/MacExplorer-0.1.0-25-macos.dmg) | [SHA256](./release-artifacts/MacExplorer-0.1.0-25-macos.dmg.sha256) |
| Intel | [MacExplorer-0.1.0-25-macos-x86_64.dmg](./release-artifacts/MacExplorer-0.1.0-25-macos-x86_64.dmg) | [SHA256](./release-artifacts/MacExplorer-0.1.0-25-macos-x86_64.dmg.sha256) |
| Universal | [MacExplorer-0.1.0-25-macos-universal.dmg](./release-artifacts/MacExplorer-0.1.0-25-macos-universal.dmg) | [SHA256](./release-artifacts/MacExplorer-0.1.0-25-macos-universal.dmg.sha256) |

校验示例：

```bash
cd release-artifacts
shasum -a 256 -c MacExplorer-0.1.0-25-macos.dmg.sha256
```

当前安装包仍使用本地 ad-hoc 签名，首次运行时可能需要在 macOS 安全设置中手动允许。后续接入 Developer ID 签名和 notarization 后再作为正式对外分发包。

## 环境要求

- macOS 14 或更高版本。
- Swift 6 toolchain。
- 当前项目可直接用 Command Line Tools 构建。
- 如需完整 Xcode 调试、Developer ID 签名和 notarization，建议安装完整 Xcode。

## 构建

```bash
swift build
```

Release 构建：

```bash
swift build -c release
```

## 版本号

版本号集中在 [VERSION](./VERSION)：

```text
APP_VERSION=0.1.0
BUILD_NUMBER=25
```

`scripts/package_app.sh` 会读取该文件写入 `Info.plist`。zip、dmg 和 manifest 的文件名会继续从生成后的 `Info.plist` 读取版本号。

## 打包本地应用

生成 debug app：

```bash
scripts/package_app.sh debug
```

生成 release app：

```bash
scripts/package_app.sh release
```

生成指定架构 app：

```bash
scripts/package_app.sh release arm64
scripts/package_app.sh release x86_64
scripts/package_app.sh release universal
```

生成 release zip 和 SHA256 校验文件：

```bash
scripts/create_release_zip.sh release
```

生成指定架构 release zip：

```bash
scripts/create_release_zip.sh release x86_64
scripts/create_release_zip.sh release universal
```

生成 release dmg 和 SHA256 校验文件：

```bash
scripts/create_release_dmg.sh release
```

生成指定架构 release dmg：

```bash
scripts/create_release_dmg.sh release x86_64
scripts/create_release_dmg.sh release universal
```

生成 release manifest：

```bash
scripts/create_release_manifest.sh
```

生成指定架构 release manifest：

```bash
scripts/create_release_manifest.sh x86_64
scripts/create_release_manifest.sh universal
```

输出位置：

```text
dist/MacExplorer.app
dist/MacExplorer-0.1.0-25-macos.zip
dist/MacExplorer-0.1.0-25-macos.zip.sha256
dist/MacExplorer-0.1.0-25-macos.dmg
dist/MacExplorer-0.1.0-25-macos.dmg.sha256
dist/MacExplorer-0.1.0-25-macos.manifest.json
dist/MacExplorer-0.1.0-25-macos-x86_64.dmg
dist/MacExplorer-0.1.0-25-macos-universal.dmg
```

`dist/` 是构建产物，已被 `.gitignore` 排除。

## 发布前验证

单独检查仓库卫生：

```bash
scripts/check_repo_hygiene.sh
```

运行完整本地验证：

```bash
scripts/verify_release.sh
```

验证内容包括：

- 仓库卫生检查
- debug 构建
- release 构建
- release `.app` 打包
- `Info.plist` 校验
- ad-hoc 签名校验
- bundle 内图标资源一致性
- release zip 和 SHA256 校验
- release dmg 和 SHA256 校验
- release manifest JSON 校验
- 旧版 `textformat.abc` 工具栏图标扫描
- release app 启动冒烟检查
- Gatekeeper 评估提示

当前使用本地 ad-hoc 签名，`spctl` Gatekeeper 评估会提示 rejected，这是未做 Developer ID 签名和 notarization 前的预期状态。

## 生成应用图标

应用图标由 Swift 脚本可重复生成：

```bash
swift scripts/generate_app_icon.swift
```

生成内容：

- `Resources/MacExplorer.iconset/`
- `Resources/MacExplorer.icns`

## 仓库规则

已忽略：

- `.build/`
- `.swiftpm/`
- `dist/`
- `.DS_Store`
- Xcode 用户态文件
- 除当前最新 DMG 安装包外的 `release-artifacts/` 文件

不要提交本地 token、账号凭据、临时构建产物、签名证书或 notarization 密钥。

可用 `scripts/check_repo_hygiene.sh` 检查 remote、被跟踪产物和常见凭据形状。

## 开源协作

- 许可证：[MIT License](./LICENSE)。
- 贡献说明：[CONTRIBUTING.md](./CONTRIBUTING.md)。
- 安全问题报告：[SECURITY.md](./SECURITY.md)。
- GitHub 已准备 issue 模板、PR 模板和基础 Swift 构建 workflow。

## 当前发布限制

- 尚未配置 Developer ID 签名。
- 尚未配置 notarization。
- 当前 Command Line Tools 环境未完整暴露 `XCTest` / Swift `Testing` 所需模块，因此暂不保留会失败的测试 target。
- 后续如果安装完整 Xcode，可以再补单元测试 target、UI 测试和 notarized release 流程。
