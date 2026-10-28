#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="mortalpages Studio"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_BUNDLE="${SCRIPT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "=================================================="
echo "    Building ${APP_NAME} for macOS               "
echo "=================================================="

# 1. Clean previous build
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 2. Compile Swift sources
echo "--> Compiling Swift sources..."
swiftc -O -parse-as-library \
    -framework SwiftUI \
    -framework AppKit \
    -framework PDFKit \
    -framework CoreGraphics \
    -framework WebKit \
    -framework Foundation \
    "${SCRIPT_DIR}/App/mortalpagesStudioApp.swift" \
    "${SCRIPT_DIR}/Models/NotebookTemplateMapping.swift" \
    "${SCRIPT_DIR}/Models/NotebookConfig.swift" \
    "${SCRIPT_DIR}/Models/ThemePreset.swift" \
    "${SCRIPT_DIR}/Models/WatermarkSettings.swift" \
    "${SCRIPT_DIR}/Models/HTMLTemplateTheme.swift" \
    "${SCRIPT_DIR}/Models/AIChatSession.swift" \
    "${SCRIPT_DIR}/Engine/KeynoteBridge.swift" \
    "${SCRIPT_DIR}/Engine/PDFLinkEngine.swift" \
    "${SCRIPT_DIR}/Engine/WatermarkRenderer.swift" \
    "${SCRIPT_DIR}/Engine/WebKitPreviewView.swift" \
    "${SCRIPT_DIR}/Engine/AutonomousNotebookCompiler.swift" \
    "${SCRIPT_DIR}/Engine/TemplateRegistry.swift" \
    "${SCRIPT_DIR}/Engine/AIAgentBridge.swift" \
    "${SCRIPT_DIR}/Engine/CodeBeautifier.swift" \
    "${SCRIPT_DIR}/Engine/SyntaxHighlighter.swift" \
    "${SCRIPT_DIR}/Views/Components/FileDropZone.swift" \
    "${SCRIPT_DIR}/Views/Components/TemplatePicker.swift" \
    "${SCRIPT_DIR}/Views/Components/AIConfigSheet.swift" \
    "${SCRIPT_DIR}/Views/Components/IDECodeEditor.swift" \
    "${SCRIPT_DIR}/Views/GeneratorView.swift" \
    "${SCRIPT_DIR}/Views/LayoutConfigView.swift" \
    "${SCRIPT_DIR}/Views/WatermarkConfigView.swift" \
    "${SCRIPT_DIR}/Views/ThemePresetsView.swift" \
    "${SCRIPT_DIR}/Views/TemplateStudioView.swift" \
    "${SCRIPT_DIR}/Views/AIChatView.swift" \
    "${SCRIPT_DIR}/Views/MainAppView.swift" \
    -o "${MACOS_DIR}/${APP_NAME}"

chmod +x "${MACOS_DIR}/${APP_NAME}"

# 3. Create Info.plist
echo "--> Generating Info.plist..."
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>mortalpages Studio</string>
    <key>CFBundleIdentifier</key>
    <string>com.mortalpages.studio</string>
    <key>CFBundleName</key>
    <string>mortalpages Studio</string>
    <key>CFBundleDisplayName</key>
    <string>mortalpages Studio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>mortalpages Studio requires AppleEvents access to automate background slides in Keynote and detect active Preview documents.</string>
</dict>
</plist>
EOF

# 4. Copy Icon & Resources
if [ -f "/tmp/AppIcon.icns" ]; then
    cp "/tmp/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

echo "--> Bundling HTML/CSS Templates..."
cp -R "${SCRIPT_DIR}/Templates" "${RESOURCES_DIR}/"

# 5. Link / Copy to /Applications if writable, or user's ~/Applications
echo "--> Installing application..."
USER_APPS="${HOME}/Applications"
mkdir -p "${USER_APPS}"
rm -rf "${USER_APPS}/${APP_NAME}.app"
cp -R "${APP_BUNDLE}" "${USER_APPS}/${APP_NAME}.app"

# Also try system /Applications if permissions allow
if [ -w "/Applications" ]; then
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
    echo "✓ Installed to /Applications/${APP_NAME}.app"
else
    echo "✓ Installed to ${USER_APPS}/${APP_NAME}.app"
fi

echo "=================================================="
echo "    Build Complete: ${APP_BUNDLE}"
echo "=================================================="
