# Madori-Fit

賃貸の引っ越し前に、部屋の間取りと家具の寸法から、条件に合う家具配置案を複数作る iOS アプリ。
買い切り・完全オンデバイス（サーバーなし）。

## 構成

- `MadoriCore/` — UI・iOS API に依存しない Swift Package。間取り・家具のモデルと配置生成ロジック。`swift test` で単体テストできる。
- （今後）アプリ本体 — SwiftUI、RoomPlan によるスキャン、SwiftData、StoreKit 2。

## MadoriCore の流れ

1. `Room` … 反時計回りの頂点列（cm、y 上向き）と、ドア・窓（`Opening`）。壁は軸に平行を前提。
2. `Furniture` … 幅・奥行き・高さ・正面の空き。`FurniturePresets` に日本の一般的な寸法を用意。
3. `LayoutGenerator` … 大きい家具から順に、壁沿いなどの候補位置へ乱数を交えて置き、何度も試して評価の高い順に、互いに似ていない案を返す。同じ seed なら同じ結果。
4. `LayoutEvaluator` … 必須条件（部屋に収まる・重ならない・ドアの開閉スペースと背の高い家具の窓ふさぎを避ける）、通路幅（ドアから各家具の正面まで `minWalkway` を保って行けるか）、好み（デスクを窓の近く、ベッドをドアから遠く、部屋の中央を空ける）。

## Capabilities

登録済み: iCloud / Push Notifications / In-App Purchase / Data Protection。
Push Notifications は、サーバーを持たないため、SwiftData の CloudKit 同期を使う場合にのみ意味がある。
Info.plist には `NSCameraUsageDescription`（スキャン）と `NSPhotoLibraryAddUsageDescription`（画像の書き出し）が必要になる。
