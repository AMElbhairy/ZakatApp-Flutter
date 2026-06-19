import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../services/auth_controller.dart';
import 'auth_brand_ui.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _createAccountMode = false;
  bool _passwordObscured = true;
  bool _confirmPasswordObscured = true;
  String? _validationMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color secondaryTextColor = dark
        ? tokens.colors.textSecondary
        : tokens.colors.hero;
    final auth = context.watch<AuthController>();
    final AppLocalizations l10n = context.l10n;
    final bool isLoading = auth.isLoading;

    return AuthBrandShell(
      tone: AuthBackdropTone.hero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AuthBrandHeader(
                    title: l10n.tr('brand_title'),
                    subtitle: l10n.tr('brand_tagline'),
                    logoSize: 84,
                    framedLogo: false,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.tr('brand_trust_message'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: secondaryTextColor,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AuthBrandBodyCard(
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            _createAccountMode
                                ? l10n.tr('create_account_title')
                                : l10n.tr('login_intro'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: tokens.colors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (_createAccountMode) ...<Widget>[
                            TextField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l10n.tr('full_name'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          TextField(
                            key: const Key('emailField'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: l10n.tr('email_address'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            key: const Key('passwordField'),
                            controller: _passwordController,
                            obscureText: _passwordObscured,
                            textInputAction: _createAccountMode
                                ? TextInputAction.next
                                : TextInputAction.done,
                            autofillHints: <String>[
                              _createAccountMode
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.tr('password'),
                              helperText: _createAccountMode
                                  ? l10n.tr('password_requirements')
                                  : null,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _passwordObscured = !_passwordObscured;
                                  });
                                },
                                icon: Icon(
                                  _passwordObscured
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (_createAccountMode) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              key: const Key('confirmPasswordField'),
                              controller: _confirmPasswordController,
                              obscureText: _confirmPasswordObscured,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: l10n.tr('confirm_password'),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _confirmPasswordObscured =
                                          !_confirmPasswordObscured;
                                    });
                                  },
                                  icon: Icon(
                                    _confirmPasswordObscured
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          AuthBrandPrimaryButton(
                            key: const Key('emailAuthButton'),
                            label: _createAccountMode
                                ? l10n.tr('create_account')
                                : l10n.tr('sign_in_with_email'),
                            isLoading: isLoading,
                            leading: const Icon(Icons.mail_outline_rounded),
                            onPressed: () => _submitEmailAuth(context),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (!_createAccountMode)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => _sendResetEmail(context),
                                child: Text(l10n.tr('forgot_password')),
                              ),
                            ),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _createAccountMode =
                                            !_createAccountMode;
                                        _validationMessage = null;
                                      });
                                    },
                              child: Text(
                                _createAccountMode
                                    ? l10n.tr('already_have_account')
                                    : l10n.tr('need_account'),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Divider(
                                  color: secondaryTextColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                child: Text(
                                  l10n.tr('or_continue_with'),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: secondaryTextColor),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: secondaryTextColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AuthBrandSecondaryButton(
                            key: const Key('googleSignInButton'),
                            label: l10n.tr('continue_with_google'),
                            leading: const _GoogleBrandMark(),
                            foregroundColor: tokens.colors.textPrimary,
                            onPressed: isLoading
                                ? null
                                : () => context.read<AuthController>().signIn(
                                    provider: AuthProvider.google,
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.tr('login_note'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: secondaryTextColor,
                                  height: 1.4,
                                ),
                          ),
                          if (_validationMessage != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _validationMessage!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: tokens.colors.danger),
                            ),
                          ],
                          if (auth.error != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              auth.error!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: tokens.colors.danger),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitEmailAuth(BuildContext context) async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String name = _nameController.text.trim();
    final String? validationError = _validateInputs(
      email: email,
      password: password,
      name: name,
      confirmPassword: _confirmPasswordController.text,
      l10n: context.l10n,
    );
    setState(() => _validationMessage = validationError);
    if (validationError != null) return;
    final AuthController authController = context.read<AuthController>();
    if (_createAccountMode) {
      await authController.createAccountWithEmail(
        email: email,
        password: password,
        displayName: name,
      );
      if (!context.mounted) return;
      final AuthController auth = context.read<AuthController>();
      if (auth.error == null) {
        final bool shouldSave = await authController.shouldPromptToSaveCredentials(
          email,
        );
        TextInput.finishAutofillContext(shouldSave: shouldSave);
        if (shouldSave) {
          await authController.markCredentialsSavePrompted(email);
        }
        if (!context.mounted) return;
        showTopSnackBar(
          context,
          context.l10n.tr('signup_verification_sent'),
          kind: AppToastKind.success,
        );
      }
      return;
    }
    await authController.signInWithEmail(
      email: email,
      password: password,
    );
    if (!context.mounted) return;
    if (authController.error == null) {
      final bool shouldSave = await authController.shouldPromptToSaveCredentials(
        email,
      );
      TextInput.finishAutofillContext(shouldSave: shouldSave);
      if (shouldSave) {
        await authController.markCredentialsSavePrompted(email);
      }
    }
  }

  Future<void> _sendResetEmail(BuildContext context) async {
    final String email = _emailController.text.trim();
    if (email.isEmpty) {
      showTopSnackBar(
        context,
        context.l10n.tr('enter_email_for_reset'),
        kind: AppToastKind.warning,
      );
      return;
    }
    try {
      await context.read<AuthController>().sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      showTopSnackBar(
        context,
        context.l10n.tr('password_reset_sent'),
        kind: AppToastKind.success,
      );
    } catch (_) {}
  }

  String? _validateInputs({
    required String email,
    required String password,
    required String name,
    required String confirmPassword,
    required AppLocalizations l10n,
  }) {
    if (email.isEmpty) return l10n.tr('email_required');
    if (!email.contains('@') || !email.contains('.')) {
      return l10n.tr('email_invalid');
    }
    if (password.isEmpty) return l10n.tr('password_required');
    if (_createAccountMode) {
      if (name.isEmpty) return l10n.tr('full_name_required');
      if (password.length < 8) return l10n.tr('password_too_short');
      if (confirmPassword.trim().isEmpty) {
        return l10n.tr('confirm_password_required');
      }
      if (password != confirmPassword.trim()) {
        return l10n.tr('passwords_do_not_match');
      }
    }
    return null;
  }
}

class _GoogleBrandMark extends StatelessWidget {
  const _GoogleBrandMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google-logo.png',
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox(width: 20, height: 20),
    );
  }
}
