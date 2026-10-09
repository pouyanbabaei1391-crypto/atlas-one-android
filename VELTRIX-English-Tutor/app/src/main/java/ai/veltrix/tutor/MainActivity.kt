package ai.veltrix.tutor

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebChromeClient
import android.view.View
import com.arm.aichat.AiChat
import com.arm.aichat.InferenceEngine
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.util.Locale

/** Android app: local WebView + official llama.cpp Android inference engine + OS STT/TTS. */
class MainActivity : Activity(), TextToSpeech.OnInitListener {
    private lateinit var web: WebView
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var engine: InferenceEngine? = null
    private var engineInitialized = false
    private var modelReady = false
    private var modelInstalling = false
    private var generation: Job? = null
    private var recognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var firstPrompt = true
    private var webLoaded = false
    private var isDownloading = false
    private var speakingEnabled = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.rgb(8, 13, 20)
        window.navigationBarColor = Color.rgb(8, 13, 20)
        window.decorView.systemUiVisibility = 0

        web = WebView(this).apply {
            setBackgroundColor(Color.rgb(8, 13, 20))
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            settings.allowFileAccessFromFileURLs = false
            settings.allowUniversalAccessFromFileURLs = false
            settings.javaScriptCanOpenWindowsAutomatically = false
            settings.setSupportMultipleWindows(false)
            webChromeClient = WebChromeClient()
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    // Only first-party packaged screens exist; never navigate to untrusted pages with JS bridge.
                    return request?.url?.toString()?.startsWith("file:///android_asset/") != true
                }
                override fun onPageFinished(view: WebView?, url: String?) {
                    webLoaded = true
                    pushStatus()
                }
            }
            addJavascriptInterface(Bridge(), "AndroidBridge")
            loadUrl("file:///android_asset/index.html")
        }
        setContentView(web)
        tts = TextToSpeech(this, this)
        scope.launch(Dispatchers.Default) {
            try {
                val e = AiChat.getInferenceEngine(applicationContext)
                withTimeout(35_000) {
                    e.state.first { it is InferenceEngine.State.Initialized || it is InferenceEngine.State.Error }
                }
                if (e.state.value is InferenceEngine.State.Error) throw IllegalStateException("Native library could not initialize")
                withContext(Dispatchers.Main) {
                    engine = e
                    engineInitialized = true
                    if (ModelDownloader.downloaded(this@MainActivity)) loadModel()
                    else pushStatus()
                }
            } catch (ex: Exception) {
                send("error", "message" to "Inference engine initialization failed: ${ex.message}")
            }
        }
    }

    inner class Bridge {
        @JavascriptInterface fun getStatus() = runOnUiThread { pushStatus() }
        // Explicitly invoke the Activity method, not this JS bridge method.
        // An unqualified installModel() here recursively resolves to Bridge.installModel(),
        // causing a Kotlin type-inference recursion error at compile time.
        @JavascriptInterface
        fun installModel(): Unit {
            this@MainActivity.runOnUiThread {
                this@MainActivity.installModel()
            }
        }
        @JavascriptInterface fun importModel() = runOnUiThread { openModelPicker() }
        @JavascriptInterface fun ask(text: String, level: String, goal: String) = runOnUiThread {
            generate(text.take(1800).trim(), level.take(3), goal.take(100))
        }
        @JavascriptInterface fun beginVoice() = runOnUiThread { startVoice() }
        @JavascriptInterface fun stopAll() = runOnUiThread { stopAllTasks() }
        @JavascriptInterface fun speak(text: String) = runOnUiThread { speakText(text.take(1900)) }
        @JavascriptInterface fun stopVoice() = runOnUiThread { tts?.stop(); recognizer?.cancel(); send("robot", "state" to "idle") }
        @JavascriptInterface fun setSpeaking(enabled: Boolean) = runOnUiThread { speakingEnabled = enabled; if (!enabled) tts?.stop() }
        @JavascriptInterface fun resetLesson() = runOnUiThread { clearConversation() }
    }

    private fun pushStatus() {
        val ready = ModelDownloader.downloaded(this)
        send("status",
            "installed" to ready,
            "ready" to modelReady,
            "engine" to engineInitialized,
            "installing" to modelInstalling,
            "storageGb" to ((filesDir.usableSpace / 1_000_000_000.0 * 10).toInt() / 10.0))
    }

    private fun send(type: String, vararg fields: Pair<String, Any?>) {
        runOnUiThread {
            if (!webLoaded) return@runOnUiThread
            val json = JSONObject().put("type", type)
            for ((key, value) in fields) json.put(key, value)
            web.evaluateJavascript("window.Veltrix&&window.Veltrix.onNative(${json})", null)
        }
    }

    private fun installModel() {
        if (isDownloading || modelInstalling) return
        if (ModelDownloader.downloaded(this)) { loadModel(); return }
        isDownloading = true
        modelInstalling = true
        send("model_progress", "percent" to 0, "message" to "Downloading local intelligence model (about 2.4 GB)…")
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    ModelDownloader.download(this@MainActivity) { current, total ->
                        val pct = if (total > 0) (100.0 * current / total).toInt().coerceIn(0, 100) else -1
                        send("model_progress", "percent" to pct, "downloadedGb" to ((current / 100_000_000.0).toInt() / 10.0), "message" to "Downloading…")
                    }
                }
                send("model_progress", "percent" to 100, "message" to "Model verified. Loading locally…")
                isDownloading = false
                loadModel()
            } catch (ex: Exception) {
                isDownloading = false
                modelInstalling = false
                send("error", "message" to (ex.message ?: "Model download failed"))
                pushStatus()
            }
        }
    }

    private fun openModelPicker() {
        if (isDownloading || modelInstalling) return
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            type = "application/octet-stream"
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        startActivityForResult(intent, 5431)
    }

    @Deprecated("Legacy file picker callback for minSdk 33 support")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 5431 || resultCode != RESULT_OK || data?.data == null) return
        val uri = data.data ?: return
        isDownloading = true
        modelInstalling = true
        send("model_progress", "percent" to -1, "message" to "Importing and verifying selected file…")
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    ModelDownloader.importFromUri(this@MainActivity, uri) { bytes, total ->
                        send("model_progress", "percent" to -1, "downloadedGb" to ((bytes / 100_000_000.0).toInt() / 10.0), "message" to "Importing…")
                    }
                }
                isDownloading = false
                loadModel()
            } catch (ex: Exception) {
                isDownloading = false; modelInstalling = false
                send("error", "message" to (ex.message ?: "Model import failed")); pushStatus()
            }
        }
    }

    private fun loadModel() {
        if (modelReady || !ModelDownloader.downloaded(this)) { pushStatus(); return }
        if (!engineInitialized || engine == null) {
            send("model_progress", "percent" to 100, "message" to "Preparing inference engine…")
            return
        }
        modelInstalling = true
        send("model_progress", "percent" to 100, "message" to "Loading model into memory. This may take a while…")
        scope.launch {
            try {
                withContext(Dispatchers.Default) {
                    engine!!.loadModel(ModelDownloader.modelFile(this@MainActivity).absolutePath)
                }
                modelReady = true
                modelInstalling = false
                firstPrompt = true
                send("model_ready", "message" to "Local MODEL ready. Start speaking English.")
                pushStatus()
            } catch (ex: Exception) {
                modelInstalling = false
                send("error", "message" to "Unable to load local model: ${ex.message}. The phone may need more free RAM.")
                pushStatus()
            }
        }
    }

    private fun generate(message: String, level: String, goal: String) {
        if (message.isEmpty()) return
        if (!modelReady || engine == null) {
            send("error", "message" to "First install and load the local model on this phone.")
            return
        }
        if (generation?.isActive == true) {
            send("error", "message" to "Wait for the current reply, or tap Stop.")
            return
        }
        tts?.stop()
        val selectedLevel = if (level in listOf("A1", "A2", "B1", "B2", "C1", "C2")) level else "A1"
        val prompt = if (firstPrompt) TutorPrompts.firstTurn(message, selectedLevel, goal)
                     else TutorPrompts.nextTurn(message, selectedLevel, goal)
        firstPrompt = false
        send("robot", "state" to "thinking")
        send("generation_start", "original" to message)
        generation = scope.launch(Dispatchers.Default) {
            val reply = StringBuilder()
            var lastUi = SystemClock.elapsedRealtime()
            try {
                engine!!.sendUserPrompt(prompt, 930).collect { token ->
                    reply.append(token)
                    val now = SystemClock.elapsedRealtime()
                    if (now - lastUi > 130L) {
                        send("generation_chunk", "text" to reply.toString())
                        lastUi = now
                    }
                }
                send("generation_chunk", "text" to reply.toString())
                if (reply.isBlank()) throw IllegalStateException("No response generated. Try again with a shorter message.")
                send("generation_done", "text" to reply.toString())
                send("robot", "state" to "happy")
            } catch (ex: CancellationException) {
                send("generation_cancelled")
                send("robot", "state" to "idle")
                throw ex
            } catch (ex: Exception) {
                send("error", "message" to "Model could not complete the reply: ${ex.message}")
                send("generation_cancelled")
                send("robot", "state" to "idle")
            }
        }
    }

    private fun stopAllTasks() {
        generation?.cancel()
        recognizer?.cancel()
        tts?.stop()
        send("robot", "state" to "idle")
    }
    private fun clearConversation() {
        stopAllTasks()
        modelReady = false
        modelInstalling = true
        send("model_progress", "percent" to 100, "message" to "Clearing conversation and reloading model…")
        scope.launch {
            try {
                generation?.join()
                withContext(Dispatchers.Default) {
                    engine?.cleanUp()
                    engine?.loadModel(ModelDownloader.modelFile(this@MainActivity).absolutePath)
                }
                firstPrompt = true
                modelInstalling = false
                modelReady = true
                send("lesson_reset", "message" to "Model context cleared. A new lesson is ready.")
                pushStatus()
            } catch (ex: Exception) {
                modelInstalling = false
                send("error", "message" to "Could not reset the lesson: ${ex.message}")
            }
        }
    }

    private fun startVoice() {
        if (!modelReady) { send("error", "message" to "Install the model before starting a voice lesson."); return }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 105)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            send("error", "message" to "No Android speech recognition service is installed. You can type instead.")
            return
        }
        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        recognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { send("robot", "state" to "listening") }
            override fun onBeginningOfSpeech() { send("robot", "state" to "listening") }
            override fun onRmsChanged(rmsdB: Float) { send("mic_level", "level" to rmsdB) }
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() { send("robot", "state" to "thinking") }
            override fun onError(error: Int) {
                send("error", "message" to "Speech recognition error ($error). Check microphone permission, offline speech pack, or connection.")
                send("robot", "state" to "idle")
            }
            override fun onResults(results: Bundle?) {
                val best = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
                if (best.isNotBlank()) send("transcription", "text" to best)
                else send("robot", "state" to "idle")
            }
            override fun onPartialResults(partialResults: Bundle?) {
                partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let {
                    send("speech_partial", "text" to it)
                }
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true) // platform best-effort, not guaranteed
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        tts?.stop()
        send("robot", "state" to "listening")
        recognizer?.startListening(intent)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 105) {
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) startVoice()
            else send("error", "message" to "Microphone permission is required for spoken lessons. Typed messages still work.")
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            ttsReady = true
            tts?.language = Locale.US
            tts?.setSpeechRate(0.90f)
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) { send("robot", "state" to "speaking") }
                override fun onDone(utteranceId: String?) { send("robot", "state" to "idle") }
                @Deprecated("Deprecated TTS callback") override fun onError(utteranceId: String?) { send("robot", "state" to "idle") }
            })
        }
    }

    private fun speakText(text: String) {
        if (!speakingEnabled || !ttsReady || text.isBlank()) return
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), "veltrix-${System.currentTimeMillis()}")
    }

    override fun onStop() { recognizer?.cancel(); super.onStop() }
    override fun onDestroy() {
        stopAllTasks()
        recognizer?.destroy()
        tts?.stop(); tts?.shutdown()
        scope.cancel()
        if (engineInitialized) try { engine?.destroy() } catch (_: Exception) {}
        web.removeJavascriptInterface("AndroidBridge")
        web.destroy()
        super.onDestroy()
    }
}
