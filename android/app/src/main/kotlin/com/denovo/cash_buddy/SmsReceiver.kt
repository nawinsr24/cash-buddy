package com.denovo.cash_buddy

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Fires the moment an SMS arrives. If it *looks like* an executed bank
 * transaction it posts a "tap to review" notification. The message itself is
 * not stored or sent anywhere here; Dart re-reads the inbox when the app opens
 * and applies the real parsing / dedup rules before anything is queued.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val prefs = context.getSharedPreferences(MainActivity.PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(MainActivity.KEY_AUTO_DETECT, false)) return

        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val body = parts.joinToString("") { it.messageBody ?: "" }
        val summary = summarize(body) ?: return

        val channelId = "txn_detected"
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "New transactions", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Alerts when a bank message looks like a transaction"
                }
            )
        }
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_ACTION, "inbox")
        }
        val pi = PendingIntent.getActivity(
            context, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("New transaction detected")
            .setContentText(summary)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$summary\nTap to review and confirm."))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify((System.currentTimeMillis() % 100000).toInt(), n)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted: silently skip, the app still finds it on next open
        }
    }

    companion object {
        private val amount = Regex("""(?i)(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)""")
        private val debit = Regex("""(?i)\b(debited|spent|withdrawn|purchase|paid|sent)\b""")
        private val credit = Regex("""(?i)\b(credited|received|deposited)\b""")
        private val reject = Regex(
            """(?i)\b(otp|one[- ]time|verification code|do not share|offer|click|apply now|pre-?approved|congratulations)\b|https?://|will be debited|declined|failed|request"""
        )

        /** Cheap pre-filter; returns e.g. "₹500.00 debited" or null if not transaction-like. */
        fun summarize(body: String): String? {
            if (reject.containsMatchIn(body)) return null
            val amt = amount.find(body)?.groupValues?.get(1) ?: return null
            val d = debit.find(body)
            val c = credit.find(body)
            val kind = when {
                d != null && (c == null || d.range.first < c.range.first) -> "debited"
                c != null -> "credited"
                else -> return null
            }
            return "₹$amt $kind"
        }
    }
}
