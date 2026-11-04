package com.denovo.cash_buddy

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the SMS inbox on-device and hands messages to Dart for parsing.
 * Nothing leaves the phone. The user is asked for READ_SMS at runtime.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "cash_buddy/sms"
    private val requestCode = 4711
    private var pending: MethodChannel.Result? = null

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
                    ActivityCompat.requestPermissions(
                        this, arrayOf(Manifest.permission.READ_SMS), requestCode
                    )
                }
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
            pending?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            pending = null
        }
    }
}
