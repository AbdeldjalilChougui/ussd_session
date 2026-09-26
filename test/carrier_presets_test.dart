import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_session/ussd_session.dart';

void main() {
  test('every preset is a valid code with an official source', () {
    expect(AlgerianCarrierPresets.all, isNotEmpty);
    for (final p in AlgerianCarrierPresets.all) {
      expect(UssdCode.isValid(p.code), isTrue, reason: p.code);
      expect(Uri.parse(p.sourceUrl).isAbsolute, isTrue);
      expect(p.verifiedOn, DateTime.utc(2026, 9, 26));
      expect(p.mcc, '603');
    }
  });

  test('balance presets per carrier', () {
    expect(AlgerianCarrierPresets.mobilisBalance.code, '*222#');
    expect(AlgerianCarrierPresets.djezzyBalance.code, '*710#');
    expect(AlgerianCarrierPresets.ooredooBalance.code, '*200#');
  });

  test('balanceFor matches a SIM by MCC/MNC', () {
    const djezzySim = SimCard(
      subscriptionId: 2,
      slotIndex: 1,
      carrierName: 'Djezzy',
      displayName: 'SIM 2',
      mcc: '603',
      mnc: '02',
      countryIso: 'dz',
    );
    expect(AlgerianCarrierPresets.balanceFor(djezzySim),
        AlgerianCarrierPresets.djezzyBalance);
    const foreign =
        SimCard(subscriptionId: 3, slotIndex: 0, mcc: '208', mnc: '01');
    expect(AlgerianCarrierPresets.balanceFor(foreign), isNull);
  });
}
