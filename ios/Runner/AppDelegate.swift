import Flutter
import AuthenticationServices
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var smartCaptureChannel: FlutterMethodChannel?
  private var shortcutBridgeChannel: FlutterMethodChannel?
  private var appleSignInChannel: FlutterMethodChannel?
  private var shortcutBridgeRegistrationAttempts = 0
  private var appleSignInRegistrationAttempts = 0
  private let appleSignInCoordinator = AppleSignInCoordinator()

  private static let shortcutQueueStorageKey = "com.zakahwealth.smartcapture.pendingShortcutMessages"
  private static let shortcutQueueSuiteName = "group.com.zakahwealth.app"
  private static let shortcutQueueLock = NSLock()
  private static var pendingShortcutMessages: [String] = []
  private static var shortcutQueueLoaded = false
  private static var flutterShortcutServiceReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinishLaunching = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    configureSmartCaptureChannel()
    configureShortcutBridgeChannel()
    configureAppleSignInChannel()
    scheduleShortcutBridgeRegistrationRetry()
    scheduleAppleSignInRegistrationRetry()

    return didFinishLaunching
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    configureSmartCaptureChannel()
    configureShortcutBridgeChannel()
    configureAppleSignInChannel()
    scheduleShortcutBridgeRegistrationRetry()
    scheduleAppleSignInRegistrationRetry()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  static func enqueueShortcutMessage(_ messageText: String) -> Bool {
    let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 10_000 else {
      NSLog("[Shortcut] Payload rejected")
      return false
    }

    shortcutQueueLock.lock()
    defer { shortcutQueueLock.unlock() }

    loadShortcutQueueLocked()
    pendingShortcutMessages.append(trimmed)
    saveShortcutQueueLocked()

    NSLog("[Shortcut] Payload queued")
    NSLog("[Shortcut] Queue size: \(pendingShortcutMessages.count)")
    DispatchQueue.main.async {
      AppDelegate.sharedDeliverQueuedShortcutMessagesIfPossible()
    }
    return true
  }

  private static func sharedDeliverQueuedShortcutMessagesIfPossible() {
    guard flutterShortcutServiceReady,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }
    appDelegate.deliverQueuedShortcutMessagesIfPossible()
  }

  private func configureSmartCaptureChannel() {
    guard smartCaptureChannel == nil,
          let controller = activeFlutterViewController() else {
      return
    }
    smartCaptureChannel = FlutterMethodChannel(
      name: "com.zakahwealth.smartcapture",
      binaryMessenger: controller.binaryMessenger
    )
  }

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
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    shortcutBridgeChannel = channel
    NSLog("[Shortcut] Native method channel registered")
  }

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
      channel.invokeMethod("logBankMessage", arguments: [
        "messageContent": message,
      ])
    }
  }

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
    pendingShortcutMessages = defaults.stringArray(forKey: shortcutQueueStorageKey) ?? []
    shortcutQueueLoaded = true
  }

  private static func refreshShortcutQueueFromStorageLocked() {
    let defaults = shortcutDefaults()
    pendingShortcutMessages = defaults.stringArray(forKey: shortcutQueueStorageKey) ?? []
    shortcutQueueLoaded = true
  }

  private static func saveShortcutQueueLocked() {
    let defaults = shortcutDefaults()
    defaults.set(pendingShortcutMessages, forKey: shortcutQueueStorageKey)
    defaults.synchronize()
  }

  static func drainShortcutQueue() -> [String] {
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
}

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
