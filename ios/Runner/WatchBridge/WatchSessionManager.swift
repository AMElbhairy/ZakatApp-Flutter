import Foundation
import WatchConnectivity
#if canImport(Flutter)
import Flutter
#endif

@objc final class WatchSessionManager: NSObject {
  @objc static let shared = WatchSessionManager()
  private static let appGroupSuiteName = "group.com.zakahwealth.app"
  private static let watchSnapshotStorageKey = "zakah_wealth_watch_snapshot_v1"
  private static let commandTimeout: TimeInterval = 12

  #if canImport(Flutter)
  private var watchChannel: FlutterMethodChannel?
  private var flutterBridgeReady = false
  private var pendingCommands: [String: PendingCommand] = [:]
  private struct PendingCommand { let message: [String: Any]; var replies: [([String: Any]) -> Void] }
  #endif

  private override init() { super.init(); activateSessionIfSupported() }

  #if canImport(Flutter)
  @objc func configure(with binaryMessenger: FlutterBinaryMessenger) {
    guard watchChannel == nil else { return }
    let channel = FlutterMethodChannel(name: "com.zakahwealth.watch", binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterError(code: "UNAVAILABLE", message: "WatchSessionManager deallocated", details: nil)); return }
      switch call.method {
      case "watchBridgeReady":
        self.flutterBridgeReady = true
        self.debugLog("Flutter authoritative bridge ready; pending=\(self.pendingCommands.count)")
        self.forwardPendingCommandsIfReady()
        result(true)
      case "syncWatchData":
        guard let snapshot = call.arguments as? [String: Any] else { result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected snapshot dictionary", details: nil)); return }
        self.handleSyncWatchData(snapshot); result(true)
      default: result(FlutterMethodNotImplemented)
      }
    }
    watchChannel = channel
    activateSessionIfSupported()
    debugLog("Native Flutter watch channel configured")
  }
  #endif

  @objc func activateSessionIfSupported() {
    guard WCSession.isSupported() else { debugLog("WCSession is not supported"); return }
    let session = WCSession.default
    if session.delegate == nil { session.delegate = self }
    if session.activationState == .notActivated { session.activate(); debugLog("Activating WCSession") }
  }

  private func handleSyncWatchData(_ snapshot: [String: Any]) {
    UserDefaults(suiteName: Self.appGroupSuiteName)?.set(snapshot, forKey: Self.watchSnapshotStorageKey)
    let session = WCSession.default
    guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
    do { try session.updateApplicationContext(snapshot); debugLog("Updated application context") }
    catch { debugLog("Failed to updateApplicationContext: \(error.localizedDescription)") }
  }

  #if canImport(Flutter)
  private func receiveOrHold(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    let operationId = (message["operationId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !operationId.isEmpty else { replyHandler(failure(operationId: "", code: "MISSING_OPERATION_ID", message: "operationId is required.")); return }
    guard let channel = watchChannel, flutterBridgeReady else {
      if var existing = pendingCommands[operationId] { existing.replies.append(replyHandler); pendingCommands[operationId] = existing }
      else {
        pendingCommands[operationId] = PendingCommand(message: message, replies: [replyHandler])
        debugLog("Holding command operationId=\(operationId)")
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.commandTimeout) { [weak self] in
          guard let self, let expired = self.pendingCommands.removeValue(forKey: operationId) else { return }
          self.debugLog("Timed out held command operationId=\(operationId)")
          expired.replies.forEach { $0(self.failure(operationId: operationId, code: "APP_UNAVAILABLE", message: "Unable to complete. Try again.")) }
        }
      }
      return
    }
    forward(message, replies: [replyHandler], through: channel)
  }

  private func forwardPendingCommandsIfReady() {
    guard flutterBridgeReady, let channel = watchChannel else { return }
    let pending = pendingCommands; pendingCommands.removeAll()
    for (operationId, command) in pending { debugLog("Forwarding held command operationId=\(operationId)"); forward(command.message, replies: command.replies, through: channel) }
  }

  private func forward(_ message: [String: Any], replies: [([String: Any]) -> Void], through channel: FlutterMethodChannel) {
    let operationId = (message["operationId"] as? String) ?? ""
    debugLog("Forwarding command to Flutter operationId=\(operationId)")
    channel.invokeMethod("executeWatchCommand", arguments: message) { [weak self] result in
      let reply: [String: Any]
      if let dictionary = result as? [String: Any] { reply = dictionary }
      else if let error = result as? FlutterError { reply = self?.failure(operationId: operationId, code: error.code, message: error.message ?? "Command execution failed") ?? [:] }
      else { reply = self?.failure(operationId: operationId, code: "EXECUTION_ERROR", message: "Unexpected response from application") ?? [:] }
      self?.debugLog("Flutter reply operationId=\(operationId) status=\((reply["status"] as? String) ?? "unknown")")
      replies.forEach { $0(reply) }
    }
  }

  private func failure(operationId: String, code: String, message: String) -> [String: Any] { ["v": 1, "operationId": operationId, "status": "failed", "code": code, "message": message] }
  #endif

  private func debugLog(_ message: String) {
    #if DEBUG
    NSLog("[WatchBridge][\(ISO8601DateFormatter().string(from: Date()))] \(message)")
    #endif
  }
}

extension WatchSessionManager: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if let error { debugLog("WCSession activation failed: \(error.localizedDescription)") }
    else { debugLog("WCSession activated state=\(activationState.rawValue), paired=\(session.isPaired), installed=\(session.isWatchAppInstalled), reachable=\(session.isReachable)") }
  }

  #if os(iOS)
  func sessionDidBecomeInactive(_ session: WCSession) { debugLog("WCSession became inactive") }
  func sessionDidDeactivate(_ session: WCSession) { debugLog("WCSession deactivated; reactivating"); WCSession.default.activate() }
  #endif

  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    #if canImport(Flutter)
    debugLog("Received Watch command lifecycle=\(UIApplication.shared.applicationState.rawValue)")
    DispatchQueue.main.async { [weak self] in self?.receiveOrHold(message, replyHandler: replyHandler) }
    #else
    replyHandler(["v": 1, "operationId": (message["operationId"] as? String) ?? "", "status": "failed", "code": "FLUTTER_NOT_SUPPORTED", "message": "Native build without Flutter cannot process commands"])
    #endif
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { debugLog("Received one-way message without reply handler; ignored") }
}
