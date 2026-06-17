import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'app_state_controller.dart';

class ShareReceiverService {
  ShareReceiverService._();

  static StreamSubscription? _intentSub;

  static void init(AppStateController controller) {
    // Handle warm starts (app already running in background)
    try {
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> value) {
          for (final file in value) {
            // text sharing stores the text in path or message field depending on version
            final String sharedText = file.path;
            if (sharedText.trim().isNotEmpty) {
              controller.createPendingTransactionFromMessage(sharedText, 'share');
            }
          }
        },
        onError: (err) {
          // Silent catch in production
        },
      );
    } catch (_) {}

    // Handle cold starts (app was not running)
    try {
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
        for (final file in value) {
          final String sharedText = file.path;
          if (sharedText.trim().isNotEmpty) {
            controller.createPendingTransactionFromMessage(sharedText, 'share');
          }
        }
        ReceiveSharingIntent.instance.reset();
      }).catchError((_) {});
    } catch (_) {}
  }

  static void dispose() {
    _intentSub?.cancel();
  }
}
