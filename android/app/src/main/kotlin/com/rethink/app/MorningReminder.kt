package com.rethink.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/**
 * The daily "what will you focus on today?" notification, on at 6:00 AM by default.
 * An inexact alarm (no exact-alarm permission needed) re-arms itself each day; times are
 * local, so it follows the phone's timezone.
 */
object MorningReminder {
    private const val CHANNEL = "morning"
    const val NOTIFICATION_ID = 2
    const val REPLY_KEY = "goalText"

    data class Settings(val enabled: Boolean, val hour: Int, val minute: Int)

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences("rethink.morning", Context.MODE_PRIVATE)

    fun settings(context: Context) = prefs(context).let {
        Settings(it.getBoolean("enabled", true), it.getInt("hour", 6), it.getInt("minute", 0))
    }

    fun save(context: Context, settings: Settings) {
        prefs(context).edit()
            .putBoolean("enabled", settings.enabled)
            .putInt("hour", settings.hour)
            .putInt("minute", settings.minute)
            .apply()
        schedule(context)
    }

    /** Arms the next reminder, or cancels it if turned off. */
    fun schedule(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val pending = alarmIntent(context)
        alarms.cancel(pending)
        val settings = settings(context)
        if (!settings.enabled) return
        val time = LocalTime.of(settings.hour, settings.minute)
        var next = LocalDateTime.of(LocalDate.now(), time)
        if (!next.isAfter(LocalDateTime.now())) next = next.plusDays(1)
        val millis = next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, millis, pending)
    }

    fun show(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Morning reminder", NotificationManager.IMPORTANCE_DEFAULT)
                .apply { description = "Asks for today's goals each morning." },
        )
        val reply = Notification.Action.Builder(
            null,
            "Add a goal",
            PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, GoalReplyReceiver::class.java),
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            ),
        ).addRemoteInput(RemoteInput.Builder(REPLY_KEY).setLabel("Read 20 pages").build()).build()

        val open = PendingIntent.getActivity(
            context,
            1,
            Intent(context, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_ACTION, PendingActions.OPEN_GOALS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        manager.notify(
            NOTIFICATION_ID,
            Notification.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_rethink)
                .setColor(context.getColor(R.color.rethink_teal))
                .setContentTitle("Good morning")
                .setContentText("What will you focus on today instead of scrolling?")
                .setAutoCancel(true)
                .setContentIntent(open)
                .addAction(reply)
                .build(),
        )
    }

    private fun alarmIntent(context: Context) = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, MorningReminderReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}

/** Fires at the reminder time: shows it and arms tomorrow's. */
class MorningReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        MorningReminder.show(context)
        MorningReminder.schedule(context)
    }
}

/** "Add a goal" typed straight into the morning notification. */
class GoalReplyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = RemoteInput.getResultsFromIntent(intent)
            ?.getCharSequence(MorningReminder.REPLY_KEY)?.toString()
        if (!text.isNullOrBlank()) RuleStore(context).addGoal(text)
        context.getSystemService(NotificationManager::class.java)
            .cancel(MorningReminder.NOTIFICATION_ID)
    }
}

/** Things a notification tap asks the app to do once it's open. */
object PendingActions {
    const val OPEN_GOALS = "openGoals"
    private const val KEY = "pendingAction"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences("rethink.native", Context.MODE_PRIVATE)

    fun set(context: Context, action: String) = prefs(context).edit().putString(KEY, action).apply()

    fun consume(context: Context): String? {
        val action = prefs(context).getString(KEY, null)
        prefs(context).edit().remove(KEY).apply()
        return action
    }
}
