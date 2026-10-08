---
layout: default
title: AppleScript
nav_order: 5
---

# AppleScript 当前行为

命令定义以仓库中的 [SpeechDock.sdef](https://github.com/ruivza/speechdock/blob/main/Resources/SpeechDock.sdef) 为准。可以控制朗读、转录文件、翻译和面板显示；调用需要相应的服务配置与用户授权。

```applescript
tell application "SpeechDock"
    speak text "Hello from SpeechDock"
end tell
```

开发版本可按当前显示名称 `SpeechDock Dev` 选择应用。其他应用向 SpeechDock 发送自动化命令时，其自动化权限由 macOS 管理。

## 剪贴板命令

`copy to clipboard` 复制传入文字。保留的 `paste text` 命令也只复制到剪贴板并返回复制状态，不再选择目标应用、模拟按键或跨应用粘贴。需要输入到编辑器时，由用户手动粘贴或选择 Voice Input 输入法。

## 文件与面板

沙盒不会因为 AppleScript 调用而放开文件权限。文件转录和音频保存仍需当前应用可访问的文件或用户选定的位置。显示、隐藏和切换面板的录音停止行为以当前命令实现为准；调用方不应把面板隐藏当作已完成转录。

旧版的自动粘贴和辅助功能说明不适用于此分支。原项目历史：[yohasebe/speechdock](https://github.com/yohasebe/speechdock)。

[首页](index.md) · [开始使用](basics.md)
