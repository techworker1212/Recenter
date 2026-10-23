package com.rethink.app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Handles "Done: …" on a warning notification: ticks the goal off and dismisses it. */
class GoalActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val goalId = intent.getStringExtra(EXTRA_GOAL_ID) ?: return
        RuleStore(context).setGoalDone(goalId, true)
        Notifications.cancel(context, intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0))
    }

    companion object {
        private const val EXTRA_GOAL_ID = "goalId"
        private const val EXTRA_NOTIFICATION_ID = "notificationId"

        fun pendingIntent(context: Context, goalId: String, notificationId: Int): PendingIntent {
            val intent = Intent(context, GoalActionReceiver::class.java)
                .putExtra(EXTRA_GOAL_ID, goalId)
                .putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            return PendingIntent.getBroadcast(
                context,
                goalId.hashCode(),
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
    }
}
