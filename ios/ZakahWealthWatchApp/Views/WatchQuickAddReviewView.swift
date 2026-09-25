import SwiftUI
#if os(watchOS)
import WatchKit
#endif

/// Unified review and authoritative confirmation screen for all Quick Add operations.
public struct WatchQuickAddReviewView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityManager
  @Environment(\.presentationMode) private var presentationMode

  public let actionTitle: String
  public let amount: Double
  public let currency: String
  public let sourceName: String?
  public let destinationName: String?
  public let targetAmount: Double?
  public let targetCurrency: String?
  public let category: String?
  public let descriptionText: String?
  public let date: String
  public let submissionAction: String
  public let extraFields: [String: Any]
  public let onDone: (() -> Void)?

  @State private var submissionState: SubmissionState = .review
  @State private var errorMessage: String = ""
  @State private var submittedOperationId: String?

  private enum SubmissionState {
    case review
    case submitting
    case success
    case failure
  }

  public init(
    actionTitle: String,
    amount: Double,
    currency: String,
    sourceName: String? = nil,
    destinationName: String? = nil,
    targetAmount: Double? = nil,
    targetCurrency: String? = nil,
    category: String? = nil,
    descriptionText: String? = nil,
    date: String = "Today",
    submissionAction: String,
    extraFields: [String: Any],
    onDone: (() -> Void)? = nil
  ) {
    self.actionTitle = actionTitle
    self.amount = amount
    self.currency = currency
    self.sourceName = sourceName
    self.destinationName = destinationName
    self.targetAmount = targetAmount
    self.targetCurrency = targetCurrency
    self.category = category
    self.descriptionText = descriptionText
    self.date = date
    self.submissionAction = submissionAction
    self.extraFields = extraFields
    self.onDone = onDone
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        switch submissionState {
        case .review:
          reviewContent

        case .submitting:
          submittingContent

        case .success:
          successContent

        case .failure:
          failureContent
        }
      }
      .padding(.horizontal, 4)
    }
    .navigationTitle(actionTitle)
  }

  // MARK: - Review State View
  private var reviewContent: some View {
    VStack(spacing: 8) {
      // Primary Amount Display
      VStack(spacing: 2) {
        Text(actionTitle.uppercased())
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(WatchTheme.slateMuted)

        if let targetAmt = targetAmount, let targetCurr = targetCurrency {
          // Currency Exchange paired display
          Text("\(currency) \(String(format: "%.2f", amount))")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(WatchTheme.offWhite)

          Image(systemName: "arrow.down")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(WatchTheme.gold)

          Text("\(targetCurr) \(String(format: "%.2f", targetAmt))")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(WatchTheme.gold)
        } else {
          Text("\(currency) \(String(format: "%.2f", amount))")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(WatchTheme.gold)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(WatchTheme.cardSurface)
      .cornerRadius(10)
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(WatchTheme.cardBorder, lineWidth: 1)
      )

      // Details Card
      VStack(spacing: 6) {
        if let category = category, !category.isEmpty {
          detailRow(title: "Category", value: category)
        }

        if let source = sourceName, let dest = destinationName {
          // Transfer or Card Payment: Source -> Destination
          detailRow(title: "From", value: source)
          detailRow(title: "To", value: dest)
        } else if let source = sourceName {
          detailRow(title: "Paid From", value: source)
        } else if let dest = destinationName {
          detailRow(title: "Deposit To", value: dest)
        }

        if let desc = descriptionText, !desc.trimmingCharacters(in: .whitespaces).isEmpty {
          detailRow(title: "Note", value: desc)
        }

        detailRow(title: "Date", value: date)
      }
      .padding(8)
      .background(WatchTheme.cardSurface.opacity(0.7))
      .cornerRadius(8)

      // Action Buttons
      VStack(spacing: 6) {
        Button {
          submitTransaction()
        } label: {
          HStack {
            Image(systemName: "checkmark.circle.fill")
            Text("Confirm")
              .font(.system(size: 14, weight: .bold))
          }
          .foregroundColor(WatchTheme.deepEmerald)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(WatchTheme.gold)
          .cornerRadius(10)
        }
        .buttonStyle(.plain)

        Button {
          presentationMode.wrappedValue.dismiss()
        } label: {
          Text("Cancel")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(WatchTheme.slateMuted)
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 4)
    }
  }

  // MARK: - Submitting State View
  private var submittingContent: some View {
    VStack(spacing: 12) {
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: WatchTheme.gold))
        .scaleEffect(1.2)
        .padding(.top, 16)

      Text("Submitting to iPhone...")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(WatchTheme.offWhite)

      Text("Awaiting authoritative confirmation")
        .font(.system(size: 9))
        .foregroundColor(WatchTheme.slateMuted)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding()
  }

  // MARK: - Success State View
  private var successContent: some View {
    VStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 36))
        .foregroundColor(WatchTheme.successGreen)
        .padding(.top, 8)

      Text("\(actionTitle) Added")
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(WatchTheme.offWhite)

      Text("\(currency) \(String(format: "%.2f", amount))")
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundColor(WatchTheme.gold)

      Button {
        if let onDone = onDone {
          onDone()
        } else {
          presentationMode.wrappedValue.dismiss()
        }
      } label: {
        Text("Done")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(WatchTheme.deepEmerald)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(WatchTheme.gold)
          .cornerRadius(10)
      }
      .buttonStyle(.plain)
      .padding(.top, 8)
    }
    .frame(maxWidth: .infinity)
    .padding()
  }

  // MARK: - Failure State View
  private var failureContent: some View {
    VStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 30))
        .foregroundColor(WatchTheme.errorRed)
        .padding(.top, 4)

      Text("Unable to Complete")
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(WatchTheme.offWhite)

      Text(errorMessage.isEmpty ? "iPhone unavailable. Try again when connected." : errorMessage)
        .font(.system(size: 10))
        .foregroundColor(WatchTheme.slateMuted)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 4)

      VStack(spacing: 6) {
        Button {
          submitTransaction()
        } label: {
          Text("Retry")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(WatchTheme.deepEmerald)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(WatchTheme.gold)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)

        Button {
          submissionState = .review
        } label: {
          Text("Back to Review")
            .font(.system(size: 11))
            .foregroundColor(WatchTheme.slateMuted)
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity)
    .padding()
  }

  private func detailRow(title: String, value: String) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 10))
        .foregroundColor(WatchTheme.slateMuted)
      Spacer()
      Text(value)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(WatchTheme.offWhite)
        .lineLimit(1)
    }
  }

  private func submitTransaction() {
    // Generate idempotent operationId
    let opId = submittedOperationId ?? UUID().uuidString
    submittedOperationId = opId

    submissionState = .submitting

    var payload = extraFields
    payload["amount"] = amount
    payload["currency"] = currency

    connectivity.sendCommand(action: submissionAction, operationId: opId, extraFields: payload) { result in
      if result.isSuccess {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
        submissionState = .success
      } else {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.failure)
        #endif
        errorMessage = result.message ?? "Failed to create transaction."
        submissionState = .failure
      }
    }
  }
}
