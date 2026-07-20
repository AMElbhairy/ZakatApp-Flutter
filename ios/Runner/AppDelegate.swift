import UIKit
#if canImport(Flutter)
import Flutter
#endif
import AuthenticationServices
import UserNotifications
import WidgetKit

#if canImport(Flutter)
import Flutter
typealias BaseFlutterAppDelegate = FlutterAppDelegate
#else
class BaseFlutterAppDelegate: UIResponder, UIApplicationDelegate {}
protocol FlutterImplicitEngineDelegate {}
#endif

@main
@objc class AppDelegate: BaseFlutterAppDelegate, FlutterImplicitEngineDelegate {
#if canImport(Flutter)
  private var smartCaptureChannel: FlutterMethodChannel?
  private var shortcutBridgeChannel: FlutterMethodChannel?
  private var appleSignInChannel: FlutterMethodChannel?
  private var widgetRefreshChannel: FlutterMethodChannel?
#endif
  private var shortcutBridgeRegistrationAttempts = 0
  private var appleSignInRegistrationAttempts = 0
  private let appleSignInCoordinator = AppleSignInCoordinator()

  private static let shortcutQueueStorageKey = "com.zakahwealth.smartcapture.pendingShortcutMessages"
  private static let shortcutQueueSuiteName = "group.com.zakahwealth.app"
  private static let notificationLaunchStorageKey = "com.zakahwealth.smartcapture.pendingNotificationLaunches"
  private static let recentShortcutCaptureStorageKey = "com.zakahwealth.smartcapture.recentShortcutCaptures"
  private static let smartCaptureStateKey = "zakah_wealth_smart_capture_state_v1"
  private static let shortcutQueueLock = NSLock()
  private static let notificationLaunchLock = NSLock()
  private static let recentShortcutCaptureLock = NSLock()
  private static var pendingShortcutMessages: [[String: Any]] = []
  private static var pendingNotificationLaunches: [[String: Any]] = []
  private static var recentShortcutCaptures: [[String: Any]] = []
  private static var shortcutQueueLoaded = false
  private static var notificationLaunchQueueLoaded = false
  private static var recentShortcutCaptureQueueLoaded = false
  private static var flutterShortcutServiceReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinishLaunching = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

#if canImport(Flutter)
    configureSmartCaptureChannel()
    configureShortcutBridgeChannel()
    configureAppleSignInChannel()
    configureWidgetRefreshChannel()
#endif
    UNUserNotificationCenter.current().delegate = self
    requestNotificationAuthorizationIfNeeded()
#if canImport(Flutter)
    scheduleShortcutBridgeRegistrationRetry()
    scheduleAppleSignInRegistrationRetry()
#endif

    return didFinishLaunching
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
#if canImport(Flutter)
    configureSmartCaptureChannel()
    configureShortcutBridgeChannel()
    configureAppleSignInChannel()
    configureWidgetRefreshChannel()
#endif
    UNUserNotificationCenter.current().delegate = self
    requestNotificationAuthorizationIfNeeded()
#if canImport(Flutter)
    scheduleShortcutBridgeRegistrationRetry()
    scheduleAppleSignInRegistrationRetry()
#endif
  }

#if canImport(Flutter)
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
#endif

  static func enqueueShortcutMessage(_ messageText: String) async -> Bool {
    let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 10_000 else {
      NSLog("[Shortcut] Payload rejected")
      return false
    }

    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    let flutterReady = flutterShortcutServiceReady && appDelegate?.smartCaptureChannel != nil
    let appState = UIApplication.shared.applicationState
    let shouldShowNativeNotification = appState != .active || !flutterReady
    let preview = nativeShortcutPreview(from: trimmed)
    let nativeNotificationShown = shouldShowNativeNotification
      ? await sendNativeShortcutNotification(preview: preview)
      : false

    let payload: [String: Any] = [
      "messageContent": trimmed,
      "source": "shortcut",
      "sourceIdentifier": "Apple Automation",
      "notificationAlreadyShown": nativeNotificationShown ? "true" : "false",
    ]

    shortcutQueueLock.lock()
    defer { shortcutQueueLock.unlock() }

    loadShortcutQueueLocked()
    pendingShortcutMessages.append(payload)
    saveShortcutQueueLocked()

    NSLog("[Shortcut] Payload queued")
    NSLog("[Shortcut] Queue size: \(pendingShortcutMessages.count)")

    DispatchQueue.main.async {
      AppDelegate.sharedDeliverQueuedShortcutMessagesIfPossible()
    }
    return true
  }

  private struct NativeShortcutPreview {
    let statusLabel: String
    let merchant: String?
    let amount: String?
    let currency: String?
    let languageCode: String
  }

  private struct NativeSmartCaptureStateSnapshot {
    let smartCaptureAutoApproveEnabled: Bool
    let languagePreference: String
    let merchantAliases: [String: String]
    let merchantRules: [String: [String: Any]]
  }

  private struct NativeShortcutCaptureHistoryEntry {
    let signature: String
    let capturedAt: TimeInterval
  }

  private static func sharedDeliverQueuedShortcutMessagesIfPossible() {
    guard flutterShortcutServiceReady,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }
    appDelegate.deliverQueuedShortcutMessagesIfPossible()
  }

  private static func sendNativeShortcutNotification(
    preview: NativeShortcutPreview
  ) async -> Bool {
    let center = UNUserNotificationCenter.current()
    let settings = await withCheckedContinuation { continuation in
      center.getNotificationSettings { settings in
        continuation.resume(returning: settings)
      }
    }

    guard settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional else {
      NSLog("[Shortcut] Notification permission not granted, skipping native notification")
      return false
    }

    let content = UNMutableNotificationContent()
    let statusLabel = preview.statusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    let isArabic = preview.languageCode.lowercased().hasPrefix("ar")
    let merchant = preview.merchant?.trimmingCharacters(in: .whitespacesAndNewlines)
    let amount = preview.amount?.trimmingCharacters(in: .whitespacesAndNewlines)
    let currency = preview.currency?.trimmingCharacters(in: .whitespacesAndNewlines)
    let formattedAmount = [amount, currency]
      .compactMap { value -> String? in
        guard let value, !value.isEmpty else { return nil }
        return value
      }
      .joined(separator: " ")

    if statusLabel.isEmpty {
      content.title = nativeShortcutLocalizedLabel(
        english: "Smart Capture",
        arabic: "التقاط ذكي",
        isArabic: isArabic
      )
    } else {
      content.title = statusLabel
    }
    var bodyLines: [String] = []
    if let merchant, !merchant.isEmpty {
      bodyLines.append(merchant)
    }
    if !formattedAmount.isEmpty {
      bodyLines.append(formattedAmount)
    }
    if bodyLines.isEmpty {
      content.body = nativeShortcutLocalizedLabel(
        english: "New transaction captured",
        arabic: "تم التقاط عملية جديدة",
        isArabic: isArabic
      )
    } else {
      let body = bodyLines.joined(separator: "\n")
      content.body = body
    }
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: "native_shortcut_capture_\(UUID().uuidString)",
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
    )

    let success = await withCheckedContinuation { continuation in
      center.add(request) { error in
        if let error = error {
          NSLog("[Shortcut] Failed to add notification: \(error)")
          continuation.resume(returning: false)
        } else {
          NSLog("[Shortcut] Native notification posted successfully")
          continuation.resume(returning: true)
        }
      }
    }
    return success
  }

  private static func nativeShortcutPreview(from messageText: String) -> NativeShortcutPreview {
    let state = nativeShortcutSmartCaptureStateSnapshot()
    let languageCode = state?.languagePreference ?? "en"
    let signature = nativeShortcutCaptureSignature(from: messageText)
    let isDuplicate = nativeShortcutWasRecentlyCaptured(signature: signature)
    return NativeShortcutPreview(
      statusLabel: nativeShortcutStatusLabel(
        from: messageText,
        languageCode: languageCode,
        isDuplicate: isDuplicate
      ),
      merchant: nativeShortcutMerchant(from: messageText),
      amount: nativeShortcutAmount(from: messageText),
      currency: nativeShortcutCurrency(from: messageText),
      languageCode: languageCode
    )
  }

  private static func nativeShortcutStatusLabel(
    from messageText: String,
    languageCode: String,
    isDuplicate: Bool
  ) -> String {
    let normalized = messageText.replacingOccurrences(of: "\r", with: "\n")
    let lowered = normalized.lowercased()
    let isArabic = languageCode.lowercased().hasPrefix("ar")

    if isDuplicate {
      return nativeShortcutLocalizedLabel(
        english: "Rejected",
        arabic: "مرفوض",
        isArabic: isArabic
      )
    }

    if nativeShortcutContainsOtpIndicators(lowered) {
      return nativeShortcutLocalizedLabel(
        english: "Rejected",
        arabic: "مرفوض",
        isArabic: isArabic
      )
    }

    if nativeShortcutContainsAny(lowered, [
      "declined",
      "decline",
      "rejected",
      "reject",
      "failed",
      "failure",
      "unsuccessful",
      "not approved",
      "not authorized",
      "not authorised",
      "authorization failed",
      "authorisation failed",
      "authorization declined",
      "authorisation declined",
      "authorization rejected",
      "authorisation rejected",
      "payment declined",
      "transaction declined",
      "card declined",
      "unable to process",
      "unable to complete",
      "could not be completed",
      "cannot be completed",
      "could not process",
      "not completed",
      "failed to process",
      "cancelled",
      "canceled",
      "timeout",
      "expired",
      "blocked",
      "insufficient funds",
      "otp",
      "one time password",
      "one-time password",
      "verification code",
      "confirmation code",
      "رمز التحقق",
      "كود التحقق",
      "رمز لمرة واحدة",
      "الرمز لمرة واحدة",
      "كلمة مرور لمرة واحدة",
      "رمز الاستخدام لمرة واحدة",
      "مرفوضة",
      "مرفوض",
      "رفض",
      "تم الرفض",
      "عملية مرفوضة",
      "تم رفض العملية",
      "فشلت",
      "فشل",
      "فشل الدفع",
      "فشل العملية",
      "غير ناجحة",
      "تم الإلغاء",
      "ألغيت",
      "الرصيد غير كاف",
      "غير مصرح",
      "غير مصرح به",
      "تعذر",
      "تعذرت",
      "لم تتم الموافقة",
      "لم يتم الموافقة",
      "لم يتم إتمام العملية",
    ]) {
      return nativeShortcutLocalizedLabel(
        english: "Rejected",
        arabic: "مرفوض",
        isArabic: isArabic
      )
    }

    if nativeShortcutContainsAny(lowered, [
      "pending for approval",
      "pending approval",
      "pending review",
      "awaiting approval",
      "awaiting your approval",
      "approval required",
      "requires approval",
      "requires your approval",
      "waiting for approval",
      "بانتظار الموافقة",
      "في انتظار الموافقة",
      "معلق للموافقة",
      "معلّق للموافقة",
      "محتاج موافقة",
    ]) {
      return nativeShortcutLocalizedLabel(
        english: "Pending for Approval",
        arabic: "بانتظار الموافقة",
        isArabic: isArabic
      )
    }

    if nativeShortcutContainsAny(lowered, [
      "auto approved",
      "automatically approved",
      "approved automatically",
      "approval complete",
      "approved successfully",
      "successful",
      "completed",
      "captured",
      "approved",
      "تمت الموافقة",
      "تمت الموافقة تلقائيا",
      "تمت الموافقة تلقائيًا",
      "موافقة تلقائية",
      "تم بنجاح",
    ]) {
      return nativeShortcutLocalizedLabel(
        english: "Auto approved",
        arabic: "موافق عليه تلقائيًا",
        isArabic: isArabic
      )
    }

    let merchant = nativeShortcutMerchant(from: messageText)
    let amount = nativeShortcutAmount(from: messageText)
    if nativeShortcutShouldAutoApprove(
      messageText: messageText,
      merchant: merchant,
      amount: amount
    ) {
      return nativeShortcutLocalizedLabel(
        english: "Auto approved",
        arabic: "موافق عليه تلقائيًا",
        isArabic: isArabic
      )
    }

    return nativeShortcutLocalizedLabel(
      english: "Pending for Approval",
      arabic: "بانتظار الموافقة",
      isArabic: isArabic
    )
  }

  private static func nativeShortcutShouldAutoApprove(
    messageText: String,
    merchant: String?,
    amount: String?
  ) -> Bool {
    guard merchant?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
          amount?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
      return false
    }

    let normalized = messageText.lowercased()
    if nativeShortcutContainsRejectionIndicators(normalized) {
      return false
    }
    if nativeShortcutLooksLikeTransferMessage(normalized) {
      return false
    }

    guard let state = nativeShortcutSmartCaptureStateSnapshot(),
          state.smartCaptureAutoApproveEnabled else {
      return false
    }

    guard let resolvedMerchant = nativeShortcutResolvedMerchant(
      merchant: merchant!,
      state: state
    ) else {
      return false
    }

    if let rule = state.merchantRules[resolvedMerchant.lowercased()] ??
        state.merchantRules[merchant!.lowercased()] {
      let enabled = (rule["enabled"] as? Bool) ?? true
      let autoApprove = (rule["autoApprove"] as? Bool) ?? true
      let defaultType = (rule["defaultType"] as? String ?? "expense").lowercased()
      return enabled && autoApprove && defaultType != "transfer"
    }

    return nativeShortcutBuiltInAutoApproveMerchant(resolvedMerchant)
  }

  private static func nativeShortcutCaptureSignature(from messageText: String) -> String {
    let normalized = messageText.replacingOccurrences(of: "\r", with: "\n")
      .lowercased()
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized
  }

  private static func nativeShortcutWasRecentlyCaptured(signature: String) -> Bool {
    guard !signature.isEmpty else { return false }
    let now = Date().timeIntervalSince1970
    let cutoff = now - 300

    recentShortcutCaptureLock.lock()
    defer { recentShortcutCaptureLock.unlock() }
    loadRecentShortcutCapturesLocked()
    pruneRecentShortcutCapturesLocked(now: now, cutoff: cutoff)
    if recentShortcutCaptures.contains(where: { ($0["signature"] as? String) == signature }) {
      return true
    }
    recentShortcutCaptures.append([
      "signature": signature,
      "capturedAt": now,
    ])
    saveRecentShortcutCapturesLocked()
    return false
  }

  private static func nativeShortcutContainsRejectionIndicators(_ text: String) -> Bool {
    return nativeShortcutContainsAny(text, [
      "declined",
      "decline",
      "rejected",
      "reject",
      "failed",
      "failure",
      "unsuccessful",
      "not approved",
      "not authorized",
      "not authorised",
      "authorization failed",
      "authorisation failed",
      "authorization declined",
      "authorisation declined",
      "authorization rejected",
      "authorisation rejected",
      "payment declined",
      "transaction declined",
      "card declined",
      "unable to process",
      "unable to complete",
      "could not be completed",
      "cannot be completed",
      "could not process",
      "not completed",
      "failed to process",
      "cancelled",
      "canceled",
      "timeout",
      "expired",
      "blocked",
      "insufficient funds",
      "otp",
      "one time password",
      "one-time password",
      "verification code",
      "confirmation code",
      "رمز التحقق",
      "كود التحقق",
      "رمز لمرة واحدة",
      "الرمز لمرة واحدة",
      "كلمة مرور لمرة واحدة",
      "رمز الاستخدام لمرة واحدة",
      "مرفوضة",
      "مرفوض",
      "رفض",
      "تم الرفض",
      "عملية مرفوضة",
      "تم رفض العملية",
      "فشلت",
      "فشل",
      "فشل الدفع",
      "فشل العملية",
      "غير ناجحة",
      "تم الإلغاء",
      "ألغيت",
      "الرصيد غير كاف",
      "غير مصرح",
      "غير مصرح به",
      "تعذر",
      "تعذرت",
      "لم تتم الموافقة",
      "لم يتم الموافقة",
      "لم يتم إتمام العملية",
    ])
  }

  private static func nativeShortcutContainsOtpIndicators(_ text: String) -> Bool {
    return nativeShortcutContainsAny(text, [
      "otp",
      "one time password",
      "one-time password",
      "verification code",
      "confirmation code",
      "رمز التحقق",
      "كود التحقق",
      "رمز لمرة واحدة",
      "الرمز لمرة واحدة",
      "كلمة مرور لمرة واحدة",
      "رمز الاستخدام لمرة واحدة",
    ])
  }

  private static func nativeShortcutLooksLikeTransferMessage(_ text: String) -> Bool {
    return nativeShortcutContainsAny(text, [
      "transfer",
      "remittance",
      "bank transfer",
      "تحويل",
      "حوالة",
      "from account",
      "to account",
      "من حساب",
      "إلى حساب",
    ])
  }

  private static func nativeShortcutBuiltInAutoApproveMerchant(_ merchant: String) -> Bool {
    let lowered = merchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    return [
      "talabat",
      "toyou",
      "hungerstation",
      "jahez",
      "amazon",
      "noon",
      "jarir",
      "uber",
      "careem",
      "nile air",
      "flynas",
      "saudia",
      "fitness time",
      "whoop",
      "fitness plan",
      "stc",
      "mobily",
      "zain",
    ].contains(where: { lowered.contains($0) })
  }

  private static func nativeShortcutResolvedMerchant(
    merchant: String,
    state: NativeSmartCaptureStateSnapshot
  ) -> String? {
    let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    let lower = trimmed.lowercased()
    if let mapped = state.merchantAliases[lower] {
      return mapped
    }
    for (alias, canonical) in state.merchantAliases where lower.contains(alias) {
      return canonical
    }
    return trimmed
  }

  private static func nativeShortcutSmartCaptureStateSnapshot() -> NativeSmartCaptureStateSnapshot? {
    let defaults = notificationDefaults()
    guard let raw = defaults.string(forKey: smartCaptureStateKey),
          let data = raw.data(using: .utf8),
          let decoded = try? JSONSerialization.jsonObject(with: data, options: []),
          let root = decoded as? [String: Any] else {
      return nil
    }

    let smartCaptureAutoApproveEnabled = (root["smartCaptureAutoApproveEnabled"] as? Bool) ?? false
    let languagePreference = (root["languagePreference"] as? String ?? "en")
      .lowercased()
    let merchantAliases = (root["merchantAliases"] as? [String: Any] ?? [:]).reduce(
      into: [String: String]()
    ) { result, entry in
      result[entry.key.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)] =
        entry.value as? String ?? String(describing: entry.value)
    }
    let merchantRulesRaw = root["merchantRules"] as? [String: Any] ?? [:]
    var merchantRules: [String: [String: Any]] = [:]
    for (key, value) in merchantRulesRaw {
      if let rule = value as? [String: Any] {
        merchantRules[key.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)] = rule
      }
    }

    return NativeSmartCaptureStateSnapshot(
      smartCaptureAutoApproveEnabled: smartCaptureAutoApproveEnabled,
      languagePreference: languagePreference,
      merchantAliases: merchantAliases,
      merchantRules: merchantRules
    )
  }

  private static func nativeShortcutLocalizedLabel(
    english: String,
    arabic: String,
    isArabic: Bool
  ) -> String {
    isArabic ? arabic : english
  }

  private static func nativeShortcutAmount(from messageText: String) -> String? {
    let normalized = messageText.replacingOccurrences(of: "\r", with: "\n")
    if let explicit = nativeShortcutExplicitAmountCandidate(from: normalized) {
      return nativeShortcutFormatAmount(explicit.amount)
    }

    let amountRegex = #"([0-9][0-9,]*(?:\.[0-9]+)?)"#
    let lines = normalized.split(separator: "\n").map(String.init)
    var selectedPriority = Int.max
    var bestScore = -9999.0
    var selectedAmount: Double?

    for line in lines {
      let lineLower = line.lowercased()
      let matches = nativeShortcutAllMatches(in: line, pattern: amountRegex)
      guard !matches.isEmpty else { continue }

      for match in matches {
        guard let range = Range(match.range(at: 1), in: line) else { continue }
        let raw = String(line[range]).replacingOccurrences(of: ",", with: "")
        guard let value = Double(raw), value > 0 else { continue }

        if value < 100 && nativeShortcutLooksLikeDateNumberCandidate(line: line, value: value) {
          continue
        }

        let amountContext = lineLower
        if nativeShortcutContainsAny(amountContext, [
          "الرصيد",
          "رصيدك الحالي",
          "حد الصرف",
          "حد الصرف المتبقي",
          "remaining amount",
          "remaining limit",
          "سعر الصرف",
          "exchange rate",
          "available balance",
          "remaining balance",
          "credit limit",
        ]) {
          continue
        }

        let priorityAndScore = nativeShortcutAmountPriorityAndScore(from: lineLower)
        let priority = priorityAndScore.priority
        var score = priorityAndScore.score
        if let localCurrency = nativeShortcutCurrencyCode(in: lineLower),
           localCurrency == "SAR" || localCurrency == "EGP" {
          score += 30.0
        }
        if priority < selectedPriority ||
            (priority == selectedPriority && score > bestScore) {
          selectedPriority = priority
          bestScore = score
          selectedAmount = value
        }
      }
    }

    if let selectedAmount {
      return nativeShortcutFormatAmount(selectedAmount)
    }

    return nil
  }

  private static func nativeShortcutCurrency(from messageText: String) -> String? {
    let normalized = messageText.replacingOccurrences(of: "\r", with: "\n")
    let patterns: [(String, String)] = [
      (#"(?i)\b(SAR|SR|S\.R)\b"#, "SAR"),
      (#"(?i)\b(EGP|ج\.م|جنيه)\b"#, "EGP"),
      (#"(?i)\b(USD|\$)\b"#, "USD"),
      (#"(?i)\b(AED|د\.إ|د.إ|درهم)\b"#, "AED"),
      (#"(?i)\b(KWD)\b"#, "KWD"),
      (#"(?i)\b(QAR)\b"#, "QAR"),
      (#"(?i)\b(BHD)\b"#, "BHD"),
      (#"(?i)\b(OMR)\b"#, "OMR"),
      (#"(?i)ر\.س"#, "SAR"),
      (#"(?i)⃁"#, "SAR"),
      (#"(?i)€"#, "EUR"),
      (#"(?i)£"#, "GBP"),
    ]

    for (pattern, mapped) in patterns {
      if nativeShortcutFirstMatch(in: normalized, pattern: pattern) != nil {
        return nativeShortcutCurrencyDisplay(from: mapped)
      }
    }

    return nil
  }

  private static func nativeShortcutCurrencyDisplay(
    from currencyCode: String
  ) -> String {
    let upper = currencyCode.uppercased()
    switch upper {
    case "SAR":
      return "⃁"
    case "EGP":
      return "E£"
    case "USD":
      return "$"
    case "AED":
      return "د.إ"
    case "KWD":
      return "KWD"
    case "QAR":
      return "QAR"
    case "BHD":
      return "BHD"
    case "OMR":
      return "OMR"
    case "EUR":
      return "€"
    case "GBP":
      return "£"
    default:
      return currencyCode
    }
  }

  private static func nativeShortcutMerchant(from messageText: String) -> String? {
    let normalized = messageText.replacingOccurrences(of: "\r", with: "\n")
    let lines = normalized
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    let inlinePatterns: [String] = [
      #"(?i)(?:(?<![A-Za-z0-9])(?:at|merchant|store)(?![A-Za-z0-9])|لدى|عند|في)\s*[:\-]?\s*([A-Za-z\u0600-\u06FF0-9][A-Za-z0-9\u0600-\u06FF&*.,\- ]{1,80})"#
    ]
    for pattern in inlinePatterns {
      if let candidate = nativeShortcutValidatedMerchant(
        from: normalized,
        pattern: pattern
      ) {
        return candidate
      }
    }

    let fieldPatterns: [String] = [
      #"(?i)^\s*(?:merchant|at|to|from|in)\s*[:\-]?\s*(.+)$"#,
      #"(?i)^\s*(?:عند|إلى|الى|من)\s*[:\-]?\s*(.+)$"#,
    ]
    for line in lines {
      for pattern in fieldPatterns {
        if let candidate = nativeShortcutValidatedMerchant(
          from: line,
          pattern: pattern
        ) {
          return candidate
        }
      }
    }

    for line in lines {
      let candidate = nativeShortcutValidatedMerchant(from: line)
      guard let candidate, !candidate.isEmpty else { continue }
      if candidate.rangeOfCharacter(from: .decimalDigits) != nil { continue }
      let lower = candidate.lowercased()
      if nativeShortcutContainsAny(lower, [
        "otp",
        "verification",
        "balance",
        "الرصيد",
        "card",
        "بطاقة",
        "amount",
        "مبلغ",
        "purchase",
        "payment",
        "transfer",
        "حساب",
        "account",
      ]) {
        continue
      }
      return candidate
    }

    return nil
  }

  private static func nativeShortcutValidatedMerchant(
    from text: String,
    pattern: String? = nil
  ) -> String? {
    var candidate = text
    if let pattern,
       let match = nativeShortcutFirstMatch(in: text, pattern: pattern),
       let range = Range(match.range(at: 1), in: text) {
      candidate = String(text[range])
    }

    candidate = nativeShortcutTrimMerchantCandidate(candidate)
    guard !candidate.isEmpty else { return nil }

    let normalized = candidate.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let searchToken = nativeShortcutMerchantSearchToken(candidate)
    if nativeShortcutIsInvalidMerchantCandidate(normalized: normalized, searchToken: searchToken) {
      return nil
    }
    return candidate
  }

  private static func nativeShortcutTrimMerchantCandidate(_ rawMerchant: String) -> String {
    let tokens = rawMerchant
      .replacingOccurrences(of: "\r", with: " ")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\t", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .split(whereSeparator: { $0.isWhitespace })
      .map(String.init)

    var kept: [String] = []
    for token in tokens {
      let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
      if cleaned.isEmpty { continue }
      if nativeShortcutMerchantIsStopWord(cleaned) { break }
      kept.append(cleaned)
    }

    var candidate = kept.joined(separator: " ")
    candidate = candidate.replacingOccurrences(
      of: #"(?i)\s*(?:sar|sr|s\.r|egp|usd|aed|kwd|qar|bhd|omr|ر\.س|ج\.م|ريال|جنيه|درهم|د\.إ|د.إ)\s*$"#,
      with: "",
      options: .regularExpression
    )
    candidate = candidate.replacingOccurrences(
      of: #"(?i)\s*-\s*(?:sa|ksa|uae|eg|egy|sr|s\.r|egp|usd|aed)\s*$"#,
      with: "",
      options: .regularExpression
    )
    candidate = candidate.replacingOccurrences(
      of: #"(?i)\s+\d{1,2}[:/ -]\d{1,2}.*$"#,
      with: "",
      options: .regularExpression
    )
    candidate = candidate.replacingOccurrences(
      of: #"(?i)^(?:purchase|pos purchase|pos|payment|spent|withdrawal|debit|شراء|عملية شراء|سداد|خصم|دفع|transfer|تحويل|حوالة|تم|وارد|merchant|at|from|من|لدى|عند)\s*[:\-]?\s+"#,
      with: "",
      options: .regularExpression
    )
    return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static let nativeShortcutMerchantStopWords: Set<String> = [
    "bank", "card", "payment", "purchase", "pos", "debit", "credit",
    "account", "balance", "amount", "merchant", "mobile", "by", "from",
    "at", "with", "cardholder", "transaction", "trans", "cash", "invoice",
    "receipt", "بطاقة", "الخصم", "المباشر", "رقم", "المتاح", "الرصيد",
    "الحساب", "اليوم", "يوم", "الساعة", "عملية", "شراء", "دفع", "سداد",
    "تم", "من", "لدى", "عند", "في", "داخل", "المبلغ", "المستحق", "العملية",
    "pending", "approval", "approved", "rejected", "declined", "captured",
    "successful", "completed", "review", "smart", "capture",
  ]

  private static func nativeShortcutMerchantIsStopWord(_ token: String) -> Bool {
    let normalized = nativeShortcutMerchantSearchToken(token)
    if normalized.isEmpty { return false }
    if normalized.range(of: #"^\d+(?:[\/\-:]\d+)*$"#, options: .regularExpression) != nil {
      return true
    }
    if normalized.range(of: #"^\d+(?:\.\d+)?$"#, options: .regularExpression) != nil {
      return true
    }
    return nativeShortcutMerchantStopWords.contains(normalized)
  }

  private static func nativeShortcutMerchantSearchToken(_ input: String) -> String {
    input
      .lowercased()
      .replacingOccurrences(of: #"[\u200e\u200f\u202a-\u202e]"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"[^a-z0-9\u0600-\u06FF]+"#, with: "", options: .regularExpression)
  }

  private static func nativeShortcutIsInvalidMerchantCandidate(
    normalized: String,
    searchToken: String
  ) -> Bool {
    let invalidExact: Set<String> = [
      "account", "bank", "balance", "amount", "card", "merchant", "payment",
      "purchase", "pos", "debit", "credit", "cash", "transfer", "expense",
      "income", "بطاقة", "حساب", "الرصيد", "مبلغ", "عملية", "شراء", "دفع",
      "سداد", "رقم", "المتاح", "المباشر", "الخصم", "إلى", "الى", "من",
      "لدى", "عند", "في", "داخل", "pending", "approval", "approved",
      "rejected", "declined", "captured", "successful", "completed",
      "review", "smart", "capture",
    ]
    if invalidExact.contains(normalized) || invalidExact.contains(searchToken) {
      return true
    }
    if searchToken.contains("حساب") ||
        searchToken.contains("account") ||
        searchToken.contains("بطاقة") ||
        searchToken.contains("pending") ||
        searchToken.contains("approval") ||
        searchToken.contains("approved") ||
        searchToken.contains("rejected") ||
        searchToken.contains("declined") ||
        searchToken.contains("captured") ||
        searchToken.contains("successful") ||
        searchToken.contains("completed") ||
        searchToken.hasPrefix("visa") ||
        searchToken.hasPrefix("mastercard") ||
        searchToken.hasPrefix("mada") ||
        searchToken.hasPrefix("applepay") ||
        searchToken.hasPrefix("stcpay") ||
        searchToken.contains("الرصيد") ||
        searchToken.contains("balance") ||
        searchToken.contains("amount") ||
        searchToken.contains("مبلغ") ||
        searchToken.contains("رقم") {
      return true
    }
    return false
  }

  private static func nativeShortcutFirstMatch(
    in text: String,
    pattern: String
  ) -> NSTextCheckingResult? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return nil
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.firstMatch(in: text, options: [], range: range)
  }

  private static func nativeShortcutAllMatches(
    in text: String,
    pattern: String
  ) -> [NSTextCheckingResult] {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return []
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, options: [], range: range)
  }

  private static func nativeShortcutContainsAny(_ text: String, _ needles: [String]) -> Bool {
    for needle in needles where text.contains(needle) {
      return true
    }
    return false
  }

  private static func nativeShortcutFormatAmount(_ amount: Double) -> String {
    let formatted = String(format: "%.2f", amount)
    return formatted.replacingOccurrences(of: #"(\.\d*?[1-9])0+$"#, with: "$1", options: .regularExpression)
      .replacingOccurrences(of: #"\.0+$"#, with: "", options: .regularExpression)
  }

  private static func nativeShortcutExplicitAmountCandidate(from text: String) -> (amount: Double, currency: String?)? {
    let patterns: [String] = [
      #"(?i)(?:amount|المبلغ|مبلغ|charged amount|transaction amount|purchase amount|total|value|price|due)\s*[:\-]?\s*(?:SAR|SR|S\.R|EGP|USD|AED|KWD|QAR|BHD|OMR|ر\.س|ج\.م|ريال|جنيه|درهم|د\.إ|د.إ)?\s*([0-9][0-9,]*(?:\.[0-9]+)?)"#,
      #"(?i)(?:SAR|SR|S\.R|EGP|USD|AED|KWD|QAR|BHD|OMR|ر\.س|ج\.م|ريال|جنيه|درهم|د\.إ|د.إ)\s*([0-9][0-9,]*(?:\.[0-9]+)?)"#,
      #"(?i)([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:SAR|SR|S\.R|EGP|USD|AED|KWD|QAR|BHD|OMR|ر\.س|ج\.م|ريال|جنيه|درهم|د\.إ|د.إ)"#,
    ]

    for pattern in patterns {
      guard let match = nativeShortcutFirstMatch(in: text, pattern: pattern) else {
        continue
      }
      guard let range = Range(match.range(at: 1), in: text) else {
        continue
      }
      let rawAmount = String(text[range]).replacingOccurrences(of: ",", with: "")
      guard let parsedAmount = Double(rawAmount), parsedAmount > 0 else {
        continue
      }

      var currency: String? = nil
      if let fullRange = Range(match.range, in: text) {
        currency = nativeShortcutCurrencyCode(in: String(text[fullRange]))
      }
      return (amount: parsedAmount, currency: currency)
    }

    return nil
  }

  private static func nativeShortcutCurrencyCode(in text: String) -> String? {
    let patterns: [(String, String)] = [
      (#"(?i)\b(SAR|SR|S\.R)\b"#, "SAR"),
      (#"(?i)\b(EGP|ج\.م|جنيه)\b"#, "EGP"),
      (#"(?i)\b(USD|\$)\b"#, "USD"),
      (#"(?i)\b(AED|د\.إ|د.إ|درهم)\b"#, "AED"),
      (#"(?i)\b(KWD)\b"#, "KWD"),
      (#"(?i)\b(QAR)\b"#, "QAR"),
      (#"(?i)\b(BHD)\b"#, "BHD"),
      (#"(?i)\b(OMR)\b"#, "OMR"),
      (#"(?i)ر\.س"#, "SAR"),
      (#"(?i)⃁"#, "SAR"),
      (#"(?i)€"#, "EUR"),
      (#"(?i)£"#, "GBP"),
    ]
    for (pattern, code) in patterns {
      if nativeShortcutFirstMatch(in: text, pattern: pattern) != nil {
        return code
      }
    }
    return nil
  }

  private static func nativeShortcutAmountPriorityAndScore(from lineLower: String) -> (priority: Int, score: Double) {
    if nativeShortcutContainsAny(lineLower, [
      "total due",
      "total charged",
      "إجمالي المبلغ المستحق",
      "المبلغ النهائي",
      "إجمالي المبلغ",
    ]) {
      return (1, 10000.0)
    }
    if nativeShortcutContainsAny(lineLower, [
      "charged amount",
      "المبلغ المطلوب",
      "total charged amount",
    ]) {
      return (2, 8000.0)
    }
    if nativeShortcutContainsAny(lineLower, [
      "مبلغ",
      "amount",
      "amt",
      "value",
      "بقيمة",
      "بقيمه",
      "purchase amount",
      "transaction amount",
    ]) {
      return (3, 6000.0)
    }
    if nativeShortcutContainsAny(lineLower, [
      "purchase",
      "pos",
      "payment",
      "debit",
      "credit",
      "شراء",
      "دفع",
      "خصم",
      "سحب",
    ]) {
      return (3, 5500.0)
    }
    if nativeShortcutContainsAny(lineLower, [
      "fee",
      "fees",
      "رسوم",
      "رسوم العملية",
    ]) {
      return (4, 4000.0)
    }
    if nativeShortcutContainsAny(lineLower, [
      "balance",
      "remaining",
      "spending limit",
      "remaining amount",
      "remaining limit",
    ]) {
      return (5, 2000.0)
    }
    return (5, 0.0)
  }

  private static func nativeShortcutLooksLikeDateNumberCandidate(line: String, value: Double) -> Bool {
    guard value < 100 else { return false }
    let lower = line.lowercased()
    return nativeShortcutContainsAny(lower, [
      "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct",
      "nov", "dec", "يناير", "فبراير", "مارس", "أبريل", "ابريل", "مايو",
      "يونيو", "يوليو", "أغسطس", "اغسطس", "سبتمبر", "أكتوبر", "اكتوبر",
      "نوفمبر", "ديسمبر",
    ]) || lower.contains("-") || lower.contains("/")
  }

#if canImport(Flutter)
  private func configureSmartCaptureChannel() {
    guard smartCaptureChannel == nil,
          let controller = activeFlutterViewController() else {
      return
    }
    smartCaptureChannel = FlutterMethodChannel(
      name: "com.zakahwealth.smartcapture",
      binaryMessenger: controller.binaryMessenger
    )
    deliverQueuedNotificationLaunchesIfPossible()
  }
#endif

#if canImport(Flutter)
  private func configureShortcutBridgeChannel() {
    guard shortcutBridgeChannel == nil,
          let controller = activeFlutterViewController() else {
      return
    }
    NSLog("[Shortcut] Registering native channel")
    let channel = FlutterMethodChannel(
      name: "com.zakahwealth.smartcapture.native",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getPendingShortcutMessages":
        let messages = AppDelegate.drainShortcutQueue()
        result(messages)
      case "clearPendingShortcutMessages":
        AppDelegate.clearShortcutQueue()
        result(true)
      case "markShortcutServiceReady":
        AppDelegate.flutterShortcutServiceReady = true
        NSLog("[Shortcut] Flutter marked service ready")
        self.deliverQueuedShortcutMessagesIfPossible()
        result(true)
      case "openShortcutsApp":
        if let url = URL(string: "shortcuts://") {
          UIApplication.shared.open(url, options: [:]) { opened in
            result(opened)
          }
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    shortcutBridgeChannel = channel
    NSLog("[Shortcut] Native method channel registered")
  }
#endif

#if canImport(Flutter)
  private func configureAppleSignInChannel() {
    guard appleSignInChannel == nil,
          let controller = activeFlutterViewController() else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "zakatapp_flutter/apple_sign_in",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "signIn":
        self.appleSignInCoordinator.signIn(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    appleSignInChannel = channel
  }
#endif

#if canImport(Flutter)
  private func configureWidgetRefreshChannel() {
    guard widgetRefreshChannel == nil,
          let controller = activeFlutterViewController() else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.zakahwealth.widgets",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "reloadAllTimelines":
        WidgetCenter.shared.reloadAllTimelines()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    widgetRefreshChannel = channel
  }
#endif

  private func scheduleAppleSignInRegistrationRetry() {
    guard appleSignInChannel == nil,
          appleSignInRegistrationAttempts < 8 else {
      return
    }

    appleSignInRegistrationAttempts += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
      guard let self else { return }
      self.configureAppleSignInChannel()
      if self.appleSignInChannel == nil {
        self.scheduleAppleSignInRegistrationRetry()
      }
    }
  }

#if canImport(Flutter)
  private func deliverQueuedShortcutMessagesIfPossible() {
    guard AppDelegate.flutterShortcutServiceReady,
          let channel = smartCaptureChannel else {
      return
    }

    AppDelegate.shortcutQueueLock.lock()
    let messages = AppDelegate.pendingShortcutMessages
    guard !messages.isEmpty else {
      AppDelegate.shortcutQueueLock.unlock()
      return
    }
    AppDelegate.pendingShortcutMessages.removeAll()
    AppDelegate.saveShortcutQueueLocked()
    AppDelegate.shortcutQueueLock.unlock()

    NSLog("[Shortcut] Native push delivering queued messages: \(messages.count)")
    for message in messages {
      channel.invokeMethod("logBankMessage", arguments: message)
    }
  }
#endif

  private static func notificationDefaults() -> UserDefaults {
    UserDefaults(suiteName: shortcutQueueSuiteName) ?? .standard
  }

  private static func loadRecentShortcutCapturesLocked() {
    guard !recentShortcutCaptureQueueLoaded else { return }
    let defaults = notificationDefaults()
    if let rawQueue = defaults.array(forKey: recentShortcutCaptureStorageKey) as? [[String: Any]] {
      recentShortcutCaptures = rawQueue
    } else {
      recentShortcutCaptures = []
    }
    recentShortcutCaptureQueueLoaded = true
  }

  private static func pruneRecentShortcutCapturesLocked(now: TimeInterval, cutoff: TimeInterval) {
    recentShortcutCaptures = recentShortcutCaptures.filter {
      let capturedAt = ($0["capturedAt"] as? Double) ?? 0
      return capturedAt >= cutoff && capturedAt <= now
    }
  }

  private static func saveRecentShortcutCapturesLocked() {
    let defaults = notificationDefaults()
    defaults.set(recentShortcutCaptures, forKey: recentShortcutCaptureStorageKey)
    defaults.synchronize()
  }

  private static func loadNotificationLaunchQueueLocked() {
    guard !notificationLaunchQueueLoaded else {
      return
    }
    let defaults = notificationDefaults()
    let rawQueue = defaults.array(forKey: notificationLaunchStorageKey) as? [[String: Any]] ?? []
    pendingNotificationLaunches = rawQueue
    notificationLaunchQueueLoaded = true
  }

  private static func refreshNotificationLaunchQueueFromStorageLocked() {
    let defaults = notificationDefaults()
    let rawQueue = defaults.array(forKey: notificationLaunchStorageKey) as? [[String: Any]] ?? []
    pendingNotificationLaunches = rawQueue
    notificationLaunchQueueLoaded = true
  }

  private static func saveNotificationLaunchQueueLocked() {
    let defaults = notificationDefaults()
    defaults.set(pendingNotificationLaunches, forKey: notificationLaunchStorageKey)
    defaults.synchronize()
  }

  static func queueNotificationLaunch(_ payload: [String: Any]) {
    notificationLaunchLock.lock()
    defer { notificationLaunchLock.unlock() }

    loadNotificationLaunchQueueLocked()
    pendingNotificationLaunches.append(payload)
    saveNotificationLaunchQueueLocked()
    DispatchQueue.main.async {
      AppDelegate.sharedDeliverQueuedNotificationLaunchesIfPossible()
    }
  }

  private static func sharedDeliverQueuedNotificationLaunchesIfPossible() {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }
    appDelegate.deliverQueuedNotificationLaunchesIfPossible()
  }

  private func deliverQueuedNotificationLaunchesIfPossible() {
    guard let channel = smartCaptureChannel else {
      return
    }

    AppDelegate.notificationLaunchLock.lock()
    AppDelegate.refreshNotificationLaunchQueueFromStorageLocked()
    let launches = AppDelegate.pendingNotificationLaunches
    guard !launches.isEmpty else {
      AppDelegate.notificationLaunchLock.unlock()
      return
    }
    AppDelegate.pendingNotificationLaunches.removeAll()
    AppDelegate.saveNotificationLaunchQueueLocked()
    AppDelegate.notificationLaunchLock.unlock()

    NSLog("[SMS] Native push delivering queued notification launches: \(launches.count)")
    for launch in launches {
      channel.invokeMethod("notificationLaunchReceived", arguments: launch)
    }
  }

#if canImport(Flutter)
  private func activeFlutterViewController() -> FlutterViewController? {
    let scenes = UIApplication.shared.connectedScenes
    for scene in scenes {
      guard let windowScene = scene as? UIWindowScene else {
        continue
      }
      for window in windowScene.windows {
        if let controller = window.rootViewController as? FlutterViewController {
          return controller
        }
      }
    }
    return nil
  }
#endif

  private func scheduleShortcutBridgeRegistrationRetry() {
    guard shortcutBridgeChannel == nil,
          shortcutBridgeRegistrationAttempts < 5 else {
      return
    }

    shortcutBridgeRegistrationAttempts += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
      guard let self else { return }
      self.configureSmartCaptureChannel()
      self.configureShortcutBridgeChannel()
      if self.shortcutBridgeChannel == nil {
        self.scheduleShortcutBridgeRegistrationRetry()
      }
    }
  }

  private static func shortcutDefaults() -> UserDefaults {
    UserDefaults(suiteName: shortcutQueueSuiteName) ?? .standard
  }

  private static func loadShortcutQueueLocked() {
    guard !shortcutQueueLoaded else {
      return
    }
    let defaults = shortcutDefaults()
    if let rawQueue = defaults.array(forKey: shortcutQueueStorageKey) as? [[String: Any]] {
      pendingShortcutMessages = rawQueue
    } else if let legacyQueue = defaults.stringArray(forKey: shortcutQueueStorageKey) {
      pendingShortcutMessages = legacyQueue.map { message in
        [
          "messageContent": message,
          "source": "shortcut",
          "sourceIdentifier": "Apple Automation",
          "notificationAlreadyShown": "false",
        ]
      }
    } else {
      pendingShortcutMessages = []
    }
    shortcutQueueLoaded = true
  }

  private static func refreshShortcutQueueFromStorageLocked() {
    let defaults = shortcutDefaults()
    if let rawQueue = defaults.array(forKey: shortcutQueueStorageKey) as? [[String: Any]] {
      pendingShortcutMessages = rawQueue
    } else if let legacyQueue = defaults.stringArray(forKey: shortcutQueueStorageKey) {
      pendingShortcutMessages = legacyQueue.map { message in
        [
          "messageContent": message,
          "source": "shortcut",
          "sourceIdentifier": "Apple Automation",
          "notificationAlreadyShown": "false",
        ]
      }
    } else {
      pendingShortcutMessages = []
    }
    shortcutQueueLoaded = true
  }

  private static func saveShortcutQueueLocked() {
    let defaults = shortcutDefaults()
    defaults.set(pendingShortcutMessages, forKey: shortcutQueueStorageKey)
    defaults.synchronize()
  }

  static func drainShortcutQueue() -> [[String: Any]] {
    shortcutQueueLock.lock()
    defer { shortcutQueueLock.unlock() }

    NSLog("[Shortcut] getPendingShortcutMessages called")
    refreshShortcutQueueFromStorageLocked()
    let messages = pendingShortcutMessages
    guard !messages.isEmpty else {
      NSLog("[Shortcut] Returning queued messages: 0")
      return []
    }

    pendingShortcutMessages.removeAll()
    saveShortcutQueueLocked()
    NSLog("[Shortcut] Returning queued messages: \(messages.count)")
    NSLog("[Shortcut] Queue cleared")
    return messages
  }

  static func clearShortcutQueue() {
    shortcutQueueLock.lock()
    defer { shortcutQueueLock.unlock() }

    pendingShortcutMessages.removeAll()
    saveShortcutQueueLocked()
    NSLog("[Shortcut] Queue cleared")
  }

  private func requestNotificationAuthorizationIfNeeded() {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      guard settings.authorizationStatus == .notDetermined else {
        return
      }

      center.requestAuthorization(options: [.alert, .badge, .sound]) {
        granted, error in
        if let error = error {
          NSLog("[Shortcut] Native notification authorization failed: \(error)")
          return
        }
        NSLog("[Shortcut] Native notification authorization granted=\(granted)")
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    defer { completionHandler() }

    let userInfo = response.notification.request.content.userInfo
    var payload = userInfo.reduce(into: [String: Any]()) { result, entry in
      result["\(entry.key)"] = entry.value
    }
    payload["notificationTap"] = "true"
    if payload["notificationTapToken"] == nil {
      if let transactionId = payload["pendingTransactionId"] as? String,
         !transactionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        payload["notificationTapToken"] = transactionId
      } else {
        payload["notificationTapToken"] = UUID().uuidString
      }
    }

    AppDelegate.queueNotificationLaunch(payload)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}

#if canImport(Flutter)
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  private var resultHandler: FlutterResult?

  func signIn(result: @escaping FlutterResult) {
    guard #available(iOS 13.0, *) else {
      result(FlutterError(code: "UNAVAILABLE", message: "Apple Sign In requires iOS 13+", details: nil))
      return
    }
    resultHandler = result
    let provider = ASAuthorizationAppleIDProvider()
    let request = provider.createRequest()
    request.requestedScopes = [.fullName, .email]

    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    controller.performRequests()
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow } ?? UIWindow()
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      resultHandler?(nil)
      resultHandler = nil
      return
    }

    let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    let payload: [String: Any] = [
      "userId": credential.user,
      "email": credential.email ?? "",
      "givenName": credential.fullName?.givenName ?? "",
      "familyName": credential.fullName?.familyName ?? "",
      "identityToken": identityToken,
    ]
    resultHandler?(payload)
    resultHandler = nil
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    resultHandler?(FlutterError(code: "APPLE_SIGN_IN_FAILED", message: error.localizedDescription, details: nil))
    resultHandler = nil
  }
}
#endif
