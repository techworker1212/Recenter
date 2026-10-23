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
  func getPermissionStatus(completion: @escaping (Result<PermissionSnapshot, Error>) -> Void) {
    Task { @MainActor in
      completion(.success(await self.currentSnapshot()))
    }
  }

  func requestPermission(
    kind: String,
    completion: @escaping (Result<PermissionSnapshot, Error>) -> Void
  ) {
    switch kind {
    case "familyControls":
      Task { @MainActor in
        try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        completion(.success(await self.currentSnapshot()))
      }
    case "notifications":
      Task { @MainActor in
        _ = try? await UNUserNotificationCenter.current()
          .requestAuthorization(options: [.alert, .sound])
        completion(.success(await self.currentSnapshot()))
      }
    default:
      Task { @MainActor in
        completion(.success(await self.currentSnapshot()))
      }
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
    // Called after getPermissionStatus has already waited for the status to load.
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

  /// Waits for iOS's real answers instead of reading values that may not have loaded yet.
  @MainActor
  private func currentSnapshot() async -> PermissionSnapshot {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    let notifications = [.authorized, .provisional, .ephemeral]
      .contains(settings.authorizationStatus)
    return PermissionSnapshot(
      familyControls: await Self.familyControlsApproved(),
      notifications: notifications,
      usageAccess: false,
      overlay: false,
      batteryExemption: false
    )
  }

  /// Right after launch, AuthorizationCenter can briefly report "not determined" before it
  /// has loaded the saved approval. Give it up to ~2 seconds to settle before saying no.
  @MainActor
  private static func familyControlsApproved() async -> Bool {
    let center = AuthorizationCenter.shared
    for _ in 0..<8 {
      switch center.authorizationStatus {
      case .approved:
        return true
      case .denied:
        return false
      default:
        try? await Task.sleep(nanoseconds: 250_000_000)
      }
    }
    return center.authorizationStatus == .approved
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
