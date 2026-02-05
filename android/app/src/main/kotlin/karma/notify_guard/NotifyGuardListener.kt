package karma.notify_guard

import android.app.Notification
import android.content.Context
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.*

/**
 * Extends the package's NotificationListener to add SharedPreferences storage.
 * This ensures notifications are persisted even when the app is killed.
 * The super class handles sending broadcasts to the Flutter stream.
 */
class NotifyGuardListener : notification.listener.service.NotificationListener() {

    companion object {
        const val TAG = "NotifyGuard"

        private const val PREFS_NAME = "notify_guard_pending"
        private const val KEY_PENDING = "pending_notifications"
        private const val DEDUP_WINDOW_MS = 5000L

        private val recentlySentKeys = LinkedHashMap<String, Long>(50, 0.75f, true)

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

        private fun containsWord(content: String, keyword: String): Boolean {
            return Regex("\\b${Regex.escape(keyword)}\\b").containsMatchIn(content)
        }

        private fun categorizeNotification(content: String): String {
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

    override fun onNotificationPosted(notification: StatusBarNotification?) {
        // Let package handle the broadcast to Flutter stream
        super.onNotificationPosted(notification)

        // Also save to SharedPreferences for background persistence
        notification?.let { sbn ->
            try {
                if (BLOCKED_PACKAGES.contains(sbn.packageName)) return

                val extras = sbn.notification.extras
                val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
                val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
                val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: text
                val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""

                val content = "$title $text $bigText $subText".lowercase(Locale.getDefault())
                val category = categorizeNotification(content)

                // Only save critical notifications
                if (category == "general") return

                // Dedup check
                val dedupeKey = "${sbn.key}:${sbn.postTime}"
                val now = System.currentTimeMillis()
                val lastSent = recentlySentKeys[dedupeKey]

                if (lastSent != null && (now - lastSent) < DEDUP_WINDOW_MS) return
                recentlySentKeys[dedupeKey] = now
                recentlySentKeys.entries.removeAll { (now - it.value) > DEDUP_WINDOW_MS }

                val data = mapOf(
                    "id" to sbn.id.toString(),
                    "packageName" to sbn.packageName,
                    "title" to title,
                    "text" to if (bigText.isNotEmpty()) bigText else text,
                    "category" to category,
                    "timestamp" to sbn.postTime.toString(),
                    "key" to sbn.key
                )

                savePendingNotification(data)
            } catch (e: Exception) {
                Log.e(TAG, "Error saving notification: ${e.message}")
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotifyGuardListener CONNECTED")

        // Save active notifications to pending storage
        try {
            val active = activeNotifications ?: return

            for (sbn in active) {
                if (BLOCKED_PACKAGES.contains(sbn.packageName)) continue

                val extras = sbn.notification.extras
                val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
                val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
                val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: text
                val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""

                val content = "$title $text $bigText $subText".lowercase(Locale.getDefault())
                val category = categorizeNotification(content)

                if (category == "general") continue

                val data = mapOf(
                    "id" to sbn.id.toString(),
                    "packageName" to sbn.packageName,
                    "title" to title,
                    "text" to if (bigText.isNotEmpty()) bigText else text,
                    "category" to category,
                    "timestamp" to sbn.postTime.toString(),
                    "key" to sbn.key
                )

                savePendingNotification(data)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error saving active notifications: ${e.message}")
        }
    }

    private fun savePendingNotification(data: Map<String, String>) {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existing = prefs.getString(KEY_PENDING, null)
            val array = if (existing != null) JSONArray(existing) else JSONArray()

            val newKey = data["key"] ?: ""
            val newTime = data["timestamp"] ?: ""

            // Prevent duplicates by key + timestamp
            for (i in 0 until array.length()) {
                val old = array.getJSONObject(i)
                if (old.optString("key", "") == newKey &&
                    old.optString("timestamp", "") == newTime) {
                    return
                }
            }

            val obj = JSONObject()
            data.forEach { (k, v) -> obj.put(k, v) }
            array.put(obj)

            // Keep only last 200 notifications
            while (array.length() > 200) {
                array.remove(0)
            }

            prefs.edit().putString(KEY_PENDING, array.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving pending notification: ${e.message}")
        }
    }
}
