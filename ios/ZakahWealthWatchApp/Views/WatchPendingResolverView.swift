import SwiftUI
import Combine

public struct WatchPendingResolverView: View {
  @ObservedObject var connectivity = WatchConnectivityManager.shared
  @ObservedObject var navigation = WatchNavigationManager.shared

  public let pendingId: String

  @State private var isAwaitingSync: Bool = true
  @State private var secondsWaited: Double = 0
  private let maxWaitSeconds: Double = 2.5
  private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

  public init(pendingId: String) {
    self.pendingId = pendingId
  }

  public var body: some View {
    let resolvedItem = connectivity.snapshot.pendingInbox.first(where: { $0.id == pendingId })

    Group {
      if let item = resolvedItem {
        // EXACT Phase 3 Review View (Zero duplication, pure authoritative snapshot source)
        WatchReviewItemView(item: item)
      } else if isAwaitingSync && secondsWaited < maxWaitSeconds {
        // Lightweight Resolving State (Section 5 requirement)
        VStack(spacing: 8) {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: WatchTheme.gold))
            .scaleEffect(1.0)
            .padding(.bottom, 2)

          Text("Resolving...")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(WatchTheme.offWhite)

          Text("Checking latest sync from iPhone")
            .font(.system(size: 10))
            .foregroundColor(WatchTheme.slateMuted)
            .multilineTextAlignment(.center)
        }
        .padding()
        .onReceive(timer) { _ in
          secondsWaited += 0.5
          if secondsWaited >= maxWaitSeconds {
            isAwaitingSync = false
          }
        }
      } else {
        // Item No Longer Pending / Already Processed (Section 6 requirement)
        ScrollView {
          VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 32))
              .foregroundColor(WatchTheme.gold)
              .padding(.top, 6)

            Text("Already Processed")
              .font(.system(size: 15, weight: .bold, design: .rounded))
              .foregroundColor(WatchTheme.offWhite)

            Text("This transaction is no longer in the pending review inbox.")
              .font(.system(size: 11))
              .foregroundColor(WatchTheme.slateMuted)
              .multilineTextAlignment(.center)

            Divider()
              .padding(.vertical, 2)

            // Return Options
            Button {
              navigation.routeToInbox()
            } label: {
              HStack {
                Image(systemName: "tray.fill")
                  .foregroundColor(WatchTheme.deepEmerald)
                Text("View Inbox (\(connectivity.snapshot.pendingInbox.count))")
                  .font(.system(size: 12, weight: .bold))
                  .foregroundColor(WatchTheme.deepEmerald)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
              .background(WatchTheme.gold)
              .cornerRadius(18)
            }
            .buttonStyle(.plain)

            Button {
              navigation.routeToHome()
            } label: {
              Text("Home")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WatchTheme.slateMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 8)
        }
      }
    }
    .navigationTitle("Review")
  }
}
