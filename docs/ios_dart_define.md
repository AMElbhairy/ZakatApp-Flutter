Providing GOLD_API_KEY to iOS / Xcode

- Preferred (CLI):

  flutter run --dart-define=GOLD_API_KEY=your_api_key_here

- When running from Xcode (Debug scheme):

  1. Open Xcode and select the `Runner` scheme.
  2. Product → Scheme → Edit Scheme...
  3. Choose `Run` on the left, then the `Arguments` tab.
  4. Under "Arguments Passed On Launch" add a single argument:

     --dart-define=GOLD_API_KEY=your_api_key_here

  5. Close the dialog and run from Xcode. The app will receive the value via `String.fromEnvironment('GOLD_API_KEY')`.

Notes:
- The app logs whether the key is configured but never prints the key itself.
- For CI or release builds use `flutter build ios --dart-define=GOLD_API_KEY=...` or set your CI secrets accordingly.
