import 'sim_card.dart';

/// A USSD code published by a carrier, with where and when it was checked.
class CarrierPreset {
  /// Creates a preset.
  const CarrierPreset({
    required this.carrier,
    required this.mcc,
    required this.mnc,
    required this.code,
    required this.description,
    required this.sourceUrl,
    required this.verifiedOn,
  });

  /// Commercial carrier name.
  final String carrier;

  /// Mobile country code of the carrier.
  final String mcc;

  /// Mobile network code of the carrier.
  final String mnc;

  /// The USSD code.
  final String code;

  /// What the carrier says the code does.
  final String description;

  /// The carrier's own page that documents the code.
  final String sourceUrl;

  /// The date the code was read on [sourceUrl].
  final DateTime verifiedOn;
}

/// Balance codes published by the Algerian carriers on their own websites.
///
/// Carriers can change codes at any time and some codes answer with a menu
/// rather than a single message; check the [CarrierPreset.sourceUrl] if a
/// code stops working. MCC/MNC values are from ITU-T E.212 as listed on
/// Wikipedia's "Mobile network codes in ITU region 6xx (Africa)".
abstract final class AlgerianCarrierPresets {
  static final DateTime _checked = DateTime.utc(2026, 9, 26);

  /// Mobilis (603-01) balance: "يمكنك الاطلاع على رصيدك عبر تشكيل *222#".
  static final CarrierPreset mobilisBalance = CarrierPreset(
    carrier: 'Mobilis',
    mcc: '603',
    mnc: '01',
    code: '*222#',
    description: 'Consult your balance (from the MobiNet pack page)',
    sourceUrl: 'https://mobilis.dz/mobinet',
    verifiedOn: _checked,
  );

  /// Djezzy (603-02) prepaid account: "interroger votre compte pour
  /// connaitre le solde de votre crédit".
  static final CarrierPreset djezzyBalance = CarrierPreset(
    carrier: 'Djezzy',
    mcc: '603',
    mnc: '02',
    code: '*710#',
    description: 'Prepaid: credit balance and consumption',
    sourceUrl: 'https://www.djezzy.dz/particuliers/services/numeros-utiles/',
    verifiedOn: _checked,
  );

  /// Ooredoo (603-03): "Vous pouvez à tout moment consulter votre crédit en
  /// composant *200#."
  static final CarrierPreset ooredooBalance = CarrierPreset(
    carrier: 'Ooredoo',
    mcc: '603',
    mnc: '03',
    code: '*200#',
    description: 'Consult your credit',
    sourceUrl:
        'https://www.ooredoo.dz/fr/particuliers/offres-mobiles/ooredoo-500',
    verifiedOn: _checked,
  );

  /// All presets.
  static final List<CarrierPreset> all =
      List.unmodifiable([mobilisBalance, djezzyBalance, ooredooBalance]);

  /// The balance preset for [sim]'s network, matched by MCC/MNC, or null.
  static CarrierPreset? balanceFor(SimCard sim) {
    for (final p in all) {
      if (p.mcc == sim.mcc && p.mnc == sim.mnc) return p;
    }
    return null;
  }
}
