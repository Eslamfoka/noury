package com.nouri.nouri

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Lets the adhan through Do Not Disturb.
 *
 * **Why this is native.** `flutter_local_notifications` does not expose
 * `NotificationChannel.setBypassDnd`, and there is no way to reach it from
 * Dart. Measured on the user's HONOR on 8 September 2026: all five
 * `adhan_*_v2` channels reported `mBypassDnd=false`, so Do Not Disturb
 * silenced every prayer call. That matters more here than in most apps — the
 * user works night shifts and sleeps through the day with DND on, which is
 * exactly when the adhan is the thing he most needs to hear.
 *
 * **Two Android rules govern everything below.**
 *
 * 1. `setBypassDnd(true)` is ignored unless the app holds
 *    `ACCESS_NOTIFICATION_POLICY`, which is not a runtime permission in the
 *    usual sense: it is granted by the user on a system screen, and only they
 *    can grant it. There is no dialog an app can raise.
 * 2. A channel's bypass, like its sound, is fixed when the channel is created.
 *    Calling `createNotificationChannel` again on an existing id updates its
 *    name and description and silently ignores everything else.
 *
 * Together those mean the honest sequence is: ask for access, and only once it
 * is held create the channels that bypass. So the adhan channel ids come in
 * two variants — the plain one and a `_dnd` one — and Dart picks between them
 * from [hasPolicyAccess]. Two ids rather than one is not elegant, but the
 * alternative is deleting and recreating a channel the user may have tuned,
 * which Android partly resists anyway by restoring the settings of a channel
 * that comes back under a name it has seen before.
 *
 * Nothing here decides *which* channels exist; the ids arrive from
 * `adhan_sounds.dart`, which stays the single source of truth for them.
 */
class DndPlugin(private val context: Context) {

    companion object {
        private const val METHOD_CHANNEL = "com.nouri.nouri/dnd"
    }

    /** Set by [MainActivity]; null whenever no activity is attached. */
    var activity: Activity? = null

    private val notifications: NotificationManager? =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPolicyAccess" -> result.success(hasPolicyAccess())

                "openPolicySettings" -> result.success(openPolicySettings())

                "ensureAdhanChannels" -> {
                    val specs = call.argument<List<Map<String, Any?>>>("channels")
                    if (specs == null) {
                        result.error("bad-args", "channels missing", null)
                    } else {
                        result.success(ensureAdhanChannels(specs))
                    }
                }

                "channelReport" -> result.success(
                    channelReport(call.argument<List<String>>("ids")),
                )

                "deleteChannels" -> {
                    val ids = call.argument<List<String>>("ids").orEmpty()
                    ids.forEach { notifications?.deleteNotificationChannel(it) }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Whether the user has granted Nouri notification-policy access.
     *
     * Below Android M there is no such concept and DND does not exist in the
     * form this guards against, so the answer is a plain yes.
     */
    private fun hasPolicyAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return notifications?.isNotificationPolicyAccessGranted == true
    }

    /**
     * Sends the user to the system screen where policy access is granted.
     *
     * Returns false when no activity is attached or the screen does not exist
     * on this device — some manufacturers remove it — so the caller can say so
     * rather than leave the user waiting for a screen that never opens.
     */
    private fun openPolicySettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
        val host = activity
        return try {
            if (host != null) {
                host.startActivity(intent)
            } else {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            }
            true
        } catch (_: Exception) {
            // A device without the screen, or one that refuses the intent.
            false
        }
    }

    /**
     * Creates the five adhan channels, bypassing DND when that is allowed.
     *
     * Each spec is `{id, name, description, sound, bypass}`. Returns the
     * bypass state **read back off the created channel** rather than the state
     * that was asked for: the two differ whenever policy access is missing,
     * and a screen that reports the request rather than the result is how the
     * user ends up believing the adhan will wake him when it will not.
     */
    private fun ensureAdhanChannels(
        specs: List<Map<String, Any?>>,
    ): Map<String, Boolean> {
        val manager = notifications ?: return emptyMap()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            // No channels before Oreo; DND does not gate per-channel either.
            return specs.associate { (it["id"] as String) to true }
        }

        val granted = hasPolicyAccess()
        val out = mutableMapOf<String, Boolean>()

        for (spec in specs) {
            val id = spec["id"] as? String ?: continue
            val name = spec["name"] as? String ?: id
            val description = spec["description"] as? String
            val sound = spec["sound"] as? String
            val wantsBypass = (spec["bypass"] as? Boolean) ?: false

            val channel = NotificationChannel(
                id,
                name,
                NotificationManager.IMPORTANCE_MAX,
            ).apply {
                this.description = description
                enableVibration(true)
                // Alarm usage, not notification usage. A prayer call at
                // notification volume is easy to sleep through, and the
                // difference between the two streams is the difference
                // between hearing the adhan and missing it.
                if (sound != null) {
                    val uri = Uri.parse(
                        "android.resource://${context.packageName}/raw/$sound",
                    )
                    setSound(
                        uri,
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                }
                // Honoured only with policy access; silently dropped without
                // it, which is why the caller is told what actually landed.
                setBypassDnd(wantsBypass && granted)
            }

            manager.createNotificationChannel(channel)

            val live = manager.getNotificationChannel(id)
            out[id] = live?.canBypassDnd() ?: false
        }

        return out
    }

    /**
     * What every Nouri channel currently *is*, as the system holds it.
     *
     * The settings screen reads this instead of describing what the app asked
     * for. On the user's phone MagicOS caps the adhan channels at importance 4
     * despite the 5 they are created with, and locks the field; a screen that
     * printed the request would be wrong on his most important device.
     */
    private fun channelReport(ids: List<String>?): List<Map<String, Any?>> {
        val manager = notifications ?: return emptyList()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return emptyList()
        // Filtered here rather than in Dart. Nouri owns about thirty channels
        // and each one crosses the platform boundary as a map of six values;
        // serialising all of them to answer a question about five was measured
        // at 5.5s inside `readStatus`, which sits on the startup path.
        val wanted = ids?.toSet()
        return manager.notificationChannels
            .filter { wanted == null || it.id in wanted }
            .map { channel ->
                mapOf(
                    "id" to channel.id,
                    "name" to channel.name?.toString(),
                    "importance" to channel.importance,
                    "bypassDnd" to channel.canBypassDnd(),
                    "sound" to channel.sound?.toString(),
                )
            }
    }
}
