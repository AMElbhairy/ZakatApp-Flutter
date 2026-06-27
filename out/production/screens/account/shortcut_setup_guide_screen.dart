import 'package:flutter/material.dart';

class ShortcutSetupGuideScreen extends StatelessWidget {
  const ShortcutSetupGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apple Shortcuts Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          Text(
            'Automate Bank Messages',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.0),
          _Step(number: 1, action: 'Open:', detail: 'Shortcuts'),
          _Step(number: 2, action: 'Create:', detail: 'Automation'),
          _Step(number: 3, action: 'Choose:', detail: 'Message Received'),
          _Step(number: 4, action: 'Add Action:', detail: 'Zakah Wealth'),
          _Step(number: 5, action: 'Select:', detail: 'Log Bank Message'),
          _Step(number: 6, action: 'Pass:', detail: 'Message Content'),
          _Step(number: 7, action: 'Enable:', detail: 'Run Immediately'),
          _Step(number: 8, action: 'Disable:', detail: 'Notify When Run'),
          SizedBox(height: 32.0),
          Text(
            'Automation Examples',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.0),
          Text('Saudi Banks\nSender: Al Rajhi, SNB, Alinma, Riyad Bank, SAB', style: TextStyle(fontWeight: FontWeight.w600)),
          Text('Action: Zakah Wealth → Log Bank Message'),
          SizedBox(height: 16.0),
          Text('Egyptian Banks\nSender: Bank Misr, CIB, QNB, Banque du Caire, NBE', style: TextStyle(fontWeight: FontWeight.w600)),
          Text('Action: Zakah Wealth → Log Bank Message'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String action;
  final String detail;

  const _Step({required this.number, required this.action, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            child: Text(number.toString(), style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
