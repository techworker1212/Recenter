package com.rethink.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var pendingPermission: ((Result<PermissionSnapshot>) -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        RecenterHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, HostApi())
    }

    override fun onResume() {
        super.onResume()
        resolvePendingPermission()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATIONS) resolvePendingPermission()
    }

    private fun resolvePendingPermission() {
        val callback = pendingPermission ?: return
        pendingPermission = null
        callback(Result.success(Permissions.snapshot(this)))
    }

    /** Opens the system screen for [kind]; the result is delivered when the user comes back. */
    private fun requestPermission(kind: String, callback: (Result<PermissionSnapshot>) -> Unit) {
        val packageUri = Uri.parse("package:$packageName")
        val settingsIntent = when (kind) {
            "usageAccess" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            "overlay" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, packageUri)
            "battery" -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            "notifications" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    pendingPermission?.invoke(Result.success(Permissions.snapshot(this)))
                    pendingPermission = callback
                    requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        REQUEST_NOTIFICATIONS,
                    )
                    return
                }
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            else -> null
        }
        if (settingsIntent == null) {
            callback(Result.success(Permissions.snapshot(this)))
            return
        }
        pendingPermission?.invoke(Result.success(Permissions.snapshot(this)))
        pendingPermission = callback
        startActivity(settingsIntent)
    }

    private inner class HostApi : RecenterHostApi {
        private val store = RuleStore(this@MainActivity)

        override fun getPermissionStatus() = Permissions.snapshot(this@MainActivity)

        override fun requestPermission(
            kind: String,
            callback: (Result<PermissionSnapshot>) -> Unit,
        ) = this@MainActivity.requestPermission(kind, callback)

        override fun upsertAppRule(rule: NativeAppRule) {
            store.upsert(
                StoredRule(
                    id = rule.id,
                    packageName = rule.platformAppId,
                    label = rule.displayLabel,
                    limitMinutes = rule.limitMinutes.toInt(),
                    unlockMinutes = rule.unlockMinutes.toInt(),
                    title = rule.notificationTitle,
                    body = rule.notificationBody,
                    enabled = rule.enabled,
                ),
            )
        }

        override fun deleteAppRule(id: String) {
            store.delete(id)
            Notifications.clearWarning(this@MainActivity, id)
        }

        override fun startMonitoring() {
            store.monitoring = true
            if (!Permissions.hasUsageAccess(this@MainActivity)) {
                throw FlutterError(
                    "usage_access",
                    "Turn on Usage Access so Recenter can see which app is open.",
                )
            }
            MonitorService.start(this@MainActivity)
        }

        override fun stopMonitoring() {
            store.monitoring = false
            MonitorService.stop(this@MainActivity)
        }

        override fun getMonitoringStatus() = MonitoringStatus(
            running = MonitorService.running,
            interruptionsToday = store.interruptionsToday().toLong(),
            interruptionsByRule = store.interruptionsByRule().mapValues { it.value.toLong() },
        )

        override fun listInstalledApps(): List<InstalledApp> {
            val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            return packageManager.queryIntentActivities(launcher, 0)
                .filter { it.activityInfo.packageName != packageName }
                .distinctBy { it.activityInfo.packageName }
                .map {
                    InstalledApp(
                        packageId = it.activityInfo.packageName,
                        label = it.loadLabel(packageManager).toString(),
                    )
                }
                .sortedBy { it.label.lowercase() }
        }

        override fun pickIosActivity(callback: (Result<String>) -> Unit) {
            callback(Result.success(""))
        }

        override fun unlockApp(ruleId: String) = store.unlock(ruleId)

        override fun getGoals() = store.goals().map(::native)

        override fun addGoal(text: String) = store.addGoal(text).map(::native)

        override fun setGoalDone(id: String, done: Boolean) =
            store.setGoalDone(id, done).map(::native)

        override fun deleteGoal(id: String) = store.deleteGoal(id).map(::native)

        private fun native(goal: StoredGoal) = NativeGoal(goal.id, goal.text, goal.done)
    }

    companion object {
        private const val REQUEST_NOTIFICATIONS = 41
    }
}
