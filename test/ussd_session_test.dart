import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_session/ussd_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(UssdSession.channelName);
  final calls = <MethodCall>[];

  void mock(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<UssdErrorCode> errorOf(Future<Object?> f) async {
    try {
      await f;
    } on UssdException catch (e) {
      return e.code;
    }
    fail('expected UssdException');
  }

  group('send', () {
    test('success returns a UssdResponse and passes arguments', () async {
      mock((call) async => <String, Object?>{
            'text': 'Votre solde est de 150,00 DA',
            'subscriptionId': 2,
            'receivedAtMillis': 1790000000000,
          });

      final r = await UssdSession.send(' *222 # ',
          subscriptionId: 2, timeout: const Duration(seconds: 12));

      expect(r.request, '*222#');
      expect(r.text, 'Votre solde est de 150,00 DA');
      expect(r.subscriptionId, 2);
      expect(r.receivedAt,
          DateTime.fromMillisecondsSinceEpoch(1790000000000, isUtc: true));
      expect(calls.single.method, 'send');
      expect(calls.single.arguments, <String, Object?>{
        'code': '*222#',
        'subscriptionId': 2,
        'timeoutMillis': 12000,
      });
    });

    test('default SIM sends a null subscriptionId', () async {
      mock((call) async => <String, Object?>{
            'text': 'ok',
            'subscriptionId': null,
            'receivedAtMillis': 0,
          });
      final r = await UssdSession.send('*710#');
      expect(r.subscriptionId, isNull);
      expect((calls.single.arguments as Map)['subscriptionId'], isNull);
      expect((calls.single.arguments as Map)['timeoutMillis'],
          UssdSession.defaultTimeout.inMilliseconds);
    });

    const mapping = <String, UssdErrorCode>{
      'USSD_RETURN_FAILURE': UssdErrorCode.returnFailure,
      'SERVICE_UNAVAILABLE': UssdErrorCode.serviceUnavailable,
      'CALL_PHONE_PERMISSION_DENIED': UssdErrorCode.callPhonePermissionDenied,
      'READ_PHONE_STATE_PERMISSION_DENIED':
          UssdErrorCode.readPhoneStatePermissionDenied,
      'NO_SIM': UssdErrorCode.noSim,
      'INVALID_SUBSCRIPTION': UssdErrorCode.invalidSubscription,
      'TIMEOUT': UssdErrorCode.timeout,
      'UNSUPPORTED': UssdErrorCode.unsupported,
      'INVALID_CODE': UssdErrorCode.invalidCode,
      'NO_DIALER': UssdErrorCode.noDialer,
      'SOMETHING_NEW': UssdErrorCode.unknown,
    };
    mapping.forEach((wire, expected) {
      test('maps $wire to $expected', () async {
        mock((call) async => throw PlatformException(
            code: wire, message: 'native says $wire', details: {'x': 1}));
        try {
          await UssdSession.send('*222#');
          fail('expected UssdException');
        } on UssdException catch (e) {
          expect(e.code, expected);
          expect(e.message, 'native says $wire');
          expect(e.details, {'x': 1});
          expect(e.toString(), contains(expected.name));
        }
      });
    });

    test('invalid code format throws before calling the platform', () async {
      mock((call) async => fail('platform must not be called'));
      expect(
          await errorOf(UssdSession.send('*22a#')), UssdErrorCode.invalidCode);
      expect(calls, isEmpty);
    });

    test('negative subscriptionId throws invalidSubscription', () async {
      mock((call) async => fail('platform must not be called'));
      expect(await errorOf(UssdSession.send('*222#', subscriptionId: -1)),
          UssdErrorCode.invalidSubscription);
      expect(calls, isEmpty);
    });

    test('non-positive timeout is an ArgumentError', () {
      expect(() => UssdSession.send('*222#', timeout: Duration.zero),
          throwsArgumentError);
    });

    test('times out on the Dart side when the platform never answers',
        () async {
      final never = Completer<Object?>();
      mock((call) => never.future);
      expect(
          await errorOf(UssdSession.send('*222#',
              timeout: const Duration(milliseconds: 50))),
          UssdErrorCode.timeout);
    });

    test('missing plugin maps to unsupported', () async {
      expect(
          await errorOf(UssdSession.send('*222#')), UssdErrorCode.unsupported);
    });
  });

  group('simCards', () {
    test('parses the active SIM list', () async {
      mock((call) async => <Object?>[
            <String, Object?>{
              'subscriptionId': 1,
              'slotIndex': 0,
              'carrierName': 'Mobilis',
              'displayName': 'Work',
              'mcc': '603',
              'mnc': '01',
              'countryIso': 'dz',
            },
            <String, Object?>{
              'subscriptionId': 4,
              'slotIndex': 1,
              'carrierName': null,
              'displayName': null,
              'mcc': null,
              'mnc': null,
              'countryIso': null,
            },
          ]);
      final sims = await UssdSession.simCards();
      expect(calls.single.method, 'simCards');
      expect(sims, hasLength(2));
      expect(
          sims.first,
          const SimCard(
            subscriptionId: 1,
            slotIndex: 0,
            carrierName: 'Mobilis',
            displayName: 'Work',
            mcc: '603',
            mnc: '01',
            countryIso: 'dz',
          ));
      expect(sims.first.mccMnc, '60301');
      expect(sims.last.carrierName, isNull);
      expect(sims.last.mccMnc, isNull);
    });

    test('null list means no SIM', () async {
      mock((call) async => null);
      expect(await UssdSession.simCards(), isEmpty);
    });

    test('missing READ_PHONE_STATE permission is typed', () async {
      mock((call) async => throw PlatformException(
          code: 'READ_PHONE_STATE_PERMISSION_DENIED', message: 'denied'));
      expect(await errorOf(UssdSession.simCards()),
          UssdErrorCode.readPhoneStatePermissionDenied);
    });
  });

  group('permissionsStatus', () {
    test('reports both permissions without requesting', () async {
      mock((call) async =>
          <String, Object?>{'callPhone': true, 'readPhoneState': false});
      final s = await UssdSession.permissionsStatus();
      expect(calls.single.method, 'permissionsStatus');
      expect(s.callPhone, isTrue);
      expect(s.readPhoneState, isFalse);
      expect(s.canSend, isTrue);
      expect(s.canListSims, isFalse);
    });
  });

  group('dial', () {
    test('sends the normalised code to the platform', () async {
      mock((call) async => null);
      await UssdSession.dial(' *222 # ');
      expect(calls.single.method, 'dial');
      expect(calls.single.arguments, <String, Object?>{'code': '*222#'});
    });

    test('rejects invalid codes', () async {
      mock((call) async => fail('platform must not be called'));
      expect(await errorOf(UssdSession.dial('abc')), UssdErrorCode.invalidCode);
    });

    test('maps NO_DIALER', () async {
      mock((call) async =>
          throw PlatformException(code: 'NO_DIALER', message: 'none'));
      expect(await errorOf(UssdSession.dial('*222#')), UssdErrorCode.noDialer);
    });
  });
}
