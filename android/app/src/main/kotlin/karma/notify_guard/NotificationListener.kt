package karma.notify_guard

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.*

class NotificationListener : NotificationListenerService() {

    companion object {
        const val TAG = "NotifyGuard"

        // Reference to the service instance
        var instance: NotificationListener? = null

        // Set to false to capture only critical notifications (OTP, bank, security)
        var debugMode = false

        // Callback for sending notifications to Flutter
        var notificationCallback: ((Map<String, String>) -> Unit)? = null

        // Track recently sent notification keys to prevent duplicates
        private val recentlySentKeys = LinkedHashMap<String, Long>(50, 0.75f, true)
        private const val DEDUP_WINDOW_MS = 5000L

        // Keywords for detecting critical notifications
        private val OTP_KEYWORDS = listOf(
            "otp", "verification code", "verify", "one-time", "one time",
            "authentication code", "security code", "login code", "2fa",
            "two-factor", "passcode", "pin code", "confirmation code"
        )

        private val BANK_KEYWORDS = listOf(
            "bank","banking", "credit", "debit", "transaction", "payment", "upi",
            "credited", "debited", "account", "balance", "transfer",
            "withdrawn","withdraw", "deposit", "atm"
        )

        private val EMERGENCY_KEYWORDS = listOf(
            "emergency", "help", "health", "sos", "accident", "blood"
        )

        private val SECURITY_KEYWORDS = listOf(
            "security", "warning", "suspicious", "unauthorized",
            "login attempt", "new device", "password changed", "breach"
        )

        private val BLOCKED_PACKAGES = listOf(
            "com.android.systemui",
            "android",
        )
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "NotificationListener onCreate")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "NotificationListener onDestroy")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        Log.d(TAG, "========================================")
        Log.d(TAG, "NotificationListener CONNECTED!")
        Log.d(TAG, "Service is ready to receive notifications")
        Log.d(TAG, "========================================")

        // Log currently active notifications
        try {
            val activeNotifications = activeNotifications
            Log.d(TAG, "Currently active notifications: ${activeNotifications?.size ?: 0}")
            activeNotifications?.forEach { sbn ->
                Log.d(TAG, "  - ${sbn.packageName}: ${sbn.notification.extras.getCharSequence(Notification.EXTRA_TITLE)}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting active notifications: ${e.message}")
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        instance = null
        Log.d(TAG, "NotificationListener DISCONNECTED!")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        Log.d(TAG, "")
        Log.d(TAG, "╔══════════════════════════════════════╗")
        Log.d(TAG, "║    NOTIFICATION RECEIVED!            ║")
        Log.d(TAG, "╚══════════════════════════════════════╝")

        sbn?.let { notification ->
            try {
                Log.d(TAG, "Package: ${notification.packageName}")
                Log.d(TAG, "ID: ${notification.id}")
                Log.d(TAG, "Key: ${notification.key}")

                // Skip system notifications and our own app
                if (BLOCKED_PACKAGES.contains(notification.packageName)) {
                    Log.d(TAG, "⛔ Skipping blocked package")
                    return
                }

                val extras = notification.notification.extras
                val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
                val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
                val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: text
                val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""

                Log.d(TAG, "Title: $title")
                Log.d(TAG, "Text: $text")
                Log.d(TAG, "BigText: $bigText")

                val content = "$title $text $bigText $subText".lowercase(Locale.getDefault())
                val category = categorizeNotification(content)

                Log.d(TAG, "Category: $category")
                Log.d(TAG, "Debug mode: $debugMode")
                Log.d(TAG, "Callback exists: ${notificationCallback != null}")

                // In debug mode, capture ALL notifications
                if (debugMode || category != "general") {
                    val finalCategory = if (category == "general" && debugMode) "debug" else category

                    // Dedup check: skip if same key was sent recently
                    val dedupeKey = "${notification.key}:${notification.postTime}"
                    val now = System.currentTimeMillis()
                    val lastSent = recentlySentKeys[dedupeKey]
                    if (lastSent != null && (now - lastSent) < DEDUP_WINDOW_MS) {
                        Log.d(TAG, "⏭️ Skipping duplicate notification: $dedupeKey")
                        return
                    }
                    recentlySentKeys[dedupeKey] = now

                    // Cleanup old entries
                    recentlySentKeys.entries.removeAll { (now - it.value) > DEDUP_WINDOW_MS }

                    val notificationData = mapOf(
                        "id" to notification.id.toString(),
                        "packageName" to notification.packageName,
                        "title" to title,
                        "text" to if (bigText.isNotEmpty()) bigText else text,
                        "category" to finalCategory,
                        "timestamp" to notification.postTime.toString(),
                        "key" to notification.key
                    )

                    if (notificationCallback != null) {
                        Log.d(TAG, "✅ Sending to Flutter...")
                        notificationCallback?.invoke(notificationData)
                        Log.d(TAG, "✅ Sent successfully!")
                    } else {
                        Log.w(TAG, "⚠️ No callback registered - Flutter not listening")
                    }
                } else {
                    Log.d(TAG, "ℹ️ Notification skipped - not critical and debug mode is off")
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error: ${e.message}")
                e.printStackTrace()
            }
        } ?: Log.w(TAG, "⚠️ StatusBarNotification is null")
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        Log.d(TAG, "Notification removed: ${sbn?.packageName}")
    }

    private fun containsWord(content: String, keyword: String): Boolean {
        return Regex("\\b${Regex.escape(keyword)}\\b").containsMatchIn(content)
    }

    private fun categorizeNotification(content: String): String {
        // Count keyword matches per category using whole-word matching
        val scores = mapOf(
            "otp" to OTP_KEYWORDS.count { containsWord(content, it) },
            "bank" to BANK_KEYWORDS.count { containsWord(content, it) },
            "emergency" to EMERGENCY_KEYWORDS.count { containsWord(content, it) },
            "security" to SECURITY_KEYWORDS.count { containsWord(content, it) }
        )

        val best = scores.maxByOrNull { it.value }
        return if (best != null && best.value > 0) best.key else "general"
    }
}
