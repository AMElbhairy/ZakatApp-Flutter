import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

void main() {
  testWidgets('app launches and shell tabs are visible',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository =
        AppStateRepository(localStorage: localStorage);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppStateController>(
        create: (_) => AppStateController(repository: repository),
        child: const ZakatApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    // Dashboard placeholder title is visible by default.
    expect(find.text('Dashboard'), findsWidgets);
  });
}
