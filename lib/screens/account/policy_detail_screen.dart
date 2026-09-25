import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';

class PolicyDetailScreen extends StatefulWidget {
  const PolicyDetailScreen({
    super.key,
    required this.type,
  });

  final String type; // 'privacy', 'terms', 'support'

  static Route<void> route({required String type}) {
    return CupertinoPageRoute<void>(
      builder: (_) => PolicyDetailScreen(type: type),
    );
  }

  @override
  State<PolicyDetailScreen> createState() => _PolicyDetailScreenState();
}

class _PolicyDetailScreenState extends State<PolicyDetailScreen> {
  late String _currentLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = Localizations.localeOf(context).languageCode.toLowerCase();
    _currentLanguage = (localeCode == 'ar') ? 'ar' : 'en';
  }

  String _getScreenTitle(bool isArabic) {
    switch (widget.type) {
      case 'privacy':
        return isArabic ? 'سياسة الخصوصية' : 'Privacy Policy';
      case 'terms':
        return isArabic ? 'شروط الخدمة' : 'Terms of Service';
      case 'support':
      default:
        return isArabic ? 'الدعم والملاحظات' : 'Support & Feedback';
    }
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
            _getScreenTitle(isArabic),
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
            children: _buildContent(tokens, isArabic),
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

  List<Widget> _buildContent(PremiumThemeTokens tokens, bool isArabic) {
    switch (widget.type) {
      case 'privacy':
        return isArabic ? _buildArabicPrivacy(tokens) : _buildEnglishPrivacy(tokens);
      case 'terms':
        return isArabic ? _buildArabicTerms(tokens) : _buildEnglishTerms(tokens);
      case 'support':
      default:
        return isArabic ? _buildArabicSupport(tokens) : _buildEnglishSupport(tokens);
    }
  }

  // --- PRIVACY POLICY ---
  List<Widget> _buildEnglishPrivacy(PremiumThemeTokens tokens) {
    return [
      _buildSectionHeader(tokens, 'Privacy Commitment', Icons.security),
      _buildCard(
        tokens: tokens,
        child: _buildDescriptionText(
          'Zakah Wealth is committed to protecting your privacy. This policy outlines how we handle and secure your financial data.',
          tokens,
        ),
      ),
      const SizedBox(height: 16),
      _buildSectionHeader(tokens, 'Data Processing & Storage', Icons.storage_outlined),
      _buildCard(
        tokens: tokens,
        child: Column(
          children: [
            _buildItem(tokens, 'On-Device Storage', 'All account configurations, transaction logs, and balances are stored locally inside an SQLite database on your physical device. We do not upload or send your financial data to external servers.', true),
            const Divider(height: 24),
            _buildItem(tokens, 'Optional Google Drive Sync', 'You can choose to synchronize or backup your local database. Backup copies are stored on your personal Google Drive account in an encrypted format.', true),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildSectionHeader(tokens, 'SMS Tracking Permission', Icons.message_outlined),
      _buildCard(
        tokens: tokens,
        child: Column(
          children: [
            _buildItem(tokens, 'Local Capture Only', 'The RECEIVE_SMS permission is used exclusively to scan incoming bank messages on your device. The parsing logic drafts pending transactions for your manual approval.', true),
            const Divider(height: 24),
            _buildItem(tokens, 'OTP & Personal Text Filter', 'The app strictly filters and ignores any OTPs, personal messages, or non-financial notifications.', true),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildContactSupportCard(tokens, false),
    ];
  }

  List<Widget> _buildArabicPrivacy(PremiumThemeTokens tokens) {
    return [
      _buildSectionHeader(tokens, 'الالتزام بالخصوصية', Icons.security),
      _buildCard(
        tokens: tokens,
        child: _buildDescriptionText(
          'نحن ملتزمون بحماية خصوصيتك وأمان بياناتك المالية بالكامل.',
          tokens,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 16),
      _buildSectionHeader(tokens, 'معالجة البيانات وتخزينها', Icons.storage_outlined),
      _buildCard(
        tokens: tokens,
        child: Column(
          children: [
            _buildItem(tokens, 'التخزين المحلي بالكامل', 'يتم تخزين جميع حساباتك ومعاملاتك وأرصدتك محلياً على قاعدة بيانات جهازك المادي. نحن لا نقوم برفع أو نقل هذه البيانات إطلاقاً.', false),
            const Divider(height: 24),
            _buildItem(tokens, 'النسخ الاحتياطي على Google Drive', 'يمكنك اختيار مزامنة قاعدة البيانات اختيارياً. تُحفظ النسخ الاحتياطية في حسابك الشخصي بصيغة مشفرة وآمنة.', false),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildSectionHeader(tokens, 'أذونات تتبع الرسائل', Icons.message_outlined),
      _buildCard(
        tokens: tokens,
        child: Column(
          children: [
            _buildItem(tokens, 'تحليل محلي للرسائل', 'يُطلب إذن RECEIVE_SMS لقراءة رسائل المعاملات البنكية محلياً على جهازك ومساعدتك في تدوين المعاملات بشكل أسرع.', false),
            const Divider(height: 24),
            _buildItem(tokens, 'تجاهل الرسائل الشخصية ورموز التحقق', 'يتجاهل التطبيق تماماً الرموز الشخصية، رسائل التحقق (OTP)، وأي نصوص غير متعلقة بالمعاملات المالية.', false),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildContactSupportCard(tokens, true),
    ];
  }

  // --- TERMS OF SERVICE ---
  List<Widget> _buildEnglishTerms(PremiumThemeTokens tokens) {
    return [
      _buildSectionHeader(tokens, 'Usage Terms', Icons.gavel_outlined),
      _buildCard(
        tokens: tokens,
        child: _buildDescriptionText(
          'By using Zakah Wealth, you agree to these Terms of Service. Please read them carefully.',
          tokens,
        ),
      ),
      const SizedBox(height: 16),
      _buildSectionHeader(tokens, 'Scope of Service', Icons.help_outline),
      _buildCard(
        tokens: tokens,
        child: Column(
          children: [
            _buildItem(tokens, 'Calculations Purpose', 'Zakat calculations provided are for informational and planning purposes only. They do not constitute official religious rulings or licensed financial advisory.', true),
            const Divider(height: 24),
            _buildItem(tokens, 'Local Device Security', 'Since data is stored locally, you are responsible for maintaining the physical security and access passwords of your device and Drive account backups.', true),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildSectionHeader(tokens, 'Limitation of Liability', Icons.warning_amber_outlined),
      _buildCard(
        tokens: tokens,
        child: Column(
          children: [
            _buildItem(tokens, 'Provided "As-Is"', 'The app is provided without warranties of any kind. We are not liable for any financial decisions or inaccuracies in calculations.', true),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildArabicTerms(PremiumThemeTokens tokens) {
    return [
      _buildSectionHeader(tokens, 'شروط الاستخدام', Icons.gavel_outlined),
      _buildCard(
        tokens: tokens,
        child: _buildDescriptionText(
          'باستخدامك لتطبيق Zakah Wealth، فإنك توافق على شروط الخدمة هذه.',
          tokens,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 16),
      _buildSectionHeader(tokens, 'نطاق الخدمة', Icons.help_outline),
      _buildCard(
        tokens: tokens,
        child: Column(
          children: [
            _buildItem(tokens, 'أغراض حسابات الزكاة', 'الحسابات التي يقدمها التطبيق هي لأغراض إعلامية وتخطيطية واسترشادية فقط، ولا تغني عن المشورة الدينية الفقهية أو المالية الرسمية.', false),
            const Divider(height: 24),
            _buildItem(tokens, 'أمن الجهاز المحلي', 'بما أن البيانات تُخزن محلياً، فأنت مسؤول تماماً عن حماية جهازك المادي وكلمات المرور الخاصة بنسخك الاحتياطية.', false),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildSectionHeader(tokens, 'حدود المسؤولية', Icons.warning_amber_outlined),
      _buildCard(
        tokens: tokens,
        child: Column(
          children: [
            _buildItem(tokens, 'التقديم كما هو', 'يُقدم التطبيق "كما هو" دون أي ضمانات. ولا نتحمل أي مسؤولية عن قراراتك المالية بناءً على النتائج الحسابية.', false),
          ],
        ),
      ),
    ];
  }

  // --- SUPPORT & FEEDBACK ---
  List<Widget> _buildEnglishSupport(PremiumThemeTokens tokens) {
    return [
      _buildSectionHeader(tokens, 'Get in Touch', Icons.email_outlined),
      _buildContactSupportCard(tokens, false),
      const SizedBox(height: 16),
      _buildSectionHeader(tokens, 'Frequently Asked Questions', Icons.question_answer_outlined),
      _buildCard(
        tokens: tokens,
        child: Column(
          children: [
            _buildItem(tokens, 'Where is my data stored?', 'All data is stored directly in an encrypted-capable local database on your device and never uploaded to public clouds.', true),
            const Divider(height: 24),
            _buildItem(tokens, 'Can I toggle SMS capture off?', 'Yes. Go to settings in the Account screen to turn it on or off anytime.', true),
            const Divider(height: 24),
            _buildItem(tokens, 'How does the backup work?', 'The app creates a compressed copy of your local database and uploads it securely to your private Google Drive account.', true),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildArabicSupport(PremiumThemeTokens tokens) {
    return [
      _buildSectionHeader(tokens, 'تواصل معنا', Icons.email_outlined),
      _buildContactSupportCard(tokens, true),
      const SizedBox(height: 16),
      _buildSectionHeader(tokens, 'الأسئلة الشائعة', Icons.question_answer_outlined),
      _buildCard(
        tokens: tokens,
        child: Column(
          children: [
            _buildItem(tokens, 'أين يتم حفظ بياناتي؟', 'تظل جميع الحسابات والبيانات مشفرة ومحفوظة على جهازك محلياً بشكل كامل.', false),
            const Divider(height: 24),
            _buildItem(tokens, 'هل يمكنني إيقاف التقاط الرسائل؟', 'نعم، يمكنك تشغيل أو إيقاف الالتقاط التلقائي للرسائل البنكية في أي وقت من شاشة الحساب.', false),
            const Divider(height: 24),
            _buildItem(tokens, 'كيف يعمل النسخ الاحتياطي؟', 'يقوم التطبيق بضغط قاعدة البيانات ورفعها بشكل آمن وخاص إلى حساب Google Drive التابع لك مباشرة.', false),
          ],
        ),
      ),
    ];
  }

  Widget _buildDescriptionText(String text, PremiumThemeTokens tokens, {String? fontFamily}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color descColor = isDark ? tokens.colors.textSecondary : const Color(0xFF4A5D5A);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: descColor,
        fontFamily: fontFamily,
      ),
    );
  }

  // --- BUILD HELPERS ---
  Widget _buildSectionHeader(PremiumThemeTokens tokens, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.colors.gold),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: _currentLanguage == 'ar' ? 'Cairo' : 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required PremiumThemeTokens tokens,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: tokens.colors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: tokens.softShadow,
        border: Border.all(color: tokens.colors.divider),
      ),
      child: child,
    );
  }

  Widget _buildItem(PremiumThemeTokens tokens, String title, String desc, bool isEnglish) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color descColor = isDark ? tokens.colors.textSecondary : const Color(0xFF4A5D5A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: tokens.colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            fontFamily: isEnglish ? 'Inter' : 'Cairo',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: TextStyle(
            color: descColor,
            fontSize: 12,
            height: 1.5,
            fontFamily: isEnglish ? 'Inter' : 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildContactSupportCard(PremiumThemeTokens tokens, bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: tokens.colors.hero,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: tokens.heroShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline, color: tokens.colors.gold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'الدعم الفني وملاحظات التطبيق' : 'Technical Support & Feedback',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'support@zakahwealth.com',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
