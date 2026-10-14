package com.darkvibex.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlin.math.absoluteValue

class DarkVibeXMessagingService : FirebaseMessagingService() {
    companion object {
        const val CHANNEL_ID = "darkvibex_messages"
        const val CHANNEL_NAME = "DarkVibeX messages"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val MESSAGE_ENABLED_KEY = "flutter.dvx.notifications.messages"
        private const val TOKEN_KEY = "darkvibex_fcm_token"

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

        if (message.data["type"] != "direct_message") return
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

        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        openIntent.addFlags(
            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        )
        openIntent.putExtra("darkvibex_notification_type", "direct_message")
        openIntent.putExtra("darkvibex_sender_user_id", senderUserId)

        val pendingIntent = PendingIntent.getActivity(
            this,
            senderUserId.hashCode().absoluteValue,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
                .setDefaults(Notification.DEFAULT_ALL)
                .setPriority(Notification.PRIORITY_HIGH)
        }

        val notification = builder
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setContentTitle(senderName)
            .setContentText(preview)
            .setStyle(Notification.BigTextStyle().bigText(preview))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val stableId = if (messageId.isNotEmpty()) {
            messageId.hashCode().absoluteValue
        } else {
            (senderUserId + preview).hashCode().absoluteValue
        }
        getSystemService(NotificationManager::class.java)
            .notify(stableId, notification)
    }
}
