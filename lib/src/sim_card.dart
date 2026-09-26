/// An active SIM subscription, from
/// `SubscriptionManager.getActiveSubscriptionInfoList`.
class SimCard {
  /// Creates a SIM description.
  const SimCard({
    required this.subscriptionId,
    required this.slotIndex,
    this.carrierName,
    this.displayName,
    this.mcc,
    this.mnc,
    this.countryIso,
  });

  /// Parses the map sent by the platform channel.
  factory SimCard.fromMap(Map<Object?, Object?> map) => SimCard(
        subscriptionId: (map['subscriptionId']! as num).toInt(),
        slotIndex: (map['slotIndex'] as num?)?.toInt() ?? -1,
        carrierName: map['carrierName'] as String?,
        displayName: map['displayName'] as String?,
        mcc: map['mcc'] as String?,
        mnc: map['mnc'] as String?,
        countryIso: map['countryIso'] as String?,
      );

  /// The subscription id to pass to `UssdSession.send`.
  final int subscriptionId;

  /// The physical SIM slot, starting at 0 (-1 if unknown).
  final int slotIndex;

  /// The carrier name shown by the system, if any.
  final String? carrierName;

  /// The user-visible SIM name, if any.
  final String? displayName;

  /// Mobile country code, for example `603` for Algeria.
  final String? mcc;

  /// Mobile network code, for example `01`. On Android below 10 the platform
  /// only exposes it as a number, so a leading zero is restored for one-digit
  /// values; three-digit MNCs with a leading zero cannot be recovered there.
  final String? mnc;

  /// ISO 3166-1 country code of the SIM, lowercase, for example `dz`.
  final String? countryIso;

  /// `mcc` followed by `mnc` (for example `60302`), or null if either is
  /// unknown.
  String? get mccMnc => (mcc == null || mnc == null) ? null : '$mcc$mnc';

  @override
  bool operator ==(Object other) =>
      other is SimCard &&
      other.subscriptionId == subscriptionId &&
      other.slotIndex == slotIndex &&
      other.carrierName == carrierName &&
      other.displayName == displayName &&
      other.mcc == mcc &&
      other.mnc == mnc &&
      other.countryIso == countryIso;

  @override
  int get hashCode => Object.hash(subscriptionId, slotIndex, carrierName,
      displayName, mcc, mnc, countryIso);

  @override
  String toString() => 'SimCard(subscriptionId: $subscriptionId, '
      'slot: $slotIndex, carrier: $carrierName, mccMnc: $mccMnc)';
}
