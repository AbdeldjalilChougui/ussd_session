import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_session/ussd_session.dart';

void main() {
  group('UssdCode.normalize', () {
    test('removes ordinary and non-breaking spaces', () {
      expect(UssdCode.normalize(' *222 # '), '*222#');
      expect(UssdCode.normalize('*710 #'), '*710#');
      expect(UssdCode.normalize('*1\t2\n3#'), '*123#');
    });

    test('converts Arabic-Indic and Persian digits to ASCII', () {
      expect(UssdCode.normalize('*٢٢٢#'), '*222#');
      expect(UssdCode.normalize('*۲۰۰#'), '*200#');
    });
  });

  group('UssdCode.validate', () {
    test('accepts typical balance codes', () {
      expect(UssdCode.validate('*222#'), '*222#');
      expect(UssdCode.validate('*710#'), '*710#');
      expect(UssdCode.validate('#100#'), '#100#');
      expect(UssdCode.validate('*123*1*2#'), '*123*1*2#');
      expect(UssdCode.validate('*200* +213555000000#'), '*200*+213555000000#');
    });

    test('returns the normalised form', () {
      expect(UssdCode.validate(' * 2 2 2 # '), '*222#');
    });

    UssdErrorCode codeOf(void Function() f) {
      try {
        f();
      } on UssdException catch (e) {
        return e.code;
      }
      fail('expected UssdException');
    }

    test('rejects empty input', () {
      expect(codeOf(() => UssdCode.validate('')), UssdErrorCode.invalidCode);
      expect(codeOf(() => UssdCode.validate('   ')), UssdErrorCode.invalidCode);
    });

    test('rejects forbidden characters', () {
      for (final bad in ['*22a#', '*222#;', '*2-2#', 'tel:*222#', '*22.2#']) {
        expect(codeOf(() => UssdCode.validate(bad)), UssdErrorCode.invalidCode,
            reason: bad);
      }
    });

    test('requires a leading * or # and a trailing #', () {
      expect(
          codeOf(() => UssdCode.validate('222#')), UssdErrorCode.invalidCode);
      expect(
          codeOf(() => UssdCode.validate('*222')), UssdErrorCode.invalidCode);
      expect(codeOf(() => UssdCode.validate('#')), UssdErrorCode.invalidCode);
    });

    test('rejects codes longer than the maximum length', () {
      final ok = '*${'1' * (UssdCode.maxLength - 2)}#';
      expect(UssdCode.validate(ok).length, UssdCode.maxLength);
      final tooLong = '*${'1' * (UssdCode.maxLength - 1)}#';
      expect(
          codeOf(() => UssdCode.validate(tooLong)), UssdErrorCode.invalidCode);
    });

    test('isValid mirrors validate', () {
      expect(UssdCode.isValid('*222#'), isTrue);
      expect(UssdCode.isValid('*22a#'), isFalse);
    });
  });

  group('UssdCode.telUri', () {
    test('encodes # as %23 and keeps * and digits', () {
      expect(UssdCode.telUri('*222#'), 'tel:*222%23');
      expect(UssdCode.telUri('#100#'), 'tel:%23100%23');
      expect(UssdCode.telUri('*123*1#'), 'tel:*123*1%23');
    });

    test('normalises before encoding', () {
      expect(UssdCode.telUri(' *710 # '), 'tel:*710%23');
    });

    test('Uri.parse keeps the hash out of the fragment', () {
      final uri = Uri.parse(UssdCode.telUri('*222#'));
      expect(uri.scheme, 'tel');
      expect(uri.hasFragment, isFalse);
      expect(Uri.decodeComponent(uri.path), '*222#');
    });
  });
}
