import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'repositories/app_state_repository.dart';
import 'screens/app_shell.dart';
import 'services/app_state_controller.dart';
import 'services/local_storage_service.dart';

void main() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository =
      AppStateRepository(localStorage: localStorage);
  runApp(
    ChangeNotifierProvider<AppStateController>(
      create: (_) => AppStateController(repository: repository),
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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _AppBootstrapper(),
    );
  }
}

class _AppBootstrapper extends StatefulWidget {
  const _AppBootstrapper();

  @override
  State<_AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<_AppBootstrapper> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = context.read<AppStateController>().load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
              ),
            ),
          );
        }
        return const AppShell();
      },
    );
  }
}
