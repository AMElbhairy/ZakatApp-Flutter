enum CaptureSource {
  sms,
  shortcut,
  manual,
  share,
}

class RawCapturePayload {
  const RawCapturePayload({
    required this.rawText,
    required this.source,
    this.sourceIdentifier,
    this.senderHeader,
    required this.receivedAt,
    this.platform,
    this.nativeMessageId,
  });

  final String rawText;
  final CaptureSource source;
  final String? sourceIdentifier;
  final String? senderHeader;
  final DateTime receivedAt;
  final String? platform;
  final String? nativeMessageId;

  String get sourceString {
    switch (source) {
      case CaptureSource.sms:
        return 'sms';
      case CaptureSource.shortcut:
        return 'shortcut';
      case CaptureSource.share:
        return 'share';
      case CaptureSource.manual:
        return 'manual';
    }
  }

  static CaptureSource parseSource(dynamic value) {
    if (value == null) return CaptureSource.shortcut;
    final String s = value.toString().trim().toLowerCase();
    switch (s) {
      case 'sms':
        return CaptureSource.sms;
      case 'shortcut':
      case 'apple automation':
      case 'apple_shortcuts':
        return CaptureSource.shortcut;
      case 'share':
      case 'sharing':
        return CaptureSource.share;
      case 'manual':
      case 'paste':
        return CaptureSource.manual;
      default:
        return CaptureSource.shortcut;
    }
  }

  factory RawCapturePayload.fromMap(
    dynamic map, {
    CaptureSource fallbackSource = CaptureSource.shortcut,
    String? fallbackPlatform,
  }) {
    if (map is String) {
      return RawCapturePayload(
        rawText: map,
        source: fallbackSource,
        receivedAt: DateTime.now().toUtc(),
        platform: fallbackPlatform,
      );
    }

    if (map is Map) {
      final String text = (map['messageContent'] ??
              map['messageText'] ??
              map['rawText'] ??
              map['text'] ??
              '')
          .toString();

      final CaptureSource src = map.containsKey('source')
          ? parseSource(map['source'])
          : fallbackSource;

      final String? srcId = map['sourceIdentifier']?.toString();
      final String? sender = (map['senderHeader'] ?? map['sender'])?.toString();
      final String? msgId = (map['nativeMessageId'] ?? map['messageId'])?.toString();
      final String? plat = (map['platform'] ?? fallbackPlatform)?.toString();

      DateTime dt = DateTime.now().toUtc();
      if (map['receivedAt'] != null) {
        final parsed = DateTime.tryParse(map['receivedAt'].toString());
        if (parsed != null) {
          dt = parsed.toUtc();
        }
      }

      return RawCapturePayload(
        rawText: text,
        source: src,
        sourceIdentifier: srcId,
        senderHeader: sender != null && sender.trim().isNotEmpty ? sender.trim() : null,
        receivedAt: dt,
        platform: plat,
        nativeMessageId: msgId,
      );
    }

    return RawCapturePayload(
      rawText: '',
      source: fallbackSource,
      receivedAt: DateTime.now().toUtc(),
      platform: fallbackPlatform,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'rawText': rawText,
      'source': sourceString,
      if (sourceIdentifier != null) 'sourceIdentifier': sourceIdentifier,
      if (senderHeader != null) 'senderHeader': senderHeader,
      'receivedAt': receivedAt.toUtc().toIso8601String(),
      if (platform != null) 'platform': platform,
      if (nativeMessageId != null) 'nativeMessageId': nativeMessageId,
    };
  }

  RawCapturePayload copyWith({
    String? rawText,
    CaptureSource? source,
    String? sourceIdentifier,
    String? senderHeader,
    DateTime? receivedAt,
    String? platform,
    String? nativeMessageId,
  }) {
    return RawCapturePayload(
      rawText: rawText ?? this.rawText,
      source: source ?? this.source,
      sourceIdentifier: sourceIdentifier ?? this.sourceIdentifier,
      senderHeader: senderHeader ?? this.senderHeader,
      receivedAt: receivedAt ?? this.receivedAt,
      platform: platform ?? this.platform,
      nativeMessageId: nativeMessageId ?? this.nativeMessageId,
    );
  }
}
