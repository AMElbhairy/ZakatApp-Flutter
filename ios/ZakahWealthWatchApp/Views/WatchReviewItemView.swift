import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

private enum WatchHapticType {
  case success, failure, click
}

private func triggerWatchHaptic(_ type: WatchHapticType) {
  #if os(watchOS)
  switch type {
  case .success:
    WKInterfaceDevice.current().play(.success)
  case .failure:
    WKInterfaceDevice.current().play(.failure)
  case .click:
    WKInterfaceDevice.current().play(.click)
  }
  #endif
}

public struct WatchReviewItemView: View {
  @Environment(\.presentationMode) var presentationMode
  @ObservedObject var connectivity = WatchConnectivityManager.shared

  public let item: WatchPendingItem

  // Review & Correction State
  @State private var type: String
  @State private var amount: Double
  @State private var currency: String
  @State private var category: String
  @State private var paymentSourceId: String?
  @State private var merchantDescription: String

  // UI Flow State
  @State private var isProcessing: Bool = false
  @State private var isRejecting: Bool = false
  @State private var showRejectConfirmation: Bool = false
  @State private var errorMessage: String? = nil

  public init(item: WatchPendingItem) {
    self.item = item
    _type = State(initialValue: item.type.lowercased())
    _amount = State(initialValue: item.amount)
    _currency = State(initialValue: item.currency)
    _category = State(initialValue: item.category)
    _paymentSourceId = State(initialValue: item.paymentSourceId)
    _merchantDescription = State(initialValue: item.merchant)
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        // 1. AMOUNT HEADER (Prominent & Tappable for Correction)
        NavigationLink(
          destination: WatchAmountEditorView(amount: $amount, currency: currency)
        ) {
          VStack(spacing: 2) {
            Text("TAP TO EDIT AMOUNT")
              .font(.system(size: 9, weight: .bold))
              .foregroundColor(WatchTheme.slateMuted)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
              Text(currency)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(WatchTheme.gold)

              Text(String(format: "%.2f", amount))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(WatchTheme.offWhite)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(WatchTheme.cardSurface)
          .cornerRadius(10)
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(WatchTheme.gold.opacity(0.4), lineWidth: 1)
          )
        }
        .buttonStyle(.plain)

        // 2. MERCHANT / DESCRIPTION
        VStack(alignment: .leading, spacing: 2) {
          Text("MERCHANT / NOTE")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(WatchTheme.slateMuted)

          Text(merchantDescription.isEmpty ? "No description" : merchantDescription)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(WatchTheme.offWhite)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(WatchTheme.cardSurface)
        .cornerRadius(8)

        // 3. TYPE PICKER (Expense / Income / Transfer)
        HStack {
          Text("Type")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(WatchTheme.slateMuted)
          Spacer()
          Picker("Type", selection: $type) {
            Text("Expense").tag("expense")
            Text("Income").tag("income")
            Text("Transfer").tag("transfer")
          }
          .labelsHidden()
          .frame(width: 90, height: 32)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(WatchTheme.cardSurface)
        .cornerRadius(8)

        // 4. CATEGORY SELECTOR
        NavigationLink(
          destination: WatchCategoryPickerView(
            availableCategories: type == "income"
              ? connectivity.snapshot.incomeCategories
              : connectivity.snapshot.expenseCategories,
            selectedCategory: $category
          )
        ) {
          HStack {
            Text("Category")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(WatchTheme.slateMuted)
            Spacer()
            Text(category)
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(WatchTheme.gold)
              .lineLimit(1)
            Image(systemName: "chevron.right")
              .font(.system(size: 9, weight: .bold))
              .foregroundColor(WatchTheme.slateMuted)
          }
          .padding(8)
          .background(WatchTheme.cardSurface)
          .cornerRadius(8)
        }
        .buttonStyle(.plain)

        // 5. PAYMENT SOURCE SELECTOR
        NavigationLink(
          destination: WatchPaymentSourcePickerView(
            availableSources: connectivity.snapshot.paymentSources,
            selectedSourceId: $paymentSourceId
          )
        ) {
          HStack {
            Text("Account / Card")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(WatchTheme.slateMuted)
            Spacer()
            Text(selectedSourceDisplay)
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(WatchTheme.gold)
              .lineLimit(1)
            Image(systemName: "chevron.right")
              .font(.system(size: 9, weight: .bold))
              .foregroundColor(WatchTheme.slateMuted)
          }
          .padding(8)
          .background(WatchTheme.cardSurface)
          .cornerRadius(8)
        }
        .buttonStyle(.plain)

        // 6. DATE / TIME
        HStack {
          Text("Date")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(WatchTheme.slateMuted)
          Spacer()
          Text(formattedItemDate)
            .font(.system(size: 10))
            .foregroundColor(WatchTheme.slateMuted)
        }
        .padding(.horizontal, 8)

        // Feedback / Error Banner
        if let error = errorMessage {
          Text(error)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(WatchTheme.errorRed)
            .multilineTextAlignment(.center)
            .padding(6)
            .background(WatchTheme.errorRed.opacity(0.15))
            .cornerRadius(8)
        }

        Divider()
          .padding(.vertical, 2)

        // 7. ACTIONS (Approve & Reject)
        VStack(spacing: 8) {
          // APPROVE BUTTON
          Button {
            handleApprove()
          } label: {
            HStack {
              if isProcessing && !isRejecting {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .black))
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.black)
              }
              Text("Approve")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isProcessing ? WatchTheme.slateMuted : WatchTheme.successGreen)
            .cornerRadius(20)
          }
          .buttonStyle(.plain)
          .disabled(isProcessing)

          // REJECT BUTTON
          Button {
            showRejectConfirmation = true
          } label: {
            HStack {
              if isProcessing && isRejecting {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: WatchTheme.errorRed))
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "xmark.circle")
                  .foregroundColor(WatchTheme.errorRed)
              }
              Text("Reject")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WatchTheme.errorRed)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.clear)
            .overlay(
              RoundedRectangle(cornerRadius: 18)
                .stroke(WatchTheme.errorRed.opacity(0.6), lineWidth: 1)
            )
          }
          .buttonStyle(.plain)
          .disabled(isProcessing)
        }
      }
      .padding(.horizontal, 6)
      .padding(.bottom, 12)
    }
    .navigationTitle("Review")
    .confirmationDialog("Reject Transaction?", isPresented: $showRejectConfirmation, titleVisibility: .visible) {
      Button("Reject", role: .destructive) {
        handleReject()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This transaction will be ignored.")
    }
  }

  // MARK: - Actions

  private func handleApprove() {
    errorMessage = nil

    // Connectivity guard: Never queue writes offline in V1
    guard connectivity.isReachable else {
      errorMessage = "iPhone unavailable. Try again when connected."
      triggerWatchHaptic(.failure)
      return
    }

    isProcessing = true
    isRejecting = false
    let operationId = UUID().uuidString

    var payload: [String: Any] = [
      "pendingId": item.id,
      "type": type.lowercased(),
      "amount": amount,
      "currency": currency,
      "category": category,
      "description": merchantDescription,
      "date": item.date
    ]
    if let sourceId = paymentSourceId, !sourceId.isEmpty {
      payload["paymentSourceId"] = sourceId
    }

    connectivity.sendCommand(
      action: "approvePending",
      operationId: operationId,
      extraFields: payload
    ) { result in
      isProcessing = false

      if result.isSuccess {
        triggerWatchHaptic(.success)
        presentationMode.wrappedValue.dismiss()
      } else {
        triggerWatchHaptic(.failure)
        if result.code == "ITEM_ALREADY_PROCESSED" || (result.message?.contains("Already processed") ?? false) {
          errorMessage = "Already processed"
        } else {
          errorMessage = result.message ?? "Unable to complete"
        }
      }
    }
  }

  private func handleReject() {
    errorMessage = nil

    // Connectivity guard: Never queue writes offline in V1
    guard connectivity.isReachable else {
      errorMessage = "iPhone unavailable. Try again when connected."
      triggerWatchHaptic(.failure)
      return
    }

    isProcessing = true
    isRejecting = true
    let operationId = UUID().uuidString

    let payload: [String: Any] = [
      "pendingId": item.id,
      "reason": "Manually Ignored"
    ]

    connectivity.sendCommand(
      action: "rejectPending",
      operationId: operationId,
      extraFields: payload
    ) { result in
      isProcessing = false
      isRejecting = false

      if result.isSuccess {
        triggerWatchHaptic(.success)
        presentationMode.wrappedValue.dismiss()
      } else {
        triggerWatchHaptic(.failure)
        if result.code == "ITEM_ALREADY_PROCESSED" || (result.message?.contains("Already processed") ?? false) {
          errorMessage = "Already processed"
        } else {
          errorMessage = result.message ?? "Unable to complete"
        }
      }
    }
  }

  // MARK: - Helpers

  private var selectedSourceDisplay: String {
    if let sourceId = paymentSourceId {
      if let found = connectivity.snapshot.paymentSources.first(where: { $0.id == sourceId }) {
        return found.name
      }
    }
    if let card4 = item.cardLast4, !card4.isEmpty {
      return "•••• \(card4)"
    } else if let acc4 = item.accountLast4, !acc4.isEmpty {
      return "•••• \(acc4)"
    }
    return "Cash Wallet"
  }

  private var formattedItemDate: String {
    if item.date.count >= 10 {
      return String(item.date.prefix(10))
    }
    return item.date
  }
}

// MARK: - Child Pickers & Editors (Native watchOS Screens)

public struct WatchAmountEditorView: View {
  @Environment(\.presentationMode) var presentationMode
  @Binding var amount: Double
  let currency: String

  public var body: some View {
    VStack(spacing: 8) {
      Text("\(currency) \(String(format: "%.2f", amount))")
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .foregroundColor(WatchTheme.gold)
        .padding(.top, 4)

      HStack(spacing: 6) {
        Button("-10") {
          adjust(by: -10)
        }
        .buttonStyle(.bordered)

        Button("-1") {
          adjust(by: -1)
        }
        .buttonStyle(.bordered)

        Button("+1") {
          adjust(by: 1)
        }
        .buttonStyle(.bordered)

        Button("+10") {
          adjust(by: 10)
        }
        .buttonStyle(.bordered)
      }
      .font(.system(size: 11, weight: .bold))

      HStack(spacing: 8) {
        Button("-0.50") {
          adjust(by: -0.50)
        }
        .buttonStyle(.bordered)

        Button("+0.50") {
          adjust(by: 0.50)
        }
        .buttonStyle(.bordered)
      }
      .font(.system(size: 11, weight: .bold))

      Spacer()

      Button("Done") {
        presentationMode.wrappedValue.dismiss()
      }
      .font(.system(size: 13, weight: .bold))
      .foregroundColor(.black)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
      .background(WatchTheme.gold)
      .cornerRadius(18)
    }
    .padding(.horizontal, 4)
    .navigationTitle("Amount")
    #if os(watchOS)
    .focusable()
    .digitalCrownRotation($amount, from: 0.01, through: 999999.0, by: 1.0, sensitivity: .medium)
    #endif
  }

  private func adjust(by delta: Double) {
    let next = amount + delta
    if next >= 0.01 {
      amount = (next * 100).rounded() / 100
      triggerWatchHaptic(.click)
    }
  }
}

public struct WatchCategoryPickerView: View {
  @Environment(\.presentationMode) var presentationMode
  let availableCategories: [String]
  @Binding var selectedCategory: String

  public var body: some View {
    List {
      if availableCategories.isEmpty {
        Text("No categories found")
          .font(.system(size: 11))
          .foregroundColor(WatchTheme.slateMuted)
      } else {
        ForEach(availableCategories, id: \.self) { cat in
          Button {
            selectedCategory = cat
            triggerWatchHaptic(.click)
            presentationMode.wrappedValue.dismiss()
          } label: {
            HStack {
              Text(cat)
                .font(.system(size: 12, weight: cat == selectedCategory ? .bold : .medium))
                .foregroundColor(cat == selectedCategory ? WatchTheme.gold : WatchTheme.offWhite)
              Spacer()
              if cat == selectedCategory {
                Image(systemName: "checkmark")
                  .foregroundColor(WatchTheme.gold)
                  .font(.system(size: 10, weight: .bold))
              }
            }
          }
        }
      }
    }
    .navigationTitle("Category")
  }
}

public struct WatchPaymentSourcePickerView: View {
  @Environment(\.presentationMode) var presentationMode
  let availableSources: [WatchPaymentSource]
  @Binding var selectedSourceId: String?

  public var body: some View {
    List {
      if availableSources.isEmpty {
        Text("No sources found")
          .font(.system(size: 11))
          .foregroundColor(WatchTheme.slateMuted)
      } else {
        ForEach(availableSources) { src in
          Button {
            selectedSourceId = src.id
            triggerWatchHaptic(.click)
            presentationMode.wrappedValue.dismiss()
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(src.name)
                  .font(.system(size: 12, weight: src.id == selectedSourceId ? .bold : .medium))
                  .foregroundColor(src.id == selectedSourceId ? WatchTheme.gold : WatchTheme.offWhite)
                Text(src.currency)
                  .font(.system(size: 9))
                  .foregroundColor(WatchTheme.slateMuted)
              }
              Spacer()
              if src.id == selectedSourceId {
                Image(systemName: "checkmark")
                  .foregroundColor(WatchTheme.gold)
                  .font(.system(size: 10, weight: .bold))
              }
            }
          }
        }
      }
    }
    .navigationTitle("Account / Card")
  }
}
