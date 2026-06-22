import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_ui.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/theme/app_radii.dart';
import '../../services/app_state_controller.dart';
import '../../models/pending_transaction.dart';

class AddSmartCaptureMessageScreen extends StatefulWidget {
  const AddSmartCaptureMessageScreen({super.key});

  @override
  State<AddSmartCaptureMessageScreen> createState() =>
      _AddSmartCaptureMessageScreenState();
}

class _AddSmartCaptureMessageScreenState
    extends State<AddSmartCaptureMessageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = context.read<AppStateController>();
    final String rawMessage = _messageController.text;

    try {
      await controller.createPendingTransactionFromMessage(
        rawMessage,
        PendingTransactionSource.manual,
      );

      if (mounted) {
        showTopSnackBar(
          context,
          'Message parsed successfully into Pending Transactions',
          kind: AppToastKind.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          'Error: ${e.toString()}',
          kind: AppToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(title: const Text('Smart Capture Paste')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste Bank Message',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste the notification SMS, email content, or raw bank details text. The system will automatically parse type, amount, and currency for review.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _messageController,
                  maxLines: 8,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText:
                        'Paste bank message here...\ne.g. Salary of SAR 8000 deposited',
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadii.card,
                      borderSide: BorderSide(color: tokens.colors.gold),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please paste a bank message to parse';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: tokens.colors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: tokens.colors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.colors.gold,
                          foregroundColor: tokens.colors.hero,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _submit,
                        child: const Text(
                          'Create Pending',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
