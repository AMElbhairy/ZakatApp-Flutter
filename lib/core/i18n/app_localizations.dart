import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  static const Map<String, Map<String, String>> _values =
      <String, Map<String, String>>{
    'en': <String, String>{
      'dashboard': 'Dashboard',
      'assets': 'Assets',
      'activity': 'Activity',
      'plans': 'Plans',
      'account': 'Account',
      'add_entry': 'Add Entry',
      'add_income_expense': 'Add Income/Expense',
      'add_saving': 'Add Saving',
      'add_investment': 'Add Investment',
      'add_plan': 'Add Plan',
      'settings': 'Settings',
      'language': 'Language',
      'english': 'English',
      'arabic': 'Arabic',
      'manual_prices_required': 'Manual prices required',
      'market_data_required': 'Market data required',
      'gold_silver_required': 'Gold/silver price required',
      'transactions': 'Transactions',
      'zakat_schedule': 'Zakat Schedule',
      'all': 'All',
      'income': 'Income',
      'expense': 'Expense',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'refresh_market_data': 'Refresh Market Data',
      'save_market_data': 'Save Market Data',
      'last_updated': 'Last updated',
      'no_transactions_yet': 'No transactions yet',
      'no_assets_yet': 'No assets added yet',
      'no_plans_yet': 'No financial plans yet',
      'financial_summary': 'Financial Summary',
      'zakat_summary': 'Zakat Summary',
      'recent_activity': 'Recent Activity',
      'view_all': 'View All',
      'no_recent_transactions': 'No recent transactions',
      'total_income': 'Total Income',
      'total_expenses': 'Total Expenses',
      'total_wealth': 'Total Wealth',
      'total_savings_wealth': 'Total Savings Wealth',
      'investment_wealth': 'Investment Wealth',
      'nisab_status': 'Nisab Status',
      'current_nisab_threshold': 'Current Nisab Threshold',
      'due_now': 'Due Now',
      'upcoming': 'Upcoming',
      'past': 'Past',
      'entries': 'Entries',
    },
    'ar': <String, String>{
      'dashboard': 'لوحة التحكم',
      'assets': 'الأصول',
      'activity': 'النشاط',
      'plans': 'الخطط',
      'account': 'الحساب',
      'add_entry': 'إضافة إدخال',
      'add_income_expense': 'إضافة دخل/مصروف',
      'add_saving': 'إضافة ادخار',
      'add_investment': 'إضافة استثمار',
      'add_plan': 'إضافة خطة',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'english': 'الإنجليزية',
      'arabic': 'العربية',
      'manual_prices_required': 'الأسعار اليدوية مطلوبة',
      'market_data_required': 'بيانات السوق مطلوبة',
      'gold_silver_required': 'سعر الذهب/الفضة مطلوب',
      'transactions': 'المعاملات',
      'zakat_schedule': 'جدول الزكاة',
      'all': 'الكل',
      'income': 'دخل',
      'expense': 'مصروف',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'refresh_market_data': 'تحديث بيانات السوق',
      'save_market_data': 'حفظ بيانات السوق',
      'last_updated': 'آخر تحديث',
      'no_transactions_yet': 'لا توجد معاملات بعد',
      'no_assets_yet': 'لا توجد أصول مضافة بعد',
      'no_plans_yet': 'لا توجد خطط مالية بعد',
      'financial_summary': 'الملخص المالي',
      'zakat_summary': 'ملخص الزكاة',
      'recent_activity': 'النشاط الأخير',
      'view_all': 'عرض الكل',
      'no_recent_transactions': 'لا توجد معاملات حديثة',
      'total_income': 'إجمالي الدخل',
      'total_expenses': 'إجمالي المصروفات',
      'total_wealth': 'إجمالي الثروة',
      'total_savings_wealth': 'إجمالي ثروة الادخار',
      'investment_wealth': 'ثروة الاستثمارات',
      'nisab_status': 'حالة النصاب',
      'current_nisab_threshold': 'حد النصاب الحالي',
      'due_now': 'مستحق الآن',
      'upcoming': 'قادم',
      'past': 'سابق',
      'entries': 'العناصر',
    },
  };

  String tr(String key) {
    final String lang = _values.containsKey(locale.languageCode)
        ? locale.languageCode
        : 'en';
    return _values[lang]?[key] ?? _values['en']?[key] ?? key;
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (Locale l) => l.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
