import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/screens/account/diagnostics_screen.dart';
import 'package:zakatapp_flutter/services/app_diagnostics.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/sync_diagnostics_service.dart';

class _DiagnosticsController extends AppStateController {
  _DiagnosticsController({required super.repository})
    : super(enableBackgroundSync: false, enableMarketAutoRefresh: false);

  int collectDiagnosticsCalls = 0;
  int collectDebugDiagnosticsCalls = 0;

  @override
  Future<AppDiagnosticsSnapshot> collectDiagnostics() async {
    collectDiagnosticsCalls += 1;
    return _buildSnapshot();
  }

  @override
  Future<DebugDiagnosticsReport> collectDebugDiagnostics({
    bool includeFirebaseSavingsComparison = false,
  }) async {
    collectDebugDiagnosticsCalls += 1;
    return _buildReport(includeFirebaseSavingsComparison);
  }

  AppDiagnosticsSnapshot _buildSnapshot() {
    return AppDiagnosticsSnapshot(
      firebaseUid: 'user-1',
      databaseFileName: 'app.sqlite',
      databasePath: '/tmp/app.sqlite',
      sqliteGateActive: true,
      migrationCompletedAt: '2026-06-20T00:00:00Z',
      runtimeJsonFallbackSizeBytes: 0,
      runtimeJsonCollectionsStripped: false,
      tableRowCounts: <String, int>{'sync_queue': 3},
      syncQueueReadyCount: 2,
      syncQueueRetryCount: 1,
      lastSyncSuccessAt: '2026-06-20T01:00:00Z',
      lastPushSuccessAt: '2026-06-20T01:05:00Z',
      lastPullSuccessAt: '2026-06-20T01:06:00Z',
      nextAutoPullAllowed: false,
      lastTriggerReason: 'app_start',
      pullSkippedDueToThrottle: true,
      queueCountBeforeTrigger: 3,
      lastSyncError: 'offline',
      syncCursors: <String, String>{'savings_cursor': '2026-06-20T00:00:00Z'},
      collectionSources: <String, String>{'savings': 'sqlite'},
      writeFailures: const <String>[],
    );
  }

  DebugDiagnosticsReport _buildReport(bool includeFirebaseSavingsComparison) {
    final DebugDiagnosticsSavingsComparison comparison =
        includeFirebaseSavingsComparison
        ? const DebugDiagnosticsSavingsComparison(
            missingFromFirebaseIds: <String>['missing-remote'],
            missingLocallyIds: <String>['missing-local'],
            mismatches: <DebugDiagnosticsSavingsMismatch>[],
          )
        : const DebugDiagnosticsSavingsComparison(
            missingFromFirebaseIds: <String>[],
            missingLocallyIds: <String>[],
            mismatches: <DebugDiagnosticsSavingsMismatch>[],
          );

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
        userId: 'user-1',
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
        pendingSyncQueueCount: 3,
        syncQueueRetryCount: 1,
        lastSuccessfulSyncAt: '2026-06-20T01:00:00Z',
        lastFailedSyncAt: '',
        lastSyncError: '',
      ),
      syncPolicy: const DebugDiagnosticsSyncPolicy(
        lastPushSuccessAt: '2026-06-20T01:05:00Z',
        lastPullSuccessAt: '2026-06-20T01:06:00Z',
        nextAutoPullAllowed: false,
        lastTriggerReason: 'app_start',
        pullSkippedDueToThrottle: true,
        queueCountBeforeTrigger: 3,
      ),
      syncHealth: const DebugDiagnosticsSyncHealth(
        pendingWrites: 1,
        cursors: <String, String>{'savings_cursor': '2026-06-20T00:00:00Z'},
      ),
      savingsSummary: const DebugDiagnosticsSavingsSummary(
        localCount: 1,
        firebaseCount: 1,
        localIds: <String>['local-1'],
        firebaseIds: <String>['firebase-1'],
        localGoldCount: 1,
        firebaseGoldCount: 1,
        localSilverCount: 0,
        firebaseSilverCount: 0,
      ),
      preciousMetalsSummary: const DebugDiagnosticsSavingsSummary(
        localCount: 1,
        firebaseCount: 1,
        localIds: <String>['local-1'],
        firebaseIds: <String>['firebase-1'],
        localGoldCount: 1,
        firebaseGoldCount: 1,
        localSilverCount: 0,
        firebaseSilverCount: 0,
      ),
      comparison: comparison,
      marketData: const DebugDiagnosticsMarketData(
        status: 'cached',
        goldApiKeyConfigured: false,
        latestCachedGoldPrice: null,
        latestCachedSilverPrice: null,
        rawSnapshot: <String, dynamic>{},
      ),
      firebaseSavingsReadPath: 'users/user-1/savings',
      firebaseSavingsWritePath: 'users/user-1/savings',
      pullSyncSavingsPath: 'users/user-1/savings',
      lastSavingsWritePath: '',
      lastSavingsWritePayload: '',
      lastSavingsWriteSuccessDocumentId: '',
      lastSavingsWriteError: '',
      recentSavingsPayloadJson: '',
      recentSavingsResponse: '',
      recentSavingsError: '',
      recentSyncLogs: const <SyncDiagnosticsLogEntry>[],
      collectionSources: <String, String>{'savings': 'sqlite'},
      writeFailures: const <String>[],
      savingsCursorValue: '2026-06-20T00:00:00Z',
      deletedSavingsCursorValue: '2026-06-20T00:00:00Z',
      localCountGreaterThanFirebaseCount: false,
      autoRepairRecommended: false,
      firebaseSavingsComparisonLoaded: includeFirebaseSavingsComparison,
    );
  }
}

Widget _buildApp({
  bool enableDeveloperDiagnostics = false,
  bool enableDeepDiagnostics = false,
}) {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  return MaterialApp(
    home: ChangeNotifierProvider<AppStateController>(
      create: (_) => _DiagnosticsController(repository: repository),
      child: DiagnosticsScreen(
        enableDeveloperDiagnostics: enableDeveloperDiagnostics,
        enableDeepDiagnostics: enableDeepDiagnostics,
      ),
    ),
  );
}

void main() {
  testWidgets('default diagnostics screen stays lightweight', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final _DiagnosticsController controller = _DiagnosticsController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppStateController>.value(
          value: controller,
          child: const DiagnosticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.collectDiagnosticsCalls, 1);
    expect(controller.collectDebugDiagnosticsCalls, 0);
    expect(find.text('Sync Status'), findsNWidgets(2));
    expect(find.text('Pending sync queue count'), findsOneWidget);
    expect(find.text('Last push success'), findsOneWidget);
    expect(find.text('Last pull success'), findsOneWidget);
    expect(find.text('Next auto pull allowed'), findsOneWidget);
    expect(find.text('Last sync error'), findsOneWidget);
    expect(find.text('Compare Local vs Firebase'), findsNothing);
    expect(find.text('Copy Diagnostics'), findsNothing);
  });

  testWidgets('deep diagnostics remains opt-in', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final _DiagnosticsController controller = _DiagnosticsController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppStateController>.value(
          value: controller,
          child: const DiagnosticsScreen(
            enableDeveloperDiagnostics: true,
            enableDeepDiagnostics: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.collectDebugDiagnosticsCalls, 1);
    expect(find.text('Developer Diagnostics'), findsOneWidget);
    expect(find.text('Compare Local vs Firebase'), findsOneWidget);
    expect(find.text('Copy Diagnostics'), findsOneWidget);
  });
}
