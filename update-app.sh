#!/bin/bash
# My Mosque Pro — puts the latest app (from the website) into the phone apps, then builds them.
# Double-click this file. It lives in Documents/MyMosquePro-app, next to "Build Android App.command".

cd "$(dirname "$0")" || exit 1
fail(){ echo ""; echo "STOPPED: $1"; echo "Please send a screenshot of this window to Claude."; read -n 1 -s -r -p "Press any key to close this window."; exit 1; }

echo "=== My Mosque Pro: updating the phone apps ==="
[ -f capacitor.config.json ] && [ -d www ] || fail "this file must be inside the MyMosquePro-app folder."

# 1. Latest app code from the website (a copy of the current one is kept in backups/)
STAMP=$(date +%Y%m%d-%H%M)
mkdir -p "backups/$STAMP" && cp www/index.html "backups/$STAMP/index.html" 2>/dev/null
echo "1/5 Downloading the latest app..."
curl -fsSL "https://tybm1.github.io/my-mosque-pro/index.html?v=$STAMP" -o "/tmp/mmp-index.html" || fail "couldn't download the app. Check the internet connection."
grep -q "qbScreenAngle" /tmp/mmp-index.html && grep -q "app_name" /tmp/mmp-index.html || fail "the website doesn't have the newest version yet. Try again in 10 minutes."
cp /tmp/mmp-index.html www/index.html
[ -f www/adhan.umd.min.js ] || curl -fsSL "https://tybm1.github.io/my-mosque-pro/adhan.umd.min.js" -o www/adhan.umd.min.js
echo "    done (old copy saved in backups/$STAMP)"

# 2. Buzz on iPhone when you face the Qibla
echo "2/5 Adding the vibration plugin..."
npm install @capacitor/haptics@8.0.2 --save >/dev/null 2>&1 || echo "    (couldn't add it: the app still works, iPhone just won't buzz)"

# 3. Copy into the iPhone and Android projects
echo "3/5 Copying into the iPhone and Android apps..."
npx cap sync || fail "the copy step (npx cap sync) didn't finish."

# 4. New build numbers (version 2.0.1 if 2.0.0 is already live in the App Store)
echo ""
read -r -p "4/5 Is version 2.0.0 already LIVE in the App Store? (y/n) " LIVE
GRADLE=android/app/build.gradle
PBX=ios/App/App.xcodeproj/project.pbxproj
OLDC=$(grep -Eo 'versionCode [0-9]+' "$GRADLE" | head -1 | awk '{print $2}')
[ -n "$OLDC" ] || fail "couldn't find versionCode in $GRADLE."
NEWC=$((OLDC+1)); sed -i '' "s/versionCode $OLDC/versionCode $NEWC/" "$GRADLE"
OLDB=$(grep -Eo 'CURRENT_PROJECT_VERSION = [0-9]+' "$PBX" | head -1 | awk '{print $3}')
[ -n "$OLDB" ] || fail "couldn't find the iPhone build number in $PBX."
NEWB=$((OLDB+1)); sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $NEWB;/g" "$PBX"
if [ "$LIVE" = "y" ] || [ "$LIVE" = "Y" ]; then
  sed -i '' -E 's/versionName "[^"]*"/versionName "2.0.1"/' "$GRADLE"
  sed -i '' -E 's/MARKETING_VERSION = [0-9.]+;/MARKETING_VERSION = 2.0.1;/g' "$PBX"
  VER="2.0.1"
else
  VER=$(grep -Eo 'MARKETING_VERSION = [0-9.]+' "$PBX" | head -1 | awk '{print $3}')
fi
echo "    Version $VER · iPhone build $NEWB · Android versionCode $NEWC"

# 5. Build Android, then open Xcode for the iPhone upload
echo "5/5 Building the Android app (a few minutes)..."
( J21=$(ls -d "$HOME"/Library/Java/JavaVirtualMachines/*21*/Contents/Home /Library/Java/JavaVirtualMachines/*21*/Contents/Home 2>/dev/null | head -1)
  [ -z "$J21" ] && J21=$(/usr/libexec/java_home -v 21 2>/dev/null)
  export JAVA_HOME="${J21:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
  cd android && chmod +x gradlew && ./gradlew --stop >/dev/null 2>&1; ./gradlew bundleRelease )
if [ -f android/app/build/outputs/bundle/release/app-release.aab ]; then
  echo "    Android app ready: android/app/build/outputs/bundle/release/app-release.aab"
  open android/app/build/outputs/bundle/release
else
  echo "    The Android build didn't finish (send Claude a screenshot). Carrying on with iPhone."
fi
if [ -d ios/App/App.xcworkspace ]; then open ios/App/App.xcworkspace; else open ios/App/App.xcodeproj; fi

echo ""
echo "=== DONE ==="
echo "iPhone: in Xcode choose 'Any iOS Device', then Product > Archive > Distribute App > App Store Connect."
echo "Android: upload app-release.aab in Play Console > Production > Create new release."
echo ""
read -n 1 -s -r -p "Press any key to close this window."
