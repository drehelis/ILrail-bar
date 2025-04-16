#!/bin/bash

set -e

BASE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

DMG_TEMP_DIR=$(mktemp -d -t ilrail)
APP_NAME="ILrail-bar"

xcodebuild -project ${APP_NAME}.xcodeproj -configuration Release

ln -s /Applications "${DMG_TEMP_DIR}/Applications"

cp -R ${BASE_DIR}/../build/Release/${APP_NAME}.app ${DMG_TEMP_DIR}

cat > ${DMG_TEMP_DIR}/README.txt << EOL
# How to Install ILrail-bar

Since this app isn't signed with an Apple Developer certificate, macOS may show a security warning when you first try to open it.

To open the app:
1. Copy the ILrail-bar app to your Applications folder
2. Right-click (or Control-click) on the app icon
3. Select "Open" from the context menu
4. Click "Open" in the dialog box that appears

You only need to do this once. After the first launch, you can open the app normally.

EOL

echo "Self-signing the app..."
codesign --verbose=4 --force --deep --sign - ${DMG_TEMP_DIR}/${APP_NAME}.app

# Create the DMG
hdiutil create -volname "${APP_NAME}" -srcfolder ${DMG_TEMP_DIR} -ov -format UDZO ${BASE_DIR}/../${APP_NAME}.dmg

echo "Cleaning up temp-dir..."
rm -rf ${DMG_TEMP_DIR}