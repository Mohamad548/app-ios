# SmartRelay / SIM800 Control — Design & Architecture Brief

**Audience:** another AI agent or senior engineer continuing this app  
**Project root:** `E:\workups\app sim800`  
**Asset kit (source of truth for UI):** `C:\Users\Mohamad\Downloads\SmartRelay_Asset_Kit\SmartRelay_Asset_Kit`  
**Last UI pass:** Flutter Android-first redesign against the Asset Kit mockups + tokens  
**App ID / package:** `com.bakhtor.sim800_controller`

---

## 1. Product goal

Control a physical **4-channel SMS relay kit** (SIM800L + ATmega32). The phone app sends short command SMS to the kit SIM number. No cloud is required for v1.

| Platform | Role | Status |
|---|---|---|
| Android | Primary: silent SMS via `SmsManager` | Active |
| iOS | Scaffold only; Apple blocks silent SMS | Deferred |
| Web | UI preview / DEMO only (no SMS) | Preview |

---

## 2. Why the phone showed a white screen

OpenCode partially migrated `lib/theme.dart` to a new `Palette` API and **removed `AppColors` / `AppTheme.fontFamily`**, while splash/home/settings/log/fan_card still referenced the old symbols.

`flutter analyze` reported dozens of `Undefined name 'AppColors'` errors. A release APK built *before* that break could still be installed; after the broken theme change, the tree no longer compiled cleanly. Hot-reload / incomplete rebuilds presented as a blank/white screen.

**Fix applied:** restore a coherent theme (`Palette` + legacy `AppColors` aliases), rewrite screens/widgets to the Asset Kit, guard `Store.init()` so prefs failure never blocks `runApp`, and rebuild.

---

## 3. Design system (must follow)

### Colors

| Token | Dark | Light |
|---|---|---|
| background-start | `#070B14` | `#F3F6FA` |
| background-end | `#0E1626` | `#E8EFF7` |
| surface | `#141E2F` | `#FFFFFF` |
| border | `#FFFFFF` @ 8% | `#D7E1EC` |
| tech | `#22D3EE` | `#087F91` |
| on | `#F59E0B` | `#B76A06` |
| danger | `#F43F5E` | `#E11D48` |
| text-primary | `#E6EDF7` | `#152238` |
| text-secondary | `#93A4BD` | `#53657D` |

Implemented in `lib/theme.dart` as `Palette.dark` / `Palette.light`. Current app forces **dark** (`ThemeMode.dark`); light theme tokens exist for confirmation mock / future toggle.

### Typography

Family: **Vazirmatn** (variable font: `assets/fonts/Vazirmatn-Variable.ttf`). Weights used: **400 / 500 / 600 only**.

| Role | Size / weight / line-height |
|---|---|
| welcome | 28 / 600 / 40 |
| screen-title | 24 / 600 / 34 |
| greeting | 20 / 500 / 30 |
| device-name | 20 / 600 / 28 |
| body | 16 / 400 / 24 |
| button | 16 / 600 / 24 |
| metadata | 13 / 400 / 20 |

Helpers: `T.welcome(p)`, `T.title(p)`, … in `lib/theme.dart`.

### Spacing / radius / touch

- Spacing scale: 8, 16, 24, 32, 40, 48 (`AppSpace`)
- Outer gutters: **24dp**; card gap: **16dp**; min touch: **48dp**
- Radii: card **24**, sheet **28**, button **24**, pills fully rounded (`AppRadii`)

### Motion

| Effect | Timing | Curve |
|---|---|---|
| Splash ring | 600ms | `cubic-bezier(0.22,1,0.36,1)` |
| Splash glyph / text | 300ms | same |
| Card toggle | 240ms | `cubic-bezier(0.2,0,0,1)` |
| Fan ON spin | 1800ms linear loop | only **rotor** layer |
| ON glow pulse | 2400ms ease-in-out | |
| Pressed scale | 0.98 over 100ms | |
| Sending arc | 1000ms linear loop | |
| Confirm sheet in | 240ms | standard |
| Confirm dismiss bar | 3000ms linear | UI dismiss only — **not** delivery proof |
| Reduced motion | static fan, no pulse; short opacity only | `MediaQuery.disableAnimationsOf` |

### Screens (match `reference-mockups/`)

1. **Splash** — aurora + luminous ring + relay glyph + Sorani welcome  
2. **Home** — greeting, GSM/DEMO pill, 2×2 fan cards (RTL: R1 top-start), all-off + settings  
3. **Card states** — OFF / ON / pressed / sending / awaiting / error / unknown  
4. **Settings** — phone, 4-digit PIN, device names, silent toggle, test SMS  
5. **Command log** — filters All / Sent / Error + timeline  
6. **Confirmation sheet** — “sent to Rn” + awaiting + 3s bar  

### Copy (Sorani)

Source: Asset Kit `localization/ckb.json` → app `lib/l10n.dart` (+ `assets/ckb.json`).  
Status words ≠ action words: `چالاکە` / `کوژاوەتەوە` (state) vs `کردنەوە` / `خاموشکردنەوە` (next action).  
`نێردرا` means SMS left the phone, **not** that the kit executed the command.

### Fan rendering (critical)

Layer order from kit README: **rotor → cage → hub**.  
Only rotate the rotor SVG around center. Do **not** rotate the whole composite (cage would spin).  
Assets live under `assets/fans/dark|light/{rotor-on,rotor-off,cage,hub}.svg`.  
Widget: `lib/widgets/fan_visual.dart`.

### Icons

`assets/icons/*.svg` with `currentColor` via `AppIcon` (`flutter_svg` + `ColorFilter`).

### RTL / bidi

App-wide `Directionality.rtl`. Keep phone numbers and `R1..R4` as **LTR** (`textDirection: TextDirection.ltr`).

---

## 4. Software architecture

```
lib/
  main.dart              bootstrap, RTL, theme, Store.init guard
  theme.dart             Palette, T, AppTheme, AppSpace, AppRadii
  l10n.dart              Sorani strings
  models.dart            Device, RelayUiState, LogEntry, LogKind
  store.dart             SharedPreferences: phone, PIN, names, silent
  sms_service.dart       MethodChannel 'sim800/sms' + CommandLog + demo flag
  screens/               splash, home, settings, log
  widgets/               aurora, glass card, fan visual/card, icons, signal pill, confirm sheet
android/.../MainActivity.kt   SmsManager send + SEND_SMS permission
firmware/atmega32/       kit firmware
docs/protocol.md         SMS command protocol
docs/circuit.md          hardware
```

### SMS protocol (summary)

| UI action | Payload |
|---|---|
| Channel n ON | `RnEN` + 4-digit PIN |
| Channel n OFF | `RnDS` + 4-digit PIN |
| Test | `STATUS` + PIN |
| All off | four `RnDS…` sends sequentially |

Native Android channel methods: `canSend`, `requestPermission`, `send`.  
Web: `SmsService.demo == true` → simulated success for UI review.

### UI state machine per card

`RelayUiState`: `off | on | sending | awaiting | error | unknown`  
Rules from kit:

- While `sending` / `awaiting`, ignore further taps (no double SMS).  
- On send failure, restore previous state (or show `error` if unknown).  
- Optimistic ON/OFF after send until inbound reply parsing exists (not implemented yet).  
- All-off must surface partial failures (`error` on failed channels).

### Persistence

`Store` keys: `kit_phone`, `kit_pass`, `silent_send`, `device_names`. Default PIN `0000`. Default names فەن ١…٤.

---

## 5. Build & install (Windows)

```powershell
$env:JAVA_HOME="E:\dev\jdk"
$env:ANDROID_HOME="E:\dev\android-sdk"
$env:PATH="E:\dev\jdk\bin;E:\dev\flutter\bin;$env:PATH"
cd "E:\workups\app sim800"
flutter pub get
flutter analyze
flutter build apk --release
copy build\app\outputs\flutter-apk\app-release.apk dist\SIM800-Control-v1.0.0.apk
```

Web preview: `flutter build web --release --no-web-resources-cdn` then `preview.bat`.

---

## 6. Known gaps / next work for another AI

1. **Inbound SMS / reply parsing** — kit replies not yet decoded; awaiting state is optimistic.  
2. **Delivery reports** — optional `SmsManager` sent/delivered intents.  
3. **Light theme toggle** — tokens ready; home currently dark-only.  
4. **iOS path** — `MFMessageComposeViewController` or GPRS/server control.  
5. **Silent send preference** — stored but Android always uses SmsManager; preference is UX/docs for now.  
6. **Semantic weight 600** — variable font registered; verify on-device Vazirmatn axis.  
7. **Replace CustomPaint fan** — old `fan_painter.dart` is unused; can delete after confirming SVG path.  
8. **Hardware test** — end-to-end with real SIM800 kit + permissions on physical phone.  
9. Sync any remaining mockup micro-copy from `ckb.json` if a native speaker reviews.

---

## 7. Do / don’t for future UI edits

**Do**

- Prefer Asset Kit SVG/WebP over Material icons.  
- Use `Palette.of(context)` and `T.*`.  
- Keep one tap target per card action.  
- Preserve RTL grid order R1→R4.

**Don’t**

- Rotate cage/hub with the rotor.  
- Treat “نێردرا” as device confirmation.  
- Use the 3s sheet timer as delivery progress.  
- Introduce Inter/Roboto or purple-gradient “AI default” styling — stick to kit tokens.

---

## 8. Reference files in the Asset Kit

- `tokens/design-tokens.json`, `tokens/tokens.css`  
- `reference-mockups/webp/01`…`06`  
- `README-fa.md` (fan layer rules, SMS semantics, RTL)  
- `localization/ckb.json`  
- `fans/layers`, `icons/svg`, `brand`, `backgrounds`, `components`

When in doubt, open `preview.html` in the Asset Kit folder — offline interactive preview of components and fan states.
