import DeviceActivity
import Foundation
import ManagedSettings
import UserNotifications

/// Runs in the background when a rule's usage threshold is reached: posts that rule's
/// custom warning, waits five seconds, then shields the app(s) in the rule.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  private let store = RuleStore.shared
  private let warningSeconds: UInt32 = 5

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
    guard event == RuleScheduler.limitEvent,
      store.monitoring,
      let rule = store.rule(id: activity.rawValue),
      rule.enabled,
      !store.isUnlocked(rule.id)
    else { return }

    store.recordInterruption(ruleId: rule.id)
    postWarning(for: rule)
    sleep(warningSeconds)
    RuleScheduler.shield(rule)
  }

  /// The daily window starting is midnight: every rule starts the day unblocked.
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    // Only the repeating daily window marks a new day. One-off windows also "start" when
    // Recenter arms a rule mid-day, and must not lift a block the user hasn't unlocked.
    guard DeviceActivityCenter().schedule(for: activity)?.repeats == true else { return }
    resetForNewDay(activity.rawValue)
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    // Recenter stopped this monitor itself to restart it (save, unlock): not a real end.
    guard !store.isRearming(activity.rawValue) else { return }
    // A window only really ends at the end of the day, so the day's block ends with it.
    resetForNewDay(activity.rawValue)
    guard store.monitoring,
      let rule = store.rule(id: activity.rawValue),
      rule.enabled
    else { return }
    // A one-off window (first arm, or after an unlock) hands over to the daily window.
    let schedule = DeviceActivityCenter().schedule(for: activity)
    if schedule?.repeats != true {
      try? RuleScheduler.arm(rule, thresholdMinutes: rule.limitMinutes, startingNow: false)
    }
  }

  private func resetForNewDay(_ ruleId: String) {
    store.startNewDay(for: ruleId)
    RuleScheduler.clearShield(ruleId)
  }

  private func postWarning(for rule: StoredRule) {
    let content = UNMutableNotificationContent()
    content.title = rule.title
    content.body = rule.body
    if let goals = GoalStore.shared.summary {
      content.body += "\n\(goals)"
    }
    content.userInfo = ["message": rule.body]
    content.sound = .default
    content.threadIdentifier = rule.id
    // Press and hold the warning: the GoalsNotification extension shows every goal as a
    // checklist that can be ticked off right there.
    content.categoryIdentifier = GoalStore.notificationCategory
    let request = UNNotificationRequest(
      identifier: "warning.\(rule.id)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }
}
