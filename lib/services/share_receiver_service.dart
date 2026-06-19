import 'dart:async';
class ShareReceiverService {
  ShareReceiverService._();

  static StreamSubscription? _intentSub;

  static void init() {
    // Sharing intent support is disabled in this build. Keep the entry point
    // so callers do not need to change, but do not register any listeners.
    _intentSub?.cancel();
    _intentSub = null;
  }

  static void dispose() {
    _intentSub?.cancel();
    _intentSub = null;
  }
}
