#!/bin/bash
# アーカイブして、TestFlight にアップロードする。
#
# 署名の方式は、環境変数で切り替える。
#   DIST_CERT_P12_BASE64 などが設定されている → 固定した配布用証明書とプロファイルで署名する（推奨）。
#   設定されていない → アーカイブは署名せず、書き出しのときに、Apple のクラウド管理の配布用証明書で署名する。
#                       （Mac も、証明書の作成も要らない。）
set -euo pipefail

mkdir -p build
KEY_PATH="$HOME/private_keys/AuthKey_${ASC_KEY_ID}.p8"
AUTH=(-authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

if [ -n "${DIST_CERT_P12_BASE64:-}" ] && [ -n "${PROVISIONING_PROFILE_BASE64:-}" ]; then
  echo "署名: 固定した配布用証明書とプロファイル"

  KEYCHAIN="$RUNNER_TEMP/madori.keychain-db"
  KEYCHAIN_PASSWORD="$(uuidgen)"
  trap 'security delete-keychain "$KEYCHAIN" 2>/dev/null || true' EXIT

  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  security set-keychain-settings -lut 21600 "$KEYCHAIN"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  echo "$DIST_CERT_P12_BASE64" | base64 --decode > "$RUNNER_TEMP/dist.p12"
  security import "$RUNNER_TEMP/dist.p12" -k "$KEYCHAIN" -P "${DIST_CERT_PASSWORD:-}" \
    -T /usr/bin/codesign -T /usr/bin/security
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" > /dev/null
  # 作ったキーチェーンを、検索の先頭に加える。
  EXISTING=$(security list-keychains -d user | sed -e 's/"//g')
  # shellcheck disable=SC2086
  security list-keychains -d user -s "$KEYCHAIN" $EXISTING
  rm -f "$RUNNER_TEMP/dist.p12"

  echo "$PROVISIONING_PROFILE_BASE64" | base64 --decode > "$RUNNER_TEMP/profile.mobileprovision"
  security cms -D -i "$RUNNER_TEMP/profile.mobileprovision" > "$RUNNER_TEMP/profile.plist"
  PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print :UUID" "$RUNNER_TEMP/profile.plist")
  PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print :Name" "$RUNNER_TEMP/profile.plist")
  mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
  cp "$RUNNER_TEMP/profile.mobileprovision" "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"
  echo "プロファイル: $PROFILE_NAME"

  xcodebuild archive \
    -project MadoriFit.xcodeproj \
    -scheme MadoriFit \
    -destination 'generic/platform=iOS' \
    -archivePath build/MadoriFit.xcarchive \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Apple Distribution" \
    PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID"

  cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>${APPLE_TEAM_ID}</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>${BUNDLE_ID}</key><string>${PROFILE_NAME}</string>
  </dict>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

  xcodebuild -exportArchive \
    -archivePath build/MadoriFit.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist build/ExportOptions.plist \
    "${AUTH[@]}"
else
  echo "署名: アーカイブは署名なし、書き出しで Apple のクラウド管理の配布用証明書を使う"

  # アーカイブで署名すると、実行のたびに開発用の証明書が作られ、上限に達する。
  # 配信に開発用の証明書は要らないので、ここでは署名せず、書き出しのときだけ署名する。
  xcodebuild archive \
    -project MadoriFit.xcodeproj \
    -scheme MadoriFit \
    -destination 'generic/platform=iOS' \
    -archivePath build/MadoriFit.xcarchive \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY=""

  cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>${APPLE_TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

  xcodebuild -exportArchive \
    -archivePath build/MadoriFit.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist build/ExportOptions.plist \
    -allowProvisioningUpdates \
    "${AUTH[@]}"
fi
