---
layout: default
title: 编译与签名发布
nav_order: 6
---

# 编译与签名发布

可以发布由自己的证书签名的版本，同时保持源码通用。签名包必然包含公开的 Team ID、证书和签名，源码只保存构建规则与占位符。

## 本机 Debug

需要 Xcode 26+、XcodeGen，以及本机 Apple Development 证书及其私钥。

```bash
cp Signing.local.xcconfig.example Signing.local.xcconfig
# 把 YOUR_TEAM_ID 换成自己的 Team ID，仅修改本机文件。
xcodegen generate
open SpeechDock.xcodeproj
```

`Signing.local.xcconfig` 被 Git 忽略，所有 target 通过 `Signing.xcconfig` 可选加载它。生成的 Xcode 项目也不上传。稳定的开发签名有助于系统授权在编译之间保持有效；更换签名后需为当前应用重新授权。

## 本机正式发布

安装自己的 Developer ID Application 证书及私钥。Apple Development 用于开发测试，不能替代站外分发的 Developer ID 签名和公证。

```bash
TEAM_ID=YOUR_TEAM_ID SIGNING_IDENTITY='Developer ID Application' bash scripts/build.sh
bash scripts/create-dmg.sh
xcrun notarytool store-credentials speechdock-release
NOTARY_PROFILE=speechdock-release bash scripts/notarize.sh
```

脚本生成 arm64、x86_64 通用 Release，在忽略的 `build/` 目录生成导出配置。可用 `SIGNING_IDENTITY` 指定本机证书名称或 SHA-1 指纹，源码无需修改。公证凭据通过钥匙串配置读取。

## GitHub 构建，本机签名与发布

GitHub Actions 只编译 arm64、x86_64 通用 Release，保存未签名的构建包，不创建 Release。Developer ID 私钥和公证凭据留在维护者的 Mac 钥匙串里。GitHub 不需要 Apple 证书、证书密码或公证 secrets。

### 本机一次性准备

安装自己的 Developer ID Application 证书及其私钥，以及 Xcode 命令行工具。证书无需导出成 .p12 或上传 GitHub。

```bash
brew install gh
gh auth login
xcrun notarytool store-credentials speechdock-release
```

最后一个命令交互式保存公证凭据。它会询问 Apple Account、Team ID 和 app-specific password。发布脚本只读取钥匙串配置；不要把密码写进命令、源码或 GitHub。

如果本机只有一个有效的 Developer ID Application，脚本会自动选择它。存在多个证书时，用 `security find-identity -v -p codesigning` 查看公开的 SHA-1 指纹，并用 `SIGNING_IDENTITY` 指定完整证书名称或指纹。

DMG 使用 macOS 自带的 `hdiutil` 和 `ditto` 制作，包含应用和 Applications 快捷方式。只需安装 GitHub 官方的 `gh`；打包无需额外安装工具。

### 每次发布

本仓库独立维护版本号，无需跟随上游。新版本使用自己的发布记录和 `vX.Y.Z` 标签；保留已有更新历史，不替换旧标签。

1. 保持 `VERSION` 与 `project.yml` 两个应用 target 的版本一致，提交并推送经过验证的修改。
2. 推送匹配的 `vX.Y.Z` 标签，触发 **Build Release Artifact**。也可运行 `rake release:github`；已有标签不会被替换。
3. 等待 Actions 成功，记下运行页面 URL 中 `/actions/runs/` 后的数字 RUN_ID。构建包保留 30 天，是维护者签名的输入，不供用户安装。
4. 本机切换到该标签，执行发布脚本。

```bash
# 把 X.Y.Z 和 RUN_ID 换成实际版本与运行编号。
git fetch origin tag vX.Y.Z
git switch --detach vX.Y.Z
NOTARY_PROFILE=speechdock-release bash scripts/release-local.sh --run RUN_ID --publish
```

脚本核对远端标签、构建提交和本机签名脚本版本，然后下载构建包，恢复可执行权限和框架符号链接。它分别签名嵌套代码、Voice Input 输入法与主应用，使用各自的权限配置，随后生成并签名 DMG，提交公证、附上票据，并检查签名与 Gatekeeper。全部成功才上传 DMG 和 SHA-256 校验文件到新 Release；不会覆盖已有 Release 或创建缺失的标签。

去掉 `--publish` 可只生成本机安装包。等价 Rake 命令是 `NOTARY_PROFILE=speechdock-release PUBLISH=1 rake 'release:local[RUN_ID]'`。其他 fork 可使用 `--repo OWNER/REPO`。

未签名 ZIP 位于 `build/SpeechDock-X.Y.Z-unsigned.zip`，正式 DMG 位于项目根目录。这些文件被 Git 忽略。本机完整编译仍可使用上一节的 `scripts/build.sh`；也可用 `bash scripts/build.sh --unsigned` 验证无证书构建。

用户从本仓库 Releases 手动下载安装更新；应用不会自动检查或下载更新，也不会更新原作者的 Homebrew tap。

## Wiki 同步

当前 Wiki 使用英文，由 `docs/wiki/` 中的文档生成。先在 GitHub Wiki 创建首页，再运行：

```bash
python3 scripts/sync-wiki.py --preview /tmp/speechdock-wiki-preview
python3 scripts/sync-wiki.py --repository ruivza/speechdock
```

同步替换 Wiki 当前页面并引用原仓库；保留 Git 历史，不强制推送。

参考：[Apple 分发签名](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac)、[GitHub 构建产物](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)、[GitHub CLI Release](https://cli.github.com/manual/gh_release_create)。

[首页](index.md) · 来源：[yohasebe/speechdock](https://github.com/yohasebe/speechdock)
