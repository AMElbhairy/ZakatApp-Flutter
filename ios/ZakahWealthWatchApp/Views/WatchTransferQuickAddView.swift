import SwiftUI
#if os(watchOS)
import WatchKit
#endif

/// Lightweight Watch-native flow for Account Transfer.
public struct WatchTransferQuickAddView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityManager
  @Environment(\.presentationMode) private var presentationMode

  @State private var fromAccountId: String = "cash"
  @State private var toAccountId: String = ""
  @State private var amount: Double = 0.0
  @State private var currency: String = "SAR"

  @State private var currentStep: FlowStep = .accounts

  private enum FlowStep {
    case accounts
    case amount
    case review
  }

  public init() {}

  private var isValidAccountPair: Bool {
    return !fromAccountId.isEmpty && !toAccountId.isEmpty && fromAccountId != toAccountId
  }

  private func displayName(for id: String) -> String {
    if id == "cash" { return "Cash Wallet" }
    if let card = connectivity.snapshot.paymentSources.first(where: { $0.id == id }) {
      if let last4 = card.last4, !last4.isEmpty {
        return "\(card.name) ••\(last4)"
      }
      return card.name
    }
    return id
  }

  public var body: some View {
    VStack {
      switch currentStep {
      case .accounts:
        accountsView

      case .amount:
        WatchAmountPadView(
          amount: $amount,
          currency: currency,
          title: "Transfer Amount"
        ) {
          currentStep = .review
        }

      case .review:
        WatchQuickAddReviewView(
          actionTitle: "Transfer",
          amount: amount,
          currency: currency,
          sourceName: displayName(for: fromAccountId),
          destinationName: displayName(for: toAccountId),
          category: "Account Transfer",
          submissionAction: "createTransaction",
          extraFields: [
            "type": "transfer",
            "transferSourceId": fromAccountId,
            "transferDestinationId": toAccountId,
            "category": "Account Transfer"
          ],
          onDone: {
            presentationMode.wrappedValue.dismiss()
          }
        )
      }
    }
    .navigationTitle("Transfer")
    .onAppear {
      if currency == "SAR" && !connectivity.snapshot.mainCurrency.isEmpty {
        currency = connectivity.snapshot.mainCurrency
      }
      // Initialize toAccountId to the first card if available
      if toAccountId.isEmpty {
        if let firstCard = connectivity.snapshot.paymentSources.first(where: { $0.type == "card" }) {
          toAccountId = firstCard.id
        } else {
          toAccountId = "cash"
        }
      }
    }
  }

  private var accountsView: some View {
    ScrollView {
      VStack(spacing: 8) {
        // From Account Picker
        VStack(alignment: .leading, spacing: 2) {
          Text("Transfer From")
            .font(.system(size: 10))
            .foregroundColor(WatchTheme.slateMuted)

          Picker("", selection: $fromAccountId) {
            Text("Cash Wallet").tag("cash")
            ForEach(connectivity.snapshot.paymentSources) { source in
              if source.type == "card" {
                Text(source.last4 != nil ? "\(source.name) (••\(source.last4!))" : source.name)
                  .tag(source.id)
              }
            }
          }
          .pickerStyle(.navigationLink)
          .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 34)
          .multilineTextAlignment(.center)
        }
        .padding(6)
        .background(WatchTheme.cardSurface)
        .cornerRadius(8)

        // Arrow Indicator
        Image(systemName: "arrow.down")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(WatchTheme.gold)

        // To Account Picker
        VStack(alignment: .leading, spacing: 2) {
          Text("Transfer To")
            .font(.system(size: 10))
            .foregroundColor(WatchTheme.slateMuted)

          Picker("", selection: $toAccountId) {
            Text("Cash Wallet").tag("cash")
            ForEach(connectivity.snapshot.paymentSources) { source in
              if source.type == "card" {
                Text(source.last4 != nil ? "\(source.name) (••\(source.last4!))" : source.name)
                  .tag(source.id)
              }
            }
          }
          .pickerStyle(.navigationLink)
          .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 34)
          .multilineTextAlignment(.center)
        }
        .padding(6)
        .background(WatchTheme.cardSurface)
        .cornerRadius(8)

        if fromAccountId == toAccountId {
          Text("Source and destination must be different.")
            .font(.system(size: 9))
            .foregroundColor(WatchTheme.errorRed)
            .multilineTextAlignment(.center)
        }

        // Continue to Amount
        Button {
          currentStep = .amount
        } label: {
          HStack {
            Text("Enter Amount")
              .font(.system(size: 13, weight: .bold))
            Image(systemName: "arrow.right")
              .font(.system(size: 11, weight: .bold))
          }
          .foregroundColor(isValidAccountPair ? WatchTheme.deepEmerald : WatchTheme.slateMuted)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 9)
          .background(isValidAccountPair ? WatchTheme.gold : WatchTheme.cardSurface)
          .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(!isValidAccountPair)
        .padding(.top, 4)
      }
      .padding(.horizontal, 4)
    }
  }
}
