class SyncStatus {
  const SyncStatus({
    required this.status,
    this.spreadsheetId,
    this.spreadsheetName,
    this.lastSyncAt,
    this.lastError,
    this.cloudHydrated = false,
  });

  final String status; // localOnly / syncing / synced / failed / needsPull / conflict
  final String? spreadsheetId;
  final String? spreadsheetName;
  final String? lastSyncAt;
  final String? lastError;
  final bool cloudHydrated;

  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      status: (json['status'] ?? 'localOnly').toString(),
      spreadsheetId: json['spreadsheetId']?.toString(),
      spreadsheetName: json['spreadsheetName']?.toString(),
      lastSyncAt: json['lastSyncAt']?.toString(),
      lastError: json['lastError']?.toString(),
      cloudHydrated: json.containsKey('cloudHydrated')
          ? (json['cloudHydrated'] == true)
          : false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status,
      if (spreadsheetId != null) 'spreadsheetId': spreadsheetId,
      if (spreadsheetName != null) 'spreadsheetName': spreadsheetName,
      if (lastSyncAt != null) 'lastSyncAt': lastSyncAt,
      if (lastError != null) 'lastError': lastError,
      'cloudHydrated': cloudHydrated,
    };
  }

  SyncStatus copyWith({
    String? status,
    String? spreadsheetId,
    String? spreadsheetName,
    String? lastSyncAt,
    String? lastError,
    bool? cloudHydrated,
  }) {
    return SyncStatus(
      status: status ?? this.status,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      spreadsheetName: spreadsheetName ?? this.spreadsheetName,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError ?? this.lastError,
      cloudHydrated: cloudHydrated ?? this.cloudHydrated,
    );
  }
}
