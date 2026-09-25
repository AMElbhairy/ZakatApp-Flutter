import Foundation
import SwiftUI
import UserNotifications
#if canImport(WatchKit)
import WatchKit
#endif

public enum WatchNotificationParser {
  /// Extracts the pendingTransactionId from a notification userInfo dictionary.
  /// Handles top-level keys, nested payload dictionary, and JSON-encoded payload strings.
  public static func extractPendingTransactionId(from userInfo: [AnyHashable: Any]) -> String? {
    // 1. Direct top-level 'pendingTransactionId'
    if let id = userInfo["pendingTransactionId"] as? String,
       !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 2. Direct top-level 'notificationTapToken'
    if let token = userInfo["notificationTapToken"] as? String,
       !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 3. Nested dictionary inside 'payload'
    if let payloadDict = userInfo["payload"] as? [String: Any] {
      if let id = payloadDict["pendingTransactionId"] as? String,
         !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return id.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      if let token = payloadDict["notificationTapToken"] as? String,
         !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return token.trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }

    // 4. JSON-encoded string inside 'payload'
    if let payloadStr = userInfo["payload"] as? String,
       let data = payloadStr.data(using: .utf8) {
      if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
        if let id = json["pendingTransactionId"] as? String,
           !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          return id.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let token = json["notificationTapToken"] as? String,
           !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          return token.trimmingCharacters(in: .whitespacesAndNewlines)
        }
      }
    }

    return nil
  }
}

#if os(watchOS)
public class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
  public func applicationDidFinishLaunching() {
    UNUserNotificationCenter.current().delegate = self
    #if DEBUG
    NSLog("[WatchApp] WatchAppDelegate initialized. UNUserNotificationCenter delegate registered.")
    #endif
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    #if DEBUG
    NSLog("[WatchApp] Notification willPresent in foreground: \(notification.request.content.userInfo)")
    #endif

    if #available(watchOS 10.0, *) {
      completionHandler([.banner, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    defer { completionHandler() }

    let userInfo = response.notification.request.content.userInfo
    #if DEBUG
    NSLog("[WatchApp] Notification didReceive tap response. Raw userInfo keys: \(userInfo.keys)")
    #endif

    if let pendingId = WatchNotificationParser.extractPendingTransactionId(from: userInfo) {
      #if DEBUG
      NSLog("[WatchApp] Notification tap recovered pendingId: '\(pendingId)'. Dispatching to WatchNavigationManager...")
      #endif
      Task { @MainActor in
        WatchNavigationManager.shared.routeToReview(pendingId: pendingId)
      }
    } else {
      #if DEBUG
      NSLog("[WatchApp] Notification tap contained no pendingTransactionId. Routing to Inbox as fallback.")
      #endif
      Task { @MainActor in
        WatchNavigationManager.shared.routeToInbox()
      }
    }
  }
}
#else
public class WatchAppDelegate: NSObject, UNUserNotificationCenterDelegate {
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    defer { completionHandler() }
  }
}
#endif
