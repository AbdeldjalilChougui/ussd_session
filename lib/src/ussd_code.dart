import 'ussd_exception.dart';

/// Validation and normalisation of USSD codes. Pure Dart.
abstract final class UssdCode {
  /// Maximum length of a USSD string in characters.
  ///
  /// 3GPP TS 23.038 allows at most 160 octets per USSD string, which is 182
  /// characters in the GSM 7-bit default alphabet.
  static const int maxLength = 182;

  static final RegExp _whitespace = RegExp(r'[\s   ‎‏]');
  static final RegExp _allowed = RegExp(r'^[*#][*#0-9+]*#$');

  /// Removes all whitespace (including non-breaking spaces and bidi marks)
  /// and converts Arabic-Indic and Extended Arabic-Indic digits to ASCII.
  /// Does not validate.
  static String normalize(String raw) {
    final noSpace = raw.replaceAll(_whitespace, '');
    return asciiDigits(noSpace);
  }

  /// Returns the normalised code, or throws a [UssdException] with
  /// [UssdErrorCode.invalidCode].
  ///
  /// A valid code only contains `*#0-9+`, starts with `*` or `#`, ends with
  /// `#`, is at least two characters and at most [maxLength] characters.
  static String validate(String raw) {
    final code = normalize(raw);
    if (code.isEmpty) {
      throw const UssdException(UssdErrorCode.invalidCode, 'Empty USSD code');
    }
    if (code.length > maxLength) {
      throw UssdException(UssdErrorCode.invalidCode,
          'USSD code longer than $maxLength characters (${code.length})');
    }
    if (code.length < 2 || !_allowed.hasMatch(code)) {
      throw UssdException(
          UssdErrorCode.invalidCode,
          'Invalid USSD code "$code": use only *#0-9+, start with * or # '
          'and end with #');
    }
    return code;
  }

  /// Whether [raw] passes [validate].
  static bool isValid(String raw) {
    try {
      validate(raw);
      return true;
    } on UssdException {
      return false;
    }
  }

  /// Builds the `tel:` URI used by the dialer fallback, with `#` encoded as
  /// `%23` so it is not read as a URI fragment. Validates first.
  static String telUri(String raw) =>
      'tel:${validate(raw).replaceAll('#', '%23')}';
}

/// Converts Arabic-Indic (U+0660..U+0669) and Extended Arabic-Indic
/// (U+06F0..U+06F9) digits in [text] to ASCII digits.
String asciiDigits(String text) {
  final out = StringBuffer();
  for (final r in text.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      out.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      out.writeCharCode(0x30 + r - 0x06F0);
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}
