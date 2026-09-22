package com.atlas.one

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Process-owned engine: closing the UI does not destroy an active voice session. */
object AtlasVoiceHost {
    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var output: TextToSpeech? = null
    private var outputReady = false
    private var outputStarting = false
    private var outputVersion = 0
    private val outputWaiters = mutableListOf<MethodChannel.Result>()
    private val spoken = mutableMapOf<String, MethodChannel.Result>()
    private var utterance = 0L
    private var sessionWaiter: MethodChannel.Result? = null
    private var startVersion = 0

    fun engine(context: Context): FlutterEngine {
        engine?.let { return it }
        val app = context.applicationContext
        val created = FlutterEngine(app)
        engine = created
        channel = MethodChannel(created.dartExecutor.binaryMessenger, "atlas.one/voice")
        channel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startSession" -> {
                        if (AtlasVoiceService.current != null) result.success(true)
                        else if (sessionWaiter != null) result.error("STARTING", "Voice is already starting.", null)
                        else {
                            sessionWaiter = result
                            val version = ++startVersion
                            val intent = Intent(app, AtlasVoiceService::class.java)
                            try {
                                if (Build.VERSION.SDK_INT >= 26) app.startForegroundService(intent)
                                else app.startService(intent)
                            } catch (e: Exception) { sessionReady(e.message ?: "Cannot start voice service") }
                            main.postDelayed({
                                if (version == startVersion && sessionWaiter != null) {
                                    sessionReady("Voice service did not start. Open Atlas and try again.")
                                    app.stopService(intent)
                                }
                            }, 10000)
                        }
                    }
                    "endSession" -> {
                        startVersion++
                        sessionWaiter?.error("CANCELLED", "Voice start cancelled.", null)
                        sessionWaiter = null
                        AtlasVoiceService.current?.endSession()
                        app.stopService(Intent(app, AtlasVoiceService::class.java))
                        result.success(null)
                    }
                    "listen" -> {
                        val service = AtlasVoiceService.current
                        if (service == null) result.error("SESSION_STOPPED", "Start voice chat while Atlas is open.", null)
                        else { service.listen(call.argument<Int>("id") ?: 0); result.success(null) }
                    }
                    "cancelListening" -> { AtlasVoiceService.current?.cancelListening(); result.success(null) }
                    "prepareOutput" -> prepareOutput(app, result)
                    "speak" -> speak(call.argument<String>("text") ?: "", result)
                    "stopSpeaking" -> { stopSpeaking(); result.success(null) }
                    "status" -> { AtlasVoiceService.current?.updateStatus(call.argument<String>("text") ?: "Voice chat active"); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("VOICE_ERROR", e.message ?: "Voice operation failed", null) }
        }
        created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return created
    }

    fun event(type: String, values: Map<String, Any?> = emptyMap()) {
        main.post { channel?.invokeMethod("event", values + ("type" to type)) }
    }

    fun sessionReady(error: String? = null) {
        val result = sessionWaiter
        sessionWaiter = null
        if (error == null) result?.success(true)
        else result?.error("VOICE_SERVICE", error, null)
    }

    private fun prepareOutput(context: Context, result: MethodChannel.Result) {
        if (outputReady) { result.success(true); return }
        outputWaiters.add(result)
        if (outputStarting) return
        outputStarting = true
        val version = ++outputVersion
        output?.shutdown()
        output = TextToSpeech(context) { status ->
            main.post {
                if (!outputStarting || version != outputVersion) return@post
                val tts = output
                var error: String? = null
                try {
                if (status != TextToSpeech.SUCCESS || tts == null) error = "No working text-to-speech engine. Install or enable an English system voice."
                else {
                    var language = tts.setLanguage(Locale.US)
                    if (language < TextToSpeech.LANG_AVAILABLE) language = tts.setLanguage(Locale.UK)
                    if (language < TextToSpeech.LANG_AVAILABLE) language = tts.setLanguage(Locale.ENGLISH)
                    if (language < TextToSpeech.LANG_AVAILABLE) error = "English voice data is missing. Install English in Android Text-to-speech settings."
                    else {
                        val local = tts.voices?.filter { it.locale.language == "en" && !it.isNetworkConnectionRequired }
                            ?.sortedWith(compareByDescending<android.speech.tts.Voice> { it.locale == Locale.US }.thenByDescending { it.quality })?.firstOrNull()
                        if (local != null) tts.voice = local
                        tts.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANT).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                        tts.setSpeechRate(1.0f)
                        tts.setPitch(1.0f)
                        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                            override fun onStart(id: String?) { event("speaking") }
                            override fun onDone(id: String?) { completeSpeech(id, null) }
                            @Deprecated("Deprecated in Java")
                            override fun onError(id: String?) { completeSpeech(id, "Speech playback failed. Check your media volume and English voice.") }
                            override fun onError(id: String?, errorCode: Int) { completeSpeech(id, "Speech playback failed (TTS $errorCode). Check your English voice and audio output.") }
                        })
                    }
                }
                } catch (e: Exception) { error = e.message ?: "Could not initialize the English voice." }
                finishOutput(error)
            }
        }
        main.postDelayed({ if (outputStarting && version == outputVersion) finishOutput("Text-to-speech initialization timed out. Check Android speech settings.") }, 8000)
    }

    private fun finishOutput(error: String?) {
        outputStarting = false
        outputReady = error == null
        val waiting = outputWaiters.toList()
        outputWaiters.clear()
        for (result in waiting) {
            if (error == null) result.success(true) else result.error("TTS_UNAVAILABLE", error, null)
        }
    }

    private fun speak(text: String, result: MethodChannel.Result) {
        if (!outputReady) { result.error("TTS_UNAVAILABLE", "Prepare the English voice first.", null); return }
        if (text.isBlank()) { result.success(null); return }
        val id = "atlas-${++utterance}"
        spoken[id] = result
        val parameters = android.os.Bundle().apply { putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f) }
        if (output!!.speak(text, TextToSpeech.QUEUE_ADD, parameters, id) == TextToSpeech.ERROR) {
            completeSpeech(id, "The speech engine rejected playback.")
        }
        main.postDelayed({
            if (spoken.containsKey(id)) {
                completeSpeech(id, "Speech playback timed out.")
                stopSpeaking()
            }
        }, 45000)
    }

    private fun completeSpeech(id: String?, error: String?) {
        main.post {
            val result = spoken.remove(id) ?: return@post
            if (error == null) result.success(null) else { outputReady = false; result.error("TTS_PLAYBACK", error, null) }
        }
    }

    fun stopSpeaking() {
        output?.stop()
        val waiting = spoken.values.toList()
        spoken.clear()
        for (result in waiting) result.success(null)
    }
}
