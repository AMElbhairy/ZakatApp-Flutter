import SwiftUI

/// Quick Add Menu displaying the 5 supported transaction actions.
public struct WatchQuickAddHomeView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityManager

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(spacing: 7) {
        // 1. Expense
        NavigationLink(destination: WatchExpenseQuickAddView()) {
          quickAddRow(
            title: "Expense",
            symbol: "arrow.up.right.circle.fill",
            color: WatchTheme.errorRed,
            subtitle: "Cash or Card"
          )
        }
        .buttonStyle(.plain)

        // 2. Income
        NavigationLink(destination: WatchIncomeQuickAddView()) {
          quickAddRow(
            title: "Income",
            symbol: "arrow.down.left.circle.fill",
            color: WatchTheme.successGreen,
            subtitle: "Cash or Card"
          )
        }
        .buttonStyle(.plain)

        // 3. Transfer
        NavigationLink(destination: WatchTransferQuickAddView()) {
          quickAddRow(
            title: "Transfer",
            symbol: "arrow.left.arrow.right.circle.fill",
            color: Color(red: 0.35, green: 0.65, blue: 0.95),
            subtitle: "Between Accounts"
          )
        }
        .buttonStyle(.plain)

        // 4. Currency Exchange
        NavigationLink(destination: WatchCurrencyExchangeQuickAddView()) {
          quickAddRow(
            title: "Currency Exchange",
            symbol: "coloncurrencysign.circle.fill",
            color: WatchTheme.gold,
            subtitle: "Authoritative FX"
          )
        }
        .buttonStyle(.plain)

        // 5. Credit Card Payment
        NavigationLink(destination: WatchCreditCardPaymentQuickAddView()) {
          quickAddRow(
            title: "Card Payment",
            symbol: "creditcard.fill",
            color: Color.orange,
            subtitle: "Pay Active Card"
          )
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 4)
      .padding(.top, 2)
    }
    .navigationTitle("Quick Add")
  }

  private func quickAddRow(
    title: String,
    symbol: String,
    color: Color,
    subtitle: String
  ) -> some View {
    HStack(spacing: 10) {
      Image(systemName: symbol)
        .font(.system(size: 20))
        .foregroundColor(color)
        .frame(width: 24, height: 24)

      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(WatchTheme.offWhite)
        Text(subtitle)
          .font(.system(size: 9))
          .foregroundColor(WatchTheme.slateMuted)
      }

      Spacer()

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
}
