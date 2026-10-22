# Testing, SMS limits, and kit sync

## Release crash that looked like “save does nothing”

`shared_preferences_android` **2.5.0** crashes **release** APKs with  
`NoSuchMethodError … SharedPreferencesApiRegistrar.getAll` (R8 strips Kotlin `Continuation`).

**Fix in this project:** pin `shared_preferences_android: ">=2.4.28 <2.5.0"` and ProGuard keep rules.

## SMS permission greyed out (“اجازه دادن” disabled)

On Android 13+ / OEM security layers, SMS is a **restricted** permission.

1. Settings → Apps → **SIM800 Control** → ⋮ → **Allow restricted settings**  
2. Then Permissions → SMS → **Allow**

Without step 1, Allow stays grey. This is OS policy, not an app bug.

## Hiding sent SMS from the messaging app

- `SmsManager` often still writes a row to the system SMS provider.  
- We **best-effort delete** from `content://sms/sent` after send when “silent” is on.  
- **Full hide** is only reliable if the app is the **default SMS app** (heavy UX) or you switch the kit to **GPRS/HTTP** (no SMS).  
- Be honest with users: silent delete is best-effort on many Iranian OEM ROMs.

## Fan state after leaving the app

1. **Local cache** — last commanded ON/OFF is stored and restored on open.  
2. **Kit sync** — on open/resume the app sends `STATUS`+PIN; firmware replies `R1=0/1 … R4=0/1`.  
3. If `RECEIVE_SMS` is granted, the reply updates the UI.  
4. If not, local cache still shows the last known state.

**Hardware note:** firmware `app_init()` calls `app_all_off()` on kit power-up — a power cut resets relays to OFF. STATUS then reports zeros; that is correct physical state, not an app bug.

## Test commands

```powershell
cd "E:\workups\app sim800"
flutter test
flutter analyze
flutter build apk --release
```
