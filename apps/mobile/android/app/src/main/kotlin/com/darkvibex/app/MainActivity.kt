package com.darkvibex.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val roomServiceChannel = "darkvibex/room_service"
    private val permissionChannel = "darkvibex/permissions"
    private val privacyChannel = "darkvibex/privacy"
    private val pushChannel = "darkvibex/push"
    private val inviteReferralChannel = "darkvibex/invite_referral"
    private val referralPrefsName = "darkvibex_referral"
    private val referralCodeKey = "pending_invite_code"
    private val referralQueriedKey = "install_referrer_queried"
    private var inviteReferralMethodChannel: MethodChannel? = null
    private val voicePermissionRequest = 744
    private val notificationPermissionRequest = 745
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        DarkVibeXMessagingService.ensureChannel(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            roomServiceChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, DarkVibeXRoomForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stop" -> {
                    stopService(Intent(this, DarkVibeXRoomForegroundService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            permissionChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestVoiceRoom" -> requestVoiceRoomPermissions(result)
                "hasVoiceRoom" -> result.success(hasVoiceRoomPermissions())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            privacyChannel
        ).setMethodCallHandler { call, result ->
            if (call.method == "setSecure") {
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (enabled) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pushChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getToken" -> {
                    FirebaseMessaging.getInstance().token
                        .addOnCompleteListener { task ->
                            if (task.isSuccessful) {
                                result.success(task.result)
                            } else {
                                result.success(null)
                            }
                        }
                }
                "requestPermission" ->
                    requestMessageNotificationPermission(result)
                "hasPermission" ->
                    result.success(hasMessageNotificationPermission())
                else -> result.notImplemented()
            }
        }

        inviteReferralMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            inviteReferralChannel
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialInviteCode" -> resolveInitialInviteCode(result)
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun validInviteCode(value: String?): String? {
        val code = value?.trim().orEmpty()
        return if (Regex("^[1-9]\\d{6}$").matches(code)) code else null
    }

    private fun inviteCodeFromUri(uri: Uri?): String? {
        if (uri == null) return null
        if (uri.scheme == "darkvibex" && uri.host == "invite") {
            return validInviteCode(uri.pathSegments.firstOrNull())
        }
        val segments = uri.pathSegments
        if ((uri.scheme == "http" || uri.scheme == "https") &&
            segments.size >= 2 && segments[0] == "invite") {
            return validInviteCode(segments[1])
        }
        return validInviteCode(uri.getQueryParameter("invite_code"))
    }

    private fun saveInviteCode(code: String) {
        getSharedPreferences(referralPrefsName, MODE_PRIVATE)
            .edit()
            .putString(referralCodeKey, code)
            .apply()
    }

    private fun inviteCodeFromInstallReferrer(rawReferrer: String?): String? {
        val raw = rawReferrer?.trim().orEmpty()
        if (raw.isEmpty()) return null
        return try {
            val uri = Uri.parse("https://darkvibex.invalid/?$raw")
            validInviteCode(uri.getQueryParameter("invite_code"))
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveInitialInviteCode(result: MethodChannel.Result) {
        val directCode = inviteCodeFromUri(intent?.data)
        if (directCode != null) {
            saveInviteCode(directCode)
            result.success(directCode)
            return
        }

        val prefs = getSharedPreferences(referralPrefsName, MODE_PRIVATE)
        val savedCode = validInviteCode(prefs.getString(referralCodeKey, null))
        if (savedCode != null) {
            result.success(savedCode)
            return
        }
        if (prefs.getBoolean(referralQueriedKey, false)) {
            result.success(null)
            return
        }

        val client = InstallReferrerClient.newBuilder(this).build()
        client.startConnection(object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
                when (responseCode) {
                    InstallReferrerClient.InstallReferrerResponse.OK -> {
                        val code = try {
                            inviteCodeFromInstallReferrer(
                                client.installReferrer.installReferrer
                            )
                        } catch (_: Exception) {
                            null
                        }
                        prefs.edit().putBoolean(referralQueriedKey, true).apply()
                        if (code != null) saveInviteCode(code)
                        client.endConnection()
                        result.success(code)
                    }
                    InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED -> {
                        prefs.edit().putBoolean(referralQueriedKey, true).apply()
                        client.endConnection()
                        result.success(null)
                    }
                    else -> {
                        client.endConnection()
                        // SERVICE_UNAVAILABLE can be temporary; allow a retry next launch.
                        result.success(null)
                    }
                }
            }

            override fun onInstallReferrerServiceDisconnected() = Unit
        })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val code = inviteCodeFromUri(intent.data) ?: return
        saveInviteCode(code)
        inviteReferralMethodChannel?.invokeMethod("inviteCode", code)
    }

    private fun voiceRoomPermissions(): Array<String> {
        val permissions = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        return permissions.toTypedArray()
    }

    private fun hasVoiceRoomPermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestVoiceRoomPermissions(result: MethodChannel.Result) {
        if (hasVoiceRoomPermissions()) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error(
                "permission_busy",
                "Permission request is already active.",
                null
            )
            return
        }
        pendingPermissionResult = result
        requestPermissions(voiceRoomPermissions(), voicePermissionRequest)
    }

    private fun hasMessageNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestMessageNotificationPermission(result: MethodChannel.Result) {
        if (hasMessageNotificationPermission()) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.error(
                "permission_busy",
                "Notification permission request is already active.",
                null
            )
            return
        }
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequest
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationPermissionRequest) {
            pendingNotificationPermissionResult?.success(
                hasMessageNotificationPermission()
            )
            pendingNotificationPermissionResult = null
            return
        }
        if (requestCode != voicePermissionRequest) return
        pendingPermissionResult?.success(hasVoiceRoomPermissions())
        pendingPermissionResult = null
    }

    override fun onDestroy() {
        inviteReferralMethodChannel?.setMethodCallHandler(null)
        inviteReferralMethodChannel = null
        pendingPermissionResult = null
        pendingNotificationPermissionResult = null
        super.onDestroy()
    }
}
