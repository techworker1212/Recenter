package com.rethink.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

object Notifications {
    private const val CHANNEL_MONITOR = "monitor"
    private const val CHANNEL_WARNING = "warning"

    const val MONITOR_ID = 1
    private const val WARNING_ID_BASE = 1000

    fun ensureChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_MONITOR,
                "Monitoring",
                NotificationManager.IMPORTANCE_MIN,
            ).apply { description = "Shown while Recenter is watching your selected apps." },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_WARNING,
                "Time-limit warnings",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Your custom reminder, five seconds before an app is paused." },
        )
    }

    fun monitoring(context: Context, ruleCount: Int, usageAccess: Boolean): Notification {
        val text = when {
            !usageAccess -> "Usage access is off. Open Recenter to turn it on."
            ruleCount == 1 -> "Watching 1 app"
            else -> "Watching $ruleCount apps"
        }
        return Notification.Builder(context, CHANNEL_MONITOR)
            .setSmallIcon(R.drawable.ic_stat_rethink)
            .setContentTitle("Recenter is on")
            .setContentText(text)
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(openApp(context))
            .build()
    }

    /** The 5-second warning, using that rule's own title and body. */
    fun showWarning(context: Context, rule: StoredRule) {
        val goals = RuleStore(context).goals().filterNot { it.done }
        val body = goals.firstOrNull()?.let { "${rule.body}\nToday's goal: ${it.text}" } ?: rule.body
        val builder = Notification.Builder(context, CHANNEL_WARNING)
        // "Done: …" buttons tick a goal off without opening the app (Android allows three).
        goals.take(3).forEach { goal ->
            builder.addAction(
                Notification.Action.Builder(
                    null,
                    "Done: ${goal.text}",
                    GoalActionReceiver.pendingIntent(context, goal.id, warningId(rule.id)),
                ).build(),
            )
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_rethink)
            .setColor(context.getColor(R.color.rethink_teal))
            .setContentTitle(rule.title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setTimeoutAfter(WARNING_SECONDS * 1000L + 2_000L)
            .setContentIntent(PauseActivity.pendingIntent(context, rule.id))
            .build()
        context.getSystemService(NotificationManager::class.java)
            .notify(warningId(rule.id), notification)
    }

    /**
     * Without "display over other apps", Android won't let a service open the pause
     * screen on its own, so the pause is offered as a tappable notification instead.
     */
    fun showPausedFallback(context: Context, rule: StoredRule) {
        val notification = Notification.Builder(context, CHANNEL_WARNING)
            .setSmallIcon(R.drawable.ic_stat_rethink)
            .setColor(context.getColor(R.color.rethink_teal))
            .setContentTitle(rule.title)
            .setContentText("${rule.label} is paused. Tap to continue.")
            .setCategory(Notification.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(PauseActivity.pendingIntent(context, rule.id))
            .build()
        context.getSystemService(NotificationManager::class.java)
            .notify(warningId(rule.id), notification)
    }

    fun cancel(context: Context, notificationId: Int) {
        context.getSystemService(NotificationManager::class.java).cancel(notificationId)
    }

    fun clearWarning(context: Context, ruleId: String) {
        context.getSystemService(NotificationManager::class.java).cancel(warningId(ruleId))
    }

    internal fun warningId(ruleId: String) = WARNING_ID_BASE + (ruleId.hashCode() and 0xFFFF)

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    const val WARNING_SECONDS = 5
}
