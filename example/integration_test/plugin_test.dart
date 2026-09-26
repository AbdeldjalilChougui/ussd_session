// Emulator integration test: lists the emulator's virtual SIM, sends a USSD
// request to its modem, and opens the dialer, comparing with getprop and
// dumpsys. adb requests are served by tool/run_on_device.dart.
//
// Needs a fresh install (no permission granted).
//
// Run from example/:
//   dart run tool/run_on_device.dart \
//     dev.abdeldjalilchougui.ussd_session_example emulator-5554

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ussd_session/ussd_session.dart';

import 'adb_bridge.dart';

const _pkg = 'dev.abdeldjalilchougui.ussd_session_example';

Matcher _ussdError(UssdErrorCode code) =>
    isA<UssdException>().having((e) => e.code, 'code', code);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final adb = AdbBridge(_pkg);

  testWidgets('without permissions: typed errors', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final p = await UssdSession.permissionsStatus();
    expect(p.callPhone, isFalse,
        reason: 'run on a fresh install (uninstall the example first)');
    expect(p.readPhoneState, isFalse);
    await expectLater(UssdSession.simCards(),
        throwsA(_ussdError(UssdErrorCode.readPhoneStatePermissionDenied)));
    await expectLater(UssdSession.send('*100#'),
        throwsA(_ussdError(UssdErrorCode.callPhonePermissionDenied)));
    // Invalid codes are refused before reaching the platform.
    for (final bad in ['', '100', '*100', '*1a0#', '*100#${'1' * 190}']) {
      await expectLater(
          UssdSession.send(bad), throwsA(_ussdError(UssdErrorCode.invalidCode)),
          reason: bad);
      await expectLater(
          UssdSession.dial(bad), throwsA(_ussdError(UssdErrorCode.invalidCode)),
          reason: bad);
    }
  });

  testWidgets('simCards() matches the emulator SIM', (tester) async {
    await tester.pumpWidget(const SizedBox());
    await adb.shell('pm grant $_pkg android.permission.READ_PHONE_STATE');
    expect((await UssdSession.permissionsStatus()).readPhoneState, isTrue);
    final sims = await UssdSession.simCards();
    debugPrint('sims: $sims');
    expect(sims, hasLength(1));
    final sim = sims.single;
    final numeric =
        (await adb.shell('getprop gsm.sim.operator.numeric')).trim();
    final iso =
        (await adb.shell('getprop gsm.sim.operator.iso-country')).trim();
    final alpha = (await adb.shell('getprop gsm.sim.operator.alpha')).trim();
    debugPrint('getprop: $numeric $iso $alpha; displayName ${sim.displayName}');
    expect(sim.mccMnc, numeric);
    expect(sim.mcc, numeric.substring(0, 3));
    expect(sim.mnc, numeric.substring(3));
    expect(sim.countryIso, iso.toLowerCase());
    expect(sim.carrierName, alpha);
    expect(sim.slotIndex, 0);
    expect(sim.subscriptionId, greaterThanOrEqualTo(1));
    // No preset for a US test network.
    expect(AlgerianCarrierPresets.balanceFor(sim), isNull);
  });

  testWidgets('send(*100#) completes with a reply or a typed error',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    await adb.shell('pm grant $_pkg android.permission.CALL_PHONE');
    final sim = (await UssdSession.simCards()).single;
    const timeout = Duration(seconds: 20);
    final outcomes = <Object>[];
    for (final subscriptionId in [null, sim.subscriptionId]) {
      final watch = Stopwatch()..start();
      Object outcome;
      try {
        outcome = await UssdSession.send('*100#',
            subscriptionId: subscriptionId, timeout: timeout);
      } catch (e) {
        outcome = e;
      }
      watch.stop();
      outcomes.add(outcome);
      debugPrint('send(*100#, sub $subscriptionId) after '
          '${watch.elapsedMilliseconds} ms: $outcome');
      if (outcome is UssdResponse) {
        expect(outcome.request, '*100#');
        expect(outcome.text, isNotEmpty);
      } else {
        expect(outcome, isA<UssdException>());
        expect((outcome as UssdException).code, isNot(UssdErrorCode.unknown));
      }
      // Never hangs: the platform answers, or the timeout fires.
      expect(watch.elapsed, lessThan(timeout + const Duration(seconds: 3)));
    }
    // The emulator modem accepts SEND_USSD but never answers. The timed-out
    // request stays pending in the phone process (Android has no API to
    // cancel it), and telephony fails every new request at once with
    // USSD_RETURN_FAILURE until it ends.
    if (outcomes.first case UssdException(code: UssdErrorCode.timeout)) {
      expect(outcomes.last, _ussdError(UssdErrorCode.returnFailure));
    }
    await expectLater(UssdSession.send('*100#', subscriptionId: 999),
        throwsA(_ussdError(UssdErrorCode.invalidSubscription)));
    await expectLater(UssdSession.send('*100#', subscriptionId: -1),
        throwsA(_ussdError(UssdErrorCode.invalidSubscription)));
    // The app is still alive and answering.
    expect((await UssdSession.permissionsStatus()).callPhone, isTrue);

    // End the pending request: turning the radio off fails it.
    await adb.shell('cmd connectivity airplane-mode enable');
    await Future<void>.delayed(const Duration(seconds: 5));
    await adb.shell('cmd connectivity airplane-mode disable');
    final voice = await eventually(
        () => adb.shell('dumpsys telephony.registry'),
        (String s) => s.contains('mVoiceRegState=0(IN_SERVICE)'),
        timeout: const Duration(seconds: 60));
    expect(voice, contains('mVoiceRegState=0(IN_SERVICE)'));
    expect(
        (await adb.shell('settings get global airplane_mode_on')).trim(), '0');
  });

  testWidgets('dial(*100#) opens the dialer with %23 intact', (tester) async {
    await tester.pumpWidget(const SizedBox());
    await UssdSession.dial('*100#');
    try {
      final top = await eventually(adb.topResumedActivity,
          (String s) => s.isNotEmpty && !s.contains(_pkg));
      debugPrint('top after dial: $top');
      final activities = await adb.shell('dumpsys activity activities');
      final intent = activities
          .split('\n')
          .firstWhere((l) => l.contains('act=android.intent.action.DIAL'),
              orElse: () => '')
          .trim();
      debugPrint('dial intent: $intent');
      expect(intent, contains('dat=tel:*100%23'));
      // The dialer decoded %23 back to # and shows the whole code.
      await adb.shell('uiautomator dump /sdcard/ussd_ui.xml');
      final xml = await adb.shell('cat /sdcard/ussd_ui.xml');
      await adb.shell('rm -f /sdcard/ussd_ui.xml');
      expect(xml, contains('text="*100#"'));
    } finally {
      expect(await adb.backTo(_pkg), isTrue);
    }
  });
}
