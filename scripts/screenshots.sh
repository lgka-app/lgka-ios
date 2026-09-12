#!/bin/bash
# Automated App Store screenshots — the native port of the Flutter
# fastlane `screenshots_ios` lane. Runs the XCUITest suite in UITests/ for
# every locale × device × appearance and stores full-resolution PNGs under
# app_store_assets/screenshots/<locale>/ios/<phone|tablet>/<dark|light>/.
#
#   LGKA_LOGIN=user:pass scripts/screenshots.sh            # everything
#   LGKA_LOGIN=user:pass scripts/screenshots.sh dark phone  # one appearance / form factor
#
# Requires Xcode 26 with the iPhone 17 Pro Max and iPad Pro 13-inch (M5)
# simulators (Xcode → Settings → Components).
set -euo pipefail
cd "$(dirname "$0")/.."

: "${LGKA_LOGIN:?set LGKA_LOGIN=user:pass (the school website read-only login)}"
MODES=(${1:-dark light})
FORMS=(${2:-phone tablet})
LOCALES=(de en)
device_for() { case "$1" in phone) echo "iPhone 17 Pro Max" ;; tablet) echo "iPad Pro 13-inch (M5)" ;; esac; }
ROOT="$PWD/app_store_assets/screenshots"
DERIVED="$PWD/build/screenshots"

xcodegen generate >/dev/null

udid_for() {
  xcrun simctl list devices available -j | python3 -c "
import json,sys; name=sys.argv[1]; d=json.load(sys.stdin)
print(next(x['udid'] for v in d['devices'].values() for x in v if x['name']==name))" "$1"
}

for form in "${FORMS[@]}"; do
  device="$(device_for "$form")"
  udid=$(udid_for "$device")
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 >/dev/null 2>&1 || true
  for mode in "${MODES[@]}"; do
    xcrun simctl ui "$udid" appearance "$mode" >/dev/null 2>&1 || true
    for locale in "${LOCALES[@]}"; do
      out="$ROOT/$locale/ios/$form/$mode"
      rm -rf "$out"; mkdir -p "$out"
      echo "▶ $device · $mode · $locale"
      # TEST_RUNNER_* environment variables (not build settings) reach the test process.
      env TEST_RUNNER_LGKA_SCREENSHOT_DIR="$out" \
          TEST_RUNNER_LGKA_LOGIN="$LGKA_LOGIN" \
          TEST_RUNNER_LGKA_THEME="$mode" \
          TEST_RUNNER_LGKA_LOCALE="$locale" \
          TEST_RUNNER_LGKA_CLASS="${LGKA_CLASS:-7b}" \
      xcodebuild test -project LGKA.xcodeproj -scheme LGKA \
        -destination "platform=iOS Simulator,id=$udid" \
        -only-testing:LGKAUITests -derivedDataPath "$DERIVED" \
        CODE_SIGN_IDENTITY=- \
        2>&1 | grep -E "Test Case .*(passed|failed|skipped)|error:|\*\* TEST" || true
      ls -1 "$out"
    done
  done
  xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
done
echo "done → $ROOT"
