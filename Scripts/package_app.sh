#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "🔨 Building release binaries with swift build -c release..."
swift build -c release

BIN_DIR=".build/release"
DIST_DIR="dist.noindex"
APP_DIR="${DIST_DIR}/Nightowler.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
HELPERS_DIR="${CONTENTS_DIR}/Library/HelperTools"
DAEMONS_DIR="${CONTENTS_DIR}/Library/LaunchDaemons"

echo "📦 Assembling Nightowler.app bundle..."
rm -rf "${DIST_DIR}" dist
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${HELPERS_DIR}" "${DAEMONS_DIR}" "${DIST_DIR}/bin"
touch "${DIST_DIR}/.metadata_never_index"
ln -sf "${DIST_DIR}" "dist"

# Copy binaries
cp "${BIN_DIR}/NightowlerApp" "${MACOS_DIR}/Nightowler"
cp "${BIN_DIR}/NightowlerHelper" "${HELPERS_DIR}/NightowlerHelper"
cp "${BIN_DIR}/nightowler" "${DIST_DIR}/bin/nightowler"
cp "${BIN_DIR}/nightowler" "${MACOS_DIR}/nightowler-cli"

# Strip debug symbols
strip -S "${MACOS_DIR}/Nightowler" || true
strip -S "${HELPERS_DIR}/NightowlerHelper" || true
strip -S "dist/bin/nightowler" || true
strip -S "${MACOS_DIR}/nightowler-cli" || true

# Copy AppIcon
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Create Info.plist
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Nightowler</string>
    <key>CFBundleExecutable</key>
    <string>Nightowler</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.nightowler.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Nightowler</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Nightowler. Released under the MIT License.</string>
</dict>
</plist>
EOF

# Create Helper LaunchDaemon plist
cat << 'EOF' > "${DAEMONS_DIR}/com.nightowler.app.helper.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nightowler.app.helper</string>
    <key>BundleProgram</key>
    <string>Contents/Library/HelperTools/NightowlerHelper</string>
    <key>MachServices</key>
    <dict>
        <key>com.nightowler.app.helper</key>
        <true/>
    </dict>
    <key>AssociatedBundleIdentifiers</key>
    <array>
        <string>com.nightowler.app</string>
    </array>
</dict>
</plist>
EOF

# Update /Applications/Nightowler.app if already present
if [ -d "/Applications/Nightowler.app" ]; then
    echo "🔄 Syncing release build to /Applications/Nightowler.app..."
    rm -rf "/Applications/Nightowler.app"
    cp -R "${APP_DIR}" "/Applications/Nightowler.app"
fi

# Create resilient CLI installer wrapper
mkdir -p "$HOME/.local/bin"
cat << 'EOF' > "$HOME/.local/bin/nightowler"
#!/bin/sh
if [ -x "/Applications/Nightowler.app/Contents/MacOS/nightowler-cli" ]; then
    exec "/Applications/Nightowler.app/Contents/MacOS/nightowler-cli" "$@"
elif [ -x "$HOME/Downloads/all projects/nightowler/dist/bin/nightowler" ]; then
    exec "$HOME/Downloads/all projects/nightowler/dist/bin/nightowler" "$@"
elif [ -x "$HOME/Downloads/lidrunrea/dist/bin/nightowler" ]; then
    exec "$HOME/Downloads/lidrunrea/dist/bin/nightowler" "$@"
fi
EOF
chmod +x "$HOME/.local/bin/nightowler"

echo "✅ App bundle assembled at dist/Nightowler.app"
echo "✅ CLI installed to ~/.local/bin/nightowler"
