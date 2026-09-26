/// Why a USSD operation failed.
enum UssdErrorCode {
  /// The code is empty, too long, or contains characters other than
  /// `*#0-9+`, or does not start with `*`/`#` and end with `#`.
  invalidCode('INVALID_CODE'),

  /// The network answered with a failure
  /// (`TelephonyManager.USSD_RETURN_FAILURE`).
  returnFailure('USSD_RETURN_FAILURE'),

  /// The USSD service is unavailable
  /// (`TelephonyManager.USSD_ERROR_SERVICE_UNAVAIL`), for example no
  /// network, airplane mode, or another USSD session already running.
  serviceUnavailable('SERVICE_UNAVAILABLE'),

  /// The app does not hold `android.permission.CALL_PHONE`.
  callPhonePermissionDenied('CALL_PHONE_PERMISSION_DENIED'),

  /// The app does not hold `android.permission.READ_PHONE_STATE`.
  readPhoneStatePermissionDenied('READ_PHONE_STATE_PERMISSION_DENIED'),

  /// No SIM card is present, or the targeted SIM is not ready.
  noSim('NO_SIM'),

  /// The requested subscription id is not an active SIM.
  invalidSubscription('INVALID_SUBSCRIPTION'),

  /// No reply arrived before the timeout.
  timeout('TIMEOUT'),

  /// Sending USSD is not supported: Android below 8.0 (API 26), a
  /// non-Android platform, or a device without telephony.
  unsupported('UNSUPPORTED'),

  /// No app can handle `ACTION_DIAL` on this device.
  noDialer('NO_DIALER'),

  /// Any other native failure.
  unknown('UNKNOWN');

  const UssdErrorCode(this.wire);

  /// The error code string used on the platform channel.
  final String wire;

  /// Maps a platform channel error code to a [UssdErrorCode], falling back
  /// to [unknown].
  static UssdErrorCode fromWire(String wire) {
    for (final c in values) {
      if (c.wire == wire) return c;
    }
    return unknown;
  }
}

/// A typed failure raised by `UssdSession`.
class UssdException implements Exception {
  /// Creates an exception with a [code], a human readable [message] and
  /// optional platform [details].
  const UssdException(this.code, this.message, {this.details});

  /// The failure category.
  final UssdErrorCode code;

  /// A human readable description, intended for logs rather than end users.
  final String message;

  /// Extra data from the platform, if any (for example the raw failure code).
  final Object? details;

  @override
  String toString() => 'UssdException(${code.name}): $message';
}
