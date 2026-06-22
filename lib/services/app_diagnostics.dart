import 'dart:convert';

import '../models/saving.dart';
import 'sync_diagnostics_service.dart';

class DebugDiagnosticsReport {
  const DebugDiagnosticsReport({
    required this.generatedAtUtc,
    required this.app,
    required this.auth,
    required this.firebase,
    required this.storage,
    required this.syncPolicy,
    required this.syncHealth,
    required this.savingsSummary,
    required this.preciousMetalsSummary,
    required this.comparison,
    required this.marketData,
    required this.firebaseSavingsReadPath,
    required this.firebaseSavingsWritePath,
    required this.pullSyncSavingsPath,
    required this.lastSavingsWritePath,
    required this.lastSavingsWritePayload,
    required this.lastSavingsWriteSuccessDocumentId,
    required this.lastSavingsWriteError,
    required this.recentSavingsPayloadJson,
    required this.recentSavingsResponse,
    required this.recentSavingsError,
    required this.recentSyncLogs,
    required this.collectionSources,
    required this.writeFailures,
    required this.savingsCursorValue,
    required this.deletedSavingsCursorValue,
    required this.localCountGreaterThanFirebaseCount,
    required this.autoRepairRecommended,
    required this.firebaseSavingsComparisonLoaded,
  });

  final String generatedAtUtc;
  final DebugDiagnosticsAppInfo app;
  final DebugDiagnosticsAuthInfo auth;
  final DebugDiagnosticsFirebaseInfo firebase;
  final DebugDiagnosticsStorageInfo storage;
  final DebugDiagnosticsSyncPolicy syncPolicy;
  final DebugDiagnosticsSyncHealth syncHealth;
  final DebugDiagnosticsSavingsSummary savingsSummary;
  final DebugDiagnosticsSavingsSummary preciousMetalsSummary;
  final DebugDiagnosticsSavingsComparison comparison;
  final DebugDiagnosticsMarketData marketData;
  final String firebaseSavingsReadPath;
  final String firebaseSavingsWritePath;
  final String pullSyncSavingsPath;
  final String lastSavingsWritePath;
  final String lastSavingsWritePayload;
  final String lastSavingsWriteSuccessDocumentId;
  final String lastSavingsWriteError;
  final String recentSavingsPayloadJson;
  final String recentSavingsResponse;
  final String recentSavingsError;
  final List<SyncDiagnosticsLogEntry> recentSyncLogs;
  final Map<String, String> collectionSources;
  final List<String> writeFailures;
  final String savingsCursorValue;
  final String deletedSavingsCursorValue;
  final bool localCountGreaterThanFirebaseCount;
  final bool autoRepairRecommended;
  final bool firebaseSavingsComparisonLoaded;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'generatedAtUtc': generatedAtUtc,
      'app': app.toJson(),
      'auth': auth.toJson(),
      'firebase': firebase.toJson(),
      'storage': storage.toJson(),
      'syncPolicy': syncPolicy.toJson(),
      'syncHealth': syncHealth.toJson(),
      'savingsSummary': savingsSummary.toJson(),
      'preciousMetalsSummary': preciousMetalsSummary.toJson(),
      'comparison': comparison.toJson(),
      'marketData': marketData.toJson(),
      'firebaseSavingsReadPath': firebaseSavingsReadPath,
      'firebaseSavingsWritePath': firebaseSavingsWritePath,
      'pullSyncSavingsPath': pullSyncSavingsPath,
      'lastSavingsWritePath': lastSavingsWritePath,
      'lastSavingsWritePayload': lastSavingsWritePayload,
      'lastSavingsWriteSuccessDocumentId': lastSavingsWriteSuccessDocumentId,
      'lastSavingsWriteError': lastSavingsWriteError,
      'recentSavingsPayloadJson': recentSavingsPayloadJson,
      'recentSavingsResponse': recentSavingsResponse,
      'recentSavingsError': recentSavingsError,
      'recentSyncLogs': recentSyncLogs
          .map((SyncDiagnosticsLogEntry entry) => entry.toJson())
          .toList(growable: false),
      'collectionSources': collectionSources,
      'writeFailures': writeFailures,
      'savingsCursorValue': savingsCursorValue,
      'deletedSavingsCursorValue': deletedSavingsCursorValue,
      'localCountGreaterThanFirebaseCount': localCountGreaterThanFirebaseCount,
      'autoRepairRecommended': autoRepairRecommended,
      'firebaseSavingsComparisonLoaded': firebaseSavingsComparisonLoaded,
    };
  }
}

class DebugDiagnosticsSyncPolicy {
  const DebugDiagnosticsSyncPolicy({
    required this.lastPushSuccessAt,
    required this.lastPullSuccessAt,
    required this.nextAutoPullAllowed,
    required this.lastTriggerReason,
    required this.pullSkippedDueToThrottle,
    required this.queueCountBeforeTrigger,
  });

  final String lastPushSuccessAt;
  final String lastPullSuccessAt;
  final bool nextAutoPullAllowed;
  final String lastTriggerReason;
  final bool pullSkippedDueToThrottle;
  final int queueCountBeforeTrigger;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lastPushSuccessAt': lastPushSuccessAt,
      'lastPullSuccessAt': lastPullSuccessAt,
      'nextAutoPullAllowed': nextAutoPullAllowed,
      'lastTriggerReason': lastTriggerReason,
      'pullSkippedDueToThrottle': pullSkippedDueToThrottle,
      'queueCountBeforeTrigger': queueCountBeforeTrigger,
    };
  }
}

class DebugDiagnosticsAppInfo {
  const DebugDiagnosticsAppInfo({
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.device,
    required this.operatingSystemVersion,
    required this.dartVersion,
  });

  final String version;
  final String buildNumber;
  final String platform;
  final String device;
  final String operatingSystemVersion;
  final String dartVersion;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'buildNumber': buildNumber,
      'platform': platform,
      'device': device,
      'operatingSystemVersion': operatingSystemVersion,
      'dartVersion': dartVersion,
    };
  }
}

class DebugDiagnosticsAuthInfo {
  const DebugDiagnosticsAuthInfo({
    required this.state,
    required this.userId,
    required this.providerIds,
    required this.isSignedIn,
  });

  final String state;
  final String userId;
  final List<String> providerIds;
  final bool isSignedIn;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'state': state,
      'userId': userId,
      'providerIds': providerIds,
      'isSignedIn': isSignedIn,
    };
  }
}

class DebugDiagnosticsFirebaseInfo {
  const DebugDiagnosticsFirebaseInfo({
    required this.projectId,
    required this.appId,
    required this.messagingSenderId,
  });

  final String projectId;
  final String appId;
  final String messagingSenderId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'projectId': projectId,
      'appId': appId,
      'messagingSenderId': messagingSenderId,
    };
  }
}

class DebugDiagnosticsStorageInfo {
  const DebugDiagnosticsStorageInfo({
    required this.sqliteActive,
    required this.databaseFileName,
    required this.databasePath,
    required this.syncEnabled,
    required this.pendingSyncQueueCount,
    required this.syncQueueRetryCount,
    required this.lastSuccessfulSyncAt,
    required this.lastFailedSyncAt,
    required this.lastSyncError,
  });

  final bool sqliteActive;
  final String databaseFileName;
  final String? databasePath;
  final bool syncEnabled;
  final int pendingSyncQueueCount;
  final int syncQueueRetryCount;
  final String lastSuccessfulSyncAt;
  final String lastFailedSyncAt;
  final String lastSyncError;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sqliteActive': sqliteActive,
      'databaseFileName': databaseFileName,
      'databasePath': databasePath,
      'syncEnabled': syncEnabled,
      'pendingSyncQueueCount': pendingSyncQueueCount,
      'syncQueueRetryCount': syncQueueRetryCount,
      'lastSuccessfulSyncAt': lastSuccessfulSyncAt,
      'lastFailedSyncAt': lastFailedSyncAt,
      'lastSyncError': lastSyncError,
    };
  }
}

class DebugDiagnosticsSyncHealth {
  const DebugDiagnosticsSyncHealth({
    required this.pendingWrites,
    required this.cursors,
  });

  final int pendingWrites;
  final Map<String, String> cursors;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pendingWrites': pendingWrites,
      'cursors': cursors,
    };
  }
}

class DebugDiagnosticsSavingsSummary {
  const DebugDiagnosticsSavingsSummary({
    required this.localCount,
    required this.firebaseCount,
    required this.localIds,
    required this.firebaseIds,
    required this.localGoldCount,
    required this.firebaseGoldCount,
    required this.localSilverCount,
    required this.firebaseSilverCount,
  });

  final int localCount;
  final int firebaseCount;
  final List<String> localIds;
  final List<String> firebaseIds;
  final int localGoldCount;
  final int firebaseGoldCount;
  final int localSilverCount;
  final int firebaseSilverCount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'localCount': localCount,
      'firebaseCount': firebaseCount,
      'localIds': localIds,
      'firebaseIds': firebaseIds,
      'localGoldCount': localGoldCount,
      'firebaseGoldCount': firebaseGoldCount,
      'localSilverCount': localSilverCount,
      'firebaseSilverCount': firebaseSilverCount,
    };
  }
}

class DebugDiagnosticsSavingsFieldMismatch {
  const DebugDiagnosticsSavingsFieldMismatch({
    required this.field,
    required this.localValue,
    required this.firebaseValue,
  });

  final String field;
  final dynamic localValue;
  final dynamic firebaseValue;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'field': field,
      'localValue': localValue,
      'firebaseValue': firebaseValue,
    };
  }
}

class DebugDiagnosticsSavingsMismatch {
  const DebugDiagnosticsSavingsMismatch({
    required this.id,
    required this.localRecord,
    required this.firebaseRecord,
    required this.fieldMismatches,
  });

  final String id;
  final Map<String, dynamic> localRecord;
  final Map<String, dynamic> firebaseRecord;
  final List<DebugDiagnosticsSavingsFieldMismatch> fieldMismatches;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'localRecord': localRecord,
      'firebaseRecord': firebaseRecord,
      'fieldMismatches': fieldMismatches
          .map((DebugDiagnosticsSavingsFieldMismatch entry) => entry.toJson())
          .toList(growable: false),
    };
  }
}

class DebugDiagnosticsSavingsComparison {
  const DebugDiagnosticsSavingsComparison({
    required this.missingFromFirebaseIds,
    required this.missingLocallyIds,
    required this.mismatches,
  });

  final List<String> missingFromFirebaseIds;
  final List<String> missingLocallyIds;
  final List<DebugDiagnosticsSavingsMismatch> mismatches;

  int get mismatchCount => mismatches.length;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'missingFromFirebaseIds': missingFromFirebaseIds,
      'missingLocallyIds': missingLocallyIds,
      'mismatches': mismatches
          .map((DebugDiagnosticsSavingsMismatch entry) => entry.toJson())
          .toList(growable: false),
      'mismatchCount': mismatchCount,
    };
  }

  static DebugDiagnosticsSavingsComparison compare({
    required Iterable<Saving> localSavings,
    required Iterable<Saving> firebaseSavings,
  }) {
    final Map<String, Saving> localById = <String, Saving>{
      for (final Saving saving in localSavings) saving.id: saving,
    };
    final Map<String, Saving> firebaseById = <String, Saving>{
      for (final Saving saving in firebaseSavings) saving.id: saving,
    };

    final Set<String> ids = <String>{...localById.keys, ...firebaseById.keys};

    final List<String> missingFromFirebaseIds = <String>[];
    final List<String> missingLocallyIds = <String>[];
    final List<DebugDiagnosticsSavingsMismatch> mismatches =
        <DebugDiagnosticsSavingsMismatch>[];

    for (final String id in ids.toList()..sort()) {
      final Saving? local = localById[id];
      final Saving? firebase = firebaseById[id];
      if (local == null) {
        missingLocallyIds.add(id);
        continue;
      }
      if (firebase == null) {
        missingFromFirebaseIds.add(id);
        continue;
      }

      final Map<String, dynamic> localJson = local.toJson();
      final Map<String, dynamic> firebaseJson = firebase.toJson();
      final List<DebugDiagnosticsSavingsFieldMismatch> fieldMismatches =
          _compareFields(localJson, firebaseJson);
      if (fieldMismatches.isNotEmpty) {
        mismatches.add(
          DebugDiagnosticsSavingsMismatch(
            id: id,
            localRecord: localJson,
            firebaseRecord: firebaseJson,
            fieldMismatches: fieldMismatches,
          ),
        );
      }
    }

    return DebugDiagnosticsSavingsComparison(
      missingFromFirebaseIds: missingFromFirebaseIds,
      missingLocallyIds: missingLocallyIds,
      mismatches: mismatches,
    );
  }

  static List<DebugDiagnosticsSavingsFieldMismatch> _compareFields(
    Map<String, dynamic> local,
    Map<String, dynamic> firebase,
  ) {
    const List<String> fieldsToCheck = <String>[
      'assetType',
      'amount',
      'remainingAmount',
      'unit',
      'description',
      'purchaseCurrency',
      'purchaseAmount',
      'createdAt',
      'fundingAllocations',
      'internalTransfer',
      'internalTransferType',
      'transferActivityId',
      'dateAcquired',
    ];

    final List<DebugDiagnosticsSavingsFieldMismatch> mismatches =
        <DebugDiagnosticsSavingsFieldMismatch>[];
    for (final String field in fieldsToCheck) {
      if (!_valuesMatch(local[field], firebase[field])) {
        mismatches.add(
          DebugDiagnosticsSavingsFieldMismatch(
            field: field,
            localValue: local[field],
            firebaseValue: firebase[field],
          ),
        );
      }
    }
    return mismatches;
  }

  static bool _valuesMatch(dynamic left, dynamic right) {
    return _canonicalJson(left) == _canonicalJson(right);
  }

  static String _canonicalJson(dynamic value) {
    dynamic normalized(dynamic input) {
      if (input is Map) {
        final Map<String, dynamic> map = <String, dynamic>{};
        final List<String> keys =
            input.keys.map((dynamic key) => key.toString()).toList()..sort();
        for (final String key in keys) {
          map[key] = normalized(input[key]);
        }
        return map;
      }
      if (input is Iterable) {
        return input.map(normalized).toList(growable: false);
      }
      if (input == null || input is String || input is num || input is bool) {
        return input;
      }
      return input.toString();
    }

    return jsonEncode(normalized(value));
  }
}

class DebugDiagnosticsMarketData {
  const DebugDiagnosticsMarketData({
    required this.status,
    required this.goldApiKeyConfigured,
    required this.latestCachedGoldPrice,
    required this.latestCachedSilverPrice,
    required this.rawSnapshot,
  });

  final String status;
  final bool goldApiKeyConfigured;
  final double? latestCachedGoldPrice;
  final double? latestCachedSilverPrice;
  final Map<String, dynamic> rawSnapshot;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status,
      'goldApiKeyConfigured': goldApiKeyConfigured,
      'latestCachedGoldPrice': latestCachedGoldPrice,
      'latestCachedSilverPrice': latestCachedSilverPrice,
      'rawSnapshot': rawSnapshot,
    };
  }
}

String formatDiagnosticsForClipboard(DebugDiagnosticsReport report) {
  final StringBuffer buffer = StringBuffer();
  void section(String title) {
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.writeln('[$title]');
  }

  void line(String key, Object? value) {
    buffer.writeln('$key: ${_formatValue(value)}');
  }

  section('App');
  line('Generated at', report.generatedAtUtc);
  line('Version', report.app.version);
  line('Build number', report.app.buildNumber);
  line('Platform', report.app.platform);
  line('Device', report.app.device);
  line('OS version', report.app.operatingSystemVersion);
  line('Dart version', report.app.dartVersion);

  section('Auth');
  line('State', report.auth.state);
  line('User ID', report.auth.userId);
  line('Signed in', report.auth.isSignedIn);
  line('Provider IDs', report.auth.providerIds.join(', '));
  line('Firebase project ID', report.firebase.projectId);
  line('Firebase app ID', report.firebase.appId);
  line('Firebase messaging sender ID', report.firebase.messagingSenderId);
  line('Firebase savings read path', report.firebaseSavingsReadPath);
  line('Firebase savings write path', report.firebaseSavingsWritePath);
  line('Pull sync savings path', report.pullSyncSavingsPath);
  line('Last savings write path', report.lastSavingsWritePath);
  line('Last savings write payload', report.lastSavingsWritePayload);
  line(
    'Last savings write success document id',
    report.lastSavingsWriteSuccessDocumentId,
  );
  line('Last savings write error', report.lastSavingsWriteError);

  section('Sync Health');
  line('SQLite active', report.storage.sqliteActive);
  line('SQLite database file', report.storage.databaseFileName);
  line('SQLite database path', report.storage.databasePath);
  line('Sync enabled', report.storage.syncEnabled);
  line('Pending sync queue count', report.storage.pendingSyncQueueCount);
  line('Sync queue retry count', report.storage.syncQueueRetryCount);
  line('Last successful sync', report.storage.lastSuccessfulSyncAt);
  line('Last failed sync', report.storage.lastFailedSyncAt);
  line('Last sync error', report.storage.lastSyncError);
  line('Last push success at', report.syncPolicy.lastPushSuccessAt);
  line('Last pull success at', report.syncPolicy.lastPullSuccessAt);
  line('Next auto pull allowed', report.syncPolicy.nextAutoPullAllowed);
  line('Last sync trigger reason', report.syncPolicy.lastTriggerReason);
  line(
    'Pull skipped due to throttle',
    report.syncPolicy.pullSkippedDueToThrottle,
  );
  line('Queue count before trigger', report.syncPolicy.queueCountBeforeTrigger);
  line('Pending writes', report.syncHealth.pendingWrites);
  line('Savings cursor', report.savingsCursorValue);
  line('Deleted savings cursor', report.deletedSavingsCursorValue);
  line(
    'Local count > Firebase count',
    report.localCountGreaterThanFirebaseCount,
  );
  line('Auto-repair recommended', report.autoRepairRecommended);

  section('Pull Cursors');
  for (final MapEntry<String, String> entry
      in report.syncHealth.cursors.entries) {
    line(entry.key, entry.value);
  }
  line('Collection sources', report.collectionSources);

  if (report.firebaseSavingsComparisonLoaded) {
    section('Savings Summary');
    line('Local savings count', report.savingsSummary.localCount);
    line('Firebase savings count', report.savingsSummary.firebaseCount);
    line('Local savings ids', report.savingsSummary.localIds.join(', '));
    line('Firebase savings ids', report.savingsSummary.firebaseIds.join(', '));
    line('Recent savings payload', report.recentSavingsPayloadJson);
    line('Recent Firebase response', report.recentSavingsResponse);
    line('Recent Firebase error', report.recentSavingsError);

    section('Precious Metals Summary');
    line('Local gold count', report.preciousMetalsSummary.localGoldCount);
    line('Firebase gold count', report.preciousMetalsSummary.firebaseGoldCount);
    line('Local silver count', report.preciousMetalsSummary.localSilverCount);
    line(
      'Firebase silver count',
      report.preciousMetalsSummary.firebaseSilverCount,
    );

    section('Local vs Firebase Mismatches');
    line(
      'Missing from Firebase',
      report.comparison.missingFromFirebaseIds.join(', '),
    );
    line('Missing locally', report.comparison.missingLocallyIds.join(', '));
    line('Mismatch count', report.comparison.mismatchCount);
    for (final DebugDiagnosticsSavingsMismatch mismatch
        in report.comparison.mismatches) {
      buffer.writeln(' - ${mismatch.id}');
      for (final DebugDiagnosticsSavingsFieldMismatch field
          in mismatch.fieldMismatches) {
        buffer.writeln(
          '   * ${field.field}: local=${_formatValue(field.localValue)} firebase=${_formatValue(field.firebaseValue)}',
        );
      }
    }
  }

  section('Recent Sync Logs');
  if (report.recentSyncLogs.isEmpty) {
    buffer.writeln('- none');
  } else {
    for (final SyncDiagnosticsLogEntry entry in report.recentSyncLogs) {
      buffer.writeln(
        '[${entry.timestamp}] ${entry.level.toUpperCase()} ${entry.subsystem}: ${entry.message}',
      );
      if (entry.metadata.isNotEmpty) {
        buffer.writeln('  metadata: ${_formatValue(entry.metadata)}');
      }
    }
  }

  section('Market Data');
  line('Status', report.marketData.status);
  line('GOLD_API_KEY configured', report.marketData.goldApiKeyConfigured);
  line('Latest cached gold price', report.marketData.latestCachedGoldPrice);
  line('Latest cached silver price', report.marketData.latestCachedSilverPrice);
  line('Raw snapshot', report.marketData.rawSnapshot);

  section('Errors');
  line('Write failures', report.writeFailures);

  return buffer.toString().trimRight();
}

String _formatValue(Object? value) {
  if (value == null) return '-';
  if (value is String) return value.isEmpty ? '-' : value;
  if (value is Map || value is Iterable) {
    return jsonEncode(value);
  }
  return value.toString();
}

class AppDiagnosticsSnapshot {
  const AppDiagnosticsSnapshot({
    required this.firebaseUid,
    required this.databaseFileName,
    required this.databasePath,
    required this.sqliteGateActive,
    required this.migrationCompletedAt,
    required this.runtimeJsonFallbackSizeBytes,
    required this.runtimeJsonCollectionsStripped,
    required this.tableRowCounts,
    required this.syncQueueReadyCount,
    required this.syncQueueRetryCount,
    required this.lastSyncSuccessAt,
    required this.lastPushSuccessAt,
    required this.lastPullSuccessAt,
    required this.nextAutoPullAllowed,
    required this.lastTriggerReason,
    required this.pullSkippedDueToThrottle,
    required this.queueCountBeforeTrigger,
    required this.lastSyncError,
    required this.syncCursors,
    required this.collectionSources,
    required this.writeFailures,
  });

  final String firebaseUid;
  final String databaseFileName;
  final String? databasePath;
  final bool sqliteGateActive;
  final String migrationCompletedAt;
  final int runtimeJsonFallbackSizeBytes;
  final bool runtimeJsonCollectionsStripped;
  final Map<String, int> tableRowCounts;
  final int syncQueueReadyCount;
  final int syncQueueRetryCount;
  final String lastSyncSuccessAt;
  final String lastPushSuccessAt;
  final String lastPullSuccessAt;
  final bool nextAutoPullAllowed;
  final String lastTriggerReason;
  final bool pullSkippedDueToThrottle;
  final int queueCountBeforeTrigger;
  final String lastSyncError;
  final Map<String, String> syncCursors;
  final Map<String, String> collectionSources;
  final List<String> writeFailures;
}
