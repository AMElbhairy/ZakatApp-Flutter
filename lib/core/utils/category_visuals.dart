import 'package:flutter/material.dart';

import '../../models/app_state.dart';
import '../theme/app_colors.dart';

@immutable
class CategoryVisual {
  const CategoryVisual({this.iconKey, this.colorValue});

  final String? iconKey;
  final int? colorValue;

  bool get hasIcon => iconKey != null && iconKey!.trim().isNotEmpty;
  bool get hasColor => colorValue != null;

  CategoryVisual copyWith({String? iconKey, int? colorValue}) {
    return CategoryVisual(
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (iconKey != null && iconKey!.trim().isNotEmpty) 'iconKey': iconKey,
      if (colorValue != null) 'colorValue': colorValue,
    };
  }

  factory CategoryVisual.fromJson(Map<String, dynamic> json) {
    return CategoryVisual(
      iconKey: json['iconKey']?.toString(),
      colorValue: json['colorValue'] == null
          ? null
          : _asInt(json['colorValue']),
    );
  }
}

@immutable
class CategoryIconChoice {
  const CategoryIconChoice({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

@immutable
class CategoryColorChoice {
  const CategoryColorChoice({
    required this.label,
    required this.value,
  });

  final String label;
  final Color value;
}

class CategoryVisuals {
  CategoryVisuals._();

  static const CategoryVisual neutralFallback = CategoryVisual(
    iconKey: 'neutral',
    colorValue: 0xFF94A3B8,
  );

  static const List<CategoryColorChoice> palette = <CategoryColorChoice>[
    CategoryColorChoice(label: 'Emerald', value: AppColors.tealAccent),
    CategoryColorChoice(label: 'Teal', value: AppColors.mintAccent),
    CategoryColorChoice(label: 'Gold', value: AppColors.goldWarm),
    CategoryColorChoice(label: 'Red', value: AppColors.redStrong),
    CategoryColorChoice(label: 'Coral', value: AppColors.orangeDeep),
    CategoryColorChoice(label: 'Blue', value: AppColors.blue),
    CategoryColorChoice(label: 'Sky', value: AppColors.sky),
    CategoryColorChoice(label: 'Purple', value: AppColors.purple),
    CategoryColorChoice(label: 'Lavender', value: AppColors.lavender),
    CategoryColorChoice(label: 'Gray', value: AppColors.gray),
    CategoryColorChoice(label: 'Olive', value: AppColors.olive),
    CategoryColorChoice(label: 'Orange', value: AppColors.orangeDeep),
  ];

  static const List<CategoryIconChoice> iconChoices = <CategoryIconChoice>[
    CategoryIconChoice(
      key: 'income',
      label: 'Income',
      icon: Icons.north_east_rounded,
    ),
    CategoryIconChoice(
      key: 'expense',
      label: 'Expense',
      icon: Icons.south_east_rounded,
    ),
    CategoryIconChoice(
      key: 'shopping',
      label: 'Shopping',
      icon: Icons.shopping_bag_outlined,
    ),
    CategoryIconChoice(
      key: 'food',
      label: 'Food',
      icon: Icons.restaurant_outlined,
    ),
    CategoryIconChoice(
      key: 'home',
      label: 'Home',
      icon: Icons.home_outlined,
    ),
    CategoryIconChoice(
      key: 'car',
      label: 'Car',
      icon: Icons.directions_car_outlined,
    ),
    CategoryIconChoice(
      key: 'fuel',
      label: 'Fuel',
      icon: Icons.local_gas_station_outlined,
    ),
    CategoryIconChoice(
      key: 'health',
      label: 'Health',
      icon: Icons.health_and_safety_outlined,
    ),
    CategoryIconChoice(
      key: 'education',
      label: 'Education',
      icon: Icons.school_outlined,
    ),
    CategoryIconChoice(
      key: 'travel',
      label: 'Travel',
      icon: Icons.flight_takeoff_outlined,
    ),
    CategoryIconChoice(
      key: 'gift',
      label: 'Gift',
      icon: Icons.card_giftcard_outlined,
    ),
    CategoryIconChoice(
      key: 'salary',
      label: 'Salary',
      icon: Icons.payments_outlined,
    ),
    CategoryIconChoice(
      key: 'business',
      label: 'Business',
      icon: Icons.storefront_outlined,
    ),
    CategoryIconChoice(
      key: 'investment',
      label: 'Investment',
      icon: Icons.trending_up_rounded,
    ),
    CategoryIconChoice(
      key: 'savings',
      label: 'Savings',
      icon: Icons.savings_outlined,
    ),
    CategoryIconChoice(
      key: 'zakat',
      label: 'Zakat',
      icon: Icons.mosque_outlined,
    ),
    CategoryIconChoice(
      key: 'charity',
      label: 'Charity',
      icon: Icons.volunteer_activism_outlined,
    ),
    CategoryIconChoice(
      key: 'phone',
      label: 'Phone',
      icon: Icons.phone_iphone_outlined,
    ),
    CategoryIconChoice(
      key: 'internet',
      label: 'Internet',
      icon: Icons.wifi_outlined,
    ),
    CategoryIconChoice(
      key: 'utilities',
      label: 'Utilities',
      icon: Icons.electrical_services_outlined,
    ),
    CategoryIconChoice(
      key: 'subscription',
      label: 'Subscription',
      icon: Icons.subscriptions_outlined,
    ),
    CategoryIconChoice(
      key: 'entertainment',
      label: 'Entertainment',
      icon: Icons.movie_outlined,
    ),
    CategoryIconChoice(
      key: 'pets',
      label: 'Pets',
      icon: Icons.pets_outlined,
    ),
    CategoryIconChoice(
      key: 'sports',
      label: 'Sports',
      icon: Icons.sports_soccer_outlined,
    ),
    CategoryIconChoice(
      key: 'gaming',
      label: 'Gaming',
      icon: Icons.sports_esports_outlined,
    ),
    CategoryIconChoice(
      key: 'clothing',
      label: 'Clothing',
      icon: Icons.checkroom_outlined,
    ),
    CategoryIconChoice(
      key: 'groceries',
      label: 'Groceries',
      icon: Icons.shopping_cart_outlined,
    ),
    CategoryIconChoice(
      key: 'rent',
      label: 'Rent',
      icon: Icons.apartment_outlined,
    ),
    CategoryIconChoice(
      key: 'insurance',
      label: 'Insurance',
      icon: Icons.shield_outlined,
    ),
    CategoryIconChoice(
      key: 'transfer',
      label: 'Transfer',
      icon: Icons.sync_alt_rounded,
    ),
    CategoryIconChoice(
      key: 'wallet',
      label: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
    ),
    CategoryIconChoice(
      key: 'bank',
      label: 'Bank',
      icon: Icons.account_balance_outlined,
    ),
  ];

  static const Map<String, IconData> _iconMap = <String, IconData>{
    'neutral': Icons.circle_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'food': Icons.restaurant_outlined,
    'home': Icons.home_outlined,
    'car': Icons.directions_car_outlined,
    'fuel': Icons.local_gas_station_outlined,
    'health': Icons.health_and_safety_outlined,
    'education': Icons.school_outlined,
    'travel': Icons.flight_takeoff_outlined,
    'gift': Icons.card_giftcard_outlined,
    'salary': Icons.payments_outlined,
    'business': Icons.storefront_outlined,
    'investment': Icons.trending_up_rounded,
    'savings': Icons.savings_outlined,
    'zakat': Icons.mosque_outlined,
    'charity': Icons.volunteer_activism_outlined,
    'phone': Icons.phone_iphone_outlined,
    'internet': Icons.wifi_outlined,
    'utilities': Icons.electrical_services_outlined,
    'subscription': Icons.subscriptions_outlined,
    'entertainment': Icons.movie_outlined,
    'pets': Icons.pets_outlined,
    'sports': Icons.sports_soccer_outlined,
    'gaming': Icons.sports_esports_outlined,
    'clothing': Icons.checkroom_outlined,
    'groceries': Icons.shopping_cart_outlined,
    'rent': Icons.apartment_outlined,
    'insurance': Icons.shield_outlined,
    'transfer': Icons.sync_alt_rounded,
    'wallet': Icons.account_balance_wallet_outlined,
    'bank': Icons.account_balance_outlined,
    'income': Icons.north_east_rounded,
    'expense': Icons.south_east_rounded,
    'transfer_fallback': Icons.swap_horiz_rounded,
  };

  static const Map<String, CategoryVisual> _defaultIncomeVisuals =
      <String, CategoryVisual>{
        'salary': CategoryVisual(iconKey: 'salary', colorValue: 0xFF047857),
        'freelance': CategoryVisual(iconKey: 'business', colorValue: 0xFF0F766E),
        'business': CategoryVisual(iconKey: 'business', colorValue: 0xFF2563EB),
        'investment returns': CategoryVisual(
          iconKey: 'investment',
          colorValue: 0xFF7C3AED,
        ),
        'rental income': CategoryVisual(
          iconKey: 'home',
          colorValue: 0xFF0EA5E9,
        ),
        'gift': CategoryVisual(iconKey: 'gift', colorValue: 0xFFEA580C),
        'bonus': CategoryVisual(iconKey: 'salary', colorValue: 0xFFC8A75B),
        'savings': CategoryVisual(iconKey: 'savings', colorValue: 0xFF0F766E),
        'other income': CategoryVisual(iconKey: 'wallet', colorValue: 0xFF64748B),
      };

  static const Map<String, CategoryVisual> _defaultExpenseVisuals =
      <String, CategoryVisual>{
        'food & dining': CategoryVisual(iconKey: 'food', colorValue: 0xFFEA580C),
        'groceries': CategoryVisual(iconKey: 'groceries', colorValue: 0xFF16A34A),
        'housing & rent': CategoryVisual(iconKey: 'rent', colorValue: 0xFF0EA5E9),
        'utilities': CategoryVisual(iconKey: 'utilities', colorValue: 0xFF2563EB),
        'internet & phone': CategoryVisual(iconKey: 'phone', colorValue: 0xFF7C3AED),
        'transportation': CategoryVisual(iconKey: 'car', colorValue: 0xFF0F766E),
        'fuel & parking': CategoryVisual(iconKey: 'fuel', colorValue: 0xFFEA580C),
        'healthcare': CategoryVisual(iconKey: 'health', colorValue: 0xFFDC2626),
        'education': CategoryVisual(iconKey: 'education', colorValue: 0xFF2563EB),
        'clothing & apparel': CategoryVisual(iconKey: 'clothing', colorValue: 0xFF7C3AED),
        'entertainment': CategoryVisual(iconKey: 'entertainment', colorValue: 0xFFF97316),
        'travel': CategoryVisual(iconKey: 'travel', colorValue: 0xFF0EA5E9),
        'shopping': CategoryVisual(iconKey: 'shopping', colorValue: 0xFFDC2626),
        'home maintenance': CategoryVisual(iconKey: 'home', colorValue: 0xFF64748B),
        'insurance': CategoryVisual(iconKey: 'insurance', colorValue: 0xFF0F766E),
        'charitable giving': CategoryVisual(iconKey: 'charity', colorValue: 0xFFC8A75B),
        'zakat': CategoryVisual(iconKey: 'zakat', colorValue: 0xFF0F766E),
        'childcare': CategoryVisual(iconKey: 'gift', colorValue: 0xFFEA580C),
        'subscriptions': CategoryVisual(
          iconKey: 'subscription',
          colorValue: 0xFF7C3AED,
        ),
        'loan payment': CategoryVisual(iconKey: 'bank', colorValue: 0xFF64748B),
        'other': CategoryVisual(iconKey: 'wallet', colorValue: 0xFF94A3B8),
      };

  static IconData iconForKey(String? key) {
    final String clean = key?.trim().toLowerCase() ?? '';
    return _iconMap[clean] ?? _iconMap['neutral']!;
  }

  static Color colorFromValue(int? value) {
    return Color(value ?? neutralFallback.colorValue!);
  }

  static CategoryVisual resolveCategoryVisual({
    required AppCategories categories,
    required String type,
    required String categoryName,
    bool preferNeutralForUnknown = false,
  }) {
    final String cleanName = categoryName.trim();
    final String lower = cleanName.toLowerCase();
    final bool income = type.trim().toLowerCase() == 'income';
    final CategoryVisual? custom = categories.metadataFor(
      type: income ? 'income' : 'expense',
      name: cleanName,
    );
    final CategoryVisual? defaults =
        income ? _defaultIncomeVisuals[lower] : _defaultExpenseVisuals[lower];
    final CategoryVisual fallback = preferNeutralForUnknown
        ? neutralFallback
        : (income
              ? const CategoryVisual(
              iconKey: 'income',
              colorValue: 0xFF047857,
                )
              : const CategoryVisual(
                  iconKey: 'expense',
                  colorValue: 0xFFDC2626,
                ));
    return CategoryVisual(
      iconKey: custom?.iconKey ?? defaults?.iconKey ?? fallback.iconKey,
      colorValue: custom?.colorValue ?? defaults?.colorValue ?? fallback.colorValue,
    );
  }

  static CategoryVisual resolveTypeFallback(String type) {
    final String clean = type.trim().toLowerCase();
    if (clean == 'income') {
      return const CategoryVisual(iconKey: 'income', colorValue: 0xFF047857);
    }
    if (clean == 'transfer') {
      return const CategoryVisual(
        iconKey: 'transfer_fallback',
        colorValue: 0xFFC8A75B,
      );
    }
    return const CategoryVisual(iconKey: 'expense', colorValue: 0xFFDC2626);
  }

  static CategoryVisual resolveCustomOverride({
    required String iconKey,
    required Color color,
  }) {
    return CategoryVisual(iconKey: iconKey, colorValue: color.toARGB32());
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
