#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MouseGestures"
BUNDLE_ID="com.freezy.MouseGestures"
CONFIGURATION="${CONFIGURATION:-release}"
BUILD_DIR="$(swift build --configuration "$CONFIGURATION" --show-bin-path)"
APP_DIR="build/${APP_NAME}.app"
INFO_PLIST_SRC="Resources/Info.plist"
APPICON_SRC="Sources/MouseGestures/Resources/AppIcon.png"

CERT_NAME="${SIGN_IDENTITY:-MouseGestures}"
CERT_AUTO_CREATE="${SIGN_IDENTITY_AUTO_CREATE:-1}"

echo "==> Building $APP_NAME ($CONFIGURATION)"
swift build --configuration "$CONFIGURATION"

echo "==> Packaging $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$INFO_PLIST_SRC" "$APP_DIR/Contents/Info.plist"

if [ -d "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_DIR/Contents/Resources/"
fi

if [ -f "$APPICON_SRC" ]; then
    echo "==> Generating AppIcon.icns"
    ICONSET_DIR="build/AppIcon.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    for size in 16 32 64 128 256 512 1024; do
        sips -z $size $size "$APPICON_SRC" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    done
    cp "$ICONSET_DIR/icon_32x32.png"   "$ICONSET_DIR/icon_16x16@2x.png"
    cp "$ICONSET_DIR/icon_64x64.png"   "$ICONSET_DIR/icon_32x32@2x.png"
    cp "$ICONSET_DIR/icon_256x256.png" "$ICONSET_DIR/icon_128x128@2x.png"
    cp "$ICONSET_DIR/icon_512x512.png" "$ICONSET_DIR/icon_256x256@2x.png"
    cp "$ICONSET_DIR/icon_1024x1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
    echo "    Generated AppIcon.icns"
fi

if security find-identity -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "==> Codesigning with identity: $CERT_NAME"
    codesign --force --deep --sign "$CERT_NAME" "$APP_DIR"
elif [ "$CERT_AUTO_CREATE" = "1" ]; then
    echo "==> Identity '$CERT_NAME' not found. Creating self-signed cert in keychain..."
    TMPDIR=$(mktemp -d -t mousegestures-cert)
    openssl genrsa -out "$TMPDIR/key.pem" 2048 2>/dev/null
    openssl req -new -x509 -days 3650 -key "$TMPDIR/key.pem" -out "$TMPDIR/cert.pem" \
        -subj "/CN=$CERT_NAME" 2>/dev/null
    openssl pkcs12 -export -out "$TMPDIR/cert.p12" -inkey "$TMPDIR/key.pem" \
        -in "$TMPDIR/cert.pem" -password pass: 2>/dev/null

    KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
    security import "$TMPDIR/cert.p12" \
        -k "$KEYCHAIN" -P "" \
        -T /usr/bin/codesign -T /usr/bin/security 2>/dev/null
    security add-trusted-cert -d -r trustRoot \
        -k "$KEYCHAIN" "$TMPDIR/cert.pem" 2>/dev/null || true
    security set-key-partition-list -S apple-tool:,apple:,codesign: \
        -s -k "" "$TMPDIR/cert.p12" 2>/dev/null || true
    rm -rf "$TMPDIR"

    if security find-identity -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
        echo "    Certificate created and imported to keychain"
        codesign --force --deep --sign "$CERT_NAME" "$APP_DIR"
    else
        echo "    WARNING: Could not verify cert trust. Falling back to ad-hoc."
        codesign --force --deep --sign - "$APP_DIR"
    fi
else
    echo "==> Identity '$CERT_NAME' not found and auto-create disabled. Ad-hoc codesigning."
    echo "    Set SIGN_IDENTITY_AUTO_CREATE=1 to enable cert creation, or create manually via Keychain Access."
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "==> Done: $APP_DIR"
