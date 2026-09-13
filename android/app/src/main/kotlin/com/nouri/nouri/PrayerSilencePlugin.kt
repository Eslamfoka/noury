package com.nouri.nouri

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * The phone going silent for the prayer — the native half.
 *
 * The user's words, 13 September 2026: «عايزك تظبط الصامت من بعد الأذان
 * لحد ميعاد بعد الصلاة ... وبعدين يرجع تاني عام مش صامت». Dart computes
 * the windows (`prayer_silence.dart`) from the same prayer times the adhan
 * uses; this holds them in AlarmManager and, at each edge,
 * [PrayerSilenceReceiver] sets or lifts Do-Not-Disturb. Native because the
 * app is not running at fajr, and because the interruption filter is a
 * system API `flutter_local_notifications` does not reach.
 *
 * **Every window is written down** in SharedPreferences before it is armed,
 * so a reboot can put it back: AlarmManager forgets everything on reboot,
 * and the receiver re-arms from the stored list on `BOOT_COMPLETED` and on
 * an app update. Dart re-arms on every launch too, exactly like the adhan.
 *
 * **Deterministic request codes.** Each edge's PendingIntent is keyed on the
 * minute it fires and which edge it is, so arming the same window twice
 * replaces rather than duplicates — the same property the notification ids
 * have, for the same reason.
 */
class PrayerSilencePlugin(private val context: Context) {

    companion object {
        private const val METHOD_CHANNEL = "com.nouri.nouri/silence"

        const val PREFS = "nouri_prayer_silence"
        const val KEY_WINDOWS = "windows"

        /** What the receiver saved before silencing, to restore. */
        const val KEY_PREVIOUS_FILTER = "previousFilter"
        const val KEY_SILENCED_BY_NOURI = "silencedByNouri"

        const val ACTION_SILENCE = "com.nouri.nouri.SILENCE"
        const val ACTION_RESTORE = "com.nouri.nouri.RESTORE"
        const val EXTRA_AT = "at"
        const val EXTRA_PRAYER = "prayer"

        /** Arms every stored window whose restore edge is still ahead. */
        fun rearmFromStore(context: Context) {
            val stored = readWindows(context)
            val now = System.currentTimeMillis()
            for (w in stored) {
                if (w.restoreAt > now) arm(context, w)
            }
        }

        fun readWindows(context: Context): List<Window> {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_WINDOWS, null) ?: return emptyList()
            return try {
                val arr = JSONArray(raw)
                (0 until arr.length()).mapNotNull { i ->
                    val o = arr.optJSONObject(i) ?: return@mapNotNull null
                    Window(
                        prayer = o.optString("prayer", "?"),
                        silenceAt = o.optLong("silenceAt", 0L),
                        restoreAt = o.optLong("restoreAt", 0L),
                    )
                }
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun writeWindows(context: Context, windows: List<Window>) {
            val arr = JSONArray()
            for (w in windows) {
                arr.put(
                    JSONObject()
                        .put("prayer", w.prayer)
                        .put("silenceAt", w.silenceAt)
                        .put("restoreAt", w.restoreAt),
                )
            }
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_WINDOWS, arr.toString())
                .apply()
        }

        private fun pendingIntent(
            context: Context,
            action: String,
            atMillis: Long,
            prayer: String,
        ): PendingIntent {
            val intent = Intent(context, PrayerSilenceReceiver::class.java)
                .setAction(action)
                .putExtra(EXTRA_AT, atMillis)
                .putExtra(EXTRA_PRAYER, prayer)
            // One code per (minute, edge): unique for well over a year and
            // stable across launches, so the same window replaces itself.
            val minute = (atMillis / 60_000L) % 1_000_000_000L
            val code = (minute * 2 + if (action == ACTION_RESTORE) 1 else 0).toInt()
            return PendingIntent.getBroadcast(
                context,
                code,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun arm(context: Context, w: Window) {
            val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
                // Without exact alarms the edges would drift by minutes; the
                // adhan itself has the same requirement and asks for it on
                // the settings screen. Nothing to do here but wait for that.
                return
            }
            val now = System.currentTimeMillis()
            // A silence edge already passed is not armed: it would fire the
            // moment the alarm is set, silencing a phone the user is holding.
            // The receiver guards this too, for the alarm that fires late.
            if (w.silenceAt > now) {
                manager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    w.silenceAt,
                    pendingIntent(context, ACTION_SILENCE, w.silenceAt, w.prayer),
                )
            }
            if (w.restoreAt > now) {
                manager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    w.restoreAt,
                    pendingIntent(context, ACTION_RESTORE, w.restoreAt, w.prayer),
                )
            }
        }

        private fun disarm(context: Context, w: Window) {
            val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: return
            manager.cancel(pendingIntent(context, ACTION_SILENCE, w.silenceAt, w.prayer))
            manager.cancel(pendingIntent(context, ACTION_RESTORE, w.restoreAt, w.prayer))
        }

        /**
         * Lifts a silence this app set, if one is on. Called when the feature
         * is turned off, so switching it off during a prayer does not leave
         * the phone quiet until the next edge that will now never come.
         */
        fun liftIfOurs(context: Context) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(KEY_SILENCED_BY_NOURI, false)) return
            PrayerSilenceReceiver.restore(context)
        }
    }

    data class Window(val prayer: String, val silenceAt: Long, val restoreAt: Long)

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val raw = call.argument<List<Map<String, Any?>>>("windows").orEmpty()
                    val windows = raw.mapNotNull { m ->
                        val prayer = m["prayer"] as? String ?: return@mapNotNull null
                        val silenceAt = (m["silenceAt"] as? Number)?.toLong() ?: return@mapNotNull null
                        val restoreAt = (m["restoreAt"] as? Number)?.toLong() ?: return@mapNotNull null
                        Window(prayer, silenceAt, restoreAt)
                    }
                    schedule(windows)
                    result.success(true)
                }

                "cancelAll" -> {
                    schedule(emptyList())
                    liftIfOurs(context)
                    result.success(true)
                }

                "hasPolicyAccess" -> result.success(hasPolicyAccess(context))

                else -> result.notImplemented()
            }
        }
    }

    /** Replaces the armed set: disarm what was stored, store the new, arm it. */
    private fun schedule(windows: List<Window>) {
        for (old in readWindows(context)) disarm(context, old)
        writeWindows(context, windows)
        for (w in windows) arm(context, w)
    }

    private fun hasPolicyAccess(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        return nm?.isNotificationPolicyAccessGranted == true
    }
}
