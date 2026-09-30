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

## 証明書を固定する（推奨。「証明書の数が上限」のエラーが出たら必須）

自動署名のままだと、実行のたびに新しい証明書が作られ、Apple の上限に達します
（`Your account has reached the maximum number of certificates`）。
配布用の証明書とプロファイルを一度だけ作って、シークレットに入れると、この問題は起きません。
3 つのシークレットが入っていれば、自動的にこの方式になります。

1. **証明書署名要求 (CSR) を作る**（Mac）: キーチェーンアクセス > 証明書アシスタント > 認証局に証明書を要求。
   メールアドレスと名前を入れ、「ディスクに保存」を選ぶ。
2. **Apple Distribution 証明書を作る**: developer.apple.com > Certificates > ＋ > Apple Distribution。
   1 の CSR をアップロードし、できた `.cer` をダウンロードして、ダブルクリックでキーチェーンに入れる。
3. **`.p12` に書き出す**: キーチェーンアクセス > 「自分の証明書」で、「Apple Distribution: …」を右クリック > 書き出す。
   形式は `.p12`、パスワードを決める。
4. **プロファイルを作る**: Profiles > ＋ > App Store Connect（App Store）> 自分のバンドル ID > 2 の証明書を選ぶ。
   名前は、例えば `MadoriFit AppStore`。できた `.mobileprovision` をダウンロードする。
5. **シークレットを登録する**（Mac のターミナルで、値をクリップボードにコピーしてから貼る）。

   | 名前 | 内容 | 値の作り方 |
   |---|---|---|
   | `DIST_CERT_P12_BASE64` | `.p12` の中身 | `base64 -i 証明書.p12 \| pbcopy` |
   | `DIST_CERT_PASSWORD` | 3 で決めたパスワード | そのまま |
   | `PROVISIONING_PROFILE_BASE64` | `.mobileprovision` の中身 | `base64 -i プロファイル.mobileprovision \| pbcopy` |

プロファイルには、App ID に登録した Capabilities（Data Protection など）が含まれている必要があります。
Capabilities を変えたときは、プロファイルを作り直して、シークレットを更新してください。
証明書とプロファイルの有効期限は 1 年です。切れたら、作り直します。

## 配信のしかた

```sh
git tag v1.0.0
git push origin v1.0.0
```

アップロード後、App Store Connect 側の処理に 5〜30 分ほどかかり、その後 TestFlight に出る。
バージョン（`1.0.0`）は `project.yml` の `MARKETING_VERSION` で変える。

## うまくいかないとき

- **`No profiles for ... were found` / 証明書の作成に失敗**: API キーの権限が Admin か確認する。
- **`Your account has reached the maximum number of certificates`**: 上の「証明書を固定する」を行う。すぐに直したいときは、developer.apple.com > Certificates で、不要な「Apple Development」証明書（`Created via API` など）を削除する。
- **`Cloud signing permission error`**: 同上。アカウントの Account Holder が、API キーの利用を許可しているか確認する。
- **`The bundle version must be higher`**: ビルド番号は日時なので、通常は増え続ける。以前に大きな番号（例: 未来の日時）で上げてしまった場合は、それより大きくなるまで待つか、`MARKETING_VERSION` を上げる。
- **アイコン関連のエラー**: `App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` は仮のアイコン。差し替えるときは、透過なしの 1024×1024 の PNG にする。
- **プライバシー関連の警告**: 使っているフレームワークによっては、プライバシーマニフェストが必要になる場合がある。メールの指示に従って追加する。
