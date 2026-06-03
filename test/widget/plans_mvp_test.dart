import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<bool> ensureSession() async => true;
  @override
  Future<UserProfile?> restoreSession() async => null;
  @override
  Future<UserProfile?> signIn() async => null;
  @override
  Future<void> signOut() async {}
}

Widget _buildApp() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository =
      AppStateRepository(localStorage: localStorage);
  return MultiProvider(
    providers: <ChangeNotifierProvider<dynamic>>[
      ChangeNotifierProvider<AppStateController>(
        create: (_) => AppStateController(repository: repository),
      ),
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          authService: _FakeAuthService(),
          localStorage: localStorage,
        ),
      ),
    ],
    child: const ZakatApp(),
  );
}

Future<void> _openPlans(WidgetTester tester) async {
  await tester.tap(find.text('Plans').first);
  await tester.pumpAndSettle();
}

Future<void> _addPlan(WidgetTester tester,
    {required String name, required String monthlySaving}) async {
  await _openPlans(tester);
  await tester.tap(find.byKey(const Key('addPlanButton')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('planNameField')), name);
  await tester.enterText(
      find.byKey(const Key('planMonthlySavingField')), monthlySaving);
  await tester.enterText(find.byKey(const Key('planDurationYearsField')), '2');

  await tester.ensureVisible(find.byKey(const Key('savePlanButton')));
  await tester.tap(find.byKey(const Key('savePlanButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add plan', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addPlan(tester, name: 'Family Plan', monthlySaving: '1500');

    expect(find.text('Family Plan'), findsOneWidget);
    expect(find.textContaining('Monthly saving: 1500.00'), findsOneWidget);
  });

  testWidgets('edit plan', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addPlan(tester, name: 'Edit Plan', monthlySaving: '500');

    await tester.tap(find.text('Edit Plan'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('planMonthlySavingField')), '900');
    await tester.ensureVisible(find.byKey(const Key('savePlanButton')));
    await tester.tap(find.byKey(const Key('savePlanButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Monthly saving: 900.00'), findsOneWidget);
  });

  testWidgets('delete plan', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addPlan(tester, name: 'Delete Plan', monthlySaving: '300');

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plansEmptyState')), findsOneWidget);
  });

  testWidgets('plans screen updates and persistence survives reload',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _addPlan(tester, name: 'Persist Plan', monthlySaving: '2000');

    expect(find.text('Persist Plan'), findsOneWidget);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await _openPlans(tester);
    expect(find.text('Persist Plan'), findsOneWidget);
  });
}
