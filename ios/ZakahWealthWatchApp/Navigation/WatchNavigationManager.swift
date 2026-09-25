import SwiftUI
import Combine

public enum WatchRoute: Hashable, Equatable {
  case home
  case inbox
  case reviewPending(id: String)
}

@MainActor
public final class WatchNavigationManager: ObservableObject {
  public static let shared = WatchNavigationManager()

  @Published public var activeRoute: WatchRoute = .home
  @Published public var deepLinkedPendingId: String? = nil

  private init() {}

  public func routeToHome() {
    self.deepLinkedPendingId = nil
    self.activeRoute = .home
  }

  public func routeToInbox() {
    self.deepLinkedPendingId = nil
    self.activeRoute = .inbox
  }

  public func routeToReview(pendingId: String) {
    let cleanId = pendingId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanId.isEmpty else {
      routeToInbox()
      return
    }
    self.deepLinkedPendingId = cleanId
    self.activeRoute = .reviewPending(id: cleanId)
  }
}
