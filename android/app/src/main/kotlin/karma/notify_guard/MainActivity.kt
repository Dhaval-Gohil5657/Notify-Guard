package karma.notify_guard

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "karma.notify_guard/notification"
    private val EVENT_CHANNEL = "karma.notify_guard/notification_stream"

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method channel for commands from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessGranted" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openNotificationSettings" -> {
                    openNotificationListenerSettings()
                    result.success(true)
                }
                "getAppName" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        result.success(getAppNameFromPackage(packageName))
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                "openAppSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(true)
                }
                "getMissedNotifications" -> {
                    val missed = mutableListOf<Map<String, String>>()

                    // 1. Get pending notifications stored while app was killed
                    missed.addAll(NotificationListener.getPendingNotifications(this@MainActivity))
                    NotificationListener.clearPendingNotifications(this@MainActivity)

                    // 2. Get currently active notifications from the shade
                    NotificationListener.instance?.let { listener ->
                        missed.addAll(listener.getActiveNotificationData())
                    }

                    result.success(missed)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Event channel for streaming notifications to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerNotificationCallback()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterNotificationCallback()
                    eventSink = null
                }
            }
        )
    }

    private fun registerNotificationCallback() {
        NotificationListener.notificationCallback = { notificationData ->
            // Post to main thread for Flutter
            mainHandler.post {
                eventSink?.success(notificationData)
            }
        }

        // Deliver any notifications that arrived while the app was killed
        deliverPendingNotifications()
    }

    private fun deliverPendingNotifications() {
        val pending = NotificationListener.getPendingNotifications(this)
        if (pending.isNotEmpty()) {
            for (notification in pending) {
                mainHandler.post {
                    eventSink?.success(notification)
                }
            }
            NotificationListener.clearPendingNotifications(this)
        }
    }

    private fun unregisterNotificationCallback() {
        NotificationListener.notificationCallback = null
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!TextUtils.isEmpty(flat)) {
            val names = flat.split(":").toTypedArray()
            for (name in names) {
                val cn = ComponentName.unflattenFromString(name)
                if (cn != null && TextUtils.equals(pkgName, cn.packageName)) {
                    return true
                }
            }
        }
        return false
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }

    private fun getAppNameFromPackage(packageName: String): String {
        return try {
            val packageManager = applicationContext.packageManager
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    override fun onResume() {
        super.onResume()
        // Re-register callback when app resumes
        if (eventSink != null) {
            registerNotificationCallback()
        }
    }

    override fun onDestroy() {
        unregisterNotificationCallback()
        super.onDestroy()
    }
}
