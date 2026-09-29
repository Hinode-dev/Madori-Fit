# TestFlight への配信

`v` から始まるタグ（例: `v1.0.0`）を push するか、Actions 画面の「TestFlight」を手動実行すると、
テスト → アーカイブ → App Store Connect へのアップロードまで自動で行う。
ビルド番号は、実行時の日時 (UTC、`202609291414` のような形式) を使う。実行し直しても、常に前回より大きくなる。
Xcode プロジェクトは `project.yml` から XcodeGen で生成する（リポジトリには入れない）。

## 最初に一度だけやること

1. **App ID を登録する**（Apple Developer > Identifiers）。
   In-App Purchase / Data Protection などの Capabilities を、登録済みのものに合わせる。
2. **App Store Connect でアプリを作成する**（マイ App > ＋ > 新規 App）。
   バンドル ID には 1 で作った ID を選ぶ。
3. **API キーを作る**（App Store Connect > ユーザとアクセス > 統合 > App Store Connect API）。
   - 権限は **Admin**。クラウド管理の署名（配布用証明書の自動作成）に必要。
   - `.p8` ファイルは一度しかダウンロードできない。
   - Key ID と Issuer ID を控える。
4. **GitHub のシークレットを登録する**（リポジトリ > Settings > Secrets and variables > Actions）。

   | 名前 | 内容 |
   |---|---|
   | `BUNDLE_ID` | バンドル ID（例: `jp.example.madorifit`） |
   | `APPLE_TEAM_ID` | Apple Developer の Team ID（10 文字） |
   | `ASC_KEY_ID` | API キーの Key ID |
   | `ASC_ISSUER_ID` | API キーの Issuer ID |
   | `ASC_KEY_P8` | `.p8` ファイルの中身（`-----BEGIN PRIVATE KEY-----` から最後まで） |

5. **TestFlight のテスターを追加する**（App Store Connect > TestFlight）。
   内部テスターは審査なしで配信できる。

## 配信のしかた

```sh
git tag v1.0.0
git push origin v1.0.0
```

アップロード後、App Store Connect 側の処理に 5〜30 分ほどかかり、その後 TestFlight に出る。
バージョン（`1.0.0`）は `project.yml` の `MARKETING_VERSION` で変える。

## うまくいかないとき

- **`No profiles for ... were found` / 証明書の作成に失敗**: API キーの権限が Admin か確認する。
- **`Cloud signing permission error`**: 同上。アカウントの Account Holder が、API キーの利用を許可しているか確認する。
- **`The bundle version must be higher`**: ビルド番号は日時なので、通常は増え続ける。以前に大きな番号（例: 未来の日時）で上げてしまった場合は、それより大きくなるまで待つか、`MARKETING_VERSION` を上げる。
- **アイコン関連のエラー**: `App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` は仮のアイコン。差し替えるときは、透過なしの 1024×1024 の PNG にする。
- **プライバシー関連の警告**: 使っているフレームワークによっては、プライバシーマニフェストが必要になる場合がある。メールの指示に従って追加する。
