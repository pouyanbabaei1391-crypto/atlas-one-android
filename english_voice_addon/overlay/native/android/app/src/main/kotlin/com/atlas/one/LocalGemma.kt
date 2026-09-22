package com.atlas.one

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.Keep
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Bundled GGUF installation and direct in-process JNI inference. No local HTTP server. */
@Keep
object LocalGemma {
    private const val SIZE = 2489758112L
    private const val HASH = "4996030242583a40aa151ff93f49ed787ac8c25e4120c3ae4588b2e2a7d1ae94"
    private const val MODEL_URL = "https://huggingface.co/bartowski/google_gemma-3-4b-it-GGUF/resolve/main/google_gemma-3-4b-it-Q4_K_M.gguf?download=true"
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val cancelled = AtomicBoolean(false)
    private val working = AtomicBoolean(false)
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    @Volatile private var ready = false
    @Volatile private var libraryLoaded = false
    @Volatile private var state = "not_installed"
    @Volatile private var progress = 0.0
    @Volatile private var connection: HttpURLConnection? = null
    private var lastProgress = 0L
    private fun modelFile() = File(context.filesDir, "models/gemma-3-4b-Q4_K_M.gguf")
    private fun receipt() = File(context.filesDir, "models/gemma-3-4b.verified")
    private fun installed() = modelFile().length() == SIZE && receipt().takeIf { it.isFile }?.readText() == HASH
    private external fun nativeLoad(path: ByteArray, threads: Int)
    private external fun nativeGenerate(prompt: ByteArray, maxTokens: Int, id: Int)
    private external fun nativeCancel()
    private external fun nativeResetCancel()

    fun attach(app: Context, messenger: BinaryMessenger) {
        context = app.applicationContext
        channel = MethodChannel(messenger, "atlas.one/local_gemma")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(snapshot())
                "cancel" -> {
                    cancelled.set(true)
                    connection?.disconnect()
                    if (libraryLoaded) nativeCancel()
                    result.success(null)
                }
                "install", "load", "generate" -> {
                    if (!working.compareAndSet(false, true)) result.error("LOCAL_BUSY", "Gemma is already working. Wait or cancel the current operation.", null)
                    else {
                        cancelled.set(false)
                        if (libraryLoaded) nativeResetCancel()
                        worker.execute {
                            try {
                                when (call.method) {
                                    "install" -> install()
                                    "load" -> load()
                                    "generate" -> {
                                        if (!ready) throw IllegalStateException("Gemma is not ready. Complete Local AI setup first.")
                                        setState("generating", 1.0)
                                        if (cancelled.get()) throw IllegalStateException("Cancelled")
                                        nativeGenerate((call.argument<String>("prompt") ?: "").toByteArray(Charsets.UTF_8), call.argument<Int>("maxTokens") ?: 192, call.argument<Int>("id") ?: 0)
                                        setState("ready", 1.0)
                                    }
                                }
                                main.post { working.set(false); result.success(snapshot()) }
                            } catch (e: Throwable) {
                                val message = if (cancelled.get()) "Operation cancelled." else e.message ?: "Local Gemma failed. Check available memory and installation."
                                setState(if (ready) "ready" else if (installed()) "installed" else "not_installed", progress, message)
                                main.post { working.set(false); result.error("LOCAL_GEMMA", message, null) }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun snapshot(): Map<String, Any> {
        val info = ActivityManager.MemoryInfo()
        (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(info)
        return mapOf("state" to if (ready && state == "not_installed") "ready" else state,
            "ready" to ready, "installed" to installed(), "progress" to progress,
            "modelBytes" to SIZE, "freeBytes" to context.filesDir.usableSpace,
            "ramBytes" to info.totalMem, "arm64" to Build.SUPPORTED_ABIS.contains("arm64-v8a"))
    }
    private fun setState(value: String, fraction: Double, error: String? = null) {
        state = value; progress = fraction
        main.post { channel.invokeMethod("state", snapshot() + if (error == null) emptyMap() else mapOf("error" to error)) }
    }
    private fun updateProgress(bytes: Long) {
        val now = System.currentTimeMillis()
        if (now - lastProgress > 250) { lastProgress = now; setState("installing", bytes.toDouble() / SIZE) }
    }
    private fun checkCancelled() { if (cancelled.get()) throw IllegalStateException("Cancelled") }

    private fun install() {
        if (!Build.SUPPORTED_ABIS.contains("arm64-v8a")) throw IllegalStateException("This Gemma build requires a 64-bit ARM Android device.")
        if (installed()) { setState(if (ready) "ready" else "installed", 1.0); return }
        val target = modelFile()
        target.parentFile!!.mkdirs()
        val temp = File(target.parentFile, "gemma-download.part")
        if (temp.length() > SIZE) temp.delete()
        if (context.filesDir.usableSpace < SIZE - temp.length() + 268435456L) throw IllegalStateException("Not enough storage. Free at least 3 GB for Gemma setup, in addition to the APK.")
        setState("installing", temp.length().toDouble() / SIZE)
        val parts = context.assets.list("gemma")?.filter { it.endsWith(".ggufpart") }?.sorted().orEmpty()
        if (parts.isNotEmpty()) {
            // Packaged weights: install without any internet access on the phone.
            if (context.filesDir.usableSpace + temp.length() < SIZE + 268435456L) throw IllegalStateException("Insufficient storage for bundled Gemma.")
            var copied = 0L
            FileOutputStream(temp, false).use { output ->
                val buffer = ByteArray(1024 * 1024)
                for (part in parts) {
                    context.assets.open("gemma/$part").use { input ->
                        while (true) {
                            checkCancelled()
                            val count = input.read(buffer)
                            if (count < 0) break
                            output.write(buffer, 0, count); copied += count
                            if (copied > SIZE) throw IllegalStateException("Bundled model exceeds its expected size.")
                            updateProgress(copied)
                        }
                    }
                }
                output.fd.sync()
            }
        } else if (temp.length() != SIZE) {
            // Small-installer fallback. A partial download can be resumed after interruption.
            val offset = temp.length()
            val http = URL(MODEL_URL).openConnection() as HttpURLConnection
            connection = http
            try {
                http.connectTimeout = 15000; http.readTimeout = 30000
                http.setRequestProperty("Accept-Encoding", "identity")
                if (offset > 0) http.setRequestProperty("Range", "bytes=$offset-")
                val code = http.responseCode
                if (code != 200 && code != 206) throw IllegalStateException("Model download returned HTTP $code. Retry on a working connection.")
                val resume = code == 206 && offset > 0
                if (resume && http.getHeaderField("Content-Range")?.startsWith("bytes $offset-") != true) throw IllegalStateException("Invalid model download range. Please retry.")
                var copied = if (resume) offset else 0L
                http.inputStream.use { input -> FileOutputStream(temp, resume).use { output ->
                    val buffer = ByteArray(1024 * 1024)
                    while (true) {
                        checkCancelled()
                        val count = input.read(buffer)
                        if (count < 0) break
                        copied += count
                        if (copied > SIZE) throw IllegalStateException("Model download exceeds expected size.")
                        output.write(buffer, 0, count); updateProgress(copied)
                    }
                    output.fd.sync()
                } }
            } finally { http.disconnect(); connection = null }
        }
        if (temp.length() != SIZE) throw IllegalStateException("Download incomplete. Tap Install again to resume.")
        setState("verifying", 1.0)
        val digest = MessageDigest.getInstance("SHA-256")
        temp.inputStream().use { input ->
            val buffer = ByteArray(1024 * 1024)
            while (true) { checkCancelled(); val n = input.read(buffer); if (n < 0) break; digest.update(buffer, 0, n) }
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        if (actual != HASH) { temp.delete(); throw IllegalStateException("Model integrity check failed. Retry installation.") }
        if (target.exists() && !target.delete()) throw IllegalStateException("Cannot replace model file.")
        if (!temp.renameTo(target)) throw IllegalStateException("Cannot complete model installation.")
        receipt().writeText(HASH)
        setState("installed", 1.0)
    }

    private fun load() {
        if (ready) return
        if (!installed()) throw IllegalStateException("Install Gemma 3 4B before starting voice chat.")
        setState("loading", 1.0)
        if (!libraryLoaded) { System.loadLibrary("atlas_gemma"); libraryLoaded = true }
        checkCancelled()
        nativeLoad(modelFile().absolutePath.toByteArray(Charsets.UTF_8), Runtime.getRuntime().availableProcessors().coerceAtMost(4))
        checkCancelled()
        // Populate model pages before enabling the microphone. Warm-up is part of setup.
        nativeGenerate("<start_of_turn>user\nReply with OK.<end_of_turn>\n<start_of_turn>model\n".toByteArray(Charsets.UTF_8), 32, -1)
        checkCancelled()
        ready = true
        setState("ready", 1.0)
    }

    @Keep fun onToken(id: Int, bytes: ByteArray) {
        main.post { channel.invokeMethod("token", mapOf("id" to id, "bytes" to bytes)) }
    }
}
