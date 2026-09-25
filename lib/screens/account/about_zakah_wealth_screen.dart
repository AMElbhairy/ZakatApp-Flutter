import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';

class AboutZakahWealthScreen extends StatefulWidget {
  const AboutZakahWealthScreen({
    super.key,
    required this.version,
    required this.buildNumber,
  });

  final String version;
  final String buildNumber;

  static Route<void> route({
    required String version,
    required String buildNumber,
  }) {
    return CupertinoPageRoute<void>(
      builder: (_) => AboutZakahWealthScreen(
        version: version,
        buildNumber: buildNumber,
      ),
    );
  }

  @override
  State<AboutZakahWealthScreen> createState() => _AboutZakahWealthScreenState();
}

class _AboutZakahWealthScreenState extends State<AboutZakahWealthScreen> {
  late String _currentLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
            isArabic ? 'عن Zakah Wealth' : 'About Zakah Wealth',
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
              // Logo and App Brand Header
              _buildBrandHeader(tokens, isArabic),
              const SizedBox(height: 20),

              // Overview Text Title
              Text(
                isArabic ? 'الركائز الأساسية للتطبيق' : 'Core Principles',
                style: TextStyle(
                  color: tokens.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Core Pillar Cards
              isArabic ? _buildArabicPillars(tokens) : _buildEnglishPillars(tokens),
              const SizedBox(height: 20),

              // Version details section card
              _buildVersionDetailsCard(tokens, isArabic),
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

  Widget _buildBrandHeader(PremiumThemeTokens tokens, bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: tokens.colors.hero,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: tokens.heroShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: tokens.colors.gold,
                width: 2.0,
              ),
              image: const DecorationImage(
                image: AssetImage('assets/images/app_icon.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Zakah Wealth',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'رفيقك المتميز لإدارة الثروة وحساب الزكاة بكل أمان'
                : 'A premium zakah and wealth companion built on privacy',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnglishPillars(PremiumThemeTokens tokens) {
    return Column(
      children: [
        _buildPillarCard(
          tokens: tokens,
          icon: Icons.lock_outline,
          title: 'Local First Privacy',
          subtitle: 'All your accounts, transaction records, and assets are stored entirely locally on your device database. We do not upload your data.',
        ),
        const SizedBox(height: 12),
        _buildPillarCard(
          tokens: tokens,
          icon: Icons.bolt_outlined,
          title: 'Automated SMS Capture',
          subtitle: 'Quickly draft transactions from bank notifications directly on-device. The app ignores OTPs and personal messages.',
        ),
        const SizedBox(height: 12),
        _buildPillarCard(
          tokens: tokens,
          icon: Icons.cloud_done_outlined,
          title: 'Encrypted Cloud Sync',
          subtitle: 'Back up your files to your personal Google Drive in an encrypted and secure manner. You remain in control of your data.',
        ),
      ],
    );
  }

  Widget _buildArabicPillars(PremiumThemeTokens tokens) {
    return Column(
      children: [
        _buildPillarCard(
          tokens: tokens,
          icon: Icons.lock_outline,
          title: 'الخصوصية والأمان محلياً',
          subtitle: 'جميع بياناتك وحساباتك المالية تظل مخزنة في قاعدة البيانات المحلية لجهازك المادي فقط، ولا نملك أي خوادم لرفعها.',
        ),
        const SizedBox(height: 12),
        _buildPillarCard(
          tokens: tokens,
          icon: Icons.bolt_outlined,
          title: 'الالتقاط التلقائي للرسائل',
          subtitle: 'صياغة سريعة للمعاملات عبر تتبع رسائل وإشعارات البنوك محلياً مع تصفية وتجاهل رسائل التحقق (OTP) تماماً.',
        ),
        const SizedBox(height: 12),
        _buildPillarCard(
          tokens: tokens,
          icon: Icons.cloud_done_outlined,
          title: 'نسخ احتياطي مشفر',
          subtitle: 'مزامنة آمنة لقاعدة بياناتك المحلية مع حساب Google Drive الخاص بك بشكل مشفر وخاص تماماً.',
        ),
      ],
    );
  }

  Widget _buildPillarCard({
    required PremiumThemeTokens tokens,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color descColor = isDark ? tokens.colors.textSecondary : const Color(0xFF4A5D5A);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: tokens.colors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: tokens.softShadow,
        border: Border.all(color: tokens.colors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: tokens.colors.gold.withValues(alpha: 0.10),
            radius: 18,
            child: Icon(icon, color: tokens.colors.gold, size: 18),
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
                    fontSize: 14,
                    fontFamily: _currentLanguage == 'ar' ? 'Cairo' : 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: descColor,
                    fontSize: 12,
                    height: 1.5,
                    fontFamily: _currentLanguage == 'ar' ? 'Cairo' : 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionDetailsCard(PremiumThemeTokens tokens, bool isArabic) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color descColor = isDark ? tokens.colors.textSecondary : const Color(0xFF4A5D5A);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: tokens.colors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tokens.colors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'إصدار التطبيق' : 'App Version',
                style: TextStyle(
                  color: tokens.colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.version,
                style: TextStyle(
                  color: descColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Container(
            height: 24,
            width: 1,
            color: tokens.colors.divider,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'رقم البناء' : 'Build Number',
                style: TextStyle(
                  color: tokens.colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.buildNumber,
                style: TextStyle(
                  color: descColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
