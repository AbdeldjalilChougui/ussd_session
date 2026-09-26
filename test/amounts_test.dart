import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_session/ussd_session.dart';

// All responses below were written for these tests. They imitate the
// shape of real operator replies but are not copies of any operator text.
void main() {
  group('extractAmounts, French', () {
    test('comma decimal with DA', () {
      expect(
        extractAmounts('Votre solde est de 150,00 DA. Validite 31/12/2026.'),
        [150.0],
      );
    });

    test('several amounts with thousands separated by spaces', () {
      expect(
        extractAmounts(
            'Solde principal: 1 250,50 DA, bonus: 300 DA, credit offert 2 000 DA'),
        [1250.5, 300.0, 2000.0],
      );
    });

    test('dot thousands with comma decimal', () {
      expect(extractAmounts('Montant: 12.500,75 DZD'), [12500.75]);
    });
  });

  group('extractAmounts, English', () {
    test('dot decimal with DZD', () {
      expect(extractAmounts('Your balance is 150.00 DZD. Thank you.'), [150.0]);
    });

    test('currency before the number and comma thousands', () {
      expect(
        extractAmounts('Main balance: DZD 1,250.00; bonus DA 75'),
        [1250.0, 75.0],
      );
    });

    test('ignores numbers without a currency', () {
      expect(
        extractAmounts(
            'You have 5 GB left, valid until 2026-10-01. Balance 40 DA'),
        [40.0],
      );
    });

    test('lowercase currency is accepted but not inside a word', () {
      expect(extractAmounts('Balance 20 da'), [20.0]);
      expect(extractAmounts('10 days left'), isEmpty);
      expect(extractAmounts('3 DAYS'), isEmpty);
    });
  });

  group('extractAmounts, Arabic', () {
    test('Arabic-Indic digits with دج', () {
      expect(extractAmounts('رصيدك الحالي هو ١٥٠ دج'), [150.0]);
    });

    test('Western digits with spaces and دج', () {
      expect(extractAmounts('رصيدك 1 250 دج صالح حتى 31/12/2026'), [1250.0]);
    });

    test('Arabic decimal and thousands separators', () {
      expect(extractAmounts('الرصيد: ١٬٢٥٠٫٥٠ د.ج'), [1250.5]);
    });

    test('Extended Arabic-Indic (Persian) digits', () {
      expect(extractAmounts('رصيدك ۲۰۰ دج'), [200.0]);
    });

    test('mixed Arabic response with two amounts', () {
      expect(
        extractAmounts('رصيدك الرئيسي ٥٠٠,٠٠ دج والرصيد الإضافي ١٠٠ دج'),
        [500.0, 100.0],
      );
    });
  });

  test('empty and currency-free text', () {
    expect(extractAmounts(''), isEmpty);
    expect(extractAmounts('Service indisponible'), isEmpty);
  });
}
