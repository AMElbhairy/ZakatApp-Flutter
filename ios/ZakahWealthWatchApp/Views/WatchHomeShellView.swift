import SwiftUI

public struct WatchHomeShellView: View {
  @ObservedObject var connectivity = WatchConnectivityManager.shared
  @ObservedObject var navigation = WatchNavigationManager.shared
  @State private var pingStatusText: String?
  @State private var pingIsSuccess: Bool = false
  @State private var isInboxActive: Bool = false
  @State private var isReviewActive: Bool = false

  public init() {}

  public var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 12) {
          // App Header
          HStack {
            Circle()
              .fill(WatchTheme.gold)
              .frame(width: 8, height: 8)
            Text("ZAKAH WEALTH")
              .font(.system(size: 11, weight: .bold, design: .rounded))
              .foregroundColor(WatchTheme.gold)
            Spacer()
            // Connection pill
            HStack(spacing: 4) {
              Circle()
                .fill(connectivity.isReachable ? WatchTheme.successGreen : WatchTheme.slateMuted)
                .frame(width: 6, height: 6)
              Text(connectivity.isReachable ? "Connected" : "Offline")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(connectivity.isReachable ? WatchTheme.offWhite : WatchTheme.slateMuted)
            }
          }
          .padding(.horizontal, 4)

          // Foundation Sync Card (Presentation Cache)
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text("Presentation Cache")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(WatchTheme.slateMuted)
              Spacer()
              Text("v\(connectivity.snapshot.v)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(WatchTheme.goldMuted)
            }

            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text("\(connectivity.snapshot.pendingInbox.count)")
                  .font(.system(size: 20, weight: .bold, design: .rounded))
                  .foregroundColor(WatchTheme.offWhite)
                Text("Pending Inbox")
                  .font(.system(size: 10))
                  .foregroundColor(WatchTheme.slateMuted)
              }
              Spacer()
              VStack(alignment: .trailing, spacing: 2) {
                Text(connectivity.snapshot.mainCurrency)
                  .font(.system(size: 18, weight: .bold, design: .rounded))
                  .foregroundColor(WatchTheme.gold)
                Text("Main Currency")
                  .font(.system(size: 10))
                  .foregroundColor(WatchTheme.slateMuted)
              }
            }

            if let lastSync = connectivity.lastSyncDate {
              Text("Synced: \(lastSync, style: .time)")
                .font(.system(size: 9))
                .foregroundColor(WatchTheme.slateMuted)
            } else {
              Text("Awaiting first sync from iPhone")
                .font(.system(size: 9))
                .foregroundColor(WatchTheme.slateMuted)
            }
          }
          .padding(10)
          .background(WatchTheme.cardSurface)
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(WatchTheme.cardBorder, lineWidth: 1)
          )

          #if DEBUG
          // Developer-only diagnostic ping. Never shown in Release builds.
          Button {
            pingStatusText = "Pinging iPhone..."
            connectivity.sendPingTest { result in
              pingIsSuccess = result.isSuccess
              if result.isSuccess {
                pingStatusText = "Pong! Response: \(result.code) (\(result.message ?? "OK"))"
              } else {
                pingStatusText = "Error [\(result.code)]: \(result.message ?? "Unavailable")"
              }
            }
          } label: {
            HStack {
              if connectivity.isExecutingCommand {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: WatchTheme.deepEmerald))
                  .scaleEffect(0.7)
              } else {
                Image(systemName: "bolt.horizontal.fill")
                  .foregroundColor(WatchTheme.deepEmerald)
              }
              Text("Test Bridge")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(WatchTheme.deepEmerald)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(WatchTheme.gold)
            .cornerRadius(10)
          }
          .buttonStyle(.plain)
          .disabled(connectivity.isExecutingCommand)

          if let status = pingStatusText {
            Text(status)
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(pingIsSuccess ? WatchTheme.successGreen : WatchTheme.errorRed)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 4)
          }
          #endif

          Divider()
            .padding(.vertical, 2)

          // Destinations (Shelled for Phases 3 - 6)
          VStack(spacing: 8) {
            // Hidden programmatic navigation link for notification deep-linked review
            if let pendingId = navigation.deepLinkedPendingId {
              NavigationLink(
                destination: WatchPendingResolverView(pendingId: pendingId),
                isActive: $isReviewActive
              ) {
                EmptyView()
              }
              .hidden()
            }

            NavigationLink(
              destination: WatchInboxView(),
              isActive: $isInboxActive
            ) {
              HStack {
                Image(systemName: "tray.fill")
                  .foregroundColor(WatchTheme.gold)
                Text("Inbox")
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundColor(WatchTheme.offWhite)
                Spacer()
                Text(connectivity.snapshot.pendingInbox.isEmpty
                     ? "0 Pending"
                     : "\(connectivity.snapshot.pendingInbox.count) Pending")
                  .font(.system(size: 11, weight: .medium))
                  .foregroundColor(connectivity.snapshot.pendingInbox.isEmpty
                                   ? WatchTheme.slateMuted
                                   : WatchTheme.gold)
                Image(systemName: "chevron.right")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundColor(WatchTheme.slateMuted)
              }
              .padding(10)
              .background(WatchTheme.cardSurface)
              .cornerRadius(10)
              .overlay(
                RoundedRectangle(cornerRadius: 10)
                  .stroke(WatchTheme.cardBorder, lineWidth: 1)
              )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: WatchQuickAddHomeView()) {
              HStack {
                Image(systemName: "plus.circle.fill")
                  .foregroundColor(WatchTheme.gold)
                Text("Quick Add")
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundColor(WatchTheme.offWhite)
                Spacer()
                Text("New")
                  .font(.system(size: 11, weight: .medium))
                  .foregroundColor(WatchTheme.gold)
                Image(systemName: "chevron.right")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundColor(WatchTheme.slateMuted)
              }
              .padding(10)
              .background(WatchTheme.cardSurface)
              .cornerRadius(10)
              .overlay(
                RoundedRectangle(cornerRadius: 10)
                  .stroke(WatchTheme.cardBorder, lineWidth: 1)
              )
            }
            .buttonStyle(.plain)

            HStack {
              Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(WatchTheme.gold)
              Text("Activity")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WatchTheme.offWhite)
              Spacer()
              Text("Phase 6")
                .font(.system(size: 9))
                .foregroundColor(WatchTheme.slateMuted)
            }
            .padding(10)
            .background(WatchTheme.cardSurface.opacity(0.6))
            .cornerRadius(8)
          }
        }
        .padding(.horizontal, 6)
      }
    }
    .onReceive(navigation.$activeRoute) { route in
      switch route {
      case .home:
        isInboxActive = false
        isReviewActive = false
      case .inbox:
        isReviewActive = false
        isInboxActive = true
      case .reviewPending:
        isInboxActive = false
        isReviewActive = true
      }
    }
  }
}
