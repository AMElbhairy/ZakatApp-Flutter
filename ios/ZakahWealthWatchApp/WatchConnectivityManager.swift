import Foundation
import WatchConnectivity
import SwiftUI

@MainActor
public final class WatchConnectivityManager: NSObject, ObservableObject {
  public static let shared = WatchConnectivityManager()
  private static let snapshotCacheKey = "zakah_wealth_watch_snapshot_local_v1"

  @Published public var snapshot: WatchStateSnapshot = WatchStateSnapshot()
  @Published public var isReachable: Bool = false
  @Published public var isSessionActivated: Bool = false
  @Published public var lastSyncDate: Date?
  @Published public var lastCommandResult: WatchCommandResult?
  @Published public var isExecutingCommand: Bool = false

  private override init() {
    super.init()
    loadCachedSnapshot()
    startSessionIfSupported()
  }

  public func startSessionIfSupported() {
    guard WCSession.isSupported() else {
      debugLog("WCSession is not supported on this watch")
      return
    }

    let session = WCSession.default
    session.delegate = self
    if session.activationState == .notActivated {
      session.activate()
      debugLog("Activating WCSession on Watch")
    }
  }

  /// Authoritative immediate command execution.
  /// Strictly requires active reachability with iPhone/Flutter.
  /// Never queues write operations offline in V1 per architecture rule #1.
  public func sendCommand(
    action: String,
    operationId: String? = nil,
    extraFields: [String: Any] = [:],
    completion: @escaping (WatchCommandResult) -> Void
  ) {
    let opId = operationId ?? UUID().uuidString
    let session = WCSession.default

    guard WCSession.isSupported() && session.activationState == .activated else {
      let failure = WatchCommandResult(
        v: 1,
        operationId: opId,
        status: "failed",
        code: "SESSION_NOT_ACTIVATED",
        message: "Watch connectivity is not active."
      )
      self.lastCommandResult = failure
      completion(failure)
      return
    }

    guard session.isReachable else {
      let failure = WatchCommandResult(
        v: 1,
        operationId: opId,
        status: "failed",
        code: "IPHONE_UNREACHABLE",
        message: "iPhone unavailable. Try again when connected."
      )
      self.lastCommandResult = failure
      completion(failure)
      return
    }

    var payload: [String: Any] = extraFields
    payload["v"] = 1
    payload["operationId"] = opId
    payload["action"] = action
    payload["timestamp"] = ISO8601DateFormatter().string(from: Date())

    self.isExecutingCommand = true
    debugLog("sendMessage action=\(action) operationId=\(opId) reachable=\(session.isReachable)")
    var didComplete = false
    let timeout = DispatchWorkItem { [weak self] in
      Task { @MainActor in
        guard let self, !didComplete else { return }
        didComplete = true
        self.isExecutingCommand = false
        let failure = WatchCommandResult(v: 1, operationId: opId, status: "failed", code: "TIMEOUT", message: "Unable to complete. Try again.")
        self.lastCommandResult = failure
        self.debugLog("sendMessage timeout operationId=\(opId)")
        completion(failure)
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)

    session.sendMessage(payload, replyHandler: { [weak self] replyDict in
      Task { @MainActor in
        guard let self, !didComplete else { return }
        didComplete = true
        timeout.cancel()
        self.isExecutingCommand = false

        let status = (replyDict["status"] as? String) ?? "failed"
        let code = (replyDict["code"] as? String) ?? "UNKNOWN"
        let message = replyDict["message"] as? String
        let entityId = replyDict["entityId"] as? String
        let payload = replyDict["payload"] as? [String: Any]
        let targetAmount = (payload?["targetAmount"] as? NSNumber)?.doubleValue
        let rate = (payload?["rate"] as? NSNumber)?.doubleValue

        let result = WatchCommandResult(
          v: 1,
          operationId: opId,
          status: status,
          code: code,
          message: message,
          entityId: entityId,
          targetAmount: targetAmount,
          rate: rate
        )
        self.lastCommandResult = result
        self.debugLog("reply received operationId=\(opId) status=\(status)")
        completion(result)
      }
    }, errorHandler: { [weak self] error in
      Task { @MainActor in
        guard let self, !didComplete else { return }
        didComplete = true
        timeout.cancel()
        self.isExecutingCommand = false
        let failure = WatchCommandResult(
          v: 1,
          operationId: opId,
          status: "failed",
          code: "COMMUNICATION_ERROR",
          message: error.localizedDescription
        )
        self.lastCommandResult = failure
        self.debugLog("error received operationId=\(opId): \(error.localizedDescription)")
        completion(failure)
      }
    })
  }

  /// Sends a harmless diagnostic ping test to verify the end-to-end pipeline.
  public func sendPingTest(completion: ((WatchCommandResult) -> Void)? = nil) {
    let start = Date()
    sendCommand(action: "ping") { result in
      let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
      if result.isSuccess {
        NSLog("[WatchApp] Ping success in \(elapsedMs)ms: \(result.message ?? "")")
      } else {
        NSLog("[WatchApp] Ping failed in \(elapsedMs)ms: \(result.code) - \(result.message ?? "")")
      }
      completion?(result)
    }
  }

  private func parseSnapshot(from dict: [String: Any]) {
    do {
      let data = try JSONSerialization.data(withJSONObject: dict, options: [])
      let decoder = JSONDecoder()
      let parsed = try decoder.decode(WatchStateSnapshot.self, from: data)
      self.snapshot = parsed
      self.lastSyncDate = parsed.generatedAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
      if let data = try? JSONEncoder().encode(parsed) {
        UserDefaults.standard.set(data, forKey: Self.snapshotCacheKey)
      }
      NSLog("[WatchApp] Received snapshot update. Pending: \(parsed.pendingInbox.count), Recent: \(parsed.recentActivity.count)")
    } catch {
      NSLog("[WatchApp] Failed to parse snapshot: \(error)")
    }
  }

  private func loadCachedSnapshot() {
    guard let data = UserDefaults.standard.data(forKey: Self.snapshotCacheKey),
          let cached = try? JSONDecoder().decode(WatchStateSnapshot.self, from: data) else { return }
    snapshot = cached
    lastSyncDate = cached.generatedAt.flatMap { ISO8601DateFormatter().date(from: $0) }
    debugLog("Loaded cached snapshot pending=\(cached.pendingInbox.count)")
  }

  private func debugLog(_ message: String) {
    #if DEBUG
    NSLog("[WatchApp][\(ISO8601DateFormatter().string(from: Date()))] \(message)")
    #endif
  }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
  nonisolated public func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in
      self.isSessionActivated = (activationState == .activated)
      self.isReachable = session.isReachable
      NSLog("[WatchApp] WCSession activation completed: \(activationState.rawValue), reachable: \(session.isReachable)")

      // If context already exists, hydrate presentation cache
      let context = session.receivedApplicationContext
      if !context.isEmpty {
        self.parseSnapshot(from: context)
      }
    }
  }

  nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
      self.isReachable = session.isReachable
      NSLog("[WatchApp] Session reachability changed: \(session.isReachable)")
    }
  }

  nonisolated public func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    Task { @MainActor in
      self.parseSnapshot(from: applicationContext)
    }
  }

  #if os(iOS)
  nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

  nonisolated public func sessionDidDeactivate(_ session: WCSession) {
    WCSession.default.activate()
  }
  #endif
}
