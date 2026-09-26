import 'ussd_code.dart';

// Integer part: either grouped thousands (1 250, 1.250, 1,250) or plain
// digits. Optional 1-2 digit decimal part with "." or ",".
const String _number =
    r'(\d{1,3}(?:[   .,]\d{3})+|\d+)(?:[.,](\d{1,2}))?(?!\d)';
const String _currency = r'(?:DZD|DA|د\.ج|دج)';
const String _after = r'(?![A-Za-z؀-ۿ])';

final RegExp _amount = RegExp(
  '(?:(?<![A-Za-z\\u0600-\\u06FF])$_currency[ \\u00A0]*(?<![\\d.,])$_number)'
  '|(?:(?<![\\d.,])$_number[ \\u00A0\\u202F]*$_currency$_after)',
  caseSensitive: false,
  unicode: true,
);

/// Finds currency amounts in Algerian dinar in a USSD reply and returns
/// them as numbers, in order of appearance.
///
/// Recognised currencies: `DA`, `DZD`, `دج` and `د.ج`, written before or
/// after the number. Digits may be ASCII, Arabic-Indic (٠-٩) or Extended
/// Arabic-Indic (۰-۹); the Arabic separators `٫` (decimal) and `٬`
/// (thousands) are understood. Thousands may be grouped with spaces, dots
/// or commas; a decimal part has one or two digits.
///
/// This is a **heuristic**. Operator messages change without notice and
/// are not standardised, so treat the result as a hint: for example
/// "1.250 DA" is read as 1250, and two numbers separated by a single space
/// before a currency may be read as one grouped number.
List<double> extractAmounts(String text) {
  final normalized = asciiDigits(text)
      .replaceAll('٫', '.') // Arabic decimal separator
      .replaceAll('٬', ','); // Arabic thousands separator
  final result = <double>[];
  for (final m in _amount.allMatches(normalized)) {
    final intPart = m.group(1) ?? m.group(3)!;
    final frac = m.group(1) != null ? m.group(2) : m.group(4);
    final digits = intPart.replaceAll(RegExp(r'\D'), '');
    var value = double.parse(digits);
    if (frac != null) {
      value += int.parse(frac) / (frac.length == 1 ? 10 : 100);
    }
    result.add(value);
  }
  return result;
}
