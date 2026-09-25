import SwiftUI
#if os(watchOS)
import WatchKit
#endif

/// Lightweight Watch-native flow for recording Income.
public struct WatchIncomeQuickAddView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityManager
  @Environment(\.presentationMode) private var presentationMode

  @State private var amount: Double = 0.0
  @State private var currency: String = "SAR"
  @State private var selectedDestinationId: String = "cash"
  @State private var selectedCategory: String = "Salary"
  @State private var note: String = ""

  @State private var currentStep: FlowStep = .amount

  private enum FlowStep {
    case amount
    case details
    case review
  }

  public init() {}

  private var destinationDisplayName: String {
    if selectedDestinationId == "cash" {
      return "Cash Wallet"
    }
    if let card = connectivity.snapshot.paymentSources.first(where: { $0.id == selectedDestinationId }) {
      if let last4 = card.last4, !last4.isEmpty {
        return "\(card.name) •••• \(last4)"
      }
      return card.name
    }
    return "Cash Wallet"
  }

  public var body: some View {
    VStack {
      switch currentStep {
      case .amount:
        WatchAmountPadView(
          amount: $amount,
          currency: currency,
          title: "Income Amount"
        ) {
          currentStep = .details
        }

      case .details:
        detailsView

      case .review:
        WatchQuickAddReviewView(
          actionTitle: "Income",
          amount: amount,
          currency: currency,
          destinationName: destinationDisplayName,
          category: selectedCategory,
          descriptionText: note.isEmpty ? nil : note,
          submissionAction: "createTransaction",
          extraFields: [
            "type": "income",
            "category": selectedCategory,
            "paymentSourceId": selectedDestinationId,
            "description": note
          ],
          onDone: {
            presentationMode.wrappedValue.dismiss()
          }
        )
      }
    }
    .navigationTitle("Income")
    .onAppear {
      if currency == "SAR" && !connectivity.snapshot.mainCurrency.isEmpty {
        currency = connectivity.snapshot.mainCurrency
      }
      if let firstCat = connectivity.snapshot.incomeCategories.first {
        selectedCategory = firstCat
      }
    }
  }

  private var detailsView: some View {
    ScrollView {
      VStack(spacing: 8) {
        // Amount and Currency Summary Pill
        HStack {
          Text("\(currency) \(String(format: "%.2f", amount))")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(WatchTheme.successGreen)
          Spacer()
          Button {
            currentStep = .amount
          } label: {
            Text("Edit")
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(WatchTheme.slateMuted)
          }
          .buttonStyle(.plain)
        }
        .padding(8)
        .background(WatchTheme.cardSurface)
        .cornerRadius(8)

        // Destination Picker (Cash or Credit Cards)
        VStack(alignment: .leading, spacing: 2) {
          Text("Deposit To")
            .font(.system(size: 10))
            .foregroundColor(WatchTheme.slateMuted)

          Picker("", selection: $selectedDestinationId) {
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
        .background(WatchTheme.cardSurface.opacity(0.8))
        .cornerRadius(8)

        // Income Category Picker
        VStack(alignment: .leading, spacing: 2) {
          Text("Category")
            .font(.system(size: 10))
            .foregroundColor(WatchTheme.slateMuted)

          Picker("", selection: $selectedCategory) {
            if connectivity.snapshot.incomeCategories.isEmpty {
              Text("Salary").tag("Salary")
              Text("Bonus").tag("Bonus")
              Text("Investment Returns").tag("Investment Returns")
              Text("Other Income").tag("Other Income")
            } else {
              ForEach(connectivity.snapshot.incomeCategories, id: \.self) { cat in
                Text(cat).tag(cat)
              }
            }
          }
          .pickerStyle(.navigationLink)
          .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 34)
          .multilineTextAlignment(.center)
        }
        .padding(6)
        .background(WatchTheme.cardSurface.opacity(0.8))
        .cornerRadius(8)

        // Currency Picker
        if connectivity.snapshot.currencies.count > 1 {
          VStack(alignment: .leading, spacing: 2) {
            Text("Currency")
              .font(.system(size: 10))
              .foregroundColor(WatchTheme.slateMuted)

            Picker("", selection: $currency) {
              ForEach(connectivity.snapshot.currencies, id: \.self) { curr in
                Text(curr).tag(curr)
              }
            }
            .pickerStyle(.navigationLink)
            .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 34)
            .multilineTextAlignment(.center)
          }
          .padding(6)
          .background(WatchTheme.cardSurface.opacity(0.8))
          .cornerRadius(8)
        }

        // Proceed to Review
        Button {
          currentStep = .review
        } label: {
          HStack {
            Text("Review")
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
      .padding(.horizontal, 4)
    }
  }
}
