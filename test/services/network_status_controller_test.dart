import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/services/network_status_controller.dart';

void main() {
  test(
    'network status toggles offline and online from probe results',
    () async {
      bool online = false;
      final NetworkStatusController controller = NetworkStatusController(
        connectivityProbe: () async => online,
        refreshInterval: const Duration(days: 1),
      );

      await controller.refresh();
      expect(controller.isOffline, isTrue);

      online = true;
      await controller.refresh();
      expect(controller.isOffline, isFalse);
    },
  );

  test('probe failures are treated as offline', () async {
    final NetworkStatusController controller = NetworkStatusController(
      connectivityProbe: () async => throw StateError('offline'),
      refreshInterval: const Duration(days: 1),
    );

    await controller.refresh();
    expect(controller.isOffline, isTrue);
  });
}
