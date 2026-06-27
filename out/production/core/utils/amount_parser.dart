double? tryParseAmount(String? value) {
  final String sanitized = (value ?? '').replaceAll(RegExp(r'[,\s]'), '');
  if (sanitized.isEmpty) return null;
  return double.tryParse(sanitized);
}
