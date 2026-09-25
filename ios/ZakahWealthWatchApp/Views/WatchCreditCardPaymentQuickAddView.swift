import SwiftUI
#if os(watchOS)
import WatchKit
#endif

/// Lightweight Watch-native flow for Credit Card Payment.
public struct WatchCreditCardPaymentQuickAddView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityManager
  @Environment(\.presentationMode) private var presentationMode

  @State private var selectedCardId: String = ""
  @State private var selectedSourceId: String = "cash"
  @State private var amount: Double = 0.0

  @State private var currentStep: FlowStep = .selection

  private enum FlowStep {
    case selection
    case amount
    case review
  }

  public init() {}

  private var activeCards: [WatchPaymentSource] {
    return connectivity.snapshot.paymentSources.filter { $0.type == "card" }
  }

  private var selectedCard: WatchPaymentSource? {
    return activeCards.first(where: { $0.id == selectedCardId }) ?? activeCards.first
  }

  private var cardCurrency: String {
    return selectedCard?.currency ?? connectivity.snapshot.mainCurrency
  }

  private var cardDisplayName: String {
    guard let card = selectedCard else { return "No Card" }
    if let last4 = card.last4, !last4.isEmpty {
      return "\(card.name) ••\(last4)"
    }
    return card.name
  }

  public var body: some View {
    VStack {
      switch currentStep {
      case .selection:
        selectionView

      case .amount:
        WatchAmountPadView(
          amount: $amount,
          currency: cardCurrency,
          title: "Payment Amount"
        ) {
          currentStep = .review
        }

      case .review:
        WatchQuickAddReviewView(
          actionTitle: "Card Payment",
          amount: amount,
          currency: cardCurrency,
          sourceName: "Cash Wallet",
          destinationName: cardDisplayName,
          category: "Credit Card Payment",
          submissionAction: "creditCardPayment",
          extraFields: [
            "cardId": selectedCard?.id ?? selectedCardId,
            "paymentSourceId": selectedSourceId
          ],
          onDone: {
            presentationMode.wrappedValue.dismiss()
          }
        )
      }
    }
    .navigationTitle("Card Payment")
    .onAppear {
      if selectedCardId.isEmpty, let first = activeCards.first {
        selectedCardId = first.id
      }
    }
  }

  private var selectionView: some View {
    ScrollView {
      VStack(spacing: 8) {
        if activeCards.isEmpty {
          VStack(spacing: 6) {
            Image(systemName: "creditcard")
              .font(.system(size: 24))
              .foregroundColor(WatchTheme.slateMuted)
            Text("No Active Credit Cards")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(WatchTheme.offWhite)
            Text("Add a card on iPhone to make card payments.")
              .font(.system(size: 9))
              .foregroundColor(WatchTheme.slateMuted)
              .multilineTextAlignment(.center)
          }
          .padding()
        } else {
          // Select Credit Card
          VStack(alignment: .leading, spacing: 2) {
            Text("Card to Pay")
              .font(.system(size: 10))
              .foregroundColor(WatchTheme.slateMuted)

            Picker("", selection: $selectedCardId) {
              ForEach(activeCards) { card in
                Text(card.last4 != nil ? "\(card.name) (••\(card.last4!))" : card.name)
                  .tag(card.id)
              }
            }
            .pickerStyle(.navigationLink)
            .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 34)
            .multilineTextAlignment(.center)
          }
          .padding(6)
          .background(WatchTheme.cardSurface)
          .cornerRadius(8)

          // Payment Source
          VStack(alignment: .leading, spacing: 2) {
            Text("Paid From")
              .font(.system(size: 10))
              .foregroundColor(WatchTheme.slateMuted)

            Picker("", selection: $selectedSourceId) {
              Text("Cash Wallet").tag("cash")
            }
            .pickerStyle(.navigationLink)
            .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 34)
            .multilineTextAlignment(.center)
          }
          .padding(6)
          .background(WatchTheme.cardSurface)
          .cornerRadius(8)

          // Continue
          Button {
            currentStep = .amount
          } label: {
            HStack {
              Text("Enter Amount")
                .font(.system(size: 13, weight: .bold))
              Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(WatchTheme.deepEmerald)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(WatchTheme.gold)
            .cornerRadius(10)
          }
          .buttonStyle(.plain)
          .padding(.top, 4)
        }
      }
      .padding(.horizontal, 4)
    }
  }
}
