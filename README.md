# ussd_session

Send single-response USSD requests (balance, bundle and account queries) from Flutter on Android,
with dual-SIM targeting, typed errors and a dialer fallback. It uses only the official
`TelephonyManager.sendUssdRequest` API.

[![pub package](https://img.shields.io/pub/v/ussd_session.svg)](https://pub.dev/packages/ussd_session)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Android only (API 26+ for send; dial works everywhere Android).** Android only; iOS not supported.

## Features

- `UssdSession.send(code, subscriptionId:, timeout:)` calls
  [`TelephonyManager.sendUssdRequest`](https://developer.android.com/reference/android/telephony/TelephonyManager)
  and returns a `UssdResponse(request, text, subscriptionId, receivedAt)`.
- Dual SIM: `UssdSession.simCards()` lists the active SIMs from
  `SubscriptionManager.getActiveSubscriptionInfoList`, with subscription id, slot, carrier name,
  display name, MCC/MNC and country ISO. `send` then targets a SIM through
  `TelephonyManager.createForSubscriptionId`.
- Typed failures: every error is a `UssdException` with a `UssdErrorCode`.
- `UssdSession.permissionsStatus()` reports `CALL_PHONE` and `READ_PHONE_STATE` without ever
  prompting.
- `UssdSession.dial(code)` opens the dialer with the code filled in (`ACTION_DIAL`, with `#`
  encoded as `%23`). It needs no permission and the user presses call.
- Pure Dart helpers: `UssdCode.validate` / `normalize` / `telUri`, and `extractAmounts`, which
  reads dinar amounts ("150,00 DA", "150.00 DZD", "١٥٠ دج") out of a reply.
- `AlgerianCarrierPresets`: the Mobilis, Djezzy and Ooredoo balance codes, each checked on the
  carrier's own website (see [Data sources](#data-sources)).

## Install

```yaml
dependencies:
  ussd_session: ^0.1.0
```

Declare the permissions you use in `android/app/src/main/AndroidManifest.xml`. The plugin does not
declare them for you, so an app that only uses `dial` does not ask for phone permissions.

```xml
<!-- Needed by UssdSession.send -->
<uses-permission android:name="android.permission.CALL_PHONE" />
<!-- Needed by UssdSession.simCards (and for checking a subscriptionId before sending) -->
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
```

| Method | Android version | Permission |
| --- | --- | --- |
| `send` | 8.0+ (API 26) | `CALL_PHONE` |
| `simCards` | 5.1+ (API 22) | `READ_PHONE_STATE` |
| `permissionsStatus` | any | none |
| `dial` | any | none |

## Usage

### Asking for permissions

This plugin only reports the status. Request at runtime with
[permission_handler](https://pub.dev/packages/permission_handler). On Android its
`Permission.phone` asks for the phone permission group, which includes `CALL_PHONE` and
`READ_PHONE_STATE` when they are declared in the manifest:

```dart
import 'package:permission_handler/permission_handler.dart';
import 'package:ussd_session/ussd_session.dart';

Future<bool> ensureUssdPermissions() async {
  final status = await UssdSession.permissionsStatus();
  if (status.canSend && status.canListSims) return true;
  return (await Permission.phone.request()).isGranted;
}
```

### Sending a code on a chosen SIM

```dart
import 'package:ussd_session/ussd_session.dart';

Future<void> checkBalances() async {
  final sims = await UssdSession.simCards();
  for (final sim in sims) {
    final preset = AlgerianCarrierPresets.balanceFor(sim);
    if (preset == null) continue;
    try {
      final reply = await UssdSession.send(
        preset.code,
        subscriptionId: sim.subscriptionId,
        timeout: const Duration(seconds: 20),
      );
      print('${sim.carrierName}: ${reply.text}');
      print('Amounts found: ${extractAmounts(reply.text)}');
    } on UssdException catch (e) {
      switch (e.code) {
        case UssdErrorCode.unsupported:
          await UssdSession.dial(preset.code); // Android < 8: let the user dial
        case UssdErrorCode.callPhonePermissionDenied:
          print('Grant the phone permission first');
        default:
          print('USSD failed: ${e.code.name} (${e.message})');
      }
    }
  }
}
```

The same call works for any carrier's single-response code, for example
`UssdSession.send('*123#')` on the default SIM.

### Errors

| `UssdErrorCode` | When |
| --- | --- |
| `invalidCode` | Code has characters other than `*#0-9+`, does not start with `*`/`#` and end with `#`, or is longer than 182 characters. Checked in Dart before any platform call. |
| `returnFailure` | The network answered `USSD_RETURN_FAILURE`. |
| `serviceUnavailable` | `USSD_ERROR_SERVICE_UNAVAIL`: no service, airplane mode, another USSD session in progress, and so on. |
| `callPhonePermissionDenied` | `CALL_PHONE` not granted. |
| `readPhoneStatePermissionDenied` | `READ_PHONE_STATE` not granted (from `simCards`). |
| `noSim` | No SIM, or the targeted SIM is locked or not ready. |
| `invalidSubscription` | The `subscriptionId` is negative or not an active SIM. The active-SIM check runs only when `READ_PHONE_STATE` is granted. |
| `timeout` | No reply before `timeout` (default 30 s). |
| `unsupported` | Android below 8.0, no telephony hardware, or not running on Android. |
| `noDialer` | No app handles `ACTION_DIAL` (from `dial`). |
| `unknown` | Any other native failure. |

### Validating codes and building the dialer URI

```dart
UssdCode.validate(' *222 # ');   // '*222#' (spaces removed)
UssdCode.validate('*٢٢٢#');     // '*222#' (Arabic-Indic digits converted)
UssdCode.isValid('*22a#');      // false
UssdCode.telUri('*222#');       // 'tel:*222%23'
```

### Reading amounts

```dart
extractAmounts('Votre solde est de 1 250,50 DA'); // [1250.5]
extractAmounts('Your balance is DZD 150.00');     // [150.0]
extractAmounts('رصيدك الحالي هو ١٥٠ دج');           // [150.0]
```

`extractAmounts` is a **heuristic**. Carriers do not standardise their messages and change them
without notice. It understands `DA`, `DZD`, `دج` and `د.ج` before or after the number, ASCII and
Arabic-Indic digits, Arabic separators (`٫` `٬`), and thousands grouped with spaces, dots or commas.
It reads "1.250 DA" as 1250, and two numbers separated only by a space before a currency may be
read as one grouped number.

## Limitations

- **Single-response USSD only. Multi-step menus are not supported.** Android's public API offers
  exactly one USSD call, `sendUssdRequest`. It sends one string and delivers one reply to a
  callback. There is no official API to answer a menu ("1. Balance 2. Bundles") and keep the
  session open. The only ways to do that are an AccessibilityService that reads and types into the
  system USSD dialog, or private telephony internals. Both are fragile, raise Play policy
  problems, and are deliberately left out. If a code answers with a menu, you get the first
  screen's text and the session ends. For such codes, use `dial` and let the user navigate.
  Some carriers also let you put the menu choices in the code itself (for example `*123*1*2#`);
  only use that form if your carrier documents it.
- `send` needs Android 8.0 (API 26). On older devices it throws `unsupported`; use `dial`.
- Only one USSD request can run at a time on a device. Wait for each reply before sending the
  next one: while a request is pending, Android fails a new one at once with `returnFailure`.
- A request that times out is not cancelled (Android has no API for it). If the network never
  answers, it stays pending in the phone process, even after the app exits, and every later
  `send` fails with `returnFailure` until the radio turns off (airplane mode) or the device
  restarts. The API 37 emulator's modem behaves this way: it accepts `*100#` and never replies.
- Some devices and carriers ignore the subscription chosen with `createForSubscriptionId` and use
  the default SIM. This is a device limitation the plugin cannot detect.
- On Android below 10, the platform gives the MNC as a number. A leading zero is restored for
  one-digit values (Algerian MNCs are `01`, `02`, `03`), but a three-digit MNC with a leading zero
  cannot be recovered.
- The plugin never reads or types into other apps' windows and does not use an
  AccessibilityService.
- The Kotlin code compiles and its pure logic is unit tested, but this release has not yet been
  checked on a physical device against live networks.

## Data sources

`AlgerianCarrierPresets` contains only codes read on the carriers' own websites on 2026-09-26:

| Carrier (MCC-MNC) | Code | Source text | Source |
| --- | --- | --- | --- |
| Mobilis (603-01) | `*222#` | "يمكنك الاطلاع على رصيدك عبر تشكيل *222#" | <https://mobilis.dz/mobinet> |
| Djezzy (603-02) | `*710#` | "Dédié aux abonnés prépayés, vous pouvez à tout moment interroger votre compte pour connaitre le solde de votre crédit et faire le suivi de vos consommations" | <https://www.djezzy.dz/particuliers/services/numeros-utiles/> |
| Ooredoo (603-03) | `*200#` | "Vous pouvez à tout moment consulter votre crédit en composant *200#." | <https://www.ooredoo.dz/fr/particuliers/offres-mobiles/ooredoo-500> |

Notes: the Mobilis code comes from the MobiNet pack page. The Djezzy code is for prepaid lines. On
another Ooredoo page (<https://www.ooredoo.dz/fr/particuliers/internet/ooredoo-internet>), `*200#`
is also the code to follow internet consumption. Carriers can change these codes at any time, and
a code may answer with a menu rather than a single message.

The MCC/MNC pairs follow ITU-T E.212, as listed in Wikipedia's
[Mobile network codes in ITU region 6xx (Africa)](https://en.wikipedia.org/wiki/Mobile_network_codes_in_ITU_region_6xx_(Africa)).

All response texts in the tests were written for the tests. They are not copies of operator
messages.

## License

MIT. See [LICENSE](LICENSE).

Made by [Abdeldjalil Chougui](https://abdeldjalilchougui.biz/).
