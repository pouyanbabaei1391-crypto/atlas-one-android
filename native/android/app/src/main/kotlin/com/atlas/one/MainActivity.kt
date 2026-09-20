package com.atlas.one

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "atlas.one/native"
    private val screenRequest = 64001
    private var pendingScreenResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenVision" -> startScreenVision(result)
                "stopScreenVision" -> {
                    stopService(Intent(this, ScreenCaptureService::class.java))
                    result.success(null)
                }
                "captureScreenFrame" -> result.success(ScreenCaptureService.latestFrameBase64())
                "listApps" -> result.success(listLaunchableApps())
                "launchApp" -> {
                    val id = call.argument<String>("id")
                    result.success(if (id == null) false else launchPackage(id))
                }
                "revokeSensitivePermissions" -> {
                    revokeSensitivePermissions()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startScreenVision(result: MethodChannel.Result) {
        if (pendingScreenResult != null) {
            result.error("BUSY", "Screen capture permission request already active", null)
            return
        }
        pendingScreenResult = result
        val mgr = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(mgr.createScreenCaptureIntent(), screenRequest)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != screenRequest) return
        val reply = pendingScreenResult
        pendingScreenResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            reply?.success(false)
            return
        }
        val intent = Intent(this, ScreenCaptureService::class.java).apply {
            putExtra("resultCode", resultCode)
            putExtra("data", data)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
        reply?.success(true)
    }

    private fun listLaunchableApps(): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
        val infos = packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        return infos
            .map {
                mapOf(
                    "id" to it.activityInfo.packageName,
                    "name" to it.loadLabel(packageManager).toString()
                )
            }
            .distinctBy { it["id"] }
            .sortedBy { it["name"]?.lowercase() }
    }

    private fun launchPackage(packageName: String): Boolean {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(launch)
        return true
    }

    private fun revokeSensitivePermissions() {
        stopService(Intent(this, ScreenCaptureService::class.java))
        if (Build.VERSION.SDK_INT >= 33) {
            val perms = mutableListOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO)
            revokeSelfPermissionsOnKill(perms)
        }
    }
}
