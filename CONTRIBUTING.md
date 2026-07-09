# Contributing

感谢你愿意参与 MacExplorer。这个项目的目标是做一个更接近 Windows Explorer 操作习惯、同时保持 macOS 原生质感的文件管理器。

## 开发环境

- macOS 14 或更高版本
- Swift 6 toolchain
- Command Line Tools 或完整 Xcode

常用验证命令：

```bash
swift build
swift build -c release
scripts/check_repo_hygiene.sh
```

## 提交前检查

- 不提交 `.build/`、`.swiftpm/`、`dist/`、Xcode 用户态文件。
- 不提交 token、账号凭据、签名证书、notarization 密钥或私有本地路径密钥。
- `release-artifacts/` 只保留当前最新公开 DMG 安装包和对应 `.sha256`。
- UI 变更要尽量保持 Windows Explorer 风格、macOS 原生控件质感和中英文文案一致。
- 文件操作、删除、覆盖、拖拽、搜索等高风险逻辑需要说明验证方式。

## Pull Request 建议

- 一个 PR 聚焦一个问题或一个小主题。
- 描述用户可见变化、风险点和验证结果。
- 如果变更了快捷键、菜单、右键菜单或文件操作行为，请在描述里写清楚。
- 如果变更了发布流程，请同步更新 `README.md`、`docs/RELEASE_PROCESS.md` 或 `docs/RELEASE_CHECKLIST.md`。
