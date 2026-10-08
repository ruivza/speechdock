# SpeechDock

macOS のメニューバーから音声認識、読み上げ、字幕、OCR、翻訳を利用するアプリです。

このリポジトリは [yohasebe/speechdock](https://github.com/yohasebe/speechdock) の独立したフォークです。旧マニュアルは掲載せず、このフォークの動作に合わせて説明を作り直しています。原著作者の著作権と Apache License 2.0 は保持します。

- [このフォークのリリース](https://github.com/ruivza/speechdock/releases)
- [日本語の概要](docs/index_ja.md)
- [現在の利用ガイド](docs/index.md) · [権限](docs/permissions.md) · [プライバシーとキャッシュ](docs/advanced.md)
- [ビルドと署名](docs/build-release.md) · [中文](README.md)

アプリと Voice Input 入力メソッドは App Sandbox を使用します。通常の文字起こしはクリップボードへコピーし、ユーザーが貼り付けます。直接入力は InputMethodKit 入力メソッドを選択して行います。1Password 連携は削除しました。

画面の言語はシステム標準、中国語、英語、日本語、ドイツ語、フランス語、韓国語から選べます。変更後はアプリを再起動してください。履歴は最大 50 件のローカル平文で、保存の停止と削除ができます。

開発者の Team ID や秘密鍵は共有ソースに含めません。署名はローカル設定または GitHub Secrets からビルド時に適用します。配布済みバイナリの公開署名情報は必要です。
