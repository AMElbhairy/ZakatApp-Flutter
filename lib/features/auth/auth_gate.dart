import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../screens/app_shell.dart';
import '../../services/auth_controller.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    if (auth.currentUser == null) {
      return LoginPage(showLegacyAuthUi: kDebugMode);
    }
    return const AppShell();
  }
}
