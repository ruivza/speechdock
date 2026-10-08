# SpeechDock

macOS 菜单栏语音工具：语音转文字、文字朗读、系统或应用音频转录、字幕、OCR 与翻译。

本仓库是 [yohasebe/speechdock](https://github.com/yohasebe/speechdock) 的独立维护分支。当前说明按本分支的实现重写；原项目历史文档请到原仓库查看。许可证和原作者版权归属保留。

## 下载与文档

- [本仓库 Releases](https://github.com/ruivza/speechdock/releases)：正式发布包将在签名与公证完成后提供。
- [使用说明](docs/index.md) · [系统权限](docs/permissions.md) · [隐私与缓存](docs/advanced.md)
- [编译与签名发布](docs/build-release.md) · [AppleScript](docs/applescript.md)
- [日本語](README_ja.md)

应用的更新源只指向本仓库。原项目的 Homebrew 安装命令不会安装这个分支。

## 当前功能与变化

- 麦克风、系统音频或指定应用音频转录，以及文件转录和实时字幕。
- macOS 原生及可选云服务的语音识别、朗读和翻译。
- 主程序和独立 Voice Input 输入法都启用 App Sandbox 与 Hardened Runtime。
- 普通转录复制到剪贴板，由用户粘贴；跨应用直接输入通过 InputMethodKit 语音输入法完成。
- OCR 将用户选中的屏幕区域识别为文字，放入朗读面板供编辑。
- 界面支持跟随系统、简体中文、英语、日语、德语、法语和韩语；切换后重启生效。
- 历史记录最多 50 条，可关闭保存并清空。历史仍是本地明文，尚未实现内容加密。
- API 密钥保存在 macOS 钥匙串；1Password 集成及相关 private API 已移除。
- 临时音频自动清理；设置提供声音列表与网络缓存清理。

## 开发

需要 macOS 14+、Xcode 26+ 和 XcodeGen。原生识别依赖语言和设备支持；macOS 14/15 不支持本地识别的语言会报错，不回退到云端。

```bash
git clone https://github.com/ruivza/speechdock.git
cd speechdock
cp Signing.local.xcconfig.example Signing.local.xcconfig
# 在这个被 Git 忽略的本机文件中填入自己的 Team ID。
xcodegen generate
open SpeechDock.xcodeproj
```

共享源码不包含任何开发者的 Team ID、个人证书名称或私钥。正式 Release 在构建时从本机配置或 GitHub Secrets 选择签名身份；发布包本身包含必要的公开签名信息。更新验证公钥可以公开保存在源码中。

## 许可与来源

[Apache License 2.0](LICENSE)。原项目：[yohasebe/speechdock](https://github.com/yohasebe/speechdock)，原作者 Yoichiro Hasebe。本分支由 [ruivza](https://github.com/ruivza) 维护。
