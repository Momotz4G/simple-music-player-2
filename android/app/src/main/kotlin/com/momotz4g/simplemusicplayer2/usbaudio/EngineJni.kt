package com.momotz4g.simplemusicplayer2.usbaudio

import android.util.Log
import java.nio.ByteBuffer

/**
 * Kotlin wrapper around the C audio engine (cpp_audio_engine) loaded as
 * libaudio_engine.so + libengine_jni.so.
 *
 * The engine drives decoding + DSP for the USB DAC bypass path on Android.
 * Once UsbAudioPlayer prepares a DAC and connects, it instantiates one
 * EngineJni, calls [prepareFile] for the current track, then pulls PCM
 * frames via [readFrames] in its decode thread and feeds them into the
 * existing ring buffer that backs UsbIsoTransfer.
 *
 * Lifecycle:
 * ```
 *   val eng = EngineJni()
 *   if (!eng.create()) return
 *   eng.prepareFile(path, 48000, 24, 2, bitPerfect = true)
 *   val (sr, ch, bd) = eng.getFormat()
 *   while (running) {
 *       val frames = eng.readFrames(directBuf, framesPerChunk)
 *       if (frames < 0) break
 *   }
 *   eng.releaseRawSink()
 *   eng.dispose()
 * ```
 *
 * Threading: methods are NOT thread-safe at the wrapper level. The native
 * engine itself uses an internal mutex, but [handle] is a plain field
 * that callers must synchronize externally.
 */
class EngineJni {

    companion object {
        private const val TAG = "EngineJni"

        /** True if both native libraries loaded successfully. */
        @Volatile
        var isAvailable: Boolean = false
            private set

        init {
            isAvailable = try {
                System.loadLibrary("audio_engine")
                System.loadLibrary("engine_jni")
                Log.i(TAG, "Native libraries loaded")
                true
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load native engine libraries: ${e.message}")
                false
            } catch (e: SecurityException) {
                Log.e(TAG, "SecurityException loading engine libraries: ${e.message}")
                false
            }
        }

        // ---- Native methods (static; engine handle passed as long) ----
        @JvmStatic private external fun nativeCreate(): Long
        @JvmStatic private external fun nativeDispose(handle: Long)
        @JvmStatic private external fun nativePrepareFile(
            handle: Long, path: String,
            sampleRate: Int, bitDepth: Int, channels: Int, bitPerfect: Boolean
        ): Boolean
        @JvmStatic private external fun nativePrepareUrl(
            handle: Long, url: String, reader: JniStreamReader,
            sampleRate: Int, bitDepth: Int, channels: Int, bitPerfect: Boolean
        ): Boolean
        @JvmStatic private external fun nativeReadFrames(
            handle: Long, buffer: ByteBuffer, frameCount: Int
        ): Long
        /** Returns [sampleRate, channels, bitDepth, returnCode]; rc<0 on error. */
        @JvmStatic private external fun nativeGetFormat(handle: Long): IntArray
        @JvmStatic private external fun nativeReleaseRawSink(handle: Long)
        @JvmStatic private external fun nativeGetPosition(handle: Long): Float
        @JvmStatic private external fun nativeSeek(handle: Long, positionSeconds: Float)
        @JvmStatic private external fun nativeGetDuration(handle: Long): Float
        @JvmStatic private external fun nativeIsCompleted(handle: Long): Boolean
        @JvmStatic private external fun nativeSetVolume(handle: Long, volume: Float)
        @JvmStatic private external fun nativeSetEQBand(
            handle: Long, bandIndex: Int,
            frequency: Float, gain: Float, q: Float
        )
    }

    /** Opaque engine handle. Zero until [create] succeeds. */
    private var handle: Long = 0L

    val isCreated: Boolean get() = handle != 0L

    /**
     * Allocate a fresh engine instance. Must be called once before any
     * other method. Returns false if the native libraries are not
     * available or the engine constructor itself fails.
     */
    fun create(): Boolean {
        if (!isAvailable) {
            Log.w(TAG, "create() ignored: native libraries unavailable")
            return false
        }
        if (handle != 0L) {
            Log.w(TAG, "create() called twice; reusing existing handle")
            return true
        }
        handle = nativeCreate()
        return handle != 0L
    }

    /**
     * Configure the engine to decode [path] and apply DSP per [bitPerfect].
     *
     * Hints of 0 mean "use the file's native value":
     *  - sampleRate = 0 → engine picks the file's native rate
     *  - channels = 0 → file's native channel count
     *  - bitDepth = 0 → engine picks f32 (with EQ) or native (bit-perfect)
     *
     * When [bitPerfect] is true, EQ is bypassed and only volume scaling is
     * applied to preserve signal purity for USB DAC output.
     */
    fun prepareFile(
        path: String,
        sampleRate: Int = 0,
        bitDepth: Int = 0,
        channels: Int = 0,
        bitPerfect: Boolean = true,
    ): Boolean {
        if (handle == 0L) return false
        return nativePrepareFile(handle, path, sampleRate, bitDepth, channels, bitPerfect)
    }

    /**
     * Configure the engine to stream [url] via JniStreamReader and apply DSP per [bitPerfect].
     */
    fun prepareUrl(
        url: String,
        reader: JniStreamReader,
        sampleRate: Int = 0,
        bitDepth: Int = 0,
        channels: Int = 0,
        bitPerfect: Boolean = true,
    ): Boolean {
        if (handle == 0L) return false
        return nativePrepareUrl(handle, url, reader, sampleRate, bitDepth, channels, bitPerfect)
    }

    /**
     * Read [frameCount] frames into [directBuffer]. The buffer MUST be a
     * direct ByteBuffer (allocateDirect); otherwise the native side cannot
     * obtain a raw pointer.
     *
     * Returns:
     *  - positive = frames written
     *  - 0 = end-of-stream
     *  - negative = error
     */
    fun readFrames(directBuffer: ByteBuffer, frameCount: Int): Long {
        if (handle == 0L) return -1
        if (!directBuffer.isDirect) {
            Log.e(TAG, "readFrames requires a direct ByteBuffer")
            return -1
        }
        return nativeReadFrames(handle, directBuffer, frameCount)
    }

    /**
     * Get the negotiated PCM format after [prepareFile]. Returns Triple of
     * (sampleRate, channels, bitDepth). All zero if no raw sink is active.
     */
    fun getFormat(): Triple<Int, Int, Int> {
        if (handle == 0L) return Triple(0, 0, 0)
        val arr = nativeGetFormat(handle)
        if (arr.size < 4 || arr[3] < 0) return Triple(0, 0, 0)
        return Triple(arr[0], arr[1], arr[2])
    }

    /** Tear down the raw-sink decoder; the engine handle is preserved. */
    fun releaseRawSink() {
        if (handle == 0L) return
        nativeReleaseRawSink(handle)
    }

    /** Current playback cursor in seconds. */
    fun getPosition(): Float {
        if (handle == 0L) return 0f
        return nativeGetPosition(handle)
    }

    /** Seek to [seconds] from the start of the file. */
    fun seek(seconds: Float) {
        if (handle == 0L) return
        nativeSeek(handle, seconds)
    }

    /** Total duration of the prepared file in seconds. */
    fun getDuration(): Float {
        if (handle == 0L) return 0f
        return nativeGetDuration(handle)
    }

    /** True when the decoder has reached the end of the stream. */
    fun isCompleted(): Boolean {
        if (handle == 0L) return false
        return nativeIsCompleted(handle)
    }

    /** Linear volume in [0.0, 1.0]. Applied to PCM frames in [readFrames]. */
    fun setVolume(volume: Float) {
        if (handle == 0L) return
        nativeSetVolume(handle, volume)
    }

    /**
     * Configure one of the 10 peaking EQ bands. No-op when bit-perfect mode
     * is active for this raw sink (engine bypasses EQ in that case).
     */
    fun setEQBand(bandIndex: Int, frequency: Float, gain: Float, q: Float) {
        if (handle == 0L) return
        if (bandIndex !in 0..9) return
        nativeSetEQBand(handle, bandIndex, frequency, gain, q)
    }

    /** Free the engine instance. After this, [handle] is zero. */
    fun dispose() {
        if (handle == 0L) return
        nativeDispose(handle)
        handle = 0L
    }
}
