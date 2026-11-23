#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/KeyFlow.app"
STAGE="$ROOT/dist/dmg-stage"
INFO_PLIST="$ROOT/Resources/Info.plist"
ENTITLEMENTS="$ROOT/Resources/KeyFlow.entitlements"
SKIP_NOTARIZATION="${KEYFLOW_SKIP_NOTARIZATION:-0}"

cd "$ROOT"

fail() {
    echo "error: $*" >&2
    exit 1
}

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
if [[ -n "${KEYFLOW_VERSION:-}" ]]; then
    version="$KEYFLOW_VERSION"
elif [[ -n "${GITHUB_REF_NAME:-}" ]]; then
    version="${GITHUB_REF_NAME#v}"
fi
version="${version//\//-}"
DMG="$ROOT/dist/KeyFlow-$version.dmg"

CODE_SIGN_IDENTITY="${APPLE_SIGNING_IDENTITY:-${CODE_SIGN_IDENTITY:-}}" ./Scripts/package-app.sh

signing_identity="${APPLE_SIGNING_IDENTITY:-${CODE_SIGN_IDENTITY:-}}"
if [[ -z "$signing_identity" ]]; then
    signing_identity="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -n 1)"
fi

if [[ -z "$signing_identity" ]]; then
    if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
        if [[ "$(security find-identity -v -p codesigning)" == *"KeyFlow Local Development"* ]]; then
            signing_identity="KeyFlow Local Development"
        else
            signing_identity="-"
        fi
    else
        fail "找不到 Developer ID Application 签名身份。请设置 APPLE_SIGNING_IDENTITY，或导入 Developer ID 证书。"
    fi
fi

if [[ "$SKIP_NOTARIZATION" != "1" && "$signing_identity" != Developer\ ID\ Application:* ]]; then
    fail "公证分发必须使用 Developer ID Application 签名，当前身份是：$signing_identity"
fi

codesign_args=(
    --force
    --sign "$signing_identity"
    --entitlements "$ENTITLEMENTS"
    --options runtime
)
if [[ "$signing_identity" == Developer\ ID\ Application:* ]]; then
    codesign_args+=(--timestamp)
fi
codesign "${codesign_args[@]}" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/KeyFlow.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "KeyFlow" \
    -srcfolder "$STAGE" \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

rm -rf "$STAGE"

notary_auth=()
if [[ -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" ]]; then
    api_key_path="${APPLE_API_KEY_PATH:-$HOME/.private_keys/AuthKey_${APPLE_API_KEY_ID}.p8}"
    [[ -f "$api_key_path" ]] || fail "找不到 App Store Connect API Key：$api_key_path"
    notary_auth=(--key "$api_key_path" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
    notary_auth=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
fi

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
    echo "warning: 已跳过公证，仅用于本机验证；该 DMG 不适合直接分发给其他用户。" >&2
elif [[ ${#notary_auth[@]} -eq 0 ]]; then
    fail "缺少公证凭据。请设置 APPLE_API_KEY_ID / APPLE_API_ISSUER_ID / APPLE_API_KEY_PATH，或 APPLE_ID / APPLE_APP_SPECIFIC_PASSWORD / APPLE_TEAM_ID。"
else
    submit_output="$(xcrun notarytool submit "$DMG" "${notary_auth[@]}")"
    printf '%s\n' "$submit_output"
    submission_id="$(printf '%s\n' "$submit_output" | awk '/id: / { print $2; exit }')"
    [[ -n "$submission_id" ]] || fail "notarytool 未返回 submission id。"

    if ! wait_output="$(xcrun notarytool wait "$submission_id" "${notary_auth[@]}" 2>&1)"; then
        printf '%s\n' "$wait_output" >&2
        xcrun notarytool log "$submission_id" "${notary_auth[@]}" >&2 || true
        fail "公证等待失败：$submission_id"
    fi
    printf '%s\n' "$wait_output"

    if ! grep -q "status: Accepted" <<<"$wait_output"; then
        xcrun notarytool log "$submission_id" "${notary_auth[@]}" >&2 || true
        fail "公证未通过：$submission_id"
    fi

    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl -a -vv -t open "$DMG"
fi

printf '\n%s\n' "$DMG"
