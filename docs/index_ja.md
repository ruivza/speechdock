---
layout: default
title: 日本語の概要
nav_order: 7
lang: ja
---

# SpeechDock このフォークの使い方

このページは現在の実装に合わせて書き直しました。原プロジェクトは [yohasebe/speechdock](https://github.com/yohasebe/speechdock) です。古い仕様や配布情報は原リポジトリを参照してください。

- 文字起こし、読み上げ、OCR、字幕、翻訳をメニューバーから利用できます。
- 通常の文字起こしはコピーして手動で貼り付けます。直接入力には Voice Input 入力メソッドを選択し、Control + Option + R で開始・終了、Esc でキャンセルします。
- アプリと入力メソッドは別々の沙盒と権限を持ちます。Debug 版とリリース版の権限も別です。
- 表示言語は外観設定で変更し、完全に終了して再起動すると適用されます。
- 履歴は最大 50 件のローカル平文です。保存の停止と削除を別々に選択できます。1Password 連携は削除しました。
- このフォークのダウンロードと更新は [ruivza/speechdock](https://github.com/ruivza/speechdock) から提供します。

現在の詳細説明：[開始する](basics.md)、[権限](permissions.md)、[プライバシーとキャッシュ](advanced.md)、[ビルドと署名](build-release.md)、[AppleScript](applescript.md)。
