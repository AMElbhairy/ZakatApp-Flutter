package com.zakahwealth.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.PowerManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.net.Uri
import android.provider.Settings

class MainActivity : FlutterFragmentActivity() {
    private val captureChannelName = "com.zakahwealth.smartcapture"
    private val nativeChannelName = "com.zakahwealth.smartcapture.native"
    private var captureChannel: MethodChannel? = null
    private var nativeChannel: MethodChannel? = null
    private var pendingSmsPermissionResult: MethodChannel.Result? = null
    private var lastHandledNotificationTapToken: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            captureChannelName,
        )
        nativeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            nativeChannelName,
        ).apply {
            setMethodCallHandler { call: MethodCall, result ->
                when (call.method) {
                    "markShortcutServiceReady" -> {
                        AndroidSmsCaptureBridge.setFlutterReady(true)
                        AndroidSmsCaptureBridge.attachChannel(captureChannel)
                        result.success(true)
                    }
                    "getPendingShortcutMessages" -> {
                        result.success(
                            ArrayList(
                                AndroidSmsCaptureBridge.drainQueuedPayloads(
                                    this@MainActivity,
                                ),
                            ),
                        )
                    }
                    "hasSmsPermission" -> {
                        result.success(
                            AndroidSmsCaptureBridge.hasSmsPermission(
                                this@MainActivity,
                            ),
                        )
                    }
                    "isAndroidBatteryOptimizationIgnored" -> {
                        result.success(isBatteryOptimizationIgnored())
                    }
                    "requestSmsPermission" -> {
                        requestSmsPermission(result)
                    }
                    "setAndroidSmsAutoCaptureEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        AndroidSmsCaptureBridge.setEnabled(
                            this@MainActivity,
                            enabled,
                        )
                        result.success(true)
                    }
                    "syncSmartCaptureState" -> {
                        val state = call.argument<Map<String, Any?>>("state")
                        AndroidSmsCaptureBridge.saveSmartCaptureState(
                            this@MainActivity,
                            state,
                        )
                        result.success(true)
                    }
                    "openAndroidBatteryOptimizationSettings" -> {
                        result.success(
                            openBatteryOptimizationSettings(),
                        )
                    }
                    "openAndroidAppSettings" -> {
                        result.success(openAppSettings())
                    }
                    else -> result.notImplemented()
                }
            }
        }
        AndroidSmsCaptureBridge.attachChannel(captureChannel)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        val notificationLaunchPayload = extractNotificationLaunchPayload(intent)
        if (notificationLaunchPayload != null) {
            val tapToken = notificationLaunchPayload["notificationTapToken"]
            if (
                tapToken != null &&
                tapToken.isNotEmpty() &&
                tapToken == lastHandledNotificationTapToken
            ) {
                return
            }
            lastHandledNotificationTapToken = tapToken
            AndroidSmsCaptureBridge.enqueueOrDeliverNotificationLaunch(
                this,
                notificationLaunchPayload,
            )
            return
        }
        val sharedText = extractSharedText(intent) ?: return
        AndroidSmsCaptureBridge.enqueueOrDeliver(
            this,
            mapOf(
                "messageContent" to sharedText,
                "source" to "shortcut",
                "sourceIdentifier" to "Android Share",
            ),
        )
    }

    private fun extractNotificationLaunchPayload(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        val tapped = intent.getStringExtra("notificationTap")
            ?.trim()
            ?.lowercase()
            .orEmpty()
        val tapToken = intent.getStringExtra("notificationTapToken")
            ?.trim()
            .orEmpty()
        if (tapped != "true" || tapToken.isEmpty()) {
            return null
        }

        return mapOf(
            "notificationTap" to "true",
            "notificationTapToken" to tapToken,
        )
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (AndroidSmsCaptureBridge.hasSmsPermission(this)) {
            result.success(true)
            return
        }
        if (pendingSmsPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "SMS permission request is already in progress.",
                null,
            )
            return
        }
        pendingSmsPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECEIVE_SMS),
            SMS_PERMISSION_REQUEST_CODE,
        )
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                ).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } else {
                openAppSettings()
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun isBatteryOptimizationIgnored(): Boolean {
        return try {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } catch (_: Throwable) {
            false
        }
    }

    private fun openAppSettings(): Boolean {
        return try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            ).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action ?: return null
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_VIEW) {
            return null
        }

        val sharedText = when {
            intent.type == "text/plain" -> intent.getStringExtra(Intent.EXTRA_TEXT)
            else -> intent.getStringExtra(Intent.EXTRA_TEXT)
        }
        return sharedText?.trim()?.takeIf { it.isNotEmpty() }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SMS_PERMISSION_REQUEST_CODE) return
        val granted =
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingSmsPermissionResult?.success(granted)
        pendingSmsPermissionResult = null
    }

    companion object {
        private const val SMS_PERMISSION_REQUEST_CODE = 9821
    }
}
