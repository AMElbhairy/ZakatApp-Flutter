import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/services/canonical_capture_normalizer.dart';

void main() {
  group('CanonicalCaptureNormalizer', () {
    test('normalizes CRLF and CR line endings to LF while preserving lines', () {
      const crlfInput = 'Line 1\r\nLine 2\r\nLine 3';
      const crInput = 'Line 1\rLine 2\rLine 3';

      final normalizedCrlf = CanonicalCaptureNormalizer.normalize(crlfInput);
      final normalizedCr = CanonicalCaptureNormalizer.normalize(crInput);

      expect(normalizedCrlf, 'Line 1\nLine 2\nLine 3');
      expect(normalizedCr, 'Line 1\nLine 2\nLine 3');
    });

    test('replaces exotic Unicode whitespace with ASCII spaces', () {
      // \u00A0: non-breaking space, \u202F: narrow NBSP, \u2007: figure space
      const input = 'Amount:\u00A0150.00\u202FSAR\u2007paid';
      final normalized = CanonicalCaptureNormalizer.normalize(input);

      expect(normalized, 'Amount: 150.00 SAR paid');
    });

    test('strips invisible zero-width characters and directional marks', () {
      // \u200B: ZWSP, \u200C: ZWNJ, \u200D: ZWJ, \uFEFF: BOM, \u200E: LRM, \u200F: RLM
      const input = '\uFEFF\u200Eشراء\u200B من: \u200FStarbucks\u200C بمبلغ 25';
      final normalized = CanonicalCaptureNormalizer.normalize(input);

      expect(normalized, 'شراء من: Starbucks بمبلغ 25');
    });

    test('converts Arabic-Indic digits to Latin digits', () {
      const input = 'شراء بمبلغ ١٢٥.٥٠ ر.س في تاريخ ٢٠٢٦/٠٦/١٤';
      final normalized = CanonicalCaptureNormalizer.normalize(input);

      expect(normalized, 'شراء بمبلغ 125.50 ر.س في تاريخ 2026/06/14');
    });

    test('converts Eastern Arabic / Persian digits to Latin digits', () {
      const input = 'واریز مبلغ ۵۰۰۰ ریال در تاریخ ۱۴۰۵/۰۴/۰۱';
      final normalized = CanonicalCaptureNormalizer.normalize(input);

      expect(normalized, 'واریز مبلغ 5000 ریال در تاریخ 1405/04/01');
    });

    test('collapses multiple horizontal spaces per line without collapsing lines', () {
      const input = '   Purchase    at    Amazon SA   \n   Amount:   125.50 SAR   ';
      final normalized = CanonicalCaptureNormalizer.normalize(input);

      expect(normalized, 'Purchase at Amazon SA\nAmount: 125.50 SAR');
    });

    test('handles empty and whitespace-only inputs safely', () {
      expect(CanonicalCaptureNormalizer.normalize(''), '');
      expect(CanonicalCaptureNormalizer.normalize('   \n  \t  \n  '), '');
    });
  });
}
