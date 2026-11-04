package com.denovo.cash_buddy

import android.Manifest
import android.content.pm.PackageManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the SMS inbox on-device and hands messages to Dart for parsing.
 * Nothing leaves the phone. The user is asked for READ_SMS at runtime.
 */
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "cash_buddy/sms"
    private val requestCode = 4711
    private var pending: MethodChannel.Result? = null
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

    private fun granted() = ContextCompat.checkSelfPermission(
        this, Manifest.permission.READ_SMS
    ) == PackageManager.PERMISSION_GRANTED

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(granted())
            "requestPermission" -> {
                if (granted()) {
                    result.success(true)
                } else if (pending != null) {
                    result.error("busy", "A permission request is already in progress", null)
                } else {
                    pending = result
                    // RECEIVE_SMS lets us alert the moment a message arrives
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
                        requestCode
                    )
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
                    if (on) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
            "consumeLaunchAction" -> {
                val a = launchAction
                launchAction = null
                result.success(a)
            }
            "readInbox" -> {
                if (!granted()) {
                    result.error("no_permission", "READ_SMS not granted", null)
                    return
                }
                val since = (call.argument<Number>("sinceMillis") ?: 0).toLong()
                val limit = call.argument<Int>("limit") ?: 500
                Thread {
                    try {
                        val out = readInbox(since, limit)
                        runOnUiThread { result.success(out) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("read_failed", e.message, null) }
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun readInbox(since: Long, limit: Int): List<Map<String, Any?>> {
        val rows = ArrayList<Map<String, Any?>>()
        val cursor = contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("address", "body", "date"),
            "date > ?",
            arrayOf(since.toString()),
            "date DESC"
        ) ?: return rows
        cursor.use {
            val a = it.getColumnIndexOrThrow("address")
            val b = it.getColumnIndexOrThrow("body")
            val d = it.getColumnIndexOrThrow("date")
            while (it.moveToNext() && rows.size < limit) {
                rows.add(mapOf("address" to it.getString(a), "body" to it.getString(b), "date" to it.getLong(d)))
            }
        }
        return rows
    }

    override fun onRequestPermissionsResult(
        code: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(code, permissions, grantResults)
        if (code == requestCode) {
            val i = permissions.indexOf(Manifest.permission.READ_SMS)
            pending?.success(i >= 0 && grantResults[i] == PackageManager.PERMISSION_GRANTED)
            pending = null
        }
    }
}
