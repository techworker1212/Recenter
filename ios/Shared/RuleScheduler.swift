import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// One DeviceActivity monitor and one named ManagedSettings store per rule, both keyed
/// by the rule id, so each extension callback knows exactly which rule (and copy) fired.
enum RuleScheduler {
  static let limitEvent = DeviceActivityEvent.Name("limit")

  /// Apple rejects schedules shorter than this.
  private static let minimumInterval: TimeInterval = 15 * 60

  static func activityName(_ ruleId: String) -> DeviceActivityName {
    DeviceActivityName(ruleId)
  }

  static func settingsStore(_ ruleId: String) -> ManagedSettingsStore {
    ManagedSettingsStore(named: ManagedSettingsStore.Name(ruleId))
  }

  /// Starts counting [thresholdMinutes] of use for [rule]. With `startingNow`, the count
  /// starts from zero now and runs until midnight; otherwise it is the repeating daily
  /// window. iOS counts total use within the window, not one continuous session.
  static func arm(_ rule: StoredRule, thresholdMinutes: Int, startingNow: Bool) throws {
    let center = DeviceActivityCenter()
    let name = activityName(rule.id)
    RuleStore.shared.markRearming(rule.id)
    center.stopMonitoring([name])

    let event = DeviceActivityEvent(
      applications: rule.selection.applicationTokens,
      categories: rule.selection.categoryTokens,
      webDomains: rule.selection.webDomainTokens,
      threshold: DateComponents(minute: max(1, thresholdMinutes))
    )
    let schedule = startingNow ? scheduleFromNow() : dailySchedule()
    try center.startMonitoring(name, during: schedule, events: [limitEvent: event])
  }

  /// Applies a saved edit to a rule while monitoring is on. Only a change that affects the
  /// limit touches the running count, so editing a message can't hand out a fresh limit.
  static func apply(
    edited rule: StoredRule, previous: StoredRule?, store: RuleStore = .shared
  ) throws {
    guard rule.enabled else {
      disarm(rule.id)
      return
    }
    let isRunning = DeviceActivityCenter().activities.contains(activityName(rule.id))
    let unchangedRule = previous?.enabled == true && previous?.selection == rule.selection
    guard unchangedRule, isRunning, let previous else {
      store.clearLimitReached(rule.id)
      try arm(rule, thresholdMinutes: rule.limitMinutes, startingNow: true)
      return
    }
    if store.limitReachedToday(rule.id) {
      // Already over the old limit: a higher limit lifts the block and grants the difference.
      guard rule.limitMinutes > previous.limitMinutes else { return }
      store.setUnlockedUntil(nil, for: rule.id)
      clearShield(rule.id)
      try arm(
        rule, thresholdMinutes: rule.limitMinutes - previous.limitMinutes, startingNow: true)
    } else if rule.limitMinutes != previous.limitMinutes {
      // iOS can't report usage so far, so a changed limit counts from now.
      try arm(rule, thresholdMinutes: rule.limitMinutes, startingNow: true)
    }
  }

  static func armAll(store: RuleStore = .shared) throws {
    for rule in store.rules() {
      store.clearLimitReached(rule.id)
      if rule.enabled {
        try arm(rule, thresholdMinutes: rule.limitMinutes, startingNow: true)
      } else {
        disarm(rule.id)
      }
    }
  }

  static func disarm(_ ruleId: String) {
    RuleStore.shared.markRearming(ruleId)
    DeviceActivityCenter().stopMonitoring([activityName(ruleId)])
    clearShield(ruleId)
  }

  static func disarmAll(store: RuleStore = .shared) {
    DeviceActivityCenter().stopMonitoring()
    for rule in store.rules() {
      clearShield(rule.id)
    }
  }

  static func shield(_ rule: StoredRule) {
    let store = settingsStore(rule.id)
    let selection = rule.selection
    store.shield.applications =
      selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories =
      selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains =
      selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    store.shield.webDomainCategories =
      selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
  }

  static func clearShield(_ ruleId: String) {
    settingsStore(ruleId).clearAllSettings()
  }

  /// Lifts the shield and re-arms the rule so the next warning comes after the cool-down.
  static func unlock(_ ruleId: String, store: RuleStore = .shared) {
    // Record the unlock window first, so any threshold event that races with the re-arm
    // below is ignored instead of re-blocking the app the user just unlocked.
    let minutes = store.rule(id: ruleId)?.unlockMinutes ?? StoredRule.defaultUnlockMinutes
    store.setUnlockedUntil(Date().addingTimeInterval(TimeInterval(minutes * 60)), for: ruleId)
    clearShield(ruleId)
    guard store.monitoring, let rule = store.rule(id: ruleId), rule.enabled else { return }
    try? arm(rule, thresholdMinutes: minutes, startingNow: true)
  }

  private static func dailySchedule() -> DeviceActivitySchedule {
    DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
      repeats: true
    )
  }

  private static func scheduleFromNow(now: Date = Date()) -> DeviceActivitySchedule {
    let calendar = Calendar.current
    let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
    // Late at night the rest of the day is too short, so the window runs past midnight.
    let end = endOfDay.timeIntervalSince(now) >= minimumInterval
      ? endOfDay
      : now.addingTimeInterval(minimumInterval + 60)
    return DeviceActivitySchedule(
      intervalStart: calendar.dateComponents([.hour, .minute, .second], from: now),
      intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: end),
      repeats: false
    )
  }
}
