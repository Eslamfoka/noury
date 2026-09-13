package com.nouri.nouri

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * The two edges of a prayer's silence, and the reboot that would lose them.
 *
 * **Alarms-only, and only if the phone was not already in a DND mode.** At
 * the silence edge the current interruption filter is read; if it is `ALL`
 * — the phone was ringing normally — it becomes `ALARMS` and a flag says
 * Nouri did that. At the restore edge, the filter goes back to `ALL` **only
 * if** the flag is set and the filter is still `ALARMS`: if the user changed
 * it himself in between, his choice stands. A phone that was already in
 * priority-only, total-silence or alarms-only is left exactly as it is, both
 * ways — a night-shift user asleep with DND on keeps his DND after fajr.
 *
 * `ALARMS` rather than `NONE` because the adhan, the iqama and the task
 * tones are all on the alarm stream and must still sound. It is also what
 * Android itself does when the ringer is dragged to silent, so the status
 * bar shows the familiar icon and the volume panel reads «silent».
 *
 * **Needs notification-policy access**, the same grant the adhan's DND
 * bypass needs, given once on a system screen. Without it every call below
 * throws a SecurityException, so each is guarded and the receiver simply
 * does nothing — the settings screen already tells the user where to grant
 * it.
 */
class PrayerSilenceReceiver : BroadcastReceiver() {

    companion object {
        /** A silence edge delivered more than this late is ignored. */
        private const val STALE_MS = 3 * 60_000L

        fun silence(context: Context, atMillis: Long) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as? NotificationManager ?: return
            if (!nm.isNotificationPolicyAccessGranted) return

            // Late by minutes — a phone that was off, an alarm deferred past
            // the window — means the adhan is long over; silencing now would
            // catch the user mid-conversation for no reason.
            if (System.currentTimeMillis() - atMillis > STALE_MS) return

            val prefs = context.getSharedPreferences(
                PrayerSilencePlugin.PREFS, Context.MODE_PRIVATE,
            )
            val current = try {
                nm.currentInterruptionFilter
            } catch (_: Exception) {
                return
            }
            // Only a phone that was ringing normally. Any DND the user set
            // himself is his, and the restore edge must not undo it.
            if (current != NotificationManager.INTERRUPTION_FILTER_ALL) return

            try {
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALARMS)
            } catch (_: Exception) {
                return
            }
            prefs.edit()
                .putInt(PrayerSilencePlugin.KEY_PREVIOUS_FILTER, current)
                .putBoolean(PrayerSilencePlugin.KEY_SILENCED_BY_NOURI, true)
                .apply()
        }

        fun restore(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
            val prefs = context.getSharedPreferences(
                PrayerSilencePlugin.PREFS, Context.MODE_PRIVATE,
            )
            if (!prefs.getBoolean(PrayerSilencePlugin.KEY_SILENCED_BY_NOURI, false)) return

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as? NotificationManager
            // Whatever happens below, the flag is spent: a restore that could
            // not run must not fire again at some later, unrelated edge.
            prefs.edit().putBoolean(PrayerSilencePlugin.KEY_SILENCED_BY_NOURI, false).apply()

            if (nm == null || !nm.isNotificationPolicyAccessGranted) return
            try {
                // Still as Nouri left it? Then put it back. If the user moved
                // it since — to priority-only for the night, say — that is
                // his, and it stays.
                if (nm.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALARMS) {
                    nm.setInterruptionFilter(
                        prefs.getInt(
                            PrayerSilencePlugin.KEY_PREVIOUS_FILTER,
                            NotificationManager.INTERRUPTION_FILTER_ALL,
                        ),
                    )
                }
            } catch (_: Exception) {
                // Access revoked between the two edges. Nothing to restore to.
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            PrayerSilencePlugin.ACTION_SILENCE ->
                silence(context, intent.getLongExtra(PrayerSilencePlugin.EXTRA_AT, 0L))

            PrayerSilencePlugin.ACTION_RESTORE -> restore(context)

            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" ->
                PrayerSilencePlugin.rearmFromStore(context)
        }
    }
}
