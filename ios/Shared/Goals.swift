import Foundation
import UserNotifications

/// A goal for today, stored in the App Group so the warning notification, the shield and
/// the app all see the same list.
struct Goal: Codable, Equatable {
  var id: String
  var text: String
  var done: Bool
}

extension RuleStore {
  /// Today's goals. Goals from an earlier day read as an empty list.
  var goals: [Goal] {
    guard goalsDay == RuleStore.today(),
      let data = sharedDefaults.data(forKey: GoalKeys.goals),
      let goals = try? JSONDecoder().decode([Goal].self, from: data)
    else { return [] }
    return goals
  }

  var nextGoal: Goal? {
    goals.first { !$0.done }
  }

  @discardableResult
  func addGoal(_ text: String) -> [Goal] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return goals }
    return saveGoals(goals + [Goal(id: UUID().uuidString, text: trimmed, done: false)])
  }

  @discardableResult
  func setGoal(_ id: String, done: Bool) -> [Goal] {
    saveGoals(goals.map { $0.id == id ? Goal(id: $0.id, text: $0.text, done: done) : $0 })
  }

  @discardableResult
  func deleteGoal(_ id: String) -> [Goal] {
    saveGoals(goals.filter { $0.id != id })
  }

  private var goalsDay: String? {
    sharedDefaults.string(forKey: GoalKeys.day)
  }

  private func saveGoals(_ goals: [Goal]) -> [Goal] {
    if let data = try? JSONEncoder().encode(goals) {
      sharedDefaults.set(data, forKey: GoalKeys.goals)
      sharedDefaults.set(RuleStore.today(), forKey: GoalKeys.day)
    }
    GoalNotifications.registerCategory(for: goals)
    return goals
  }

  private enum GoalKeys {
    static let goals = "goals"
    static let day = "goalsDay"
  }
}

/// The warning notification's "Done: …" buttons, one per unfinished goal (up to three).
/// iOS needs the buttons registered as a category before a notification can use them, so the
/// category is rebuilt whenever goals change and again just before each warning is posted.
enum GoalNotifications {
  static let categoryId = "recenter.warning"
  static let actionPrefix = "goal.done."
  private static let maxActions = 3

  static func registerCategory(for goals: [Goal]) {
    let actions = goals.filter { !$0.done }.prefix(maxActions).map { goal in
      UNNotificationAction(
        identifier: actionPrefix + goal.id,
        title: "Done: \(goal.text)",
        options: []
      )
    }
    let category = UNNotificationCategory(
      identifier: categoryId,
      actions: Array(actions),
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  /// The goal id for a "Done: …" action, or nil for any other action.
  static func goalId(forAction identifier: String) -> String? {
    guard identifier.hasPrefix(actionPrefix) else { return nil }
    return String(identifier.dropFirst(actionPrefix.count))
  }
}
