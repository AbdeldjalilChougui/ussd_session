import 'dart:async';

import 'package:flutter/services.dart';

import 'sim_card.dart';
import 'ussd_code.dart';
import 'ussd_exception.dart';
import 'ussd_permissions.dart';
import 'ussd_response.dart';

/// Entry point: single-response USSD requests, SIM listing, permission
/// status and a dialer fallback. Android only.
abstract final class UssdSession {
  /// Name of the platform channel.
  static const String channelName = 'dev.abdeldjalilchougui/ussd_session';

  /// Timeout used by [send] when none is given.
  static const Duration defaultTimeout = Duration(seconds: 30);

  static const MethodChannel _channel = MethodChannel(channelName);

  /// Sends [code] with `TelephonyManager.sendUssdRequest` (Android 8.0,
  /// API 26+) and returns the network reply.
  ///
  /// [subscriptionId] targets a SIM from [simCards]; null uses the default
  /// SIM for calls. Requires the `CALL_PHONE` permission.
  ///
  /// Throws a [UssdException]; see [UssdErrorCode] for the cases.
  static Future<UssdResponse> send(
    String code, {
    int? subscriptionId,
    Duration timeout = defaultTimeout,
  }) async {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'must be positive');
    }
    final request = UssdCode.validate(code);
    if (subscriptionId != null && subscriptionId < 0) {
      throw UssdException(UssdErrorCode.invalidSubscription,
          'Invalid subscription id $subscriptionId');
    }
    final reply = await _invoke<Map<Object?, Object?>>(
      'send',
      <String, Object?>{
        'code': request,
        'subscriptionId': subscriptionId,
        'timeoutMillis': timeout.inMilliseconds,
      },
    ).timeout(
      timeout,
      onTimeout: () => throw UssdException(
          UssdErrorCode.timeout, 'No USSD reply within $timeout'),
    );
    if (reply == null) {
      throw const UssdException(UssdErrorCode.unknown, 'Empty platform reply');
    }
    final millis = (reply['receivedAtMillis'] as num?)?.toInt();
    return UssdResponse(
      request: request,
      text: reply['text'] as String? ?? '',
      subscriptionId: (reply['subscriptionId'] as num?)?.toInt(),
      receivedAt: millis == null
          ? DateTime.now().toUtc()
          : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
    );
  }

  /// Lists the active SIMs. Requires `READ_PHONE_STATE`; without it throws
  /// a [UssdException] with [UssdErrorCode.readPhoneStatePermissionDenied].
  /// Returns an empty list when no SIM is inserted.
  static Future<List<SimCard>> simCards() async {
    final list = await _invoke<List<Object?>>('simCards');
    if (list == null) return const [];
    return [
      for (final item in list) SimCard.fromMap(item! as Map<Object?, Object?>),
    ];
  }

  /// Reports which permissions are granted. Never requests anything.
  static Future<UssdPermissions> permissionsStatus() async {
    final map = await _invoke<Map<Object?, Object?>>('permissionsStatus');
    return UssdPermissions(
      callPhone: map?['callPhone'] == true,
      readPhoneState: map?['readPhoneState'] == true,
    );
  }

  /// Opens the phone dialer with [code] pre-filled through `ACTION_DIAL`
  /// and a `tel:` URI (see [UssdCode.telUri]). No permission is needed;
  /// the user presses the call button. Works on every Android version.
  static Future<void> dial(String code) async {
    final request = UssdCode.validate(code);
    await _invoke<Object?>('dial', <String, Object?>{'code': request});
  }

  static Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw UssdException(
        UssdErrorCode.fromWire(e.code),
        e.message ?? e.code,
        details: e.details,
      );
    } on MissingPluginException catch (e) {
      throw UssdException(UssdErrorCode.unsupported,
          e.message ?? 'ussd_session is only implemented on Android');
    }
  }
}
