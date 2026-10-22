# SMS platforms — what is implemented vs not verified

The kit speaks SMS only. There is no API and no server.

## Protocol (unchanged)

Commands the app sends, ASCII, PIN appended:

| Action | Body |
|---|---|
| Relay n on | `RnEN` + 4-digit PIN (`R1EN0000`) |
| Relay n off | `RnDS` + PIN |
| Status | `STATUS` + PIN |

Replies the Android inbox understands: `R1=0/1 … R4=0/1`, `Rn ON OK`, `Rn OFF OK`, `PASS ERROR`, `UNKNOWN CMD`.

## Layers

`SmsService` → `SmsTransport`

| Impl | Where |
|---|---|
| `NativeSmsTransport` | Android `SmsManager` + sent PendingIntent; iOS `MFMessageComposeViewController` |
| `WebSmsTransport` | `sms:?body=` via `url_launcher` |

Inbox stream is empty unless `supportsInbox` (Android only). iOS and PWA never synthesize a kit reply.

## States

| UI | Meaning |
|---|---|
| sending | Request handed to the phone |
| awaiting | Phone accepted send (Android radio OK / iOS user tapped Send) or PWA opened Messages. **Not** kit-confirmed |
| on / off | Android: kit reply. Elsewhere: last local cache only |
| error | Send failure, timeout (Android), PASS ERROR, UNKNOWN CMD |
| unknown | No snapshot yet |

`CommandPhase` in `models.dart` names the same split for logs/tests: pending, sentByPhone, confirmed, failed, unknown.

## Security notes

- PIN stays on device (`shared_preferences`). Commands are not signed; the kit checks the PIN.
- `CommandGate` drops a duplicate body for 2s and while a send is in flight.
- Android inbox ignores SMS whose number does not match the saved kit number (last digits).
- Reply timeout is 12s and only arms when inbox is supported.
- Android “silent” delete of the sent row is best-effort and needs SMS provider access. It is not a security boundary.
- Google Play: `SEND_SMS` + `RECEIVE_SMS` + `READ_SMS` are restricted. A store listing needs a core-functionality declaration (device control by SMS). Sideload APK is unaffected.

## Not verified on hardware

- Real SMS send/receive on a physical Android phone and a live SIM800.
- Real iOS Messages sheet on an iPhone with a SIM.
- PWA `sms:` on Android Chrome and iOS Safari (body query differs by OS; ASCII body is used so both can carry `R1EN0000`).
- Whether a given OEM delivers `SMS_SENT` before the modem accepts the PDU.
