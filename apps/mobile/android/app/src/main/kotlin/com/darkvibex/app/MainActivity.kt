package com.darkvibex.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val roomServiceChannel = "darkvibex/room_service"
    private val permissionChannel = "darkvibex/permissions"
    private val privacyChannel = "darkvibex/privacy"
    private val pushChannel = "darkvibex/push"
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
        pendingPermissionResult = null
        pendingNotificationPermissionResult = null
        super.onDestroy()
    }
}
