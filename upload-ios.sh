#!/bin/bash
# My Mosque Pro — builds the iPhone app and uploads it to App Store Connect, without clicking through Xcode.
# Uses the Apple account already signed in to Xcode (Xcode > Settings > Accounts).
cd "$HOME/Documents/MyMosquePro-app/ios/App" 2>/dev/null || { echo "Can't find Documents/MyMosquePro-app/ios/App"; exit 1; }
fail(){ echo ""; echo "STOPPED: $1"; echo "Please send a screenshot of this window to Claude."; exit 1; }

if [ -d App.xcworkspace ]; then SRC=(-workspace App.xcworkspace); else SRC=(-project App.xcodeproj); fi
OUT="$HOME/Documents/MyMosquePro-app/build-ios"
rm -rf "$OUT"; mkdir -p "$OUT"
VER=$(grep -Eo 'MARKETING_VERSION = [0-9.]+' App.xcodeproj/project.pbxproj | head -1 | awk '{print $3}')
BLD=$(grep -Eo 'CURRENT_PROJECT_VERSION = [0-9]+' App.xcodeproj/project.pbxproj | head -1 | awk '{print $3}')
echo "=== My Mosque Pro $VER (build $BLD): building for the App Store (5–10 minutes) ==="

xcodebuild "${SRC[@]}" -scheme App -configuration Release -destination "generic/platform=iOS" \
  -archivePath "$OUT/MyMosquePro.xcarchive" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=B36HQZ94S9 archive -quiet || fail "the iPhone build didn't finish."
echo "Built. Uploading to App Store Connect..."

cat > "$OUT/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>B36HQZ94S9</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST

xcodebuild -exportArchive -archivePath "$OUT/MyMosquePro.xcarchive" -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/export" -allowProvisioningUpdates || fail "the upload didn't finish. Is Xcode signed in to your Apple account (Xcode > Settings > Accounts)?"

echo ""
echo "=== UPLOADED: My Mosque Pro $VER (build $BLD) ==="
echo "In 10–30 minutes it appears in App Store Connect. Then: + next to 'iOS App' > $VER > pick build $BLD > What's New > Add for Review > Submit."
