class MarketSnapshot {
  const MarketSnapshot({
    required this.gold24kPricePerGramEgp,
    required this.silverPricePerGramEgp,
    required this.usdToEgp,
    required this.sarToEgp,
    required this.aedToEgp,
    required this.kwdToEgp,
    required this.qarToEgp,
    required this.lastUpdated,
  });

  final double gold24kPricePerGramEgp;
  final double silverPricePerGramEgp;
  final double usdToEgp;
  final double sarToEgp;
  final double aedToEgp;
  final double kwdToEgp;
  final double qarToEgp;
  final String lastUpdated;

  static const MarketSnapshot empty = MarketSnapshot(
    gold24kPricePerGramEgp: 0,
    silverPricePerGramEgp: 0,
    usdToEgp: 0,
    sarToEgp: 0,
    aedToEgp: 0,
    kwdToEgp: 0,
    qarToEgp: 0,
    lastUpdated: '',
  );

  bool get hasRequiredData =>
      gold24kPricePerGramEgp > 0 && silverPricePerGramEgp > 0;

  factory MarketSnapshot.fromJson(Map<String, dynamic> json) {
    return MarketSnapshot(
      gold24kPricePerGramEgp: _asDouble(json['gold24kPricePerGramEgp']),
      silverPricePerGramEgp: _asDouble(json['silverPricePerGramEgp']),
      usdToEgp: _asDouble(json['usdToEgp']),
      sarToEgp: _asDouble(json['sarToEgp']),
      aedToEgp: _asDouble(json['aedToEgp']),
      kwdToEgp: _asDouble(json['kwdToEgp']),
      qarToEgp: _asDouble(json['qarToEgp']),
      lastUpdated: (json['lastUpdated'] ?? '').toString(),
    );
  }

  factory MarketSnapshot.fromAppStateJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rates =
        Map<String, dynamic>.from((json['RATES_TO_EGP'] as Map?) ?? const <String, dynamic>{});

    return MarketSnapshot(
      gold24kPricePerGramEgp: _asDouble(json['GOLD_PRICE_24K_EGP']),
      silverPricePerGramEgp: _asDouble(json['SILVER_PRICE_EGP']),
      usdToEgp: _asDouble(json['USD_TO_EGP']),
      sarToEgp: _asDouble(json['SAR_TO_EGP']),
      aedToEgp: _asDouble(rates['AED']),
      kwdToEgp: _asDouble(rates['KWD']),
      qarToEgp: _asDouble(rates['QAR']),
      lastUpdated: (json['LAST_UPDATED'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'gold24kPricePerGramEgp': gold24kPricePerGramEgp,
      'silverPricePerGramEgp': silverPricePerGramEgp,
      'usdToEgp': usdToEgp,
      'sarToEgp': sarToEgp,
      'aedToEgp': aedToEgp,
      'kwdToEgp': kwdToEgp,
      'qarToEgp': qarToEgp,
      'lastUpdated': lastUpdated,
    };
  }

  Map<String, dynamic> toAppStateJson() {
    return <String, dynamic>{
      'GOLD_PRICE_24K_EGP': gold24kPricePerGramEgp,
      'SILVER_PRICE_EGP': silverPricePerGramEgp,
      'USD_TO_EGP': usdToEgp,
      'SAR_TO_EGP': sarToEgp,
      'RATES_TO_EGP': <String, dynamic>{
        'EGP': 1,
        if (usdToEgp > 0) 'USD': usdToEgp,
        if (sarToEgp > 0) 'SAR': sarToEgp,
        if (aedToEgp > 0) 'AED': aedToEgp,
        if (kwdToEgp > 0) 'KWD': kwdToEgp,
        if (qarToEgp > 0) 'QAR': qarToEgp,
      },
      'LAST_UPDATED': lastUpdated,
    };
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }
}
