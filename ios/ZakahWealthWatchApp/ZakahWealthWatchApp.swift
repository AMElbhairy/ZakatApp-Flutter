import SwiftUI

#if os(watchOS)
import WatchKit
#endif

@main
struct ZakahWealthWatchApp: App {
  #if os(watchOS)
  @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate
  #endif
  @StateObject private var connectivity = WatchConnectivityManager.shared
  @StateObject private var navigation = WatchNavigationManager.shared

  var body: some Scene {
    WindowGroup {
      WatchHomeShellView()
        .environmentObject(connectivity)
        .environmentObject(navigation)
        .onOpenURL { url in
          if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let pendingId = components.queryItems?.first(where: { $0.name == "id" || $0.name == "pendingTransactionId" })?.value {
              WatchNavigationManager.shared.routeToReview(pendingId: pendingId)
            }
          }
        }
    }
  }
}
