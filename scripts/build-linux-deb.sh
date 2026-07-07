#!/usr/bin/env bash
# Build Maran Billing Linux release and package as a .deb for Ubuntu/Debian.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_ID="com.maranbilling.mobile"
APP_NAME="Maran Billing"
PACKAGE_NAME="maran-billing"
INSTALL_DIR="/opt/maran-billing"
BINARY_NAME="mobile"
CLI_NAME="maran-billing"

SKIP_BUILD=0
OUTPUT_DIR="$ROOT/dist/linux"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Build the Flutter Linux release bundle and create a .deb installer.

Options:
  --skip-build    Skip 'flutter build linux --release' (reuse existing bundle)
  --output DIR    Output directory for .deb (default: dist/linux)
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1; shift ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found in PATH" >&2
  exit 1
fi

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "error: dpkg-deb not found. Install with: sudo apt install dpkg-dev" >&2
  exit 1
fi

VERSION_LINE="$(grep '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
VERSION="${VERSION_LINE%%+*}"
BUILD_NUM="${VERSION_LINE#*+}"
if [[ "$BUILD_NUM" == "$VERSION_LINE" ]]; then
  BUILD_NUM="1"
fi

ARCH="$(dpkg --print-architecture)"
BUNDLE_DIR="$ROOT/build/linux/x64/release/bundle"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "==> Building Flutter Linux release..."
  flutter build linux --release
fi

if [[ ! -x "$BUNDLE_DIR/$BINARY_NAME" ]]; then
  echo "error: release bundle not found at $BUNDLE_DIR/$BINARY_NAME" >&2
  echo "Run without --skip-build or fix the Flutter build." >&2
  exit 1
fi

STAGING="$(mktemp -d)"
PKG_ROOT="$STAGING/${PACKAGE_NAME}_${VERSION}_${ARCH}"
DEBIAN_DIR="$PKG_ROOT/DEBIAN"
mkdir -p "$DEBIAN_DIR" "$PKG_ROOT$INSTALL_DIR" "$PKG_ROOT/usr/bin"
mkdir -p "$PKG_ROOT/usr/share/applications"
mkdir -p "$PKG_ROOT/usr/share/icons/hicolor"

cleanup() {
  rm -rf "$STAGING"
}
trap cleanup EXIT

echo "==> Staging application files..."
cp -a "$BUNDLE_DIR/$BINARY_NAME" "$PKG_ROOT$INSTALL_DIR/"
cp -a "$BUNDLE_DIR/lib" "$PKG_ROOT$INSTALL_DIR/"
cp -a "$BUNDLE_DIR/data" "$PKG_ROOT$INSTALL_DIR/"

ln -sf "$INSTALL_DIR/$BINARY_NAME" "$PKG_ROOT/usr/bin/$CLI_NAME"

cat >"$PKG_ROOT/usr/share/applications/${APP_ID}.desktop" <<EOF
[Desktop Entry]
Name=${APP_NAME}
Comment=Pet shop billing and EMR
Exec=${CLI_NAME}
Icon=${APP_ID}
Terminal=false
Type=Application
Categories=Office;Finance;
StartupWMClass=${BINARY_NAME}
EOF

if [[ -d "$BUNDLE_DIR/share/icons/hicolor" ]]; then
  cp -a "$BUNDLE_DIR/share/icons/hicolor/." "$PKG_ROOT/usr/share/icons/hicolor/"
fi

cat >"$DEBIAN_DIR/control" <<EOF
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: office
Priority: optional
Architecture: ${ARCH}
Depends: libgtk-3-0, libsecret-1-0, libglib2.0-0, libstdc++6, libc6
Maintainer: Maran Billing <support@maranbilling.local>
Description: ${APP_NAME} — pet shop billing and EMR
 Desktop client for billing, inventory, purchases, and veterinary EMR.
 Built with Flutter (${BUILD_NUM}).
EOF

cat >"$DEBIAN_DIR/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
fi
EOF
chmod 0755 "$DEBIAN_DIR/postinst"

cat >"$DEBIAN_DIR/prerm" <<'EOF'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
fi
EOF
chmod 0755 "$DEBIAN_DIR/prerm"

mkdir -p "$OUTPUT_DIR"
DEB_FILE="$OUTPUT_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

echo "==> Building $DEB_FILE ..."
dpkg-deb --build --root-owner-group "$PKG_ROOT" "$DEB_FILE"

echo ""
echo "Done."
echo "  Package: $DEB_FILE"
echo "  Install: sudo apt install ./$(basename "$DEB_FILE")"
echo "  Run:     $CLI_NAME"
