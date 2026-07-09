# Release Artifacts

开源仓库只保留当前最新公开 DMG 安装包和对应 SHA256 校验文件。

当前保留：

- `MacExplorer-0.1.0-22-macos.dmg`
- `MacExplorer-0.1.0-22-macos.dmg.sha256`
- `MacExplorer-0.1.0-22-macos-x86_64.dmg`
- `MacExplorer-0.1.0-22-macos-x86_64.dmg.sha256`
- `MacExplorer-0.1.0-22-macos-universal.dmg`
- `MacExplorer-0.1.0-22-macos-universal.dmg.sha256`

本地构建输出仍放在 `dist/`，并由 `.gitignore` 排除。发布新版本时，用新版本的最新 DMG 和 `.sha256` 替换这里的文件。
