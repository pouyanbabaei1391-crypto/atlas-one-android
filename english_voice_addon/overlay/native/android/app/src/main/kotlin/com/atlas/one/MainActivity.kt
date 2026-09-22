package com.atlas.one

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine = AtlasVoiceHost.engine(context)
    override fun shouldDestroyEngineWithHost(): Boolean = false

    private val channelName = "atlas.one/native"
    private val screenRequest = 64001
    private var pendingScreenResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
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
                    result.success(id != null && launchPackage(id))
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
            result.error("BUSY", "Screen capture consent request is already active", null)
            return
        }
        pendingScreenResult = result
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        @Suppress("DEPRECATION")
        startActivityForResult(manager.createScreenCaptureIntent(), screenRequest)
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

        val serviceIntent = Intent(this, ScreenCaptureService::class.java).apply {
            putExtra("resultCode", resultCode)
            putExtra("data", data)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        reply?.success(true)
    }

    private fun listLaunchableApps(): List<Map<String, String?>> {
        val query = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
        val flags = if (Build.VERSION.SDK_INT >= 33) {
            PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong())
        } else {
            @Suppress("DEPRECATION")
            null
        }
        val infos = if (Build.VERSION.SDK_INT >= 33 && flags != null) {
            packageManager.queryIntentActivities(query, flags)
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(query, PackageManager.MATCH_ALL)
        }

        return infos
            .map { info ->
                val icon = try {
                    drawableToBase64(info.loadIcon(packageManager))
                } catch (_: Throwable) {
                    null
                }
                mapOf(
                    "id" to info.activityInfo.packageName,
                    "name" to info.loadLabel(packageManager).toString(),
                    "iconBase64" to icon,
                )
            }
            .distinctBy { it["id"] }
            .sortedBy { it["name"]?.lowercase() }
    }

    private fun drawableToBase64(drawable: Drawable): String? {
        val width = drawable.intrinsicWidth.takeIf { it > 0 }?.coerceAtMost(160) ?: 96
        val height = drawable.intrinsicHeight.takeIf { it > 0 }?.coerceAtMost(160) ?: 96
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
        bitmap.recycle()
        return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    }

    private fun launchPackage(packageName: String): Boolean {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(launchIntent)
        return true
    }

    private fun revokeSensitivePermissions() {
        stopService(Intent(this, ScreenCaptureService::class.java))
        if (Build.VERSION.SDK_INT >= 33) {
            revokeSelfPermissionsOnKill(
                listOf(
                    Manifest.permission.CAMERA,
                    Manifest.permission.RECORD_AUDIO,
                ),
            )
        }
    }
}
