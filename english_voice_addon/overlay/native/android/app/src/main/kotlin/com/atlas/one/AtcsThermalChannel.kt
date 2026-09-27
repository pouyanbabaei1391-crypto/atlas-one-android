package com.atlas.one

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Read-only Android thermal telemetry. No identifier or image leaves the phone. */
object AtcsThermalChannel {
    private const val CHANNEL = "atlas.one/atcs"

    fun install(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "telemetry") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                result.success(readTelemetry(app))
            } catch (error: Throwable) {
                result.error("ATCS_SENSOR", "Thermal telemetry is temporarily unavailable", null)
            }
        }
    }

    private fun readTelemetry(context: Context): Map<String, Any?> {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val battery = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val temperatureTenths = battery?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val status = battery?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        val thermalStatus = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            power.currentThermalStatus
        } else {
            0
        }
        val headroom = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            power.getThermalHeadroom(0).takeUnless { it.isNaN() || it.isInfinite() }
        } else {
            null
        }
        return mapOf(
            "batteryCelsius" to temperatureTenths
                ?.takeUnless { it == Int.MIN_VALUE }
                ?.div(10.0),
            "thermalHeadroom" to headroom,
            "thermalStatus" to thermalStatus,
            "batteryPercent" to if (level >= 0 && scale > 0) level * 100 / scale else -1,
            "charging" to charging,
            "powerSave" to power.isPowerSaveMode,
            "elapsedRealtimeMs" to SystemClock.elapsedRealtime(),
        )
    }
}
