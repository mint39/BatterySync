# BatterySync
BatterySyncは、複数のデバイス間や異なるOS間でバッテリー情報を共有するアプリです。このアプリを使用すると、複数のデバイスのバッテリー状況を一目で把握でき、効率的なバッテリーマネジメントが可能になります。

## 目次
1. [機能](#機能)
2. [インストール](#インストール)
3. [使い方](#使い方)
4. [ライセンス](#ライセンス)

## 機能
- 複数デバイス間や異なるOS間でのリアルタイムバッテリー情報共有
- デバイスのバッテリー状態を一元管理
- Geminiによるバッテリー残量の推移予測

## インストール
### 前提条件
- Flutterのビルド環境
  - テスト環境ではAndroid Studio Ladybug | 2024.2.1 Patch 3を用いています。
- Android 4.4以降を搭載した端末（実機でテストする場合）

## 使い方
1. **アカウントの作成、サインイン**
   - アプリを開き、右上の設定ボタンより設定メニューを開きます。
   - サインイン項目より、アカウントを作成、又はサインインします。
      - メールアドレス、Googleアカウントの2種類のサインイン方法が用意されています。
2. **デバイスの登録**
   - デバイスリストに登録をしたいデバイス全て、共通のアカウントでサインインします。
   - 各デバイスで初めてアカウントにサインインすると、自動でリストに追加されます。

3. **バッテリー情報の確認**
   - 登録されたデバイスのバッテリー状態が一覧表示されます。
   - 各デバイスのバッテリー残量が確認できます。

4. **Geminiによるバッテリー残量の推移予測**
   - アカウントへのサインイン後、リスト画面の下部には、Geminiを用いた今後24時間のバッテリー残量の推移予測が表示されています。
   - 十分なデータ量がログに記載されるまでは推移予測は使用できません（例：サインイン直後）。

## ライセンス
このプロジェクトはMITライセンスの下でライセンスされています。詳細については、[LICENSE](LICENSE)ファイルを参照してください。