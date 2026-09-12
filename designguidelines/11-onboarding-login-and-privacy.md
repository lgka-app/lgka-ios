# Onboarding, Login and Privacy

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Adopted |

---

## 1. The first-run flow

```
Welcome ──► Features ──► Accent colour ──► Appearance ──► Login ──► Home
  logo       6 rows        5 swatches       3 segments     2 fields
  „Weiter"   „Weiter"      „Weiter"         „Los geht's!"  „Anmelden"
```

Four screens plus the login gate, defined in [`App/OnboardingViews.swift`](../App/OnboardingViews.swift):

```swift
struct OnboardingFlow: View {
    @State private var path: [Step] = []
    enum Step: Hashable { case features, accent, appearance, auth }
    // welcome -> what-you-can-do -> accent-color -> appearance -> auth
}
```

### 1.1 What each screen does

| Screen | Content | Haptic on continue |
|---|---|---|
| **Welcome** | 160 pt logo, „Willkommen!" (`largeTitle.bold`), „Bei der neuen App fürs Lessing-Gymnasium Karlsruhe." | `light()` |
| **Features** | An inset-grouped list of six `Label` rows: Vertretungsplan, Stundenplan, Wetterdaten, Neuigkeiten, Krankmeldung, Schulveranstaltungen | `medium()` |
| **Accent colour** | Headline, explanation, the palette picker at 1.3× | `medium()` |
| **Appearance** | Headline, the segmented picker capped at 340 pt | `medium()` |
| **Login** | Username, password, prominent „Anmelden" | `success()` / `error()` |

### 1.2 How it measures against the HIG

> **If you need to present a prerequisite onboarding flow, design a brief, enjoyable experience
> that doesn't require people to memorize a lot of information.** When onboarding is quick and
> entertaining, people are more likely to complete it.
> — [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)

Four taps, nothing to memorise, and two of the four screens are *choices* rather than instruction —
the user is configuring the app, not being lectured at. The flow never reappears:
`onboardingCompleted` is set once, in `signIn(_:)`.

> **Keep onboarding content focused on the experience you provide.** People enter your onboarding
> flow to learn about your app or game; they don't need to learn how to use the system or the device.
> — [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)

The feature list names six app features. It never explains what a tap is.

> **Avoid displaying licensing details within your onboarding flow.** Let the App Store display
> agreements and disclaimers so people can read them before downloading your app or game.
> — [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)

No terms, no consent gate, no licence screen. Privacy policy and Impressum live in settings, where
they belong.

> **Warning — two accepted deviations.**
>
> 1. **The flow is not skippable.** The HIG says: *If it makes sense to offer a separate tutorial,
>    consider making it optional* ([Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)).
>    There is no "Skip" on any screen, and `navigationBarBackButtonHidden()` on three of the four
>    removes the back chevron too. The mitigation is that the two configuration screens have working
>    defaults — the user can hit „Weiter" three times without choosing anything and land on a
>    correctly configured app. The feature list is the one screen that is pure instruction and the
>    obvious candidate for a skip affordance.
>
> 2. **Setup precedes use.** The HIG says: *Postpone nonessential setup flows or customization
>    steps. Provide reasonable default settings so most people can immediately start interacting
>    with your app or game without performing additional configuration*
>    ([Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)).
>    LGKA+ asks about accent colour and appearance before the user has seen a single substitution
>    plan. Both settings are also reachable from the settings sheet at any time, so the flow is
>    redundant with a permanent surface — but it is also two taps, and it gives the app a moment of
>    personality before the login wall. Keep it, but don't add a fifth question.

### 1.3 Copy consistency

> **Give clear guidance and use consistent language throughout processes with multiple steps.** …
> You can use the button label to hint at the next step, or use terms like "Continue" or "Next," but
> be consistent with what you choose. Make it clear when a flow is complete by using language like
> "Done."
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

The app does exactly this: „Weiter" three times, then „Los geht's!" on the last step. One string key
(`continueLabel`) for the repeats, one (`letsGo`) for the finish.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/01_welcome.png" width="180"><br><sub>de · phone · dark — welcome</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/dark/01_welcome.png" width="180"><br><sub>en · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/light/01_welcome.png" width="180"><br><sub>de · phone · light</sub></td>
  </tr>
</table>

---

## 2. The login gate

### 2.1 What is being asked for

The school's website sits behind HTTP basic auth. Every pupil already has the credentials. The app
asks for those, verifies them **against the server**, and stores them in the Keychain.

```swift
/// Login gate — the school website's credentials are verified against the
/// server and stored in the Keychain; the app never compares them locally.
```

That comment is the whole security posture in one line, and it is the right one. There is no
hard-coded password, no local comparison, no shared secret in the binary.

> The school website's read-only credentials are entered once by the user, verified with a request
> to the server and stored in the Keychain. They are never part of the source code and are only ever
> sent to `lessing-gymnasium-karlsruhe.de`.
> — [`README.md`](../README.md)

### 2.2 The form

```swift
TextField(L.s("username"), text: $username)
    .textContentType(.username)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .submitLabel(.next)
    .onSubmit { focus = .password }
SecureField(L.s("password"), text: $password)
    .textContentType(.password)
    .submitLabel(.go)
    .onSubmit { if canLogin { validate() } }
```

| HIG requirement | Status |
|---|---|
| Secure field for the password | ✅ `SecureField` |
| Never prepopulate a password field | ✅ Both fields start empty; there is no "remember" checkbox |
| Hint text in every field | ✅ „Benutzername", „Passwort" |
| Logical submit order | ✅ next → go |
| Gate the action until data is entered | ✅ `canLogin` requires both fields non-blank after trimming |
| Content types for AutoFill | ✅ `.username`, `.password` |

> **Use a secure text-entry field when appropriate.** If your app or game needs sensitive data, use
> a field that obscures people's input as they enter it.
> — [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data)

> **Never prepopulate a password field.** Always ask people to enter their password or use biometric
> or keychain authentication.
> — [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data)

Setting `.textContentType` enables Password AutoFill, which is the system-provided path the HIG
prefers over any custom scheme:

> **Avoid inventing custom authentication schemes.** If your app requires authentication, prefer
> system-provided features like passkeys, Sign in with Apple or Password AutoFill.
> — [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)

The README notes the screenshot suite guards every capture against the AutoFill "Save Password?"
sheet, which confirms AutoFill is live in practice.

### 2.3 The header

The title and subtitle live in the `Form` section's `header`, not in a navigation bar:

```swift
} header: {
    VStack(spacing: 8) {
        Text(L.s("authTitle")).font(.title2.bold())
            .frame(maxWidth: .infinity).accessibilityAddTraits(.isHeader)
        Text(L.s("authSubtitle")).font(.subheadline).multilineTextAlignment(.center)
    }
    .textCase(nil)
    .foregroundStyle(.primary)
    .padding(.bottom, 24).padding(.top, 40)
}
```

`.textCase(nil)` is essential — without it the form would uppercase „Anmeldung erforderlich".

The subtitle does real work: „Verwende die Zugangsdaten, die du bereits von der Schulwebsite kennst".
It tells the user *which* credentials, which is the difference between a wall and a door.

### 2.4 Errors

| Failure | Message (de) | Delivery |
|---|---|---|
| Wrong credentials | „Zugangsdaten sind falsch." | Red text in the form footer + `error()` haptic + red button flash |
| Network unreachable | „Anmeldung nicht möglich – bitte Internetverbindung prüfen." | same |
| Keychain write refused | „Zugangsdaten konnten nicht gespeichert werden." | same |

> **Write clear error messages.** … When an error message is necessary, display it as close to the
> problem as possible, avoid blame, and be clear about what someone can do to fix it.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

The footer is directly beneath the fields, no error is an alert, and each names a distinct cause
with a distinct remedy. The third case is the one most apps forget: the Keychain can refuse, and
silently signing the user in anyway would produce an app that fails every subsequent request.

```swift
if try await SchoolAPI.verify(pair) {
    flash = .success
    Haptics.success()
    try? await Task.sleep(for: .milliseconds(400))
    if !prefs.signIn(pair) { fail(L.s("login.storeFailed")) }
}
```

### 2.5 Recovering from a lost Keychain

```swift
/// Signed in means both the flag and stored credentials exist; a
/// missing keychain item (restored device, cleared keychain) sends the
/// user back through the login gate instead of failing every request.
var isSignedIn: Bool { isAuthenticated && hasCredentials }
```

A restored-from-backup device has the `UserDefaults` flag but not the Keychain item. Checking both
turns a confusing "everything is broken" state into a login screen. This is good defensive design
and should not be simplified away.

---

## 3. Credential storage

[`App/Credentials.swift`](../App/Credentials.swift).

| Property | Value |
|---|---|
| Class | `kSecClassGenericPassword` |
| Service | `de.lgka.school-website` |
| Account | `basic-auth` |
| Accessibility | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| Access group | `$(AppIdentifierPrefix)com.lgka` (entitlement in [`project.yml`](../project.yml)) |
| Format | `user\npassword` as UTF-8 |

> **Store sensitive information in a keychain.** A keychain provides a secure, predictable user
> experience when handling someone's private information.
> — [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)

> **Never store passwords or other secure content in plain-text files.** Even if you restrict access
> using file permissions, sensitive information is much safer in an encrypted keychain.
> — [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)

`…ThisDeviceOnly` is the strong choice: the credentials never sync to iCloud Keychain and never
travel in an encrypted backup to a new device. The trade-off — a restored device must log in
again — is exactly the case `isSignedIn` handles above.

Failures are logged through `os.Logger` with the OSStatus only, never the credential.

`signOut()` calls `Credentials.clear()` before flipping the flags, so the secret is gone from the
Keychain before the UI changes.

---

## 4. Privacy

### 4.1 The manifest

[`App/PrivacyInfo.xcprivacy`](../App/PrivacyInfo.xcprivacy):

```xml
<key>NSPrivacyTracking</key>          <false/>
<key>NSPrivacyTrackingDomains</key>   <array/>
<key>NSPrivacyCollectedDataTypes</key><array/>
<key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>… NSPrivacyAccessedAPICategoryUserDefaults … CA92.1 …</dict>
    <dict>… NSPrivacyAccessedAPICategoryFileTimestamp … C617.1 …</dict>
  </array>
```

- **No tracking.** No tracking domains, no ATT prompt, no advertising identifier.
- **No collected data types.** Nothing leaves the device for the developer.
- **Two required-reason APIs**, both declared: `UserDefaults` with reason `CA92.1` (access only to
  app-group data for this app) and file timestamps with `C617.1` (timestamps of files inside the
  app's own container — which is the disk cache in [`App/Cache.swift`](../App/Cache.swift) reading
  `.modificationDate` for TTL).

### 4.2 Permissions requested: none

The app asks for **zero** runtime permissions. No location, no camera, no microphone, no contacts,
no notifications. Karlsruhe's weather is fetched by fixed coordinates rather than by asking where
the user is — which for a single-school app is both accurate and the minimal-data choice.

> **Request access only to data that you actually need.** Asking for more data than a feature needs
> — or asking for data before a person shows interest in the feature — can make it hard for people
> to trust your app.
> — [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)

> **Avoid requesting permission at launch unless the data or resource is required for your app to
> function.**
> — [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)

There is nothing to postpone, because there is nothing to ask for. This is the strongest privacy
position an app can hold, and it should be treated as a constraint on future features, not an
accident.

Notifications are worth calling out explicitly: a substitution-plan app is an obvious candidate for
push. It has none.

> You need to get permission before sending any notification. … **Build trust by accurately
> representing the urgency of each notification.**
> — [Managing notifications](https://developer.apple.com/design/human-interface-guidelines/managing-notifications)

If notifications are ever added, „your lesson is cancelled tomorrow" is an *Active* notification, not
Time Sensitive — it is not relevant within the hour.

### 4.3 Where data goes

| Destination | What | Why |
|---|---|---|
| `lessing-gymnasium-karlsruhe.de` | The basic-auth header | To fetch the plans, timetables, news and events |
| `open-meteo.com` | Fixed Karlsruhe coordinates | Weather |
| `drkrankmeldung.lgka-online.de` | Whatever the user types into the school's form | The sick note |
| Google Forms | Whatever the user types into the bug report | Bug reports |

Both web views use a **non-persistent** data store:

```swift
config.websiteDataStore = .nonPersistent() // incognito parity
```

Nothing from those pages — cookies, local storage, cache — survives the screen.

The basic-auth challenge handler is tightly scoped:

```swift
if space.authenticationMethod == NSURLAuthenticationMethodHTTPBasic,
   SchoolAPI.isSchoolHost(space.host),
   challenge.previousFailureCount == 0,
   let creds = Credentials.load() {
    return (.useCredential, URLCredential(user: creds.user, password: creds.password,
                                          persistence: .forSession))
}
return (.performDefaultHandling, nil)
```

Three guards — the challenge must be basic auth, the host must be the school's, and it must be the
first attempt — before the credential is offered, and the persistence is `.forSession` so WebKit
never caches it.

### 4.4 Disclosure in the UI

The Krankmeldung info screen is shown once, before the form, and says plainly what the app is and is
not responsible for:

> „Die Krankmeldung wird vom Lessing-Gymnasium bereitgestellt und ist unabhängig von der LGKA+ App."
>
> „Bei technischen Fragen oder Problemen wende dich bitte direkt an das Lessing-Gymnasium Karlsruhe."

Shown once, then `prefs.krankmeldungInfoShown = true` and subsequent taps go straight to the form.
That is a well-judged interstitial: it appears where the boundary actually matters, it is not a
consent gate, and it does not repeat.

> **Be transparent about how your app collects and uses people's data.** People are less likely to
> be comfortable sharing data with your app if they don't understand exactly how you plan to use it.
> — [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)

The settings sheet links the full privacy policy and the Impressum as ordinary `Link` rows.

---

## 5. Do / don't

- [x] Verify credentials against the server; never compare locally.
- [x] Keychain, `…ThisDeviceOnly`, cleared on sign-out.
- [x] `.textContentType` on credential fields so AutoFill works.
- [x] Keep the privacy manifest honest — declare every required-reason API.
- [x] Show a boundary disclosure at the boundary, once.
- [ ] Don't add a permission request without a feature that cannot work without it.
- [ ] Don't add a sixth onboarding screen.
- [ ] Don't put a licence or consent gate in onboarding.
- [ ] Don't persist web-view data. `.nonPersistent()` stays.
- [ ] Don't send the basic-auth credential to any host other than the school's.

---

## Sources

| Source | Kind | Accessed |
|---|---|---|
| [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) | App source | 2026-09-12 |
| [`App/Credentials.swift`](../App/Credentials.swift) | App source | 2026-09-12 |
| [`App/LGKAApp.swift`](../App/LGKAApp.swift) | App source | 2026-09-12 |
| [`App/WebViews.swift`](../App/WebViews.swift) | App source | 2026-09-12 |
| [`App/Cache.swift`](../App/Cache.swift) | App source | 2026-09-12 |
| [`App/PrivacyInfo.xcprivacy`](../App/PrivacyInfo.xcprivacy) | App source | 2026-09-12 |
| [`App/SettingsSheet.swift`](../App/SettingsSheet.swift) | App source | 2026-09-12 |
| [`project.yml`](../project.yml) | App source | 2026-09-12 |
| [`README.md`](../README.md) | App source | 2026-09-12 |
| [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) | Apple HIG | 2026-09-12 |
| [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy) | Apple HIG | 2026-09-12 |
| [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data) | Apple HIG | 2026-09-12 |
| [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) | Apple HIG | 2026-09-12 |
| [Writing](https://developer.apple.com/design/human-interface-guidelines/writing) | Apple HIG | 2026-09-12 |
| [Managing notifications](https://developer.apple.com/design/human-interface-guidelines/managing-notifications) | Apple HIG | 2026-09-12 |
| [Launching](https://developer.apple.com/design/human-interface-guidelines/launching) | Apple HIG | 2026-09-12 |
