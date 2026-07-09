# Release Process

本文档记录 MacExplorer 从开发状态进入一个可追踪版本的推荐步骤。

## 1. 更新版本号

编辑 [VERSION](../VERSION)：

```text
APP_VERSION=0.1.0
BUILD_NUMBER=1
```

规则：

- 修复和小改动递增 patch，例如 `0.1.1`。
- 用户可见的新功能递增 minor，例如 `0.2.0`。
- 每次正式打包递增 `BUILD_NUMBER`。

## 2. 更新变更记录

编辑 [CHANGELOG.md](../CHANGELOG.md)：

- 将 `Unreleased` 中已经完成的内容移动到新的版本区块。
- 写清楚 Added、Changed、Fixed、Known Limitations。
- 如果是正式版本，补充对应的发布说明链接。

## 3. 运行本地发布验证

```bash
scripts/verify_release.sh
```

该脚本会生成并验证：

- `dist/MacExplorer.app`
- `dist/MacExplorer-<version>-<build>-macos.zip`
- `dist/MacExplorer-<version>-<build>-macos.zip.sha256`
- `dist/MacExplorer-<version>-<build>-macos.dmg`
- `dist/MacExplorer-<version>-<build>-macos.dmg.sha256`
- `dist/MacExplorer-<version>-<build>-macos.manifest.json`

当前 ad-hoc 签名阶段，Gatekeeper rejected 是预期状态。只有接入 Developer ID 签名和 notarization 后，Gatekeeper 才应作为必须通过项。

## 4. 按需生成 Intel / Universal 包

Apple Silicon 机器也可以交叉生成 Intel 包：

```bash
scripts/create_release_zip.sh release x86_64
scripts/create_release_dmg.sh release x86_64
scripts/create_release_manifest.sh x86_64
```

也可以生成同时支持 Apple Silicon 和 Intel 的 universal 包：

```bash
scripts/create_release_zip.sh release universal
scripts/create_release_dmg.sh release universal
scripts/create_release_manifest.sh universal
```

验证架构：

```bash
lipo -archs dist/MacExplorer-x86_64.app/Contents/MacOS/MacExplorer
lipo -archs dist/MacExplorer-universal.app/Contents/MacOS/MacExplorer
```

## 5. 检查 release manifest

```bash
python3 -m json.tool dist/MacExplorer-<version>-<build>-macos.manifest.json
```

重点确认：

- `version` 和 `build` 正确。
- `gitCommit` 指向当前准备发布的提交。
- 如果已经在 tag 上构建，`gitTag` 应等于对应版本标签。
- zip 和 dmg 的 `sha256` 与 `.sha256` 文件一致。

## 6. 提交代码

```bash
git status --short
git add .
git commit -m "Prepare v<version>"
```

提交前确认：

- `dist/` 没有进入 Git。
- `release-artifacts/` 只保留当前最新公开 DMG 安装包和对应 `.sha256`。
- 没有 token、证书、账号凭据或私有本地路径密钥。
- `git remote -v` 中不要包含 token。

## 7. 创建标签

```bash
git tag -a v<version> -m "MacExplorer v<version>"
```

例如：

```bash
git tag -a v0.1.0 -m "MacExplorer v0.1.0"
```

标签应该指向包含发布说明和版本号更新的提交。

## 8. 推送到 GitHub

```bash
git push origin main
git push origin v<version>
```

如果使用 access token，推荐通过临时 `GIT_ASKPASS` 或系统钥匙串提供，不要写入 `.git/config`。

## 9. 创建 GitHub Release

在对应 tag 创建 Release，上传：

- `.zip`
- `.zip.sha256`
- `.dmg`
- `.dmg.sha256`
- `.manifest.json`

Release 描述建议包含：

- 版本摘要。
- 主要变更。
- 已知限制。
- Gatekeeper / notarization 状态。
- SHA256 校验说明。

开源仓库中的 `release-artifacts/` 只作为最新 DMG 的轻量镜像，不保存历史构建包。历史版本应放在 GitHub Release 附件中。

## 10. 对外分发前

当前流程只保证本机 ad-hoc 签名版本可构建、可运行、可归档。

对外分发前还需要：

- Developer ID Application 签名。
- Hardened Runtime。
- Notarization。
- Stapling。
- 干净 macOS 用户环境安装验证。
- 如有需要，美化 dmg 背景、窗口大小和 Applications 拖拽提示。
