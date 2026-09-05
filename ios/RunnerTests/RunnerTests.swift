import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testRealDeviceTestABanqueMisrPurchase() {
    let msg = "شكرًا لاستخدامك بطاقة بنك مصر ***8799، تم الآن خصم 99.00 EGPعند Talabat Pro يوم 05/09/2026 ، الرصيد المتاح EGP 5378.54 لمزيد من المعلومات عن الحساب، تفضل بزيارة الرابط التالي"
    let preview = AppDelegate.nativeShortcutPreview(from: msg)
    XCTAssertEqual(preview.amount, "99")
    XCTAssertEqual(preview.currency, "E£")
    XCTAssertEqual(preview.merchant, "Talabat")
    XCTAssertEqual(preview.statusLabel, "Transaction captured")
  }

  func testRealDeviceTestBIncomingTransfer() {
    let msg = """
    حوالة واردة محلية
    إلى:6403*
    مبلغ:500 SAR
    من:AHMED MOSTAFA ELBHAIRY
    عبر:D360 bank
    في:26/07/26 12:52
    """
    let preview = AppDelegate.nativeShortcutPreview(from: msg)
    XCTAssertEqual(preview.amount, "500")
    XCTAssertEqual(preview.currency, "⃁")
    XCTAssertEqual(preview.merchant, "AHMED MOSTAFA ELBHAIRY")
    XCTAssertEqual(preview.statusLabel, "Transaction captured")
  }

  func testRealDeviceTestCOutgoingTransfer() {
    let msg = """
    Debit Transfer Local
    Amount:5,000 SAR
    To: Ahmed Elbhairy
    From:**4870
    Fees:0 SAR
    On :2026-09-03 22:20
    """
    let preview = AppDelegate.nativeShortcutPreview(from: msg)
    XCTAssertEqual(preview.amount, "5000")
    XCTAssertEqual(preview.currency, "⃁")
    XCTAssertEqual(preview.merchant, "Ahmed Elbhairy")
    XCTAssertEqual(preview.statusLabel, "Transaction captured")
  }

  func testRealDeviceTestDAlinmaPayDuplicate() {
    let msg = """
    Online Purchase
    By:0669 ;Visa-Apple Pay
    Amount:4200 SR
    At:AlinmaPay
    Balance:1225 SR
    2/9/26 22:19
    """
    let preview = AppDelegate.nativeShortcutPreview(from: msg)
    XCTAssertEqual(preview.amount, "4200")
    XCTAssertEqual(preview.currency, "⃁")
    XCTAssertEqual(preview.merchant, "AlinmaPay")
    XCTAssertEqual(preview.statusLabel, "Transaction captured")
    XCTAssertFalse(preview.statusLabel.contains("Pending"))
    XCTAssertFalse(preview.statusLabel.contains("Approved"))
    XCTAssertFalse(preview.statusLabel.contains("Rejected"))
  }

  func testNegativeBalanceSelectionTransactionAmountPlusBalance() {
    let msg = "Purchase of 150 SAR. Balance is 2000 SAR."
    let amount = AppDelegate.nativeShortcutAmount(from: msg)
    XCTAssertEqual(amount, "150")
  }

  func testNegativeBalanceSelectionTransactionAmountPlusAvailableBalance() {
    let msg = "خصم 75 ج.م الرصيد المتاح 1200 ج.م"
    let amount = AppDelegate.nativeShortcutAmount(from: msg)
    XCTAssertEqual(amount, "75")
  }

  func testNegativeBalanceSelectionAmountPlusFeePlusBalance() {
    let msg = "Amount: 500 SAR Fees: 10 SAR Balance: 3500 SAR"
    let amount = AppDelegate.nativeShortcutAmount(from: msg)
    XCTAssertEqual(amount, "500")
  }
}
