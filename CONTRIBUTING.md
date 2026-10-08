# 开发与贡献

本分支维护在 [ruivza/speechdock](https://github.com/ruivza/speechdock)，来源为 [yohasebe/speechdock](https://github.com/yohasebe/speechdock)。保留 Apache License 2.0 和原作者版权说明。

## 本机开发

使用 macOS 14+、Xcode 26+ 和 XcodeGen。所有应用 target 共用 `Signing.xcconfig`，它仅可选加载被 Git 忽略的 `Signing.local.xcconfig`。

1. 复制 `Signing.local.xcconfig.example` 为 `Signing.local.xcconfig`，把占位符换成自己的 Team ID。
2. 在 Xcode 登录 Apple Account，确保本机有匹配的 Apple Development 证书及私钥。
3. 运行 `xcodegen generate`，打开项目并选择 SpeechDock scheme。
4. Debug 使用 `SpeechDock Dev` 和独立 Bundle ID，系统授权与正式版分别保存。

不要把真实 Team ID、完整个人证书名称、私钥、API 密钥或本机路径加入共享配置。生成的 Xcode 项目、证书文件和本机签名配置不上传。

## 检查

```bash
xcodegen generate
xcodebuild test -project SpeechDock.xcodeproj -scheme SpeechDock -destination 'platform=macOS'
ruby scripts/lint/check_tracked_paths.rb
git diff --check
```

测试可以用命令行 `CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=` 运行，但本机实际录音或屏幕捕获应使用稳定的开发证书。自动测试不能代替真实 macOS 权限、输入法安装和云端服务验收。

## 发布

[编译与发布指南](docs/build-release.md) 说明 Developer ID Application、公证和 Sparkle 更新签名。CI 只使用 GitHub Secrets 中的凭据；任何人的 Apple 账户都不会写入源码。仓库中的 Sparkle 公钥用于验证更新，属于可公开数据。

## 文档与 Wiki

当前文档源在 `docs/`。修改说明时同步实际界面和权限行为，删除失效的原项目说明；需要查阅原项目历史时链接到原仓库。

```bash
python3 scripts/sync-wiki.py --preview /tmp/speechdock-wiki-preview
python3 scripts/sync-wiki.py --repository ruivza/speechdock
```

第一次同步前需在 GitHub Wiki 创建首页。同步会替换 Wiki 当前所有页面，Git 历史保留以便恢复；不会 force push。签名资料与转录内容禁止进入文档。

## 代码布局

- `App/`、`Views/`：生命周期、状态和 SwiftUI 界面。
- `Services/`、`Models/`、`Utilities/`：音频、翻译、存储与通用逻辑。
- `InputMethod/`：独立 InputMethodKit 语音输入法。
- `Resources/`：权限配置、资源和六种语言。
- `Tests/`：回归测试；涉及授权与异步结果时覆盖取消、拒绝和失效路径。
- `scripts/`、`.github/workflows/`：构建、路径检查、公证和发布。
