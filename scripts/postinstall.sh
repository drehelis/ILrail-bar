#!/bin/sh

APP_PATH="/Applications/ILrail-bar.app"

echo "Removing quarantine attribute from ${APP_PATH}"
xattr -d com.apple.quarantine "${APP_PATH}"

echo "Postinstall script finished."
exit 0
