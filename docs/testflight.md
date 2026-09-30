# TestFlight への配信

`v` から始まるタグ（例: `v1.0.0`）を push するか、Actions 画面の「TestFlight」を手動実行すると、
アーカイブ → App Store Connect へのアップロードまで自動で行う。テストは、通常の CI で済んでいるものとして、ここでは動かさない（タグを打つ前に、CI が通っているか確認する）。
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

## 署名について

既定では、次のようにして、**Mac も、証明書の作成も、要りません**。
- アーカイブは、署名をしないで作ります。
- 書き出しのときだけ、Apple のクラウドで管理された配布用証明書で署名して、アップロードします（API キーの権限が Admin である必要があります）。

以前は、アーカイブでも自動署名をしていたので、実行のたびに開発用の証明書が作られ、
`Your account has reached the maximum number of certificates`（証明書の数が上限）のエラーになっていました。
この方式では、開発用の証明書は作りません。すでに上限に達しているときは、
developer.apple.com > Certificates で、不要な「Apple Development」証明書（`Created via API` など）を削除してください。

### 証明書を自分で用意する方式（任意）

上の既定の方式がうまくいかないときの代わりです。次の 3 つのシークレットを入れると、自動的にこちらになります。

| 名前 | 内容 |
|---|---|
| `DIST_CERT_P12_BASE64` | Apple Distribution 証明書と秘密鍵の `.p12` を、base64 にしたもの |
| `DIST_CERT_PASSWORD` | `.p12` のパスワード |
| `PROVISIONING_PROFILE_BASE64` | App Store 用の `.mobileprovision` を、base64 にしたもの |

Mac がなくても、OpenSSL（Windows なら Git Bash や WSL に入っています）で作れます。

1. **秘密鍵と、証明書署名要求 (CSR) を作る**
   ```sh
   openssl genrsa -out madori.key 2048
   openssl req -new -key madori.key -out madori.csr -subj "/emailAddress=あなたのメール/CN=あなたの名前/C=JP"
   ```
   `madori.key` は秘密鍵です。誰にも渡さず、公開しないでください。
2. developer.apple.com > Certificates > ＋ > **Apple Distribution** で、`madori.csr` をアップロードし、`.cer` をダウンロードする。
3. **`.p12` を作る**（`.cer` は、`distribution.cer` という名前にしたとします）
   ```sh
   openssl x509 -inform DER -in distribution.cer -out distribution.pem
   openssl pkcs12 -export -inkey madori.key -in distribution.pem -out distribution.p12 \
     -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 -passout pass:好きなパスワード
   ```
4. developer.apple.com > Profiles > ＋ > **App Store Connect** > 自分のバンドル ID > 2 の証明書 で、プロファイルを作り、`.mobileprovision` をダウンロードする。
5. ファイルを base64 にして、シークレットに貼る（Windows の Git Bash なら `base64 -w0 distribution.p12`、`base64 -w0 プロファイル.mobileprovision`）。

プロファイルには、App ID に登録した Capabilities（Data Protection など）が含まれている必要があります。
証明書とプロファイルの有効期限は 1 年です。

## 配信のしかた

**Mac がなくても、GitHub の画面から配信できます。** リポジトリの「Releases」>「Draft a new release」で、
「Choose a tag」に `v1.0.0` のような新しい名前を入れ、「Create new tag」を選び、「Target」にブランチを指定して、
「Publish release」を押すと、タグが作られて、配信が始まります。

コマンドが使えるなら、次のようにもできます。

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
