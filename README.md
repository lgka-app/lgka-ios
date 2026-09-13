![LGKA+ for iOS](docs/assets/banner.png)

# LGKA+ for iOS

[![App Store](https://img.shields.io/badge/App%20Store-%20-black?style=flat&logo=apple&logoColor=white)](https://apps.apple.com/app/lgka/id6747010920)
[![CI](https://github.com/lgka-app/lgka-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/lgka-app/lgka-ios/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)

The school app for Lessing-Gymnasium Karlsruhe. Substitution plans, timetables, news, events and the weather, all in one place.

Looking for Android? That's over at [lgka-android](https://github.com/lgka-app/lgka-android).

## What it does

- Substitution plans for today and tomorrow
- Your class timetable, opened right on your page
- School news and upcoming events
- Weather for Karlsruhe with a live sky
- Sick notes through the official school form
- Dark, light or automatic, with your own accent color

The app gets its data from [api.lgka.app](https://github.com/lgka-app/api), so it loads fast and still works offline with the last data it saw.

## Building it

You need Xcode 26.6 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open LGKA.xcodeproj
```

Run the tests with `swift test`.

To sign in you need the school's substitution plan login.

## Feedback

Found a bug? [Open an issue](https://github.com/lgka-app/lgka-ios/issues) or write to [support@lgka.app](mailto:support@lgka.app).

## License

MIT. Made by [Luka Löhr](https://github.com/luka-loehr).
