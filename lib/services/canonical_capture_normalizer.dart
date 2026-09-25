class CanonicalCaptureNormalizer {
  CanonicalCaptureNormalizer._();

  static const Map<String, String> _digitMap = <String, String>{
    // Arabic-Indic digits
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    // Eastern Arabic-Indic / Persian digits
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  static final RegExp _digitRegex = RegExp(r'[٠-٩۰-۹]');

  // Zero-width and directional control characters:
  // \u200B: Zero-width space
  // \u200C: Zero-width non-joiner
  // \u200D: Zero-width joiner
  // \uFEFF: Zero-width no-break space / BOM
  // \u200E: Left-to-right mark (LRM)
  // \u200F: Right-to-left mark (RLM)
  // \u202A-\u202E: Directional embedding / override
  // \u2066-\u2069: Directional isolates
  static final RegExp _invisibleControlMarksRegex = RegExp(
    r'[\u200B\u200C\u200D\uFEFF\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );

  // Unicode whitespace varieties to normalize to standard ASCII space (0x20):
  // \u00A0: Non-breaking space (NBSP)
  // \u202F: Narrow non-breaking space (NNBSP)
  // \u2007: Figure space
  // \u2000-\u200A: En-quad, em-quad, en-space, em-space, etc.
  // \u3000: Ideographic space
  static final RegExp _unicodeWhitespaceRegex = RegExp(
    r'[\u00A0\u202F\u2007\u2000-\u200A\u3000]',
  );

  /// Normalizes transport-level noise across iOS Shortcuts, Android SMS,
  /// manual paste, and share sheets without altering financial semantic tokens.
  static String normalize(String rawInput) {
    if (rawInput.isEmpty) return '';

    // 1. Standardize line endings: CRLF and CR -> LF
    String text = rawInput.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 2. Remove invisible control marks and directional markers
    text = text.replaceAll(_invisibleControlMarksRegex, '');

    // 3. Convert exotic Unicode whitespace to standard space
    text = text.replaceAll(_unicodeWhitespaceRegex, ' ');

    // 4. Normalize Arabic-Indic and Persian digits to standard ASCII digits
    text = text.replaceAllMapped(_digitRegex, (Match m) {
      final String? char = m.group(0);
      return char != null ? (_digitMap[char] ?? char) : '';
    });

    // 5. Line-by-line whitespace normalization:
    // Collapse internal consecutive horizontal spaces/tabs within lines,
    // while preserving line boundaries (\n).
    final List<String> rawLines = text.split('\n');
    final List<String> normalizedLines = <String>[];

    for (final String line in rawLines) {
      final String collapsed = line
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .trim();
      normalizedLines.add(collapsed);
    }

    // Join lines back with \n and trim outer leading/trailing empty lines
    return normalizedLines.join('\n').trim();
  }
}
