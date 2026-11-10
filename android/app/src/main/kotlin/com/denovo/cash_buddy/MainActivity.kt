package com.denovo.cash_buddy

import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge between the app and the bank-alert listener (BankAlertListener).
 * The app never opens the SMS inbox: it only receives the bank alerts the
 * listener saw in notifications. Nothing leaves the phone.
 */
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "cash_buddy/sms"
    private var launchAction: String? = null

    companion object {
        const val PREFS = "cash_buddy_prefs"
        const val KEY_AUTO_DETECT = "auto_detect"
        const val EXTRA_ACTION = "cb_action"
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        launchAction = intent?.getStringExtra(EXTRA_ACTION)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        launchAction = intent.getStringExtra(EXTRA_ACTION)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    /** True when the user has switched on notification access for Cash++. */
    private fun listenerOn() =
        NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(listenerOn())
            "requestPermission" -> {
                if (listenerOn()) {
                    result.success(true)
                } else {
                    // Android has no pop-up for this: open its notification access screen
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(false)
                }
            }
            "setAutoDetect" -> {
                val on = call.argument<Boolean>("enabled") ?: false
                getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_AUTO_DETECT, on).apply()
                result.success(null)
            }
            "setSecure" -> {
                val on = call.argument<Boolean>("enabled") ?: false
                runOnUiThread {
                    // Touch the window only when the flag really changes:
                    // flipping window flags can flicker on some phones.
                    val has = (window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0
                    if (on && !has) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    else if (!on && has) window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
            "consumeLaunchAction" -> {
                val a = launchAction
                launchAction = null
                result.success(a)
            }
            "readInbox" -> result.success(BankAlertQueue.drain(this))
            else -> result.notImplemented()
        }
    }
}
