import Foundation
import UserNotifications
import os

private let log = Logger(subsystem: "com.aquibkhan.recenter", category: "MorningReminder")

/// The daily "what will you focus on today?" notification. It's a repeating calendar
/// notification on the phone itself: no server, and it follows the phone's timezone.
enum MorningReminder {
  static let categoryId = "recenter.morning"
  static let addGoalAction = "morning.addGoal"
  private static let requestId = "recenter.morning.reminder"

  struct Settings {
    var enabled: Bool
    var hour: Int
    var minute: Int
  }

  private static let defaults = UserDefaults.standard

  /// On at 6:00 AM until the user changes it.
  static var settings: Settings {
    get {
      Settings(
        enabled: defaults.object(forKey: Keys.enabled) as? Bool ?? true,
        hour: defaults.object(forKey: Keys.hour) as? Int ?? 6,
        minute: defaults.object(forKey: Keys.minute) as? Int ?? 0
      )
    }
    set {
      defaults.set(newValue.enabled, forKey: Keys.enabled)
      defaults.set(newValue.hour, forKey: Keys.hour)
      defaults.set(newValue.minute, forKey: Keys.minute)
      reschedule()
    }
  }

  /// "Add a goal" lets the user type a goal straight into the notification.
  static var category: UNNotificationCategory {
    let add = UNTextInputNotificationAction(
      identifier: addGoalAction,
      title: "Add a goal",
      options: [],
      textInputButtonTitle: "Add",
      textInputPlaceholder: "Read 20 pages"
    )
    return UNNotificationCategory(
      identifier: categoryId, actions: [add], intentIdentifiers: [], options: [])
  }

  /// Replaces any scheduled reminder with one matching the current settings.
  static func reschedule() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [requestId])
    let current = settings
    guard current.enabled else { return }

    let content = UNMutableNotificationContent()
    content.title = "Good morning"
    content.body = "What will you focus on today instead of scrolling?"
    content.sound = .default
    content.categoryIdentifier = categoryId
    // The user asked for this at a set time, and 6 AM often falls inside a Sleep Focus or a
    // Scheduled Summary, which would otherwise hold it back without any sign.
    content.interruptionLevel = .timeSensitive

    let trigger = UNCalendarNotificationTrigger(
      dateMatching: DateComponents(hour: current.hour, minute: current.minute),
      repeats: true
    )
    center.add(UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)) {
      error in
      center.getPendingNotificationRequests { requests in
        let next = requests.first { $0.identifier == requestId }?.trigger
          as? UNCalendarNotificationTrigger
        log.notice(
          "scheduled \(current.hour):\(current.minute) error=\(String(describing: error)) pending=\(requests.count) next=\(String(describing: next?.nextTriggerDate()))"
        )
      }
    }
  }

  private enum Keys {
    static let enabled = "morningReminder.enabled"
    static let hour = "morningReminder.hour"
    static let minute = "morningReminder.minute"
  }
}

/// Things a notification tap asks the app to do once it's open.
enum PendingAction {
  static let openGoals = "openGoals"
  private static let key = "pendingAction"

  static func set(_ action: String) {
    UserDefaults.standard.set(action, forKey: key)
  }

  static func consume() -> String? {
    let action = UserDefaults.standard.string(forKey: key)
    UserDefaults.standard.removeObject(forKey: key)
    return action
  }
}
