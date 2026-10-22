# پرامپت طراحی UI برای ChatGPT

سه پرامپت زیر را به ترتیب استفاده کن. خروجی را همان‌طور که هست (عکس + متن توکن‌ها) برای من بفرست تا دقیقاً همان را در Flutter پیاده کنم.

---

## پرامپت ۱ — طراحی صفحه‌ها (کپی کن)

```
You are a senior mobile product designer. Design a premium Android app UI for an
industrial-style smart home controller. Deliver high-fidelity mockups.

PRODUCT
An app that controls a 4-channel relay box over SMS. The box has a SIM card;
the app sends SMS commands to it (it is NOT connected to the internet).
Who uses it: a Kurdish (Sorani) speaker in his 30s-40s, non-technical, uses the
app at home and at his shop. The app must feel calm, expensive and effortless —
not like a hobbyist Arduino app.

LANGUAGE
Primary UI language: Kurdish Sorani (Arabic script, RTL). Use English only for
technical labels (GSM, SMS, R1..R4). Examples of copy:
- Welcome: "بەخێربێی کاک بەختوور"
- Subtitle: "کۆنترۆڵی چوار ئامێر بە پەیام"
- Device names: "فەن ١", "فەن ٢", "فەن ٣", "فەن ٤"
- On state: "کردنەوە"   Off state: "خاموشکردنەوە"
- Settings: "ڕێکخستن"   Log: "تۆمار"   Send: "ناردن"   Sent: "نێردرا"
- Errors: "هەڵە لە ناردن"   No signal: "هێمای نییە"

SCREENS (each 1080 x 1920 px, portrait)

1) SPLASH / WELCOME
Full-bleed deep background with a soft animated aurora gradient. Centered: a
minimal line-art relay/antenna glyph inside a thin luminous ring. Below it
"بەخێربێی کاک بەختوور" in large elegant Kurdish type, then a small subtitle.
Show the motion in 3 key frames (ring draws itself → glyph glow → text fade-up).

2) HOME / CONTROL  (the hero screen)
Top bar: small avatar/logo, greeting "بەخێربێی کاک بەختوور", and a pill showing
signal + "GSM".
Body: a 2x2 grid of four large "fan" cards. Each card shows a beautiful
vector fan illustration (4 or 5 blades, metallic gradient), the device name,
and a state label. OFF = fan blades still, cool gray-blue, dim glow.
ON = blades spinning (show motion blur ring), warm amber/teal glow, active
border, and a subtle animated pulse. Tap toggles the card.
Bottom: one wide primary button "هموو خاموش" (all off) and a small settings icon.
Make a clear visual difference between ON and OFF cards.

3) FAN CARD — states close-up
Show the same card in OFF, ON, and SENDING (in-flight) states, plus a pressed
state with a ripple. SENDING shows a thin progress arc.

4) SETTINGS
Grouped list, large touch targets, RTL: "ژمارەی مۆبایل" (the box's phone number),
"وشەی نهێنی" (4-digit, masked), device renaming, "ناردنی بێدەنگ" (silent send)
toggle with helper text, "تاقیکردنەوە" (test connection) row.

5) COMMAND LOG
Timeline of sent commands and replies: each row has a small icon, device name,
command, time, and status chip (نێردرا / هەڵە / وەڵام). Empty state with a
friendly line-art illustration.

6) TOAST / CONFIRMATION
A minimal bottom sheet: "نێردرا بۆ R1" with a thin progress line that fills for
~3 seconds, and a subtle checkmark.

STYLE
- Dark, "deep space" background (#070B14 → #0E1626), never pure black.
- Glassmorphism cards: 1px inner border rgba(255,255,255,0.08), soft shadow.
- Accent A: cyan/teal #22D3EE for active/tech. Accent B: warm amber #F59E0B for
  ON state. Danger: #F43F5E. Text: #E6EDF7 / secondary #93A4BD.
- Typography: Rabar or Vazirmatn (supports Kurdish), 3 weights only.
- Radius 24-28px, generous spacing (24px gutters), 8pt grid.
- Iconography: 1.5px stroke line icons, rounded caps.
- No stock photos, no emoji, no drop-shadow spam. Subtle noise texture allowed.

DELIVERABLES
- 6 frames at 1080x1920, consistent design system, RTL correct.
- Show at least one screen with a light-mode variant if it looks good.
- Keep everything inside the phone frame, no device mockups.

After the images, output a design-token block exactly in this format:

COLORS: name #hex (usage) — one per line
TYPE: role → font, size, weight, line-height
SPACING: scale used
RADIUS: values
MOTION: for splash, card toggle, sending state (duration + easing curve)
COMPONENTS: name → structure + states
```

---

## پرامپت ۲ — استخراج توکن و مشخصات (بعد از گرفتن عکس‌ها)

```
Now convert the design you just produced into implementation specs for Flutter.
Output ONLY:
1. A JSON object "theme" with: colors (all of them, with semantic names),
   typography scale (fontSize, fontWeight, letterSpacing, height),
   radius, spacing, elevation/shadow values, gradient definitions.
2. For each screen: a component tree (max 3 levels deep) with padding, gaps,
   sizes in logical pixels for a 390x844 logical viewport.
3. Motion specs: splash timeline (ms), card toggle (ms + curve),
   sending progress (ms + curve).
4. Exact Kurdish strings used, per screen, in a table: key | Sorani text.
No prose, no explanations.
```

---

## پرامپت ۳ — استوری‌بورد انیمیشن اسپلش (اختیاری)

```
Create a 4-frame storyboard (1080x1920) for a 2.6 second app launch animation:
frame 1 (0ms) empty deep-navy field; frame 2 (600ms) a thin luminous ring draws
clockwise and a relay glyph appears; frame 3 (1400ms) the ring blooms into soft
amber particles and the Kurdish text "بەخێربێی کاک بەختوور" rises 24px with a
fade; frame 4 (2400ms) everything settles, the logo moves up to make room for
the home screen. Keep it elegant, dark, minimal. Label each frame with its
timestamp and easing.
```

---

## بعد از این

نتیجه را (عکس صفحه‌ها + بلوک JSON) برای من بفرست. من:
1. توکن‌ها را در `lib/theme/` می‌ریزم.
2. همان کارت‌های فن را با `CustomPainter` می‌سازم (بدون نیاز به فایل عکس).
3. انیمیشن اسپلش را با `AnimationController` پیاده می‌کنم.
4. بقیه صفحه‌ها و منطق SMS را وصل می‌کنم.
