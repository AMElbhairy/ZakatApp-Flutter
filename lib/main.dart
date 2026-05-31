import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'repositories/app_state_repository.dart';
import 'screens/dashboard_screen.dart';
import 'services/app_state_controller.dart';
import 'services/local_storage_service.dart';

void main() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository =
      AppStateRepository(localStorage: localStorage);
  runApp(
    ChangeNotifierProvider<AppStateController>(
      create: (_) => AppStateController(repository: repository)..load(),
      child: const ZakatApp(),
    ),
  );
}

class ZakatApp extends StatelessWidget {
  const ZakatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZakatApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F766E),
      ),
      home: const DashboardScreen(),
    );
  }
}
