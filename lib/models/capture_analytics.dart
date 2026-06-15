class CaptureAnalytics {
  const CaptureAnalytics({
    required this.parsedMessages,
    required this.autoApprovedMessages,
    required this.duplicateMessages,
    required this.ignoredMessages,
    required this.correctedMessages,
    required this.learnedRules,
    required this.autoApprovedRules,
    required this.capturedFromAppleShortcuts,
    required this.capturedFromAppleShortcutsAutoApproved,
    required this.capturedFromAppleShortcutsIgnored,
  });

  final int parsedMessages;
  final int autoApprovedMessages;
  final int duplicateMessages;
  final int ignoredMessages;
  final int correctedMessages;
  final int learnedRules;
  final int autoApprovedRules;
  final int capturedFromAppleShortcuts;
  final int capturedFromAppleShortcutsAutoApproved;
  final int capturedFromAppleShortcutsIgnored;

  factory CaptureAnalytics.fromJson(Map<String, dynamic> json) {
    return CaptureAnalytics(
      parsedMessages: json['parsedMessages'] is int
          ? json['parsedMessages'] as int
          : 0,
      autoApprovedMessages: json['autoApprovedMessages'] is int
          ? json['autoApprovedMessages'] as int
          : 0,
      duplicateMessages: json['duplicateMessages'] is int
          ? json['duplicateMessages'] as int
          : 0,
      ignoredMessages: json['ignoredMessages'] is int
          ? json['ignoredMessages'] as int
          : 0,
      correctedMessages: json['correctedMessages'] is int
          ? json['correctedMessages'] as int
          : 0,
      learnedRules: json['learnedRules'] is int
          ? json['learnedRules'] as int
          : 0,
      autoApprovedRules: json['autoApprovedRules'] is int
          ? json['autoApprovedRules'] as int
          : 0,
      capturedFromAppleShortcuts: json['capturedFromAppleShortcuts'] is int
          ? json['capturedFromAppleShortcuts'] as int
          : 0,
      capturedFromAppleShortcutsAutoApproved:
          json['capturedFromAppleShortcutsAutoApproved'] is int
          ? json['capturedFromAppleShortcutsAutoApproved'] as int
          : 0,
      capturedFromAppleShortcutsIgnored:
          json['capturedFromAppleShortcutsIgnored'] is int
          ? json['capturedFromAppleShortcutsIgnored'] as int
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'parsedMessages': parsedMessages,
      'autoApprovedMessages': autoApprovedMessages,
      'duplicateMessages': duplicateMessages,
      'ignoredMessages': ignoredMessages,
      'correctedMessages': correctedMessages,
      'learnedRules': learnedRules,
      'autoApprovedRules': autoApprovedRules,
      'capturedFromAppleShortcuts': capturedFromAppleShortcuts,
      'capturedFromAppleShortcutsAutoApproved':
          capturedFromAppleShortcutsAutoApproved,
      'capturedFromAppleShortcutsIgnored': capturedFromAppleShortcutsIgnored,
    };
  }

  CaptureAnalytics copyWith({
    int? parsedMessages,
    int? autoApprovedMessages,
    int? duplicateMessages,
    int? ignoredMessages,
    int? correctedMessages,
    int? learnedRules,
    int? autoApprovedRules,
    int? capturedFromAppleShortcuts,
    int? capturedFromAppleShortcutsAutoApproved,
    int? capturedFromAppleShortcutsIgnored,
  }) {
    return CaptureAnalytics(
      parsedMessages: parsedMessages ?? this.parsedMessages,
      autoApprovedMessages: autoApprovedMessages ?? this.autoApprovedMessages,
      duplicateMessages: duplicateMessages ?? this.duplicateMessages,
      ignoredMessages: ignoredMessages ?? this.ignoredMessages,
      correctedMessages: correctedMessages ?? this.correctedMessages,
      learnedRules: learnedRules ?? this.learnedRules,
      autoApprovedRules: autoApprovedRules ?? this.autoApprovedRules,
      capturedFromAppleShortcuts:
          capturedFromAppleShortcuts ?? this.capturedFromAppleShortcuts,
      capturedFromAppleShortcutsAutoApproved:
          capturedFromAppleShortcutsAutoApproved ??
          this.capturedFromAppleShortcutsAutoApproved,
      capturedFromAppleShortcutsIgnored:
          capturedFromAppleShortcutsIgnored ??
          this.capturedFromAppleShortcutsIgnored,
    );
  }

  factory CaptureAnalytics.empty() {
    return const CaptureAnalytics(
      parsedMessages: 0,
      autoApprovedMessages: 0,
      duplicateMessages: 0,
      ignoredMessages: 0,
      correctedMessages: 0,
      learnedRules: 0,
      autoApprovedRules: 0,
      capturedFromAppleShortcuts: 0,
      capturedFromAppleShortcutsAutoApproved: 0,
      capturedFromAppleShortcutsIgnored: 0,
    );
  }
}
