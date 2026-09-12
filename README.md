![LGKA+ Banner](https://raw.githubusercontent.com/luka-loehr/LGKA/main/app_store_assets/banners/lgka_banner_1024x500.png)

# LGKA+ – The app for Lessing-Gymnasium Karlsruhe

[![CI](https://github.com/lgka-app/lgka-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/lgka-app/lgka-ios/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.3-F05138?style=flat&logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/iOS-26-green?style=flat)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)
[![App Store](https://img.shields.io/badge/App%20Store-%20-black?style=flat&logo=apple&logoColor=white)](https://apps.apple.com/app/lgka/id6747010920)
[![Google Play](https://img.shields.io/badge/Google%20Play-%20-3DDC84?style=flat&logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=com.lgka)

This repository contains the **native iOS source code (Swift 6 / SwiftUI, iOS 26)** of LGKA+.

**LGKA+** is a mobile app for substitution plans, timetables, news, absence reporting, and weather data of the Lessing-Gymnasium Karlsruhe.

> Android version: [lgka-app/lgka-android](https://github.com/lgka-app/lgka-android) · Parity harness: [lgka-app/verification](https://github.com/lgka-app/verification) · Predecessor (Flutter): [luka-loehr/LGKA](https://github.com/luka-loehr/LGKA)

---

## Features

- **Substitution plans** (today & tomorrow) with auto-refresh and caching
- **Timetables** (PDF) with class search and cross-PDF class switching
- **News and events**
- **PDF viewer** with search, share, and class lookup
- **Live weather** from [Open-Meteo](https://github.com/open-meteo/open-meteo) — animated Metal sky, hourly and 3-day forecast
- **Customizable accent colors**, light/dark/auto appearance
- **Absence reporting** via the official school form

---

## Structure

```
Package.swift            SwiftPM package: LGKACore + lgka-extractor + tests (swift-tools 6.2, Swift 6 language mode)
Sources/LGKACore/        the verified data layer: substitution PDF extractor, class index, schedule page,
                         news, events, weather — 100% golden parity with the Flutter app (see Tests/)
Sources/lgka-extractor/  parity CLI used by lgka-app/verification
Tests/LGKACoreTests/     Swift Testing: golden parity against ../verification + robustness tests
App/                     SwiftUI app (XcodeGen spec in project.yml)
  LGKAApp.swift          entry, Prefs (@Observable), orientation policy, refresh loop
  HomeModel.swift        home hub state (@Observable, main-actor)
  SchoolAPI.swift        typed fetchers over LGKACore, Cache.swift (disk cache + request dedup)
  Credentials.swift      Keychain-stored school website login
  Localizable.xcstrings  String Catalog (de source, en)
  PrivacyInfo.xcprivacy  privacy manifest
DESIGN_GUIDELINES.md     brand rules + reference copy of the Apple HIG chapters we follow
```

## Build

```bash
brew install xcodegen
xcodegen generate                     # creates LGKA.xcodeproj (gitignored)
xcodebuild -scheme LGKA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Requires Xcode 26.6 / Swift 6.3. The project builds with `SWIFT_STRICT_CONCURRENCY=complete` and warnings as errors.

## Test

```bash
git clone https://github.com/lgka-app/verification.git ../verification
swift test                            # golden parity + robustness (LGKA_VERIFICATION_DIR overrides the lookup)
```

The parity CLI is unchanged:

```bash
swift run lgka-extractor substitution ../verification/fixtures/substitution /tmp/out-swift
swift run lgka-extractor classindex ../verification/fixtures/schedule /tmp/out-swift
cargo run --release --manifest-path ../verification/tool/compare-report/Cargo.toml -- --swift /tmp/out-swift
```

## Login and credentials

The school website's read-only credentials are entered once by the user, verified with a request to the server and stored in the Keychain. They are never part of the source code and are only ever sent to `lessing-gymnasium-karlsruhe.de`.

---

## License

MIT - [View License](LICENSE)

## Support

- [Report bugs](https://github.com/luka-loehr/LGKA/issues)
- [luka@lukaloehr.com](mailto:luka@lukaloehr.com)

Developed by [Luka Löhr](https://github.com/luka-loehr)
