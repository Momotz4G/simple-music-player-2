/**
 * engine_jni.c — JNI bridge from Kotlin (UsbAudioPlayer) to the C audio
 * engine in cpp_audio_engine. Exposes the engine's raw-sink API so
 * UsbAudioPlayer can decode any format miniaudio supports (FLAC, MP3,
 * AAC/M4A, OGG, Vorbis, WAV) and feed PCM frames into the existing USB
 * isochronous transfer pipeline (UsbIsoTransfer) for bit-perfect output
 * to USB DACs on Android <14.
 *
 * Lifecycle from the Kotlin side:
 *   long h = nativeCreate();                       // engine handle
 *   nativePrepareFile(h, path, sr, bd, ch, true);  // raw-sink decoder
 *   while (running) {
 *       long n = nativeReadFrames(h, byteBuf, n);  // pull PCM
 *   }
 *   nativeReleaseRawSink(h);
 *   nativeDispose(h);
 *
 * Memory ownership:
 *   - The engine handle (AudioHandle = void*) is owned by the JVM via
 *     the long returned from nativeCreate. Kotlin must call nativeDispose
 *     exactly once.
 *   - PCM frames are written into a caller-provided direct ByteBuffer.
 *     We never allocate or own audio memory here.
 */

#include <jni.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <android/log.h>

#include "audio_engine.h"

#define TAG "EngineJni"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN,  TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

// Convert a Kotlin jlong into the engine's opaque AudioHandle pointer.
static inline AudioHandle handle_from_jlong(jlong h) {
    return (AudioHandle)(intptr_t)h;
}

static JavaVM* g_vm = NULL;
static jmethodID g_mid_read = NULL;
static jmethodID g_mid_seek = NULL;
static jmethodID g_mid_get_size = NULL;

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    (void)reserved;
    g_vm = vm;
    JNIEnv* env = NULL;
    if ((*vm)->GetEnv(vm, (void**)&env, JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }
    jclass cls = (*env)->FindClass(env, "com/momotz4g/simplemusicplayer2/usbaudio/JniStreamReader");
    if (cls != NULL) {
        g_mid_read = (*env)->GetMethodID(env, cls, "read", "([BI)I");
        g_mid_seek = (*env)->GetMethodID(env, cls, "seek", "(J)Z");
        g_mid_get_size = (*env)->GetMethodID(env, cls, "getSize", "()J");
    }
    return JNI_VERSION_1_6;
}

// ============================================================================
// Lifecycle
// ============================================================================

JNIEXPORT jlong JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeCreate(
        JNIEnv *env, jclass cls) {
    (void)env; (void)cls;
    AudioHandle h = Engine_Create();
    if (h == NULL) {
        LOGE("Engine_Create returned NULL");
        return 0;
    }
    LOGI("nativeCreate: handle=%p", h);
    return (jlong)(intptr_t)h;
}

JNIEXPORT void JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeDispose(
        JNIEnv *env, jclass cls, jlong handle) {
    (void)env; (void)cls;
    if (handle == 0) return;
    AudioHandle h = handle_from_jlong(handle);
    LOGI("nativeDispose: handle=%p", h);
    Engine_Dispose(h);
}

// ============================================================================
// Raw-sink playback
// ============================================================================

JNIEXPORT jboolean JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativePrepareFile(
        JNIEnv *env, jclass cls,
        jlong handle, jstring jpath,
        jint sampleRate, jint bitDepth, jint channels,
        jboolean bitPerfect) {
    (void)cls;
    if (handle == 0 || jpath == NULL) return JNI_FALSE;

    const char *path = (*env)->GetStringUTFChars(env, jpath, NULL);
    if (path == NULL) {
        LOGE("nativePrepareFile: failed to acquire UTF chars");
        return JNI_FALSE;
    }

    LOGI("nativePrepareFile: path=%s sr=%d bd=%d ch=%d bp=%d",
         path, (int)sampleRate, (int)bitDepth, (int)channels, (int)bitPerfect);

    bool ok = Engine_PrepareRawSink(
        handle_from_jlong(handle), path,
        (int)sampleRate, (int)channels, (int)bitDepth,
        (bool)bitPerfect);

    (*env)->ReleaseStringUTFChars(env, jpath, path);

    if (!ok) {
        LOGW("Engine_PrepareRawSink failed");
    }
    return ok ? JNI_TRUE : JNI_FALSE;
}

// Structure to hold JNI global references for the custom stream callbacks
typedef struct {
    jobject reader_ref;
} JniStreamContext;

static size_t jni_read_cb(void* user_data, void* buffer, size_t size) {
    JniStreamContext* ctx = (JniStreamContext*)user_data;
    if (!ctx || !ctx->reader_ref) return 0;
    
    JNIEnv* env = NULL;
    int attached = 0;
    int res = (*g_vm)->GetEnv(g_vm, (void**)&env, JNI_VERSION_1_6);
    if (res == JNI_EDETACHED) {
        (*g_vm)->AttachCurrentThread(g_vm, &env, NULL);
        attached = 1;
    }
    
    if (!env) return 0;
    
    // Allocate a temporary Java byte array
    jbyteArray jbuf = (*env)->NewByteArray(env, (jsize)size);
    if (!jbuf) {
        if (attached) (*g_vm)->DetachCurrentThread(g_vm);
        return 0;
    }
    
    jint bytesRead = (*env)->CallIntMethod(env, ctx->reader_ref, g_mid_read, jbuf, (jint)size);
    
    if (bytesRead > 0) {
        (*env)->GetByteArrayRegion(env, jbuf, 0, bytesRead, (jbyte*)buffer);
    }
    
    (*env)->DeleteLocalRef(env, jbuf);
    
    if (attached) (*g_vm)->DetachCurrentThread(g_vm);
    
    return bytesRead > 0 ? (size_t)bytesRead : 0;
}

static bool jni_seek_cb(void* user_data, long long offset) {
    JniStreamContext* ctx = (JniStreamContext*)user_data;
    if (!ctx || !ctx->reader_ref) return false;
    
    JNIEnv* env = NULL;
    int attached = 0;
    if ((*g_vm)->GetEnv(g_vm, (void**)&env, JNI_VERSION_1_6) == JNI_EDETACHED) {
        (*g_vm)->AttachCurrentThread(g_vm, &env, NULL);
        attached = 1;
    }
    
    if (!env) return false;
    
    jboolean success = (*env)->CallBooleanMethod(env, ctx->reader_ref, g_mid_seek, (jlong)offset);
    
    if (attached) (*g_vm)->DetachCurrentThread(g_vm);
    return success == JNI_TRUE;
}

static long long jni_get_size_cb(void* user_data) {
    JniStreamContext* ctx = (JniStreamContext*)user_data;
    if (!ctx || !ctx->reader_ref) return -1;
    
    JNIEnv* env = NULL;
    int attached = 0;
    if ((*g_vm)->GetEnv(g_vm, (void**)&env, JNI_VERSION_1_6) == JNI_EDETACHED) {
        (*g_vm)->AttachCurrentThread(g_vm, &env, NULL);
        attached = 1;
    }
    
    if (!env) return -1;
    
    jlong size = (*env)->CallLongMethod(env, ctx->reader_ref, g_mid_get_size);
    
    if (attached) (*g_vm)->DetachCurrentThread(g_vm);
    return (long long)size;
}

JNIEXPORT jboolean JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativePrepareUrl(
        JNIEnv *env, jclass cls,
        jlong handle, jstring jurl, jobject jreader,
        jint sampleRate, jint bitDepth, jint channels,
        jboolean bitPerfect) {
    (void)cls;
    if (handle == 0 || jurl == NULL || jreader == NULL) return JNI_FALSE;

    const char *url = (*env)->GetStringUTFChars(env, jurl, NULL);
    if (url == NULL) return JNI_FALSE;

    LOGI("nativePrepareUrl: url=%s sr=%d bd=%d ch=%d bp=%d",
         url, (int)sampleRate, (int)bitDepth, (int)channels, (int)bitPerfect);

    JniStreamContext* ctx = (JniStreamContext*)malloc(sizeof(JniStreamContext));
    ctx->reader_ref = (*env)->NewGlobalRef(env, jreader);

    bool ok = Engine_PrepareRawSinkCustom(
        handle_from_jlong(handle),
        jni_read_cb, jni_seek_cb, jni_get_size_cb, ctx,
        (int)sampleRate, (int)channels, (int)bitDepth,
        (bool)bitPerfect);

    (*env)->ReleaseStringUTFChars(env, jurl, url);

    if (!ok) {
        LOGW("Engine_PrepareRawSinkCustom failed");
        (*env)->DeleteGlobalRef(env, ctx->reader_ref);
        free(ctx);
    }
    return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jlong JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeReadFrames(
        JNIEnv *env, jclass cls,
        jlong handle, jobject directBuffer, jint frameCount) {
    (void)cls;
    if (handle == 0 || directBuffer == NULL || frameCount <= 0) return -1;

    void *buf = (*env)->GetDirectBufferAddress(env, directBuffer);
    if (buf == NULL) {
        LOGE("nativeReadFrames: GetDirectBufferAddress returned NULL");
        return -1;
    }

    long long framesWritten = Engine_ReadRawFrames(
        handle_from_jlong(handle), buf, (unsigned int)frameCount);

    return (jlong)framesWritten;
}

JNIEXPORT jintArray JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeGetFormat(
        JNIEnv *env, jclass cls, jlong handle) {
    (void)cls;
    int sr = 0, ch = 0, bd = 0;
    int rc = -1;
    if (handle != 0) {
        rc = Engine_GetRawFormat(handle_from_jlong(handle), &sr, &ch, &bd);
    }

    jintArray result = (*env)->NewIntArray(env, 4);
    if (result == NULL) return NULL;

    jint values[4] = { (jint)sr, (jint)ch, (jint)bd, (jint)rc };
    (*env)->SetIntArrayRegion(env, result, 0, 4, values);
    return result;
}

JNIEXPORT void JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeReleaseRawSink(
        JNIEnv *env, jclass cls, jlong handle) {
    (void)env; (void)cls;
    if (handle == 0) return;
    
    // We must free the global ref if we used nativePrepareUrl.
    // Engine_ReleaseRawSink will clear the engine state. We need audio_engine.h 
    // to give us back the user_data pointer so we can free it.
    void* user_data = Engine_GetRawSinkUserData(handle_from_jlong(handle));
    if (user_data) {
        JniStreamContext* ctx = (JniStreamContext*)user_data;
        if (ctx->reader_ref) {
            (*env)->DeleteGlobalRef(env, ctx->reader_ref);
        }
        free(ctx);
    }
    
    Engine_ReleaseRawSink(handle_from_jlong(handle));
}

// ============================================================================
// Position + seek + duration
// ============================================================================

JNIEXPORT jfloat JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeGetPosition(
        JNIEnv *env, jclass cls, jlong handle) {
    (void)env; (void)cls;
    if (handle == 0) return 0.0f;
    return (jfloat)Engine_GetPosition(handle_from_jlong(handle));
}

JNIEXPORT void JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeSeek(
        JNIEnv *env, jclass cls, jlong handle, jfloat positionSeconds) {
    (void)env; (void)cls;
    if (handle == 0) return;
    Engine_SetPosition(handle_from_jlong(handle), (float)positionSeconds);
}

JNIEXPORT jfloat JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeGetDuration(
        JNIEnv *env, jclass cls, jlong handle) {
    (void)env; (void)cls;
    if (handle == 0) return 0.0f;
    return (jfloat)Engine_GetDuration(handle_from_jlong(handle));
}

JNIEXPORT jboolean JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeIsCompleted(
        JNIEnv *env, jclass cls, jlong handle) {
    (void)env; (void)cls;
    if (handle == 0) return JNI_FALSE;
    return Engine_IsCompleted(handle_from_jlong(handle)) ? JNI_TRUE : JNI_FALSE;
}

// ============================================================================
// DSP — volume + EQ band
// ============================================================================

JNIEXPORT void JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeSetVolume(
        JNIEnv *env, jclass cls, jlong handle, jfloat volume) {
    (void)env; (void)cls;
    if (handle == 0) return;
    Engine_SetVolume(handle_from_jlong(handle), (float)volume);
}

JNIEXPORT void JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_EngineJni_nativeSetEQBand(
        JNIEnv *env, jclass cls,
        jlong handle, jint bandIndex,
        jfloat frequency, jfloat gain, jfloat q) {
    (void)env; (void)cls;
    if (handle == 0) return;
    Engine_SetEQBand(
        handle_from_jlong(handle),
        (int)bandIndex,
        (float)frequency, (float)gain, (float)q);
}
