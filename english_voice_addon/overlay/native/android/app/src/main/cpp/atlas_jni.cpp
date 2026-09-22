#include <jni.h>
#include "local_engine.hpp"
#include <stdexcept>
static AtlasEngine engine;
static std::string bytes(JNIEnv *env, jbyteArray value) {
    std::string out(env->GetArrayLength(value), '\0');
    env->GetByteArrayRegion(value, 0, (jsize)out.size(), reinterpret_cast<jbyte*>(out.data()));
    return out;
}
static void fail(JNIEnv *env, const char *message) { env->ThrowNew(env->FindClass("java/lang/IllegalStateException"), message); }
extern "C" JNIEXPORT void JNICALL Java_com_atlas_one_LocalGemma_nativeLoad(JNIEnv *env, jobject, jbyteArray path, jint threads) {
    try { engine.load(bytes(env, path), threads); } catch (const std::exception &e) { fail(env, e.what()); }
}
extern "C" JNIEXPORT void JNICALL Java_com_atlas_one_LocalGemma_nativeGenerate(JNIEnv *env, jobject self, jbyteArray prompt, jint maxTokens, jint id) {
    try {
        auto cls = env->GetObjectClass(self);
        auto callback = env->GetMethodID(cls, "onToken", "(I[B)V");
        if (!callback) return;
        engine.generate(bytes(env, prompt), maxTokens, [&](const std::string &piece) {
            auto chunk = env->NewByteArray((jsize)piece.size());
            env->SetByteArrayRegion(chunk, 0, (jsize)piece.size(), reinterpret_cast<const jbyte*>(piece.data()));
            env->CallVoidMethod(self, callback, id, chunk);
            env->DeleteLocalRef(chunk);
            if (env->ExceptionCheck()) throw std::runtime_error("Token callback failed.");
        });
    } catch (const std::exception &e) { if (!env->ExceptionCheck()) fail(env, e.what()); }
}
extern "C" JNIEXPORT void JNICALL Java_com_atlas_one_LocalGemma_nativeCancel(JNIEnv *, jobject) { engine.cancel(); }

extern "C" JNIEXPORT void JNICALL Java_com_atlas_one_LocalGemma_nativeResetCancel(JNIEnv *, jobject) { engine.reset_cancel(); }
