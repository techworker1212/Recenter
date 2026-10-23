package com.rethink.app

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.CountDownTimer
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.CheckBox
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * The "locked" screen over a blocked app: that rule's custom title and body, a way out,
 * and an unlock that only enables after a short pause so it is a deliberate choice.
 */
class PauseActivity : Activity() {
    private lateinit var store: RuleStore
    private var ruleId: String? = null
    private var timer: CountDownTimer? = null

    private lateinit var titleView: TextView
    private lateinit var bodyView: TextView
    private lateinit var goalsView: LinearLayout
    private lateinit var closeButton: Button
    private lateinit var unlockButton: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = RuleStore(this)
        setContentView(buildLayout())
        bind(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        bind(intent)
    }

    override fun onDestroy() {
        timer?.cancel()
        super.onDestroy()
    }

    @Deprecated("Back leaves to the home screen instead of the blocked app.")
    override fun onBackPressed() {
        goHome()
    }

    private fun bind(intent: Intent) {
        val id = intent.getStringExtra(EXTRA_RULE_ID)
        val rule = id?.let(store::rule)
        if (rule == null || !store.isBlocked(rule.id)) {
            finish()
            return
        }
        ruleId = rule.id
        Notifications.clearWarning(this, rule.id)
        titleView.text = rule.title
        bodyView.text = rule.body
        bindGoals()
        closeButton.text = "Close ${rule.label}"
        startUnlockDelay()
    }

    /** Today's goals as checkboxes, so they can be ticked off right here. */
    private fun bindGoals() {
        goalsView.removeAllViews()
        val goals = store.goals()
        goalsView.visibility = if (goals.isEmpty()) View.GONE else View.VISIBLE
        if (goals.isEmpty()) return
        goalsView.addView(
            TextView(this).apply {
                text = "Today's goals"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                typeface = Typeface.DEFAULT_BOLD
            },
        )
        goals.forEach { goal ->
            goalsView.addView(
                CheckBox(this).apply {
                    text = goal.text
                    isChecked = goal.done
                    setTextColor(Color.WHITE)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    buttonTintList = ColorStateList.valueOf(getColor(R.color.rethink_teal))
                    setOnCheckedChangeListener { _, checked -> store.setGoalDone(goal.id, checked) }
                },
            )
        }
    }

    private fun startUnlockDelay() {
        timer?.cancel()
        unlockButton.isEnabled = false
        timer = object : CountDownTimer(UNLOCK_DELAY_MS, 1_000L) {
            override fun onTick(millisUntilFinished: Long) {
                val seconds = (millisUntilFinished + 999) / 1_000
                unlockButton.text = "Unlock in $seconds…"
            }

            override fun onFinish() {
                unlockButton.isEnabled = true
                val minutes = ruleId?.let(store::rule)?.unlockMinutes
                    ?: RuleStore.DEFAULT_UNLOCK_MINUTES
                unlockButton.text = "Unlock for $minutes min"
            }
        }.start()
    }

    private fun unlock() {
        val id = ruleId ?: return
        store.unlock(id)
        finish()
    }

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        finish()
    }

    private fun buildLayout(): View {
        val teal = getColor(R.color.rethink_teal)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(28), dp(48), dp(28), dp(32))
            fitsSystemWindows = true
        }

        val badge = ImageView(this).apply {
            setImageResource(R.drawable.ic_stat_rethink)
            setColorFilter(Color.WHITE)
            setPadding(dp(12), dp(12), dp(12), dp(12))
            background = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(teal)
            }
        }
        root.addView(badge, LinearLayout.LayoutParams(dp(52), dp(52)))

        root.addView(
            TextView(this).apply {
                text = "Recenter"
                setTextColor(0xB3FFFFFF.toInt())
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            },
            margins(top = 16),
        )

        titleView = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            typeface = Typeface.DEFAULT_BOLD
        }
        root.addView(titleView, margins(top = 8))

        bodyView = TextView(this).apply {
            setTextColor(0xB3FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setLineSpacing(0f, 1.2f)
        }
        root.addView(bodyView, margins(top = 12))

        goalsView = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(goalsView, margins(top = 28))

        root.addView(View(this), LinearLayout.LayoutParams(0, 0, 1f))

        closeButton = Button(this).apply {
            setTextColor(Color.WHITE)
            isAllCaps = false
            backgroundTintList = ColorStateList.valueOf(teal)
            setOnClickListener { goHome() }
        }
        root.addView(closeButton, fullWidth(height = 56))

        unlockButton = Button(this, null, android.R.attr.borderlessButtonStyle).apply {
            isAllCaps = false
            setTextColor(
                ColorStateList(
                    arrayOf(intArrayOf(android.R.attr.state_enabled), intArrayOf()),
                    intArrayOf(Color.WHITE, 0x66FFFFFF),
                ),
            )
            setOnClickListener { unlock() }
        }
        root.addView(unlockButton, fullWidth(height = 52, top = 8))
        return root
    }

    private fun margins(top: Int) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.WRAP_CONTENT,
        LinearLayout.LayoutParams.WRAP_CONTENT,
    ).apply { topMargin = dp(top) }

    private fun fullWidth(height: Int, top: Int = 0) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        dp(height),
    ).apply { topMargin = dp(top) }

    private fun dp(value: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        resources.displayMetrics,
    ).toInt()

    companion object {
        private const val EXTRA_RULE_ID = "ruleId"
        private const val UNLOCK_DELAY_MS = 5_000L

        fun intent(context: Context, ruleId: String): Intent =
            Intent(context, PauseActivity::class.java)
                .putExtra(EXTRA_RULE_ID, ruleId)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )

        fun pendingIntent(context: Context, ruleId: String): PendingIntent =
            PendingIntent.getActivity(
                context,
                ruleId.hashCode(),
                intent(context, ruleId),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
    }
}
