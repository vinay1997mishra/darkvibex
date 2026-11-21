package com.darkvibex.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlin.math.absoluteValue

class DarkVibeXMessagingService : FirebaseMessagingService() {
    companion object {
        const val CHANNEL_ID = "darkvibex_messages"
        const val CHANNEL_NAME = "DarkVibeX messages"
        private const val CALLS_CHANNEL_PREFIX = "darkvibex_calls"
        private const val CALLS_CHANNEL_NAME = "DarkVibeX calls"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val MESSAGE_ENABLED_KEY = "flutter.dvx.notifications.messages"
        private const val CALL_RINGTONE_KEY = "flutter.dvx.call.ringtone"
        private const val TOKEN_KEY = "darkvibex_fcm_token"
        private val CALL_RINGTONES = setOf("classic", "chime", "melody", "gentle")

        fun ensureChannel(service: android.content.Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = service.getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Private message alerts from DarkVibeX."
            channel.enableVibration(true)
            manager.createNotificationChannel(channel)
        }

        // Call mute + ringtone (Vinay, 2026-11-21): one notification
        // channel per ringtone, because a channel's sound is fixed when
        // the channel is created. The selected tone is read from the
        // Flutter SharedPreferences mirror (dvx.call.ringtone), which
        // the app keeps in sync with the server setting. A muted call
        // never reaches here — the server refuses it before any call
        // or push exists — so no mute check is needed on the device.
        fun callChannelId(ringtoneId: String): String {
            val tone = if (CALL_RINGTONES.contains(ringtoneId)) ringtoneId else "classic"
            return "${CALLS_CHANNEL_PREFIX}_$tone"
        }

        fun ensureCallChannel(service: android.content.Context, ringtoneId: String) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = service.getSystemService(NotificationManager::class.java)
            val channelId = callChannelId(ringtoneId)
            if (manager.getNotificationChannel(channelId) != null) return
            val tone = if (CALL_RINGTONES.contains(ringtoneId)) ringtoneId else "classic"
            val sound = Uri.parse(
                "android.resource://${service.packageName}/raw/$tone"
            )
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val channel = NotificationChannel(
                channelId,
                CALLS_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Incoming call alerts from DarkVibeX."
            channel.setSound(sound, attributes)
            channel.enableVibration(true)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .putString(TOKEN_KEY, token)
            .apply()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // Notification-only receiver (background policy): it never
        // joins rooms or starts a service; it only posts a
        // notification for a known push type and drops the rest.
        if (message.data["type"] != "direct_message" &&
            message.data["type"] != "incoming_call" &&
            message.data["type"] != "missed_call") return
        when (message.data["type"]) {
            "direct_message" -> showDirectMessage(message)
            "incoming_call" -> showIncomingCall(message)
            "missed_call" -> showMissedCall(message)
            else -> return
        }
    }

    private fun launchIntent(type: String, extras: Map<String, String>): PendingIntent {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        openIntent.addFlags(
            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        )
        openIntent.putExtra("darkvibex_notification_type", type)
        for ((key, value) in extras) openIntent.putExtra(key, value)
        return PendingIntent.getActivity(
            this,
            (type + extras.values.joinToString()).hashCode().absoluteValue,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun notificationBuilder(channelId: String): Notification.Builder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
                .setDefaults(Notification.DEFAULT_ALL)
                .setPriority(Notification.PRIORITY_HIGH)
        }
    }

    private fun showDirectMessage(message: RemoteMessage) {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        if (!prefs.getBoolean(MESSAGE_ENABLED_KEY, true)) return

        ensureChannel(this)

        val senderName = message.data["sender_name"]
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: "DarkVibeX message"
        val preview = message.data["preview"]
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: "You received a new message."
        val senderUserId = message.data["sender_user_id"]?.trim().orEmpty()
        val messageId = message.data["message_id"]?.trim().orEmpty()

        val notification = notificationBuilder(CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setContentTitle(senderName)
            .setContentText(preview)
            .setStyle(Notification.BigTextStyle().bigText(preview))
            .setAutoCancel(true)
            .setContentIntent(
                launchIntent(
                    "direct_message",
                    mapOf("darkvibex_sender_user_id" to senderUserId)
                )
            )
            .build()

        val stableId = if (messageId.isNotEmpty()) {
            messageId.hashCode().absoluteValue
        } else {
            (senderUserId + preview).hashCode().absoluteValue
        }
        getSystemService(NotificationManager::class.java)
            .notify(stableId, notification)
    }

    private fun showIncomingCall(message: RemoteMessage) {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val ringtoneId = prefs.getString(CALL_RINGTONE_KEY, "classic") ?: "classic"
        ensureCallChannel(this, ringtoneId)

        val callerName = message.data["caller_name"]
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: "DarkVibeX user"
        val callerUserId = message.data["caller_user_id"]?.trim().orEmpty()
        val callId = message.data["call_id"]?.trim().orEmpty()

        val notification = notificationBuilder(callChannelId(ringtoneId))
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(callerName)
            .setContentText("Incoming call")
            .setCategory(Notification.CATEGORY_CALL)
            .setPriority(Notification.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(
                launchIntent(
                    "incoming_call",
                    mapOf(
                        "darkvibex_caller_user_id" to callerUserId,
                        "darkvibex_call_id" to callId
                    )
                )
            )
            .build()

        val stableId = if (callId.isNotEmpty()) {
            callId.hashCode().absoluteValue
        } else {
            (callerUserId + "incoming_call").hashCode().absoluteValue
        }
        getSystemService(NotificationManager::class.java)
            .notify(stableId, notification)
    }

    private fun showMissedCall(message: RemoteMessage) {
        ensureChannel(this)

        val callerName = message.data["caller_name"]
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: "DarkVibeX user"
        val callerUserId = message.data["caller_user_id"]?.trim().orEmpty()
        val callId = message.data["call_id"]?.trim().orEmpty()

        val notification = notificationBuilder(CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(callerName)
            .setContentText("Missed call")
            .setAutoCancel(true)
            .setContentIntent(
                launchIntent(
                    "missed_call",
                    mapOf(
                        "darkvibex_caller_user_id" to callerUserId,
                        "darkvibex_call_id" to callId
                    )
                )
            )
            .build()

        val stableId = if (callId.isNotEmpty()) {
            ("missed" + callId).hashCode().absoluteValue
        } else {
            (callerUserId + "missed_call").hashCode().absoluteValue
        }
        getSystemService(NotificationManager::class.java)
            .notify(stableId, notification)
    }
}
