package com.denovo.cash_buddy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Sees notifications from the phone's messaging app only. If one looks like an
 * executed bank transaction, it is kept for the app to check and a private
 * "tap to review" notification is shown. Every other notification, from any
 * app, is ignored at once and never stored. The SMS inbox is never opened.
 * Nothing leaves the phone.
 */
class BankAlertListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        try {
            handle(sbn)
        } catch (e: Exception) {
            // never let one odd notification stop the service
        }
    }

    private fun handle(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        val prefs = getSharedPreferences(MainActivity.PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(MainActivity.KEY_AUTO_DETECT, false)) return
        val n = sbn.notification ?: return
        if ((n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        if (!isMessagingApp(sbn.packageName, n)) return
        val extras = n.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            ?: return
        val body = text.toString()
        val summary = summarize(body) ?: return
        if (!BankAlertQueue.add(this, title, body, sbn.postTime)) return
        showReviewNotification(summary)
    }

    /** The default messaging app, or a well-known one, or one that looks like it. */
    private fun isMessagingApp(pkg: String, n: Notification): Boolean {
        val def = Telephony.Sms.getDefaultSmsPackage(this)
        if (def != null && def == pkg) return true
        if (KNOWN_APPS.contains(pkg)) return true
        val looksLike = pkg.contains("mms") || pkg.contains("messag") || pkg.contains("sms")
        return looksLike && n.category == Notification.CATEGORY_MESSAGE
    }

    private fun showReviewNotification(summary: String) {
        val channelId = "txn_detected"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "New transactions", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Alerts when a bank message looks like a transaction"
                }
            )
        }
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_ACTION, "inbox")
        }
        val pi = PendingIntent.getActivity(
            this, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // On the lock screen show only a generic line; the amount appears after unlocking.
        val publicVersion = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Cash++")
            .setContentText("New bank alert. Unlock to review.")
            .build()
        val n = NotificationCompat.Builder(this, channelId)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
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
            NotificationManagerCompat.from(this).notify((System.currentTimeMillis() % 100000).toInt(), n)
        } catch (e: SecurityException) {
            // notifications not allowed: the app still finds the alert when it opens
        }
    }

    companion object {
        private val KNOWN_APPS = setOf(
            "com.google.android.apps.messaging",
            "com.android.mms",
            "com.samsung.android.messaging",
            "com.oneplus.mms",
            "com.coloros.mms",
            "com.oplus.mms",
            "com.miui.mms",
            "com.android.messaging",
            "com.truecaller"
        )
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
