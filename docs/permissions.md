---
layout: default
title: 系统权限
nav_order: 3
---

# 系统权限

| 功能 | 所需授权 |
| --- | --- |
| 麦克风转录 | 主程序麦克风权限 |
| OCR、系统音频、应用音频 | 主程序屏幕与系统音频录制权限 |
| Voice Input 输入法 | 输入法自己的麦克风及原生语音识别权限 |
| 已输入文字的朗读 | 不需要麦克风或屏幕录制权限 |

主程序不要求辅助功能权限。App Sandbox、Hardened Runtime 是构建边界，不会替用户授予 macOS 隐私权限。

## 开关开启但仍弹出授权提示

macOS 会把授权与应用的签名身份关联。旧版、Debug 版、换证书的构建或曾经使用临时签名的构建，可能留下不匹配的记录。Debug 的 Bundle ID 为 `com.speechdock.app.dev`，正式版为 `com.speechdock.app`，两者分别授权。

1. 在应用权限页点“在 Finder 中显示当前应用”，确认当前正在运行的应用包。
2. 用菜单“退出 SpeechDock”完全退出；开发时可在 Xcode 点 Stop。
3. 在系统设置 → 隐私与安全 → 屏幕与系统音频录制中移除旧应用项，添加刚才显示的当前应用并开启。
4. 重新打开当前应用，在权限页点“重新检查”，再尝试所需功能。

不要重置所有应用的权限。只处理不匹配的 SpeechDock 项。主程序的授权不会自动授权输入法。

## 检测方式

麦克风状态通过 AVFoundation 刷新。屏幕录制在用户明确重新检查或进入捕获功能时，用 ScreenCaptureKit 验证当前会话；旧的预检查返回值不再单独阻止捕获。取消或过时的异步检查不能覆盖新结果。

重启、身份更新仍未解决时，请报告正在运行的版本、主程序或输入法、实际功能和错误提示。自动回归测试覆盖状态转换，不保证当前机器的授权记录有效。

参考：[Apple 屏幕录制权限说明](https://support.apple.com/guide/mac-help/mchld6aa7d23/mac)、[Apple 关于签名变化与授权的说明](https://developer.apple.com/forums/thread/819406)。

[首页](index.md) · 来源：[yohasebe/speechdock](https://github.com/yohasebe/speechdock)
