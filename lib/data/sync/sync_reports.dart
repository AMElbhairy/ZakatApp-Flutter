class FirestoreAuthValidationResult {
  const FirestoreAuthValidationResult({
    required this.expectedUid,
    required this.currentUid,
    required this.isSignedIn,
    required this.isUidMatch,
    required this.tokenRefreshed,
    required this.isValid,
    this.errorCode,
    this.errorMessage,
  });

  final String expectedUid;
  final String? currentUid;
  final bool isSignedIn;
  final bool isUidMatch;
  final bool tokenRefreshed;
  final bool isValid;
  final String? errorCode;
  final String? errorMessage;
}

class PullCollectionResult {
  const PullCollectionResult({
    required this.collection,
    required this.path,
    required this.upsertsApplied,
    required this.deletesApplied,
    required this.cursorUpdates,
  });

  final String collection;
  final String path;
  final int upsertsApplied;
  final int deletesApplied;
  final int cursorUpdates;
}

class PullSyncResult {
  const PullSyncResult({
    required this.uid,
    required this.firestoreUserPath,
    required this.collections,
    required this.success,
    this.errorCode,
    this.errorMessage,
  });

  final String uid;
  final String firestoreUserPath;
  final List<PullCollectionResult> collections;
  final bool success;
  final String? errorCode;
  final String? errorMessage;

  int get collectionsQueried => collections.length;
  int get docsApplied =>
      collections.fold<int>(0, (int sum, PullCollectionResult item) {
        return sum + item.upsertsApplied;
      });
  int get deletedDocsApplied =>
      collections.fold<int>(0, (int sum, PullCollectionResult item) {
        return sum + item.deletesApplied;
      });
  int get cursorUpdates =>
      collections.fold<int>(0, (int sum, PullCollectionResult item) {
        return sum + item.cursorUpdates;
      });
}

class ManualSyncResult {
  const ManualSyncResult({
    required this.success,
    required this.message,
    required this.reason,
    required this.expectedUid,
    required this.firebaseUid,
    required this.databaseFileName,
    required this.databasePath,
    required this.firestorePushPath,
    required this.firestorePullPath,
    required this.authValid,
    required this.pushAttempted,
    required this.pullAttempted,
    required this.queueCountBefore,
    required this.queueCountAfter,
    required this.rowsPushed,
    required this.rowsFailed,
    required this.pullCollectionsQueried,
    required this.pullDocsApplied,
    required this.pullDeletedDocsApplied,
    required this.cursorUpdates,
    this.failureCode,
    this.failureMessage,
    this.alreadySynced = false,
  });

  final bool success;
  final String message;
  final String reason;
  final String expectedUid;
  final String? firebaseUid;
  final String databaseFileName;
  final String? databasePath;
  final String firestorePushPath;
  final String firestorePullPath;
  final bool authValid;
  final bool pushAttempted;
  final bool pullAttempted;
  final int queueCountBefore;
  final int queueCountAfter;
  final int rowsPushed;
  final int rowsFailed;
  final int pullCollectionsQueried;
  final int pullDocsApplied;
  final int pullDeletedDocsApplied;
  final int cursorUpdates;
  final String? failureCode;
  final String? failureMessage;
  final bool alreadySynced;
}
