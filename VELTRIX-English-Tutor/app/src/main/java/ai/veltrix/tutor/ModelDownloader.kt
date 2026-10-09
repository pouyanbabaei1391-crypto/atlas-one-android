package ai.veltrix.tutor

import android.content.Context
import android.net.Uri
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/** Explicit, resumable in-app download. No model weights shipped with the APK. */
object ModelDownloader {
    private const val DOWNLOAD_URL =
        "https://huggingface.co/Antigma/Qwen3-1.7B-GGUF/resolve/main/qwen3-1.7b-q4_k_m.gguf"
    private const val FILE_SHA256 = "a7f6720f68f4a4567ebf7e3257041dd0b72077b518efe56890aec3516b59b9de"
    private const val MODEL_FILE = "veltrix-fast-qwen3-1_7b-q4km.gguf"
    private const val MIN_EXPECTED_BYTES = 1_100_000_000L

    fun modelFile(context: Context): File = File(File(context.filesDir, "models").apply { mkdirs() }, MODEL_FILE)
    fun downloaded(context: Context): Boolean {
        val file = modelFile(context)
        return file.isFile && file.length() > MIN_EXPECTED_BYTES &&
            context.getSharedPreferences("model_fast_v2", Context.MODE_PRIVATE).getBoolean("verified", false)
    }
    fun resetVerified(context: Context) = context.getSharedPreferences("model_fast_v2", Context.MODE_PRIVATE).edit().putBoolean("verified", false).apply()
    private fun markVerified(context: Context) = context.getSharedPreferences("model_fast_v2", Context.MODE_PRIVATE).edit().putBoolean("verified", true).apply()

    fun validateSHA256(file: File): Boolean {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buf = ByteArray(1024 * 1024)
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                digest.update(buf, 0, n)
            }
        }
        val hex = digest.digest().joinToString("") { "%02x".format(it) }
        return hex.equals(FILE_SHA256, true)
    }

    fun download(context: Context, progress: (Long, Long) -> Unit) {
        val dst = modelFile(context)
        if (downloaded(context)) return
        resetVerified(context)
        val tmp = File(dst.parentFile, "$MODEL_FILE.part")
        val space = dst.parentFile?.usableSpace ?: 0L
        if (space < 2_000_000_000L) throw IOException("At least 2 GB free internal storage required to download the model.")
        var error: Exception? = null
        repeat(3) { attempt ->
            try {
                var bytes = tmp.length()
                val conn = (URL(DOWNLOAD_URL).openConnection() as HttpURLConnection).apply {
                    instanceFollowRedirects = true
                    connectTimeout = 25_000
                    readTimeout = 45_000
                    setRequestProperty("User-Agent", "VELTRIX-Android/1.0")
                    if (bytes > 0) setRequestProperty("Range", "bytes=$bytes-")
                }
                try {
                    conn.connect()
                    if (conn.url.protocol != "https") throw IOException("Insecure model download redirect blocked")
                    val code = conn.responseCode
                    if (code !in listOf(200, 206)) throw IOException("Model server returned HTTP $code")
                    // A server may ignore Range. Restart rather than silently corrupting the file.
                    if (code == 200 && bytes > 0) { tmp.delete(); bytes = 0 }
                    val total = if (code == 206) {
                        conn.getHeaderField("Content-Range")?.substringAfter('/')?.toLongOrNull()
                            ?: (bytes + conn.contentLengthLong.coerceAtLeast(0))
                    } else conn.contentLengthLong
                    conn.inputStream.use { input ->
                        FileOutputStream(tmp, bytes > 0).use { output ->
                            val buf = ByteArray(256 * 1024)
                            var last = System.currentTimeMillis()
                            while (true) {
                                val n = input.read(buf)
                                if (n == -1) break
                                output.write(buf, 0, n)
                                bytes += n
                                if (System.currentTimeMillis() - last > 400) {
                                    progress(bytes, total)
                                    last = System.currentTimeMillis()
                                }
                            }
                            output.fd.sync()
                        }
                    }
                    progress(bytes, total)
                    if (bytes > 1_600_000_000L) throw IOException("Model download exceeded expected maximum size")
                    if (total > 0 && bytes != total) throw IOException("Incomplete model download ($bytes / $total bytes)")
                    if (bytes < MIN_EXPECTED_BYTES) throw IOException("Model file is unexpectedly small")
                    if (!validateSHA256(tmp)) { tmp.delete(); throw IOException("SHA-256 mismatch. Download removed; retry.") }
                    if (dst.exists()) dst.delete()
                    if (!tmp.renameTo(dst)) throw IOException("Could not finalize model installation")
                    markVerified(context)
                    return
                } finally { conn.disconnect() }
            } catch (e: Exception) {
                error = e
                if (attempt < 2) Thread.sleep((attempt + 1) * 1500L)
            }
        }
        throw IOException("Download failed after retries: ${error?.message}", error)
    }

    fun importFromUri(context: Context, uri: Uri, progress: (Long, Long) -> Unit) {
        if (downloaded(context)) return
        val dst = modelFile(context)
        resetVerified(context)
        if ((dst.parentFile?.usableSpace ?: 0L) < 2_000_000_000L) throw IOException("At least 2 GB free internal storage required")
        val tmp = File(dst.parentFile, "$MODEL_FILE.part")
        tmp.delete()
        var copied = 0L
        val input = context.contentResolver.openInputStream(uri) ?: throw IOException("Cannot open selected file")
        input.use { stream ->
            FileOutputStream(tmp).use { output ->
                val buf = ByteArray(256 * 1024)
                var last = System.currentTimeMillis()
                while (true) {
                    val n = stream.read(buf)
                    if (n < 0) break
                    output.write(buf, 0, n)
                    copied += n
                    if (System.currentTimeMillis() - last > 400) { progress(copied, 0L); last = System.currentTimeMillis() }
                }
            }
        }
        progress(copied, copied)
        if (!validateSHA256(tmp)) { tmp.delete(); throw IOException("Wrong or corrupt model: SHA-256 did not match expected model") }
        dst.delete()
        if (!tmp.renameTo(dst)) throw IOException("Could not install imported model")
        markVerified(context)
    }
}
