import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/services/app_diagnostics.dart';
import 'package:zakatapp_flutter/services/sync_diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('sync diagnostics redacts secrets in stored logs', () async {
    await SyncDiagnosticsService.record(
      level: 'info',
      subsystem: 'sync',
      message: 'payload',
      metadata: <String, dynamic>{
        'apiKey': 'secret-value',
        'token': 'token-value',
        'assetType': 'gold',
      },
    );

    final List<SyncDiagnosticsLogEntry> logs =
        await SyncDiagnosticsService.readLogs();
    expect(logs, hasLength(1));
    expect(logs.first.metadata['apiKey'], '<redacted>');
    expect(logs.first.metadata['token'], '<redacted>');
    expect(logs.first.metadata['assetType'], 'gold');
  });

  test('debug diagnostics comparison detects savings mismatches', () {
    final Saving localGold = Saving(
      id: 'gold-1',
      assetType: 'gold',
      dateAcquired: '2026-06-01',
      amount: 10,
      remainingAmount: 4,
      unit: 'G',
      description: 'Gold savings',
      purchaseCurrency: 'EGP',
      purchaseAmount: 2500,
      createdAt: '2026-06-01T00:00:00Z',
      fundingAllocations: const <Map<String, dynamic>>[
        <String, dynamic>{'source': 'cash', 'amount': 2500},
      ],
    );
    final Saving firebaseGold = localGold.copyWith(
      amount: 11,
      remainingAmount: 5,
    );
    final Saving localSilver = Saving(
      id: 'silver-1',
      assetType: 'silver',
      dateAcquired: '2026-06-02',
      amount: 5,
      remainingAmount: 5,
      unit: 'G',
      description: 'Silver savings',
      purchaseCurrency: 'EGP',
      purchaseAmount: 1200,
      createdAt: '2026-06-02T00:00:00Z',
      fundingAllocations: const <Map<String, dynamic>>[],
    );

    final DebugDiagnosticsSavingsComparison comparison =
        DebugDiagnosticsSavingsComparison.compare(
          localSavings: <Saving>[localGold, localSilver],
          firebaseSavings: <Saving>[firebaseGold],
        );

    expect(comparison.missingFromFirebaseIds, <String>['silver-1']);
    expect(comparison.missingLocallyIds, isEmpty);
    expect(comparison.mismatches, hasLength(1));
    expect(
      comparison.mismatches.first.fieldMismatches.map(
        (DebugDiagnosticsSavingsFieldMismatch entry) => entry.field,
      ),
      containsAll(<String>['amount', 'remainingAmount']),
    );
  });

  test('clipboard report includes grouped sections', () {
    final DebugDiagnosticsReport report = _buildReport(
      firebaseComparisonLoaded: false,
    );

    final String text = formatDiagnosticsForClipboard(report);

    expect(text, contains('[App]'));
    expect(text, contains('[Auth]'));
    expect(text, contains('[Sync Health]'));
    expect(text, contains('[Pull Cursors]'));
    expect(text, isNot(contains('[Savings Summary]')));
    expect(text, isNot(contains('[Precious Metals Summary]')));
    expect(text, isNot(contains('[Local vs Firebase Mismatches]')));
    expect(text, contains('[Recent Sync Logs]'));
    expect(text, contains('[Market Data]'));
    expect(text, contains('GOLD_API_KEY configured'));
    expect(text, contains('Last push success at'));
    expect(text, contains('Next auto pull allowed'));
    expect(text, contains('savings_cursor: cursor'));
  });

  test('clipboard report includes savings comparison only when loaded', () {
    final DebugDiagnosticsReport report = _buildReport(
      firebaseComparisonLoaded: true,
    );

    final String text = formatDiagnosticsForClipboard(report);

    expect(text, contains('[Savings Summary]'));
    expect(text, contains('[Precious Metals Summary]'));
    expect(text, contains('[Local vs Firebase Mismatches]'));
    expect(text, contains('Firebase savings count'));
  });
}

DebugDiagnosticsReport _buildReport({required bool firebaseComparisonLoaded}) {
  return DebugDiagnosticsReport(
    generatedAtUtc: '2026-06-20T00:00:00Z',
    app: const DebugDiagnosticsAppInfo(
      version: '1.0.0',
      buildNumber: '1',
      platform: 'ios',
      device: 'iPhone',
      operatingSystemVersion: 'iOS 18',
      dartVersion: 'unknown',
    ),
    auth: const DebugDiagnosticsAuthInfo(
      state: 'signed-in',
      userId: 'uid-123',
      providerIds: <String>['password'],
      isSignedIn: true,
    ),
    firebase: const DebugDiagnosticsFirebaseInfo(
      projectId: 'project-id',
      appId: 'app-id',
      messagingSenderId: 'sender-id',
    ),
    storage: const DebugDiagnosticsStorageInfo(
      sqliteActive: true,
      databaseFileName: 'app.sqlite',
      databasePath: '/tmp/app.sqlite',
      syncEnabled: true,
      pendingSyncQueueCount: 2,
      syncQueueRetryCount: 1,
      lastSuccessfulSyncAt: '2026-06-19T00:00:00Z',
      lastFailedSyncAt: '',
      lastSyncError: '',
    ),
    syncPolicy: const DebugDiagnosticsSyncPolicy(
      lastPushSuccessAt: '2026-06-19T00:00:00Z',
      lastPullSuccessAt: '2026-06-19T01:00:00Z',
      nextAutoPullAllowed: true,
      lastTriggerReason: 'app_start',
      pullSkippedDueToThrottle: false,
      queueCountBeforeTrigger: 0,
    ),
    syncHealth: const DebugDiagnosticsSyncHealth(
      pendingWrites: 2,
      cursors: <String, String>{'savings_cursor': 'cursor'},
    ),
    savingsSummary: const DebugDiagnosticsSavingsSummary(
      localCount: 2,
      firebaseCount: 2,
      localIds: <String>['a', 'b'],
      firebaseIds: <String>['a', 'b'],
      localGoldCount: 1,
      firebaseGoldCount: 1,
      localSilverCount: 1,
      firebaseSilverCount: 1,
    ),
    preciousMetalsSummary: const DebugDiagnosticsSavingsSummary(
      localCount: 2,
      firebaseCount: 2,
      localIds: <String>['a', 'b'],
      firebaseIds: <String>['a', 'b'],
      localGoldCount: 1,
      firebaseGoldCount: 1,
      localSilverCount: 1,
      firebaseSilverCount: 1,
    ),
    comparison: const DebugDiagnosticsSavingsComparison(
      missingFromFirebaseIds: <String>['missing-remote'],
      missingLocallyIds: <String>['missing-local'],
      mismatches: <DebugDiagnosticsSavingsMismatch>[],
    ),
    marketData: const DebugDiagnosticsMarketData(
      status: 'cached',
      goldApiKeyConfigured: true,
      latestCachedGoldPrice: 123.45,
      latestCachedSilverPrice: 67.89,
      rawSnapshot: <String, dynamic>{},
    ),
    firebaseSavingsReadPath: 'users/uid-123/savings',
    firebaseSavingsWritePath: 'users/uid-123/savings',
    pullSyncSavingsPath: 'users/uid-123/savings',
    lastSavingsWritePath: 'users/uid-123/savings/gold-1',
    lastSavingsWritePayload: '{"id":"a"}',
    lastSavingsWriteSuccessDocumentId: 'gold-1',
    lastSavingsWriteError: '',
    recentSavingsPayloadJson: '{"id":"a"}',
    recentSavingsResponse: 'success',
    recentSavingsError: '',
    recentSyncLogs: const <SyncDiagnosticsLogEntry>[
      SyncDiagnosticsLogEntry(
        timestamp: '2026-06-20T00:00:00Z',
        level: 'info',
        subsystem: 'sync',
        message: 'Queue push success',
        metadata: <String, dynamic>{},
      ),
    ],
    collectionSources: <String, String>{'savings': 'sqlite'},
    writeFailures: const <String>[],
    savingsCursorValue: 'cursor',
    deletedSavingsCursorValue: 'deleted-cursor',
    localCountGreaterThanFirebaseCount: false,
    autoRepairRecommended: false,
    firebaseSavingsComparisonLoaded: firebaseComparisonLoaded,
  );
}
