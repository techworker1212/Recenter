import DeviceActivity
import FamilyControls
import Flutter
import SwiftUI
import UIKit
import UserNotifications

/// iOS side of the Pigeon bridge: Family Controls auth, the app picker, and arming
/// one DeviceActivity monitor per rule.
final class HostApi: RecenterHostApi {
  private let store = RuleStore.shared
  private var notificationsAuthorized = false

  init() {
    refreshNotificationStatus()
  }

  func getPermissionStatus() throws -> PermissionSnapshot {
    refreshNotificationStatus()
    return snapshot()
  }

  func requestPermission(
    kind: String,
    completion: @escaping (Result<PermissionSnapshot, Error>) -> Void
  ) {
    switch kind {
    case "familyControls":
      Task { @MainActor in
        try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        completion(.success(self.snapshot()))
      }
    case "notifications":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
        granted, _ in
        DispatchQueue.main.async {
          self.notificationsAuthorized = granted
          completion(.success(self.snapshot()))
        }
      }
    default:
      completion(.success(snapshot()))
    }
  }

  func upsertAppRule(rule: NativeAppRule) throws {
    guard let selection = ActivitySelectionCoding.decode(rule.platformAppId) else {
      throw PigeonError(code: "bad_selection", message: "Pick the app again.", details: nil)
    }
    let stored = StoredRule(
      id: rule.id,
      label: rule.displayLabel,
      limitMinutes: Int(rule.limitMinutes),
      unlockMinutes: Int(rule.unlockMinutes),
      title: rule.notificationTitle,
      body: rule.notificationBody,
      enabled: rule.enabled,
      selection: selection
    )
    store.upsert(stored)
    guard store.monitoring else { return }
    if stored.enabled {
      try RuleScheduler.arm(stored, thresholdMinutes: stored.limitMinutes, startingNow: true)
    } else {
      RuleScheduler.disarm(stored.id)
    }
  }

  func deleteAppRule(id: String) throws {
    RuleScheduler.disarm(id)
    store.delete(id: id)
  }

  func startMonitoring() throws {
    guard AuthorizationCenter.shared.authorizationStatus == .approved else {
      throw PigeonError(
        code: "family_controls",
        message: "Allow Screen Time access so Recenter can watch the apps you picked.",
        details: nil
      )
    }
    store.monitoring = true
    try RuleScheduler.armAll(store: store)
  }

  func stopMonitoring() throws {
    store.monitoring = false
    RuleScheduler.disarmAll(store: store)
  }

  func getMonitoringStatus() throws -> MonitoringStatus {
    MonitoringStatus(
      running: store.monitoring && !DeviceActivityCenter().activities.isEmpty,
      interruptionsToday: Int64(store.interruptionsToday),
      interruptionsByRule: store.interruptionsByRule.mapValues { Int64($0) }
    )
  }

  func listInstalledApps() throws -> [InstalledApp] {
    []
  }

  func pickIosActivity(completion: @escaping (Result<String, Error>) -> Void) {
    guard let presenter = Self.topViewController() else {
      completion(.success(""))
      return
    }
    var host: UIViewController?
    let picker = ActivityPickerView { selection in
      host?.dismiss(animated: true)
      host = nil
      completion(.success(selection.flatMap(ActivitySelectionCoding.encode) ?? ""))
    }
    let controller = UIHostingController(rootView: picker)
    host = controller
    presenter.present(controller, animated: true)
  }

  func unlockApp(ruleId: String) throws {
    RuleScheduler.unlock(ruleId, store: store)
  }

  func getGoals() throws -> [NativeGoal] {
    Self.native(store.goals)
  }

  func addGoal(text: String) throws -> [NativeGoal] {
    Self.native(store.addGoal(text))
  }

  func setGoalDone(id: String, done: Bool) throws -> [NativeGoal] {
    Self.native(store.setGoal(id, done: done))
  }

  func deleteGoal(id: String) throws -> [NativeGoal] {
    Self.native(store.deleteGoal(id))
  }

  private static func native(_ goals: [Goal]) -> [NativeGoal] {
    goals.map { NativeGoal(id: $0.id, text: $0.text, done: $0.done) }
  }

  private func snapshot() -> PermissionSnapshot {
    PermissionSnapshot(
      familyControls: AuthorizationCenter.shared.authorizationStatus == .approved,
      notifications: notificationsAuthorized,
      usageAccess: false,
      overlay: false,
      batteryExemption: false
    )
  }

  private func refreshNotificationStatus() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let authorized = settings.authorizationStatus == .authorized
        || settings.authorizationStatus == .provisional
      DispatchQueue.main.async { self.notificationsAuthorized = authorized }
    }
  }

  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
