package karma.notify_guard

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
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

        // Track recently sent notification keys to prevent duplicates in short window
        private val recentlySentKeys = LinkedHashMap<String, Long>(50, 0.75f, true)
        private const val DEDUP_WINDOW_MS = 5000L

        // Keywords for detecting critical notifications
        private val OTP_KEYWORDS = listOf(
            "otp", "verification code", "verify", "one-time", "one time",
            "authentication code", "security code", "login code", "2fa",
            "two-factor", "passcode", "pin code", "confirmation code"
        )

        private val BANK_KEYWORDS = listOf(
            "bank", "banking", "credit", "debit", "transaction", "payment", "upi",
            "credited", "debited", "account", "balance", "transfer",
            "withdrawn", "withdraw", "deposit", "atm", "rs."
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

        private const val PREFS_NAME = "notify_guard_pending"
        private const val KEY_PENDING = "pending_notifications"

        fun getPendingNotifications(context: Context): List<Map<String, String>> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_PENDING, null) ?: return emptyList()
            val result = mutableListOf<Map<String, String>>()

            try {
                val array = JSONArray(json)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val map = mutableMapOf<String, String>()
                    obj.keys().forEach { key ->
                        map[key] = obj.getString(key)
                    }
                    result.add(map)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error reading pending notifications: ${e.message}")
            }

            return result
        }

        fun clearPendingNotifications(context: Context) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().remove(KEY_PENDING).apply()
        }
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

        // If Flutter is not connected, save all active notifications to pending
        if (notificationCallback == null) {
            try {
                val active = activeNotifications
                Log.d(TAG, "Saving ${active?.size ?: 0} active notifications to pending")

                active?.forEach { notification ->
                    if (!BLOCKED_PACKAGES.contains(notification.packageName)) {

                        val extras = notification.notification.extras
                        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
                        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
                        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: text
                        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""

                        val content =
                            "$title $text $bigText $subText".lowercase(Locale.getDefault())
                        val category = categorizeNotification(content)

                        if (debugMode || category != "general") {
                            val finalCategory =
                                if (category == "general" && debugMode) "debug" else category

                            val data = mapOf(
                                "id" to notification.id.toString(),
                                "packageName" to notification.packageName,
                                "title" to title,
                                "text" to if (bigText.isNotEmpty()) bigText else text,
                                "category" to finalCategory,
                                "timestamp" to notification.postTime.toString(),
                                "key" to notification.key
                            )

                            savePendingNotification(data)
                        }
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error saving active notifications: ${e.message}")
            }
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

                // Skip system notifications and blocked packages
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

                val content =
                    "$title $text $bigText $subText".lowercase(Locale.getDefault())
                val category = categorizeNotification(content)

                Log.d(TAG, "Category: $category")
                Log.d(TAG, "Debug mode: $debugMode")
                Log.d(TAG, "Callback exists: ${notificationCallback != null}")

                // In debug mode, capture ALL notifications
                if (debugMode || category != "general") {
                    val finalCategory =
                        if (category == "general" && debugMode) "debug" else category

                    // Dedup check (fast window) to prevent spam duplicates
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

                    // ✅ FIX: ALWAYS SAVE FIRST (even if Flutter callback exists)
                    savePendingNotification(notificationData)

                    if (notificationCallback != null) {
                        Log.d(TAG, "✅ Sending to Flutter...")
                        notificationCallback?.invoke(notificationData)
                        Log.d(TAG, "✅ Sent successfully!")
                    } else {
                        Log.w(TAG, "⚠️ No callback - stored for later delivery")
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

        // ⚠️ Not needed anymore because we already save onNotificationPosted always
        // But you can keep it for extra safety if you want
    }

    fun getActiveNotificationData(): List<Map<String, String>> {
        val result = mutableListOf<Map<String, String>>()

        try {
            val active = activeNotifications ?: return result

            for (notification in active) {
                if (BLOCKED_PACKAGES.contains(notification.packageName)) continue

                val extras = notification.notification.extras
                val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
                val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
                val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: text
                val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""

                val content =
                    "$title $text $bigText $subText".lowercase(Locale.getDefault())
                val category = categorizeNotification(content)

                if (debugMode || category != "general") {
                    val finalCategory =
                        if (category == "general" && debugMode) "debug" else category

                    result.add(
                        mapOf(
                            "id" to notification.id.toString(),
                            "packageName" to notification.packageName,
                            "title" to title,
                            "text" to if (bigText.isNotEmpty()) bigText else text,
                            "category" to finalCategory,
                            "timestamp" to notification.postTime.toString(),
                            "key" to notification.key
                        )
                    )
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error getting active notification data: ${e.message}")
        }

        return result
    }

    // ✅ Updated: Save with Dedup + Limit
    private fun savePendingNotification(data: Map<String, String>) {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existing = prefs.getString(KEY_PENDING, null)
            val array = if (existing != null) JSONArray(existing) else JSONArray()

            val newKey = data["key"] ?: ""
            val newTime = data["timestamp"] ?: ""

            // ✅ Prevent duplicates by key + timestamp
            for (i in 0 until array.length()) {
                val old = array.getJSONObject(i)
                val oldKey = old.optString("key", "")
                val oldTime = old.optString("timestamp", "")
                if (oldKey == newKey && oldTime == newTime) {
                    Log.d(TAG, "⏭️ Already stored, skipping duplicate: $newKey")
                    return
                }
            }

            val obj = JSONObject()
            data.forEach { (k, v) -> obj.put(k, v) }
            array.put(obj)

            // ✅ Optional: Keep only last 200 notifications
            val max = 200
            while (array.length() > max) {
                array.remove(0)
            }

            prefs.edit().putString(KEY_PENDING, array.toString()).apply()
            Log.d(TAG, "💾 Stored pending notification (total: ${array.length()})")

        } catch (e: Exception) {
            Log.e(TAG, "Error saving pending notification: ${e.message}")
        }
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
