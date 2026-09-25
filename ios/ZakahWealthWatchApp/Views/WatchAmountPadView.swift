import SwiftUI
#if os(watchOS)
import WatchKit
#endif

/// Reusable Apple Watch numeric amount pad supporting arbitrary amounts
/// (e.g., 25, 126.50, 1,250, 10,000, 50,000) with Digital Crown fine-tuning.
public struct WatchAmountPadView: View {
  @Binding public var amount: Double
  public let currency: String
  public let title: String
  public let onContinue: () -> Void

  @State private var amountString: String = ""
  @State private var crownValue: Double = 0.0

  public init(
    amount: Binding<Double>,
    currency: String,
    title: String = "Enter Amount",
    onContinue: @escaping () -> Void
  ) {
    self._amount = amount
    self.currency = currency
    self.title = title
    self.onContinue = onContinue
  }

  private var formattedDisplay: String {
    if amountString.isEmpty {
      return "0.00"
    }
    return amountString
  }

  private var canContinue: Bool {
    return (Double(amountString) ?? amount) > 0.0
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 6) {
        // Title and Currency Indicator
        HStack {
          Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(WatchTheme.slateMuted)
          Spacer()
          Text(currency)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(WatchTheme.gold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(WatchTheme.gold.opacity(0.15))
            .cornerRadius(6)
        }
        .padding(.horizontal, 4)

        // Amount Display Header
        HStack(alignment: .firstTextBaseline, spacing: 3) {
          Text(formattedDisplay)
            .font(.system(size: amountString.count > 6 ? 20 : 24, weight: .bold, design: .rounded))
            .foregroundColor(canContinue ? WatchTheme.offWhite : WatchTheme.slateMuted)
            .minimumScaleFactor(0.6)
            .lineLimit(1)

          Text(currency)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(WatchTheme.gold)

          Spacer()

          if !amountString.isEmpty {
            Button {
              clearInput()
            } label: {
              Text("C")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(WatchTheme.errorRed)
                .frame(width: 22, height: 22)
                .background(WatchTheme.cardSurface)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(WatchTheme.cardSurface)
        .cornerRadius(8)

        // 3x4 Keypad Grid
        VStack(spacing: 4) {
          HStack(spacing: 4) {
            keypadButton("1")
            keypadButton("2")
            keypadButton("3")
          }
          HStack(spacing: 4) {
            keypadButton("4")
            keypadButton("5")
            keypadButton("6")
          }
          HStack(spacing: 4) {
            keypadButton("7")
            keypadButton("8")
            keypadButton("9")
          }
          HStack(spacing: 4) {
            keypadButton(".", action: appendDot)
            keypadButton("0")
            keypadButton("⌫", action: backspace, isDelete: true)
          }
        }

        // Continue Button
        Button {
          playClick()
          let parsed = Double(amountString) ?? amount
          amount = parsed
          onContinue()
        } label: {
          HStack {
            Text("Next")
              .font(.system(size: 13, weight: .bold))
            Image(systemName: "arrow.right")
              .font(.system(size: 11, weight: .bold))
          }
          .foregroundColor(canContinue ? WatchTheme.deepEmerald : WatchTheme.slateMuted)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(canContinue ? WatchTheme.gold : WatchTheme.cardSurface)
          .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .padding(.top, 2)
      }
      .padding(.horizontal, 4)
    }
    #if os(watchOS)
    .focusable()
    .digitalCrownRotation(
      $crownValue,
      from: 0.0,
      through: 1000000.0,
      by: 1.0,
      sensitivity: .low,
      isContinuous: false,
      isHapticFeedbackEnabled: true
    )
    .onChange(of: crownValue) { newValue in
      let rounded = (newValue * 100).rounded() / 100
      if rounded > 0 {
        amountString = String(format: rounded.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", rounded)
        amount = rounded
      }
    }
    #endif
    .onAppear {
      if amount > 0 {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
          amountString = String(format: "%.0f", amount)
        } else {
          amountString = String(format: "%.2f", amount)
        }
        crownValue = amount
      }
    }
  }

  private func keypadButton(_ label: String, action: (() -> Void)? = nil, isDelete: Bool = false) -> some View {
    Button {
      if let action = action {
        action()
      } else {
        appendDigit(label)
      }
    } label: {
      Text(label)
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundColor(isDelete ? WatchTheme.errorRed : WatchTheme.offWhite)
        .frame(maxWidth: .infinity, minHeight: 28)
        .background(WatchTheme.cardSurface)
        .cornerRadius(6)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(WatchTheme.cardBorder, lineWidth: 0.5)
        )
    }
    .buttonStyle(.plain)
  }

  private func appendDigit(_ digit: String) {
    playClick()
    if amountString == "0" {
      amountString = digit
    } else {
      if let dotIndex = amountString.firstIndex(of: ".") {
        let decimalPart = amountString[amountString.index(after: dotIndex)...]
        if decimalPart.count >= 2 { return }
      }
      if amountString.count >= 9 { return }
      amountString.append(digit)
    }
    updateAmountFromBuffer()
  }

  private func appendDot() {
    playClick()
    if amountString.isEmpty {
      amountString = "0."
    } else if !amountString.contains(".") {
      amountString.append(".")
    }
    updateAmountFromBuffer()
  }

  private func backspace() {
    playClick()
    if !amountString.isEmpty {
      amountString.removeLast()
    }
    updateAmountFromBuffer()
  }

  private func clearInput() {
    playClick()
    amountString = ""
    amount = 0.0
    crownValue = 0.0
  }

  private func updateAmountFromBuffer() {
    if let parsed = Double(amountString) {
      amount = parsed
      crownValue = parsed
    } else {
      amount = 0.0
    }
  }

  private func playClick() {
    #if os(watchOS)
    WKInterfaceDevice.current().play(.click)
    #endif
  }
}
