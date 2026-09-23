package com.atlas.one

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicLong

class ScreenCaptureService : Service() {
    companion object {
        @Volatile private var latestFrame: String? = null
        fun latestFrameBase64(): String? = latestFrame
        private const val channelId = "atlas_screen_vision"
        private const val notificationId = 8801
    }

    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private val lastEncoded = AtomicLong(0L)
    private val frameLock = Any()
    private val worker = HandlerThread("atlas-frame-encoder")
    @Volatile private var captureActive = false

    override fun onCreate() {
        super.onCreate()
        worker.start()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "atlas.stop.screen") {
            stopSelf()
            return START_NOT_STICKY
        }
        val notification = makeNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(notificationId, notification)
        }
        if (projection != null) return START_NOT_STICKY

        val resultCode = intent?.getIntExtra("resultCode", Activity.RESULT_CANCELED) ?: Activity.RESULT_CANCELED
        val data = if (Build.VERSION.SDK_INT >= 33) {
            intent?.getParcelableExtra("data", Intent::class.java)
        } else {
            @Suppress("DEPRECATION") intent?.getParcelableExtra("data")
        }
        if (resultCode != Activity.RESULT_OK || data == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        projection = mgr.getMediaProjection(resultCode, data)
        projection?.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                cleanup()
                stopSelf()
            }
        }, null)

        val metrics = resources.displayMetrics
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi
        reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        captureActive = true
        reader?.setOnImageAvailableListener({ r ->
          synchronized(frameLock) {
            if (!captureActive) return@setOnImageAvailableListener
            val image = r.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                val now = SystemClock.elapsedRealtime()
                if (now - lastEncoded.get() < 250) return@setOnImageAvailableListener
                lastEncoded.set(now)
                val plane = image.planes[0]
                val buffer = plane.buffer
                val pixelStride = plane.pixelStride
                val rowStride = plane.rowStride
                val rowPadding = rowStride - pixelStride * width
                val paddedWidth = width + rowPadding / pixelStride
                val bitmap = Bitmap.createBitmap(paddedWidth, height, Bitmap.Config.ARGB_8888)
                bitmap.copyPixelsFromBuffer(buffer)
                val cropped = Bitmap.createBitmap(bitmap, 0, 0, width, height)
                val out = ByteArrayOutputStream()
                cropped.compress(Bitmap.CompressFormat.JPEG, 85, out)
                latestFrame = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
                bitmap.recycle()
                if (cropped !== bitmap) cropped.recycle()
            } finally {
                image.close()
            }
          }
        }, Handler(worker.looper))
        virtualDisplay = projection?.createVirtualDisplay(
            "AtlasScreenVision", width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            reader?.surface, null, null
        )
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        cleanup()
        worker.quitSafely()
        super.onDestroy()
    }

    private fun cleanup() {
        val oldProjection = synchronized(frameLock) {
            captureActive = false
            latestFrame = null
            reader?.setOnImageAvailableListener(null, null)
            reader?.close(); reader = null
            virtualDisplay?.release(); virtualDisplay = null
            val old = projection
            projection = null
            old
        }
        oldProjection?.stop()
    }

    private fun makeNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "دیدن صفحهٔ اطلس", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val stopIntent = PendingIntent.getService(
            this, 8802,
            Intent(this, ScreenCaptureService::class.java).setAction("atlas.stop.screen"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return builder
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle("دیدن صفحهٔ اطلس فعال است")
            .setContentText("صفحه فقط پس از تأیید شما در حال اشتراک‌گذاری است.")
            .addAction(android.R.drawable.ic_media_pause, "توقف دیدن صفحه", stopIntent)
            .setOngoing(true)
            .build()
    }
}
