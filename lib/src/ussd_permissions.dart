/// Which runtime permissions the app currently holds. Checking never shows
/// a permission prompt.
class UssdPermissions {
  /// Creates a status snapshot.
  const UssdPermissions(
      {required this.callPhone, required this.readPhoneState});

  /// Whether `android.permission.CALL_PHONE` is granted (needed by `send`).
  final bool callPhone;

  /// Whether `android.permission.READ_PHONE_STATE` is granted (needed by
  /// `simCards`).
  final bool readPhoneState;

  /// Whether `UssdSession.send` has the permission it needs.
  bool get canSend => callPhone;

  /// Whether `UssdSession.simCards` has the permission it needs.
  bool get canListSims => readPhoneState;

  @override
  String toString() =>
      'UssdPermissions(callPhone: $callPhone, readPhoneState: $readPhoneState)';
}
