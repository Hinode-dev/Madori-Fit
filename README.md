# Madori-Fit

賃貸の引っ越し前に、部屋の間取りと家具の寸法から、条件に合う家具配置案を複数作る iOS アプリ。
買い切り・完全オンデバイス（サーバーなし）。

## 構成

- `MadoriCore/` — UI・iOS API に依存しない Swift Package。間取り・家具のモデルと配置生成ロジック。`swift test` で単体テストできる。
- `MadoriUI`（同じパッケージ内）— 配置案の 2D 表示、部屋の寸法入力画面。
- `MadoriApp`（同じパッケージ内）— アプリの画面一式と SwiftData での保存。部屋一覧 → 部屋の詳細（家具・条件）→ 配置案。
- `App/MadoriFitApp.swift` — Xcode のアプリターゲットに置く唯一のファイル。
- （今後）RoomPlan によるスキャン、StoreKit 2。

## Xcode プロジェクトの作り方

1. Xcode で iOS App（SwiftUI）を新規作成する。最低 iOS 17。Storage は None。
2. File > Add Package Dependencies > Add Local… で `MadoriCore` フォルダを選び、`MadoriApp` をアプリターゲットに追加する。
3. 自動生成された `〜App.swift` と `ContentView.swift` を消し、`App/MadoriFitApp.swift` をターゲットに追加する。
4. Signing & Capabilities に、iCloud / In-App Purchase / Data Protection を追加する。

## MadoriCore の流れ

1. `Room` … 反時計回りの頂点列（cm、y 上向き）と、ドア・窓（`Opening`）。壁は軸に平行を前提。
2. `Furniture` … 幅・奥行き・高さ・正面の空き。`FurniturePresets` に日本の一般的な寸法を用意。
3. `LayoutGenerator` … 大きい家具から順に、壁沿いなどの候補位置へ乱数を交えて置き、何度も試して評価の高い順に、互いに似ていない案を返す。同じ seed なら同じ結果。
4. `LayoutEvaluator` … 必須条件（部屋に収まる・重ならない・ドアの開閉スペースと背の高い家具の窓ふさぎを避ける）、通路幅（ドアから各家具の正面まで `minWalkway` を保って行けるか）、好み（デスクを窓の近く、ベッドをドアから遠く、部屋の中央を空ける）。

## Capabilities

登録済み: iCloud / Push Notifications / In-App Purchase / Data Protection。
Push Notifications は、サーバーを持たないため、SwiftData の CloudKit 同期を使う場合にのみ意味がある。
Info.plist には `NSCameraUsageDescription`（スキャン）と `NSPhotoLibraryAddUsageDescription`（画像の書き出し）が必要になる。

## スキャン（LiDAR 搭載機）

RoomPlan でスキャンし、壁の向きから傾きを求めて、外周を囲む四角い部屋に近似する（`RoomFitter`）。
結果は手入力と同じ入力画面に出るので、寸法・ドア・窓を確認して補正できる。
L 字など四角くない部屋は、近似したことを画面に注意書きで出す。
`Info.plist` に `NSCameraUsageDescription` が必要。
