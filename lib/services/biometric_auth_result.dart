enum BiometricAuthResult {
  success,
  cancelled,
  systemCancelled,
  timedOut,
  authInProgress,
  failed,
  unavailable,
  temporarilyUnavailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  error,
}

enum BiometricAuthPurpose {
  appUnlock,
  sensitiveAction,
}
