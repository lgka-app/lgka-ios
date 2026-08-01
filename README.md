![LGKA+ Banner](https://raw.githubusercontent.com/luka-loehr/LGKA/main/app_store_assets/banners/lgka_banner_1024x500.png)

# LGKA+ – The app for Lessing-Gymnasium Karlsruhe

[![Swift](https://img.shields.io/badge/Swift-Latest-F05138?style=flat&logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS-green?style=flat)](https://github.com/luka-loehr/LGKA/releases)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)
[![App Store](https://img.shields.io/badge/App%20Store-%20-black?style=flat&logo=apple&logoColor=white)](https://apps.apple.com/app/lgka/id6747010920)
[![Google Play](https://img.shields.io/badge/Google%20Play-%20-3DDC84?style=flat&logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=com.lgka)

This repository contains the **native iOS source code (Swift / SwiftUI)** of LGKA+.

**LGKA+** is a mobile app for substitution plans, timetables, news, absence reporting, and weather data of the Lessing-Gymnasium Karlsruhe. Built with SwiftUI.

> Android version: [lgka-app/lgka-android](https://github.com/lgka-app/lgka-android) · Predecessor (Flutter): [luka-loehr/LGKA](https://github.com/luka-loehr/LGKA)

---

## Features

- **Substitution plans** (today & tomorrow) with auto-refresh and caching
- **Timetables** (PDF) with class search
- **News and events**
- **PDF viewer** with zoom, share, and class lookup
- **Live weather** from [Open-Meteo](https://github.com/open-meteo/open-meteo) — current conditions and 3-day forecast
- **Customizable accent colors**
- **Absence reporting** via official school form

---

## License

MIT - [View License](LICENSE)

---

## Support

- [Report bugs](https://github.com/luka-loehr/LGKA/issues)  
- [luka@lukaloehr.com](mailto:luka@lukaloehr.com)  

---

Developed by [Luka Löhr](https://github.com/luka-loehr)

---

## Extractor (first native module)

`Sources/LGKAExtractor` contains the substitution-plan extractor and the schedule class-to-page index: a Swift port of
the geometric Untis-table parser built on PDFKit glyph geometry (identical
API on iOS and macOS). It is verified at **100% parity** against the golden
dataset in [lgka-app/verification](https://github.com/lgka-app/verification).

Runner modes: `substitution` and `classindex` (PDFs), `schedulehtml`
(Stundenplan page scrape), `news`, `events`, `weather` — the app's complete
data layer, all verified against the goldens.

```bash
# run over the verification fixtures
git clone https://github.com/lgka-app/verification.git ../verification
swift run LGKAExtractor substitution ../verification/fixtures/substitution /tmp/out-swift
swift run LGKAExtractor classindex ../verification/fixtures/schedule /tmp/out-swift
# compare against goldens (Rust; run once, get report.html)
cargo run --release --manifest-path ../verification/tool/compare-report/Cargo.toml -- --swift /tmp/out-swift
```
