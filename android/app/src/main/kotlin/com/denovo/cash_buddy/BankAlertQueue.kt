package com.denovo.cash_buddy

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Bank alerts seen in notifications wait here until the app opens and checks
 * them. Only alerts that look like a bank transaction are kept (everything
 * else is dropped straight away). The list lives in the app's private storage,
 * is left out of Android backups, is emptied when the app takes it, and keeps
 * at most 200 alerts for at most 7 days.
 */
object BankAlertQueue {
    private const val KEY = "alert_queue"
    private const val MAX = 200
    private const val KEEP_MS = 7L * 24 * 60 * 60 * 1000
    private const val SAME_ALERT_MS = 120000L

    private fun load(s: String?): JSONArray =
        try {
            if (s == null) JSONArray() else JSONArray(s)
        } catch (e: Exception) {
            JSONArray()
        }

    /** Returns false when the same alert was already queued a moment ago. */
    @Synchronized
    fun add(ctx: Context, sender: String, body: String, whenMs: Long): Boolean {
        val prefs = ctx.getSharedPreferences(MainActivity.PREFS, Context.MODE_PRIVATE)
        val arr = load(prefs.getString(KEY, null))
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val same = o.getString("address") == sender && o.getString("body") == body
            if (same && Math.abs(whenMs - o.getLong("date")) < SAME_ALERT_MS) return false
        }
        arr.put(JSONObject().put("address", sender).put("body", body).put("date", whenMs))
        val cutoff = System.currentTimeMillis() - KEEP_MS
        val start = if (arr.length() > MAX) arr.length() - MAX else 0
        val kept = JSONArray()
        for (i in start until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.getLong("date") >= cutoff) kept.put(o)
        }
        prefs.edit().putString(KEY, kept.toString()).apply()
        return true
    }

    /** Hands everything over to the app and empties the list. */
    @Synchronized
    fun drain(ctx: Context): List<Map<String, Any?>> {
        val prefs = ctx.getSharedPreferences(MainActivity.PREFS, Context.MODE_PRIVATE)
        val arr = load(prefs.getString(KEY, null))
        prefs.edit().remove(KEY).apply()
        val rows = ArrayList<Map<String, Any?>>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            rows.add(
                mapOf(
                    "address" to o.getString("address"),
                    "body" to o.getString("body"),
                    "date" to o.getLong("date")
                )
            )
        }
        return rows
    }
}
