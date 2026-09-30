# App Store 掲載の下書き

App Store Connect に貼り付けるための、文章の下書きです。`[ ]` の部分は、あなたが決めてください。

## 基本情報

| 項目 | 内容 |
|---|---|
| アプリ名（30 文字以内） | Madori Fit |
| サブタイトル（30 文字以内） | 部屋をスキャンして家具の配置を提案 |
| カテゴリ | プライマリ: ライフスタイル ／ セカンダリ: ユーティリティ |
| 価格 | [480〜980 円のあいだで、決める] |
| 年齢制限 | 4+（暴力・性的表現などは、ありません） |
| サポート URL | https://hinode-dev.github.io/Madori-Fit/support（GitHub Pages を有効にした場合） |
| プライバシーポリシー URL | https://hinode-dev.github.io/Madori-Fit/privacy-policy |
| 著作権 | © 2026 Hinode Entertainment |
| 対応端末 | iPhone（iOS 17 以上）。スキャンは、LiDAR 搭載機のみ |

## プロモーション用テキスト（170 文字以内）

引っ越し前に、お部屋をスキャンして、家具の置き方を考えましょう。通路が確保できる配置案を自動で作り、3D とARで確認。玄関やエレベーターを家具が通れるかも、チェックできます。買い切り、広告なし、データは端末の中だけ。

## 説明文

引っ越し前の「この家具、入るかな？置けるかな？」を、スマホで解決します。

■ お部屋をスキャン、または寸法を入力
LiDAR搭載のiPhoneなら、部屋をぐるっと見回すだけで、間取りができあがります。スキャンできない端末でも、寸法を入力して使えます。ARの定規で測って、そのまま入力することもできます。

■ 家具の配置案を、自動で作る
ベッド、ソファ、デスク、収納など、よくある家具のサイズを用意しています。自分の家具の寸法も入力できます。ドアの開閉スペースや、通路の幅（60cm など）を守った配置案を、複数、作ります。

■ 3Dで、部屋の中を見る
部屋も家具も3Dで見られます。指で回転・拡大して、壁やドア、窓の位置を確認できます。壁の印をドラッグして、部屋の寸法を直接変えることもできます。

■ 手で直す、固定して作り直す
家具をドラッグして、位置を微調整できます。気に入った家具は「固定」して、ほかの家具だけを作り直せます。間違えたときは、元に戻せます。

■ 搬入チェック
玄関のドア、廊下の曲がり角、エレベーターの寸法を入れると、家具が通れるかを確認できます。「入らなくて運び込めない」を、引っ越しの前に防ぎます。

■ ARで、実寸の家具を置いてみる
カメラ越しに、実寸の家具を、実際の部屋に重ねて見られます。

■ 画像・PDFで書き出し
寸法つきの平面図と家具の一覧を、画像やPDFにして、家族や業者に共有できます。

■ 安心の、買い切り
- 一度の購入だけ。月額料金は、ありません。
- 広告は、表示しません。
- 部屋のデータは、端末の中だけに保存します。アカウント登録も、不要です。

■ ご注意
- 部屋のスキャンは、LiDARを搭載したiPhone・iPad Proで、使えます。
- スキャンや計測の結果には、数cmの誤差が出ることがあります。ぎりぎりの寸法は、実際に測って、ご確認ください。
- 搬入チェックは、目安です。実際の搬入は、業者にもご確認ください。

## キーワード（100 文字以内、カンマ区切り）

間取り,家具配置,レイアウト,引っ越し,搬入,LiDAR,3D,AR,部屋,スキャン,内見,採寸,模様替え,一人暮らし

## このバージョンの新機能（初回リリース）

初めてのリリースです。

## App Review に伝えること（審査メモ）

App Store Connect の「審査に関する情報」の「メモ」に、英語で書きます。

```
Thank you for reviewing Madori Fit.

- No account or sign-in is required. All data stays on the device; the app does not collect or transmit any user data.
- Room scanning (RoomPlan) requires a LiDAR-equipped device. You can review every other feature without LiDAR:
  on first launch, tap "Try the sample room" (サンプルの部屋で試す). It creates a room with furniture and a delivery route.
  From the room screen you can view the 3D model, generate layouts, edit them by hand, run the delivery check, and export an image/PDF.
- The camera is used only for room scanning, AR placement of furniture at real size, and the AR ruler. Video is processed on the device and is not stored or sent.
- This is a paid app (one-time purchase). There are no in-app purchases, ads, or subscriptions.
```

## スクリーンショットの案

iPhone で撮った画面を、そのまま使えます（TestFlight のアプリで、撮影します）。
App Store Connect は、6.9 インチと 6.5 インチのどちらかのサイズを、必須にしています。
お手持ちの iPhone の画面サイズに合うものを、アップロードしてください。

| 順番 | 撮る画面 | 添える見出しの案 |
|---|---|---|
| 1 | 部屋の3D表示（家具入り） | 部屋を3Dで、そのまま確認 |
| 2 | 配置案の一覧 | 通路を確保した配置案を、自動で作成 |
| 3 | 手で直す画面（家具を選択中） | ドラッグで直せる、固定して作り直せる |
| 4 | 搬入チェックの結果 | 「入らない」を、引っ越しの前に確認 |
| 5 | ARで家具を重ねた画面 | 実寸の家具を、部屋に置いてみる |
| 6 | 書き出した平面図 | 寸法つきで、家族や業者に共有 |

## 公開の手順（メモ）

1. `docs/` の `[ ]` の部分を、実際の内容に書き換える。
2. リポジトリの Settings > Pages で、ブランチと `/docs` フォルダを選ぶ（メインのブランチに、`docs/` が入っている必要があります）。
3. 表示された URL を、サポート URL とプライバシーポリシー URL に入れる。
4. App Store Connect で、有料 App 契約、銀行口座、税務情報を登録する。
5. 価格、年齢制限、App のプライバシー（「データを収集しない」）を回答する。
6. TestFlight のビルドを選んで、審査に提出する。
