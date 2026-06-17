class MarketSnapshot {
  const MarketSnapshot({
    required this.gold24kPricePerGramEgp,
    required this.silverPricePerGramEgp,
    required this.usdToEgp,
    required this.sarToEgp,
    required this.aedToEgp,
    required this.kwdToEgp,
    required this.qarToEgp,
    required this.eurToEgp,
    required this.gbpToEgp,
    required this.bhdToEgp,
    required this.omrToEgp,
    required this.jodToEgp,
    required this.tryToEgp,
    required this.myrToEgp,
    required this.pkrToEgp,
    required this.idrToEgp,
    required this.lastUpdated,
  });

  final double gold24kPricePerGramEgp;
  final double silverPricePerGramEgp;
  final double usdToEgp;
  final double sarToEgp;
  final double aedToEgp;
  final double kwdToEgp;
  final double qarToEgp;
  final double eurToEgp;
  final double gbpToEgp;
  final double bhdToEgp;
  final double omrToEgp;
  final double jodToEgp;
  final double tryToEgp;
  final double myrToEgp;
  final double pkrToEgp;
  final double idrToEgp;
  final String lastUpdated;

  static const MarketSnapshot empty = MarketSnapshot(
    gold24kPricePerGramEgp: 0,
    silverPricePerGramEgp: 0,
    usdToEgp: 0,
    sarToEgp: 0,
    aedToEgp: 0,
    kwdToEgp: 0,
    qarToEgp: 0,
    eurToEgp: 0,
    gbpToEgp: 0,
    bhdToEgp: 0,
    omrToEgp: 0,
    jodToEgp: 0,
    tryToEgp: 0,
    myrToEgp: 0,
    pkrToEgp: 0,
    idrToEgp: 0,
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
      eurToEgp: _asDouble(json['eurToEgp']),
      gbpToEgp: _asDouble(json['gbpToEgp']),
      bhdToEgp: _asDouble(json['bhdToEgp']),
      omrToEgp: _asDouble(json['omrToEgp']),
      jodToEgp: _asDouble(json['jodToEgp']),
      tryToEgp: _asDouble(json['tryToEgp']),
      myrToEgp: _asDouble(json['myrToEgp']),
      pkrToEgp: _asDouble(json['pkrToEgp']),
      idrToEgp: _asDouble(json['idrToEgp']),
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
      eurToEgp: _asDouble(rates['EUR']),
      gbpToEgp: _asDouble(rates['GBP']),
      bhdToEgp: _asDouble(rates['BHD']),
      omrToEgp: _asDouble(rates['OMR']),
      jodToEgp: _asDouble(rates['JOD']),
      tryToEgp: _asDouble(rates['TRY']),
      myrToEgp: _asDouble(rates['MYR']),
      pkrToEgp: _asDouble(rates['PKR']),
      idrToEgp: _asDouble(rates['IDR']),
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
      'eurToEgp': eurToEgp,
      'gbpToEgp': gbpToEgp,
      'bhdToEgp': bhdToEgp,
      'omrToEgp': omrToEgp,
      'jodToEgp': jodToEgp,
      'tryToEgp': tryToEgp,
      'myrToEgp': myrToEgp,
      'pkrToEgp': pkrToEgp,
      'idrToEgp': idrToEgp,
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
        if (eurToEgp > 0) 'EUR': eurToEgp,
        if (gbpToEgp > 0) 'GBP': gbpToEgp,
        if (bhdToEgp > 0) 'BHD': bhdToEgp,
        if (omrToEgp > 0) 'OMR': omrToEgp,
        if (jodToEgp > 0) 'JOD': jodToEgp,
        if (tryToEgp > 0) 'TRY': tryToEgp,
        if (myrToEgp > 0) 'MYR': myrToEgp,
        if (pkrToEgp > 0) 'PKR': pkrToEgp,
        if (idrToEgp > 0) 'IDR': idrToEgp,
      },
      'LAST_UPDATED': lastUpdated,
    };
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  MarketSnapshot copyWith({
    double? gold24kPricePerGramEgp,
    double? silverPricePerGramEgp,
    double? usdToEgp,
    double? sarToEgp,
    double? aedToEgp,
    double? kwdToEgp,
    double? qarToEgp,
    double? eurToEgp,
    double? gbpToEgp,
    double? bhdToEgp,
    double? omrToEgp,
    double? jodToEgp,
    double? tryToEgp,
    double? myrToEgp,
    double? pkrToEgp,
    double? idrToEgp,
    String? lastUpdated,
  }) {
    return MarketSnapshot(
      gold24kPricePerGramEgp:
          gold24kPricePerGramEgp ?? this.gold24kPricePerGramEgp,
      silverPricePerGramEgp:
          silverPricePerGramEgp ?? this.silverPricePerGramEgp,
      usdToEgp: usdToEgp ?? this.usdToEgp,
      sarToEgp: sarToEgp ?? this.sarToEgp,
      aedToEgp: aedToEgp ?? this.aedToEgp,
      kwdToEgp: kwdToEgp ?? this.kwdToEgp,
      qarToEgp: qarToEgp ?? this.qarToEgp,
      eurToEgp: eurToEgp ?? this.eurToEgp,
      gbpToEgp: gbpToEgp ?? this.gbpToEgp,
      bhdToEgp: bhdToEgp ?? this.bhdToEgp,
      omrToEgp: omrToEgp ?? this.omrToEgp,
      jodToEgp: jodToEgp ?? this.jodToEgp,
      tryToEgp: tryToEgp ?? this.tryToEgp,
      myrToEgp: myrToEgp ?? this.myrToEgp,
      pkrToEgp: pkrToEgp ?? this.pkrToEgp,
      idrToEgp: idrToEgp ?? this.idrToEgp,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
