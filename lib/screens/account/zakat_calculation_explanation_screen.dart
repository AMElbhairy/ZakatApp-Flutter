import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';

class ZakatCalculationExplanationScreen extends StatefulWidget {
  const ZakatCalculationExplanationScreen({super.key});

  static Route<void> route() {
    return CupertinoPageRoute<void>(
      builder: (_) => const ZakatCalculationExplanationScreen(),
    );
  }

  @override
  State<ZakatCalculationExplanationScreen> createState() =>
      _ZakatCalculationExplanationScreenState();
}

class _ZakatCalculationExplanationScreenState
    extends State<ZakatCalculationExplanationScreen> {
  late String _currentLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default to the current system locale of the app
    final localeCode = Localizations.localeOf(context).languageCode.toLowerCase();
    _currentLanguage = (localeCode == 'ar') ? 'ar' : 'en';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final isArabic = _currentLanguage == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: tokens.colors.background,
        appBar: AppBar(
          backgroundColor: tokens.colors.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
          iconTheme: IconThemeData(color: tokens.colors.textPrimary),
          title: Text(
            isArabic ? 'كيف يعمل حساب الزكاة؟' : 'How Zakat Calculation Works',
            style: TextStyle(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.colors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tokens.colors.divider),
                ),
                child: Row(
                  children: [
                    _buildLanguageTab('AR', 'ar', tokens),
                    _buildLanguageTab('EN', 'en', tokens),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Section banner
              _buildHeroBanner(tokens, isArabic),
              const SizedBox(height: 20),

              // Title Section
              Text(
                isArabic
                    ? 'طرق حساب الزكاة المتوفرة'
                    : 'Available Zakat Methods',
                style: TextStyle(
                  color: tokens.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Method 1 Card (Monthly/Hawl)
              _buildMethodCard(
                tokens: tokens,
                title: isArabic ? '١. طريقة الحول الشهري (شهري / حول)' : '1. Monthly / Hawl Method',
                subtitle: isArabic
                    ? 'لحساب الحول لكل تدفق مالي على حدة'
                    : 'Tracks the Hawl for each transaction individually',
                icon: Icons.calendar_month,
                colorAccent: tokens.colors.success,
                body: isArabic ? _buildArabicHawlDetails() : _buildEnglishHawlDetails(),
              ),
              const SizedBox(height: 16),

              // Method 2 Card (Annual)
              _buildMethodCard(
                tokens: tokens,
                title: isArabic ? '٢. طريقة الحساب السنوي (سنوي / تاريخ محدد)' : '2. Annual Zakat Method',
                subtitle: isArabic
                    ? 'الحساب الشامل لجميع الأصول في تاريخ محدد'
                    : 'Comprehensive wealth calculation on a fixed date',
                icon: Icons.event,
                colorAccent: tokens.colors.gold,
                body: isArabic ? _buildArabicAnnualDetails() : _buildEnglishAnnualDetails(),
              ),
              const SizedBox(height: 16),

              // Nisab details Card
              _buildMethodCard(
                tokens: tokens,
                title: isArabic ? '٣. تحديد حد النصاب (الذهب والفضة)' : '3. Nisab Threshold Basis',
                subtitle: isArabic
                    ? 'أساس تقييم بلوغ النصاب شرعاً'
                    : 'The standard limits to verify Zakat obligation',
                icon: Icons.scale_outlined,
                colorAccent: Colors.teal,
                body: isArabic ? _buildArabicNisabDetails() : _buildEnglishNisabDetails(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTab(String text, String langCode, PremiumThemeTokens tokens) {
    final isSelected = _currentLanguage == langCode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentLanguage = langCode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? tokens.colors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : tokens.colors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(PremiumThemeTokens tokens, bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.colors.hero,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: tokens.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: tokens.colors.gold, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'كيف تتم العمليات الحسابية؟' : 'How does the calculator work?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isArabic
                ? 'يستخدم التطبيق أعلى المعايير الشرعية لتتبع ثروتك وتنبيهك بمواعيد الزكاة إما شهرياً عبر تتبع الحول لكل مبلغ، أو سنوياً في موعد ثابت.'
                : 'The app combines Islamic jurisprudence standards with digital ledger tools to track your wealth and calculate Zakat based on your selected method.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required PremiumThemeTokens tokens,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color colorAccent,
    required Widget body,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: tokens.softShadow,
        border: Border.all(color: tokens.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorAccent.withValues(alpha: 0.12),
                  radius: 20,
                  child: Icon(icon, color: colorAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: tokens.colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? tokens.colors.textSecondary
                              : const Color(0xFF4A5D5A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: body,
          ),
        ],
      ),
    );
  }

  // --- ENGLISH CONTENT VIEWS ---
  Widget _buildEnglishHawlDetails() {
    final tokens = context.premiumTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint('Reaching the Nisab:', 'The app checks if your combined portfolio meets the Nisab threshold. Once met, the day Nisab is crossed starts the first Hawl.'),
        _buildBulletPoint('Individual Transaction Hawl:', 'Every incoming transaction marked as "Income" starts its own 354-day Hijri year (Hawl).'),
        _buildBulletPoint('Expense Deduction (LIFO - Newest to Oldest):', 'When you log an expense, the app deducts it from the newest income first. This keeps older income lots untouched to safely complete their Hawl.'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.colors.background,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: tokens.colors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Practical Example:',
                style: TextStyle(
                  color: tokens.colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• You receive a salary of \$2,000.\n'
                '• 50% (\$1,000) is spent on expenses during the month.\n'
                '• The app deducts the \$1,000 from the latest salary lot.\n'
                '• The remaining \$1,000 continues its Hawl. After 354 days, a 2.5% Zakat (\$25) is calculated and scheduled for payment.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? tokens.colors.textSecondary
                      : const Color(0xFF4A5D5A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnglishAnnualDetails() {
    final tokens = context.premiumTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint('Fixed Date Selection:', 'You choose a fixed Hijri date for your Zakat calculations (e.g., 1st of Ramadan).'),
        _buildBulletPoint('Eligible Assets Summation:', 'On that date, the app sums all cash, gold, and silver in your possession. Note that investments, companies, and other non-liquid assets are excluded from the annual calculation.'),
        _buildBulletPoint('No Individual Duration Requirement:', 'It does not matter when the assets were added. Even if you received a cash payment a day before, it is calculated inside the total net worth of that day.'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.colors.background,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: tokens.colors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Practical Example:',
                style: TextStyle(
                  color: tokens.colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Your selected annual date is the 1st of Ramadan.\n'
                '• On that day, you have \$10,000 in your bank accounts and \$2,000 worth of gold.\n'
                '• Your eligible assets total \$12,000 (excluding investments/companies), which exceeds the Nisab.\n'
                '• Zakat of 2.5% (\$300) is calculated on the entire \$12,000 and added to your schedule.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? tokens.colors.textSecondary
                      : const Color(0xFF4A5D5A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnglishNisabDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint('Gold Nisab:', 'Equivalent to the value of 85 grams of 24k Gold.'),
        _buildBulletPoint('Silver Nisab:', 'Equivalent to the value of 595 grams of Silver.'),
        _buildBulletPoint('Dynamic Valuation:', 'The app automatically fetches the latest live/cached market prices of Gold and Silver in EGP (or your main currency) to calculate the precise threshold.'),
      ],
    );
  }

  // --- ARABIC CONTENT VIEWS ---
  Widget _buildArabicHawlDetails() {
    final tokens = context.premiumTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint('بلوغ النصاب أولاً:', 'يتحقق التطبيق أولاً من وصول إجمالي ثروتك لحد النصاب، واليوم الذي تتجاوز فيه النصاب يبدأ حساب الحول الأول لثروتك.'),
        _buildBulletPoint('حول مستقل لكل دخل:', 'كل عملية تدخل كـ "دخل" (Income) يُحسب لها حول هجري مستقل (سنة هجرية = ٣٥٤ يوماً) من تاريخ استلامها.'),
        _buildBulletPoint('خصم المصاريف بالأحدث فالأقدم (LIFO):', 'عند تسجيل أي مصاريف، تُخصم تلقائياً من التدفقات المالية الأحدث تاريخاً، للحفاظ على استقرار الحول للمبالغ القديمة.'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.colors.background,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: tokens.colors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مثال توضيحي:',
                style: TextStyle(
                  color: tokens.colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• يدخل إليك راتب شهري بقيمة ١٠,٠٠٠ جنيه.\n'
                '• تستهلك خلال الشهر مصاريف بقيمة ٥,٠٠٠ جنيه (٥٠٪).\n'
                '• يقوم التطبيق بخصم الـ ٥,٠٠٠ جنيه من الراتب الأخير.\n'
                '• المبلغ المتبقي (٥,٠٠٠ جنيه) يستمر الحول الهجري الخاص به، وبعد ٣٥٤ يوماً، تُحسب زكاة بنسبة ٢.٥٪ (١٢٥ جنيه) وتُدرج في جدول زكاة هذا الشهر.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? tokens.colors.textSecondary
                      : const Color(0xFF4A5D5A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArabicAnnualDetails() {
    final tokens = context.premiumTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint('تحديد موعد ثابت:', 'تختار تاريخاً هجرياً ثابتاً كل عام لحساب زكاتك (مثال: الأول من رمضان).'),
        _buildBulletPoint('جمع الأصول الخاضعة للزكاة:', 'في هذا التاريخ المحدد، يقوم التطبيق بجمع كل ما تملكه من سيولة نقدية (كاش)، ذهب، وفضة فقط. يرجى العلم بأن الاستثمارات، والشركات، والأصول الأخرى غير السائلة يتم استبعادها من الحساب السنوي.'),
        _buildBulletPoint('عدم اشتراط حول فردي:', 'لا يشترط مرور حول كامل على كل جزء من ثروتك بمفرده؛ فأي مبالغ متواجدة في هذا اليوم المحدد تُزكى بالكامل طالما بلغ الرصيد النصاب.'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.colors.background,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: tokens.colors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مثال توضيحي:',
                style: TextStyle(
                  color: tokens.colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• التاريخ السنوي المحدد هو ١ رمضان.\n'
                '• في هذا اليوم، إجمالي ما تملك من كاش وذهب هو ١٠٠,٠٠٠ جنيه (يتخطى النصاب، مع استبعاد الشركات والاستثمارات).\n'
                '• يتم احتساب زكاة قيمتها ٢.٥٪ (أي ٢,٥٠0 جنيه) على كامل المبلغ مباشرةً وتضاف لجدول الزكاة.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? tokens.colors.textSecondary
                      : const Color(0xFF4A5D5A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArabicNisabDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint('نصاب الذهب:', 'ما يعادل قيمة ٨٥ جراماً من الذهب الصافي عيار ٢٤.'),
        _buildBulletPoint('نصاب الفضة:', 'ما يعادل قيمة ٥٩٥ جراماً من الفضة عيار ٩٩٩.'),
        _buildBulletPoint('تقييم ديناميكي:', 'يقوم التطبيق بتحديث أسعار الذهب والفضة لحظياً وعرض قيمة النصاب بعملتك المحلية المفضلة.'),
      ],
    );
  }

  Widget _buildBulletPoint(String title, String desc) {
    final tokens = context.premiumTokens;
    final isArabic = _currentLanguage == 'ar';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: tokens.colors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: tokens.colors.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                  fontFamily: isArabic ? 'Cairo' : 'Inter',
                ),
                children: [
                  TextSpan(
                    text: '$title ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
