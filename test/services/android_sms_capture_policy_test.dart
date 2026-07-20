import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/services/android_sms_capture_policy.dart';

void main() {
  test('bank sms is considered financial', () {
    expect(
      AndroidSmsCapturePolicy.isLikelyFinancialMessage(
        'Debit Card Purchase at Talabat SAR 45.50',
      ),
      isTrue,
    );
  });

  test('currency codes and symbols are considered financial', () {
    expect(
      AndroidSmsCapturePolicy.isLikelyFinancialMessage(
        r'You spent $12.50 at Starbucks',
      ),
      isTrue,
    );
    expect(
      AndroidSmsCapturePolicy.isLikelyFinancialMessage(
        'رصيد حسابك الآن 250 جنيه',
      ),
      isTrue,
    );
    expect(
      AndroidSmsCapturePolicy.isLikelyFinancialMessage(
        'تم خصم 40 ريال من البطاقة',
      ),
      isTrue,
    );
    expect(
      AndroidSmsCapturePolicy.isLikelyFinancialMessage(
        'Account credited with EGP 1,200',
      ),
      isTrue,
    );
  });

  test('otp sms is ignored', () {
    expect(
      AndroidSmsCapturePolicy.isLikelyOtpOrSecurityMessage(
        'Your OTP code is 123456',
      ),
      isTrue,
    );
    expect(
      AndroidSmsCapturePolicy.isLikelyFinancialMessage(
        'Your OTP code is 123456',
      ),
      isFalse,
    );
  });

  test('non financial sms is ignored', () {
    expect(
      AndroidSmsCapturePolicy.isLikelyFinancialMessage(
        'Reminder: your appointment is tomorrow at 9 AM.',
      ),
      isFalse,
    );
  });
}
