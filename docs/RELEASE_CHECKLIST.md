# Release Checklist

本文档用于区分“本机可运行版本”和“可对外分发版本”的收尾标准。

完整发版步骤见 [RELEASE_PROCESS.md](./RELEASE_PROCESS.md)。

## 每次提交前

- 确认没有把 token、账号凭据、签名证书或本地路径密钥提交进仓库。
- 确认 `.build/`、`dist/`、`.DS_Store` 等构建产物未进入 Git。
- 发版前确认 [VERSION](../VERSION) 中的 `APP_VERSION` 和 `BUILD_NUMBER` 已更新。
- 运行：

```bash
scripts/verify_release.sh
```

当前验证脚本会检查：

- 本机发布依赖命令是否存在。
- 仓库卫生状态：remote 不含凭据、构建产物未被 Git 跟踪、项目文件未出现常见凭据形状。
- debug 构建。
- release 构建。
- release `.app` 打包。
- `Info.plist` 格式。
- 本地 ad-hoc 签名完整性。
- `Resources/MacExplorer.icns` 已进入 app bundle。
- release zip 可生成且 SHA256 校验通过。
- release dmg 可生成，`hdiutil verify` 通过，且 SHA256 校验通过。
- release manifest 可生成，JSON 格式合法，并记录 zip/dmg 的大小和 SHA256。
- 工具栏不再使用会在中文环境显示成“甲乙丙”的 `textformat.abc` 图标。
- release app 可以启动并正常退出。
- Gatekeeper 当前状态。

## 本机可运行版本标准

- `swift build` 通过。
- `swift build -c release` 通过。
- `VERSION` 文件中的版本号会写入 app bundle 的 `Info.plist`。
- `scripts/package_app.sh release` 可以生成 `dist/MacExplorer.app`。
- `scripts/create_release_zip.sh release` 可以生成 release zip 和 `.sha256` 文件。
- `scripts/create_release_dmg.sh release` 可以生成 release dmg 和 `.sha256` 文件。
- `scripts/create_release_manifest.sh` 可以生成 release manifest JSON。
- `scripts/smoke_launch_app.sh` 可以启动并退出 release app。
- `codesign --verify --deep --strict --verbose=2 dist/MacExplorer.app` 通过。
- 应用可打开，主窗口无明显布局重叠。
- 默认中文界面可用，English 可切换。
- 文件区不显示大面积蓝色焦点框。
- 隐藏文件和 Quick Look 按钮图标不产生眼睛图标歧义。
- 扩展名显示开关不使用 `textformat.abc`。

## 对外分发版本仍需补齐

- 安装完整 Xcode，并确认 `xcodebuild` 可用。
- 配置 Developer ID Application 证书。
- 将 `SIGN_IDENTITY` 设置为 Developer ID 证书，而不是本地 ad-hoc 签名。
- 为 app 增加 hardened runtime 配置。
- 生成 release archive 或最终 `.app`。
- 使用 `notarytool` 提交 notarization。
- notarization 成功后 stapling：

```bash
xcrun stapler staple dist/MacExplorer.app
```

- 再次运行 Gatekeeper 评估：

```bash
spctl --assess --type execute --verbose=4 dist/MacExplorer.app
```

- 根据需要进一步美化 dmg 背景、窗口尺寸和 Applications 拖拽提示。
- 在干净用户环境中启动验证。

## 测试补齐计划

当前机器只有 Command Line Tools，`XCTest` 和 Swift `Testing` 相关模块没有完整暴露，因此暂不保留会失败的 test target。

安装完整 Xcode 后补齐：

- `FileItem` 扩展名显示规则测试。
- `FileSort` 排序方向测试。
- `PreferencesStore` 默认值和持久化测试。
- `BrowserStore` 标签页、收藏夹、最近访问逻辑测试。
- 文件操作服务的临时目录集成测试。
- 关键快捷键和窗口布局 UI 测试。

## 公开仓库维护

- 可单独运行仓库卫生检查：

```bash
scripts/check_repo_hygiene.sh
```

- 远程地址应保持为不含 token 的形式：

```text
https://github.com/yx-top/MacExplorer.git
```

- 推送时使用临时凭据或系统钥匙串，不要把 token 写入 `.git/config`。
- 若 token 曾经暴露在聊天、日志或终端历史中，应及时吊销或重置。
