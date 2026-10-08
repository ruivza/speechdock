---
layout: default
title: 使用指南
nav_order: 1
---

# SpeechDock 使用指南

本说明针对 [ruivza/speechdock](https://github.com/ruivza/speechdock) 的当前实现重写。项目来源：[yohasebe/speechdock](https://github.com/yohasebe/speechdock)。原项目的历史说明请到原仓库查阅。

SpeechDock 是 macOS 菜单栏语音工具，支持转录、朗读、实时字幕、OCR 与翻译。主程序和 Voice Input 输入法都运行在沙盒中。

## 文档

- [开始使用与语音输入法](basics.md)
- [系统权限与已授权却不可用的处理](permissions.md)
- [隐私、历史和缓存](advanced.md)
- [编译、签名与 Release](build-release.md)
- [AppleScript 当前行为](applescript.md)
- [日本語の概要](index_ja.md)

## 安装

正式安装包从 [本仓库 Releases](https://github.com/ruivza/speechdock/releases) 获取。发布包需要维护者自己的 Developer ID Application 签名与公证；没有发布包时可按编译指南本机构建。

原作者的 Homebrew tap 和旧安装包不代表此分支。更新需要从本仓库 Releases 手动下载并安装；应用不会自动检查或下载更新。

## 平台与语言

系统要求 macOS 14+；开发构建使用 Xcode 26+。原生识别取决于语言和设备的本地支持，缺少模型时系统可能下载模型；macOS 14/15 不支持本地识别的语言会提示不可用。

在设置的外观页面选择界面语言，完全退出再打开生效。支持跟随系统、简体中文、英语、日语、德语、法语、韩语。界面语言与识别、翻译语言分别设置。

## 授权范围

麦克风用于录音；屏幕与系统音频录制用于 OCR、系统或应用音频。普通文字朗读不需要麦克风权限。Voice Input 输入法有自己的授权记录。详情见 [系统权限](permissions.md)。
