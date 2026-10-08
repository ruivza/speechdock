---
layout: default
title: 编译与签名发布
nav_order: 6
---

# 编译与签名发布

可以发布由自己的证书签名的版本，同时保持源码通用。签名包必然包含公开的 Team ID、证书和签名，源码只保存构建规则、占位符和更新验证公钥。

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

## GitHub Release

在本仓库 Settings → Secrets and variables → Actions 配置以下 repository secrets：

| Secret | 内容 |
| --- | --- |
| `CERTIFICATE_BASE64` | 包含 Developer ID Application 证书和私钥的 .p12 的 Base64 |
| `CERTIFICATE_PASSWORD` | .p12 导出密码 |
| `KEYCHAIN_PASSWORD` | CI 临时钥匙串密码 |
| `TEAM_ID` | 与证书匹配的 Team ID |
| `APPLE_ID` | 公证使用的 Apple Account |
| `APP_PASSWORD` | 该账户的 app-specific password |
| `SPARKLE_PRIVATE_KEY` | 与应用内 SUPublicEDKey 匹配的更新签名私钥 |

私钥、证书、密码禁止提交到 Git；不要把它们发到 issue、Wiki、聊天或构建日志。Actions 只在发布任务中导入临时钥匙串，构建环境不继承这些密钥，结束后清理。

版本号在 `VERSION` 与 `project.yml` 的两个应用 target 中保持一致。检查完成后推送相同的 `vX.Y.Z` 标签才会触发发布，例如：

```bash
rake version:patch
rake version:verify
# 提交经过验证的版本修改，然后推送 main。
git tag vX.Y.Z
git push origin vX.Y.Z
```

把示例中的 X.Y.Z 换成 VERSION 的实际值。缺少 secrets、证书类型或 Team 不匹配、标签版本不匹配、签名或公证失败，流程都会停止。Release 成功创建后才把签名 appcast 提交到 main；不会更新原作者的 Homebrew tap。

## Sparkle 更新签名

Developer ID 与 Sparkle 是两套用途不同的签名。仓库保留公开的 `SUPublicEDKey`，只有维护者持有的对应私钥能签名可安装的更新。CI 在发布前验证 DMG 签名与应用内公钥一致。

使用校验过版本及 SHA-256 的 Sparkle 官方工具管理更新密钥。在本机钥匙串安全保存私钥；需要配置 CI 时由维护者通过工具导出到仓库外的位置，填入 `SPARKLE_PRIVATE_KEY` 并删除导出文件。不要随意生成另一个私钥来替代现有公钥的私钥；更换公钥涉及已有用户的更新信任迁移。

钥匙串在读取私钥时可能要求本机登录钥匙串授权。源码整理和公开样本验证不需要读取这个私钥。密钥导出必须由维护者在自己的机器完成。

## Wiki 同步

当前 Wiki 使用英文，由 `docs/wiki/` 中的文档生成。先在 GitHub Wiki 创建首页，再运行：

```bash
python3 scripts/sync-wiki.py --preview /tmp/speechdock-wiki-preview
python3 scripts/sync-wiki.py --repository ruivza/speechdock
```

同步替换 Wiki 当前页面并引用原仓库；保留 Git 历史，不强制推送。

参考：[GitHub macOS runner 证书配置](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)、[Sparkle 发布指南](https://sparkle-project.org/documentation/)。

[首页](index.md) · 来源：[yohasebe/speechdock](https://github.com/yohasebe/speechdock)
