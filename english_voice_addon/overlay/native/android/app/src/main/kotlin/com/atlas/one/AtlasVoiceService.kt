package com.atlas.one

import android.Manifest
import android.app.*
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.*
import android.speech.*

/** Explicitly started, visible microphone session. Never auto-starts after force-stop. */
class AtlasVoiceService : Service() {
    companion object {
        var current: AtlasVoiceService? = null
            private set
        private const val CHANNEL = "atlas_voice_session"
        private const val NOTIFICATION = 64003
        private const val STOP = "com.atlas.one.STOP_VOICE"
    }
    private val main = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var generation = 0
    private var active = false
    private var useOnDevice = false
    private var listening = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var partial = ""
    private var clientId = 0
    private var watchdog: Runnable? = null

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) { endSession(); return START_NOT_STICKY }
        if (active) { AtlasVoiceHost.sessionReady(); return START_NOT_STICKY }
        try {
            if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                throw SecurityException("Microphone permission is required.")
            }
            createChannel()
            val notification = notification("Starting English voice chat…")
            if (Build.VERSION.SDK_INT >= 30) startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            else startForeground(NOTIFICATION, notification)
            useOnDevice = Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
            if (!useOnDevice && !SpeechRecognizer.isRecognitionAvailable(this)) {
                throw IllegalStateException("No Android speech recognition service is installed or enabled. Enable Speech Services or your system speech provider.")
            }
            current = this
            active = true
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Atlas:VoiceSession").apply { setReferenceCounted(false); acquire(10 * 60 * 1000L) }
            renewWakeLock()
            AtlasVoiceHost.sessionReady()
        } catch (e: Exception) {
            AtlasVoiceHost.sessionReady(e.message ?: "Voice service failed to start")
            endSession()
        }
        return START_NOT_STICKY
    }

    private fun renewWakeLock() {
        main.postDelayed({
            if (active) { wakeLock?.acquire(10 * 60 * 1000L); renewWakeLock() }
        }, 5 * 60 * 1000L)
    }

    fun listen(id: Int) {
        if (!active) return
        cancelListening()
        clientId = id
        val token = generation
        partial = ""
        listening = true
        try {
            // Always create a fresh recognizer after a completed/error/cancelled session.
            // Prefer device recognition when available, with an explicit provider fallback.
            val speech = if (Build.VERSION.SDK_INT >= 31 && useOnDevice) SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                else SpeechRecognizer.createSpeechRecognizer(this)
            recognizer = speech
            speech.setRecognitionListener(object : RecognitionListener {
                fun valid() = active && listening && token == generation
                override fun onReadyForSpeech(params: Bundle?) {
                    if (!valid()) return
                    updateStatus("Listening in English")
                    AtlasVoiceHost.event("ready", mapOf("id" to id))
                    armWatchdog(token, 20000)
                }
                override fun onBeginningOfSpeech() { if (valid()) armWatchdog(token, 60000) }
                override fun onRmsChanged(rmsdB: Float) { if (valid()) AtlasVoiceHost.event("level", mapOf("id" to id, "value" to rmsdB.toDouble())) }
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {
                    if (!valid()) return
                    updateStatus("Transcribing…")
                    armWatchdog(token, 900)
                }
                override fun onPartialResults(results: Bundle?) {
                    if (!valid()) return
                    partial = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
                    AtlasVoiceHost.event("text", mapOf("id" to id, "text" to partial, "final" to false))
                }
                override fun onResults(results: Bundle?) {
                    if (!valid()) return
                    val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty().ifBlank { partial }
                    finish(token, text)
                }
                override fun onError(error: Int) {
                    if (!valid()) return
                    if (error in listOf(6, 7) && partial.isNotBlank()) { finish(token, partial); return }
                    cancelListening()
                    if (useOnDevice && error in listOf(1, 2, 4, 12, 13) && SpeechRecognizer.isRecognitionAvailable(this@AtlasVoiceService)) {
                        useOnDevice = false
                        AtlasVoiceHost.event("error", mapOf("id" to id, "code" to 5, "message" to "Switching to the system English recognizer…", "retry" to true))
                        return
                    }
                    val retry = error in listOf(1, 2, 3, 4, 5, 6, 7, 8, 10, 11)
                    val message = when (error) {
                        1, 2 -> "Speech recognition network error. Retrying…"
                        3 -> "Audio capture failed. Close other recording apps. Retrying…"
                        4, 11 -> "Speech service disconnected. Reconnecting…"
                        5 -> "Speech recognition restarted."
                        6, 7 -> "Listening…"
                        8 -> "Speech service is busy. Retrying…"
                        9 -> "Android denied microphone access. Check microphone permission and the system microphone privacy switch."
                        10 -> "Speech provider rate limit. Waiting before retrying…"
                        12, 13 -> "English recognition is unavailable. Install English in your speech provider settings."
                        else -> "Speech recognition error $error. Check your speech provider."
                    }
                    updateStatus(message)
                    AtlasVoiceHost.event("error", mapOf("id" to id, "code" to error, "message" to message, "retry" to retry))
                }
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            speech.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 500L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 350L)
            })
            armWatchdog(token, 8000)
        } catch (e: Exception) {
            cancelListening()
            AtlasVoiceHost.event("error", mapOf("id" to id, "message" to (e.message ?: "Speech recognition failed"), "code" to -1, "retry" to false))
        }
    }

    private fun armWatchdog(token: Int, delay: Long) {
        watchdog?.let { main.removeCallbacks(it) }
        val task = Runnable {
            if (token != generation || !active || !listening) return@Runnable
            // Use the last hypothesis only when the provider never sends a final result.
            finish(token, partial)
        }
        watchdog = task
        main.postDelayed(task, delay)
    }

    private fun finish(token: Int, text: String) {
        if (token != generation) return
        val id = clientId
        cancelListening()
        if (text.isNotBlank()) AtlasVoiceHost.event("text", mapOf("id" to id, "text" to text, "final" to true))
        else AtlasVoiceHost.event("done", mapOf("id" to id))
    }

    fun cancelListening() {
        generation++
        listening = false
        watchdog?.let { main.removeCallbacks(it) }
        watchdog = null
        val old = recognizer
        recognizer = null
        try { old?.cancel() } catch (_: Exception) {}
        try { old?.destroy() } catch (_: Exception) {}
    }

    fun updateStatus(text: String) {
        if (active) (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIFICATION, notification(text))
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(NotificationChannel(CHANNEL, "Atlas voice chat", NotificationManager.IMPORTANCE_LOW))
        }
    }

    private fun notification(text: String): Notification {
        val stop = PendingIntent.getService(this, 0, Intent(this, AtlasVoiceService::class.java).setAction(STOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open = PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        return builder.setSmallIcon(android.R.drawable.ic_btn_speak_now).setContentTitle("Atlas voice chat is active")
            .setContentText(text).setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE).addAction(Notification.Action.Builder(null, "Stop voice chat", stop).build()).build()
    }

    fun endSession() {
        active = false
        cancelListening()
        AtlasVoiceHost.stopSpeaking()
        main.removeCallbacksAndMessages(null)
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        current = null
        AtlasVoiceHost.event("stopped")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (active) endSession()
        super.onDestroy()
    }
}
