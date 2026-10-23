package com.rethink.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.util.UUID

/** A rule as the native side sees it. Copy is already resolved (fallback applied) by Flutter. */
data class StoredRule(
    val id: String,
    val packageName: String,
    val label: String,
    val limitMinutes: Int,
    /** How long "Unlock" on the pause screen opens this app before the next reminder. */
    val unlockMinutes: Int,
    val title: String,
    val body: String,
    val enabled: Boolean,
)

/** A goal for today. */
data class StoredGoal(val id: String, val text: String, val done: Boolean)

/**
 * Native-side source of truth for the monitor service and pause screen, so they keep
 * working when the Flutter UI is not running.
 */
class RuleStore(context: Context) {
    private val prefs = context.applicationContext
        .getSharedPreferences("rethink.native", Context.MODE_PRIVATE)

    fun rules(): List<StoredRule> {
        val raw = prefs.getString(KEY_RULES, null) ?: return emptyList()
        val array = JSONArray(raw)
        return (0 until array.length()).map { index ->
            val json = array.getJSONObject(index)
            StoredRule(
                id = json.getString("id"),
                packageName = json.getString("packageName"),
                label = json.getString("label"),
                limitMinutes = json.getInt("limitMinutes"),
                // Rules saved before per-rule unlock times don't have this field.
                unlockMinutes = json.optInt("unlockMinutes", DEFAULT_UNLOCK_MINUTES),
                title = json.getString("title"),
                body = json.getString("body"),
                enabled = json.getBoolean("enabled"),
            )
        }
    }

    fun rule(id: String): StoredRule? = rules().firstOrNull { it.id == id }

    fun upsert(rule: StoredRule) {
        val next = rules().filterNot { it.id == rule.id } + rule
        saveRules(next)
    }

    fun delete(id: String) {
        saveRules(rules().filterNot { it.id == id })
        prefs.edit()
            .remove(cooldownKey(id))
            .putStringSet(KEY_BLOCKED, blockedRuleIds() - id)
            .apply()
    }

    private fun saveRules(rules: List<StoredRule>) {
        val array = JSONArray()
        rules.forEach { rule ->
            array.put(
                JSONObject()
                    .put("id", rule.id)
                    .put("packageName", rule.packageName)
                    .put("label", rule.label)
                    .put("limitMinutes", rule.limitMinutes)
                    .put("unlockMinutes", rule.unlockMinutes)
                    .put("title", rule.title)
                    .put("body", rule.body)
                    .put("enabled", rule.enabled),
            )
        }
        prefs.edit().putString(KEY_RULES, array.toString()).apply()
    }

    var monitoring: Boolean
        get() = prefs.getBoolean(KEY_MONITORING, false)
        set(value) = prefs.edit().putBoolean(KEY_MONITORING, value).apply()

    fun blockedRuleIds(): Set<String> = prefs.getStringSet(KEY_BLOCKED, emptySet())!!.toSet()

    fun isBlocked(ruleId: String) = ruleId in blockedRuleIds()

    fun block(ruleId: String) {
        prefs.edit().putStringSet(KEY_BLOCKED, blockedRuleIds() + ruleId).apply()
    }

    fun cooldownUntil(ruleId: String): Long = prefs.getLong(cooldownKey(ruleId), 0L)

    /** Lifts the block and grants this rule's unlock time before the next warning cycle. */
    fun unlock(ruleId: String, now: Long = System.currentTimeMillis()) {
        val minutes = rule(ruleId)?.unlockMinutes ?: DEFAULT_UNLOCK_MINUTES
        prefs.edit()
            .putStringSet(KEY_BLOCKED, blockedRuleIds() - ruleId)
            .putLong(cooldownKey(ruleId), now + minutes * 60_000L)
            .apply()
    }

    /** Today's interruptions per rule id. Counts from earlier days read as empty. */
    fun interruptionsByRule(): Map<String, Int> {
        if (prefs.getString(KEY_INTERRUPTION_DAY, null) != today()) return emptyMap()
        val json = JSONObject(prefs.getString(KEY_INTERRUPTIONS_BY_RULE, null) ?: "{}")
        return json.keys().asSequence().associateWith { json.getInt(it) }
    }

    fun interruptionsToday(): Int = interruptionsByRule().values.sum()

    fun recordInterruption(ruleId: String) {
        val counts = interruptionsByRule().toMutableMap()
        counts[ruleId] = (counts[ruleId] ?: 0) + 1
        prefs.edit()
            .putString(KEY_INTERRUPTION_DAY, today())
            .putString(KEY_INTERRUPTIONS_BY_RULE, JSONObject(counts as Map<*, *>).toString())
            .apply()
    }

    /**
     * Once per day: lift every block and forget running unlocks, so each app starts the
     * day with its full limit. Returns true when a new day began.
     */
    fun startNewDayIfNeeded(): Boolean {
        val today = today()
        if (prefs.getString(KEY_ACTIVE_DAY, null) == today) return false
        val editor = prefs.edit()
            .putString(KEY_ACTIVE_DAY, today)
            .putStringSet(KEY_BLOCKED, emptySet())
        rules().forEach { editor.remove(cooldownKey(it.id)) }
        editor.apply()
        return true
    }

    /** Today's goals. Goals from an earlier day read as an empty list. */
    fun goals(): List<StoredGoal> {
        if (prefs.getString(KEY_GOALS_DAY, null) != today()) return emptyList()
        val array = JSONArray(prefs.getString(KEY_GOALS, null) ?: "[]")
        return (0 until array.length()).map {
            val json = array.getJSONObject(it)
            StoredGoal(json.getString("id"), json.getString("text"), json.getBoolean("done"))
        }
    }

    fun nextGoal(): StoredGoal? = goals().firstOrNull { !it.done }

    fun addGoal(text: String): List<StoredGoal> {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return goals()
        return saveGoals(goals() + StoredGoal(UUID.randomUUID().toString(), trimmed, false))
    }

    fun setGoalDone(id: String, done: Boolean): List<StoredGoal> =
        saveGoals(goals().map { if (it.id == id) it.copy(done = done) else it })

    fun deleteGoal(id: String): List<StoredGoal> = saveGoals(goals().filterNot { it.id == id })

    private fun saveGoals(goals: List<StoredGoal>): List<StoredGoal> {
        val array = JSONArray()
        goals.forEach {
            array.put(JSONObject().put("id", it.id).put("text", it.text).put("done", it.done))
        }
        prefs.edit()
            .putString(KEY_GOALS, array.toString())
            .putString(KEY_GOALS_DAY, today())
            .apply()
        return goals
    }

    private fun today() = LocalDate.now().toString()

    private fun cooldownKey(ruleId: String) = "cooldown.$ruleId"

    companion object {
        private const val KEY_RULES = "rules"
        private const val KEY_MONITORING = "monitoring"
        const val DEFAULT_UNLOCK_MINUTES = 2
        private const val KEY_BLOCKED = "blocked"
        private const val KEY_ACTIVE_DAY = "activeDay"
        private const val KEY_GOALS = "goals"
        private const val KEY_GOALS_DAY = "goalsDay"
        private const val KEY_INTERRUPTIONS_BY_RULE = "interruptionsByRule"
        private const val KEY_INTERRUPTION_DAY = "interruptionDay"
    }
}
