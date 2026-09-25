import SwiftUI

public struct WatchInboxView: View {
  @ObservedObject var connectivity = WatchConnectivityManager.shared

  public init() {}

  public var body: some View {
    let pendingItems = connectivity.snapshot.pendingInbox

    Group {
      if pendingItems.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 36))
            .foregroundColor(WatchTheme.successGreen)
            .padding(.bottom, 2)

          Text("Inbox Clear")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(WatchTheme.offWhite)

          Text("No pending items to review.")
            .font(.system(size: 11))
            .foregroundColor(WatchTheme.slateMuted)
            .multilineTextAlignment(.center)
        }
        .padding()
      } else {
        List {
          ForEach(pendingItems) { item in
            NavigationLink(destination: WatchReviewItemView(item: item)) {
              WatchInboxRow(item: item)
            }
            .listRowBackground(
              RoundedRectangle(cornerRadius: 12)
                .fill(WatchTheme.cardSurface)
                .overlay(
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(WatchTheme.cardBorder, lineWidth: 1)
                )
            )
            .padding(.vertical, 2)
          }
        }
        .listStyle(.plain)
      }
    }
    .navigationTitle("Inbox (\(pendingItems.count))")
  }
}

private struct WatchInboxRow: View {
  let item: WatchPendingItem

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Top row: Merchant name
      Text(item.merchant.isEmpty ? "Unknown Merchant" : item.merchant)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(WatchTheme.offWhite)
        .lineLimit(1)

      // Amount row: large prominent amount
      Text("\(item.currency) \(String(format: "%.2f", item.amount))")
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundColor(WatchTheme.gold)

      // Subtitle: Type • Card or Source
      HStack(spacing: 4) {
        Text(item.type.capitalized)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(WatchTheme.slateMuted)

        Text("•")
          .font(.system(size: 9))
          .foregroundColor(WatchTheme.slateMuted)

        Text(sourceSummary)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(WatchTheme.slateMuted)
          .lineLimit(1)
      }
    }
    .padding(.vertical, 4)
  }

  private var sourceSummary: String {
    if let card4 = item.cardLast4, !card4.isEmpty {
      return "•••• \(card4)"
    } else if let acc4 = item.accountLast4, !acc4.isEmpty {
      return "•••• \(acc4)"
    } else if let bank = item.detectedBank, !bank.isEmpty {
      return bank
    } else {
      return "Cash / Default"
    }
  }
}
