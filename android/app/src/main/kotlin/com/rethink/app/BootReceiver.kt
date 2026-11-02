package com.rethink.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Resumes monitoring after a reboot or app update if the user had it on. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                if (RuleStore(context).monitoring) MonitorService.start(context)
                MorningReminder.schedule(context)
            }
        }
    }
}
