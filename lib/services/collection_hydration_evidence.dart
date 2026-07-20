enum CollectionLoadStatus {
  notStarted,
  loading,
  loadedAuthoritative,
  legitimateEmpty,
  missingForNewProfile,
  fallbackDefault,
  partial,
  failed,
  identityMismatch,
  schemaMismatch,
  migrationIncomplete,
}

class CollectionHydrationEvidence {
  const CollectionHydrationEvidence({
    required this.collectionId,
    required this.status,
    required this.loadedCount,
    required this.storageCount,
    required this.source,
    required this.userIdHash,
    required this.profileIdHash,
    required this.databaseIdHash,
    required this.loadCompleted,
    required this.validationPassed,
    required this.failureCode,
  });

  final String collectionId;
  final CollectionLoadStatus status;
  final int loadedCount;
  final int? storageCount;
  final String source;
  final String userIdHash;
  final String profileIdHash;
  final String databaseIdHash;
  final bool loadCompleted;
  final bool validationPassed;
  final String? failureCode;

  bool get isAuthoritative =>
      status == CollectionLoadStatus.loadedAuthoritative ||
      status == CollectionLoadStatus.legitimateEmpty ||
      status == CollectionLoadStatus.missingForNewProfile;
}

enum AppHydrationPhase {
  notStarted,
  hydrating,
  validating,
  ready,
  failed,
}
