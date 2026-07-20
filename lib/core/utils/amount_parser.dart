double? tryParseAmount(String? value) {
  final String sanitized = normalizeAmountText(value);
  if (sanitized.isEmpty) return null;
  return double.tryParse(sanitized);
}

String normalizeDateText(String? value) {
  final String sanitized = normalizeAmountText(value).trim();
  if (sanitized.isEmpty) return '';
  return sanitized.split('T').first;
}

String normalizeTimestampText(String? value) {
  final String sanitized = normalizeAmountText(value).trim();
  if (sanitized.isEmpty) return '';
  return sanitized;
}

String? normalizeNullableDateText(String? value) {
  final String normalized = normalizeDateText(value);
  return normalized.isEmpty ? null : normalized;
}

String? normalizeNullableTimestampText(String? value) {
  final String normalized = normalizeTimestampText(value);
  return normalized.isEmpty ? null : normalized;
}

String normalizeAmountText(String? value) {
  final String input = (value ?? '').trim();
  if (input.isEmpty) return '';

  final StringBuffer buffer = StringBuffer();
  for (final int rune in input.runes) {
    final String char = String.fromCharCode(rune);
    switch (char) {
      case '٠':
        buffer.write('0');
        break;
      case '١':
        buffer.write('1');
        break;
      case '٢':
        buffer.write('2');
        break;
      case '٣':
        buffer.write('3');
        break;
      case '٤':
        buffer.write('4');
        break;
      case '٥':
        buffer.write('5');
        break;
      case '٦':
        buffer.write('6');
        break;
      case '٧':
        buffer.write('7');
        break;
      case '٨':
        buffer.write('8');
        break;
      case '٩':
        buffer.write('9');
        break;
      case '۰':
        buffer.write('0');
        break;
      case '۱':
        buffer.write('1');
        break;
      case '۲':
        buffer.write('2');
        break;
      case '۳':
        buffer.write('3');
        break;
      case '۴':
        buffer.write('4');
        break;
      case '۵':
        buffer.write('5');
        break;
      case '۶':
        buffer.write('6');
        break;
      case '۷':
        buffer.write('7');
        break;
      case '۸':
        buffer.write('8');
        break;
      case '۹':
        buffer.write('9');
        break;
      case '٫':
        buffer.write('.');
        break;
      case ',':
      case '٬':
      case ' ':
      case '\u00A0':
        break;
      default:
        buffer.write(char);
        break;
    }
  }
  return buffer.toString();
}
