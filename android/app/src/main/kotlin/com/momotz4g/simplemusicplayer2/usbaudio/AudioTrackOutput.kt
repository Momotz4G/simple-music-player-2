package com.momotz4g.simplemusicplayer2.usbaudio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * AudioTrackOutput — direct AudioTrack consumer for DAP built-in DAC playback.
 *
 * Replaces [UsbIsoTransfer] when the device is a DAP (Digital Audio Player)
 * that has a built-in high-quality DAC driving the 3.5mm / 4.4mm headphone
 * jack. In this mode, we bypass ExoPlayer entirely and feed PCM from the
 * C++ engine → ring buffer → AudioTrack at the file's native sample rate
 * and bit depth — true bit-perfect output.
 *
 * Audio data is pulled from the same ring buffer callback interface used by
 * UsbIsoTransfer, so the decode thread and engine remain unchanged.
 *
 * 24-bit audio is always preserved without fallback or resampling.
 * DAP audio HALs natively support 24-bit packed PCM even on API < 31
 * through their custom firmware.
 */
class AudioTrackOutput(
    private val sampleRate: Int,
    private val bitDepth: Int = 16,
    private val channels: Int = 2,
    private val isKnownDap: Boolean = false
) {
    companion object {
        private const val TAG = "AudioTrackOutput"

        // AudioFormat.ENCODING_PCM_24BIT_PACKED = 21 (SDK constant from API 31,
        // but the raw value works on DAP ROMs with custom audio HALs that
        // register 24-bit support at the AudioFlinger level).
        private const val ENCODING_PCM_24BIT_PACKED = 21
    }

    private var audioTrack: AudioTrack? = null
    @Volatile private var isRunning = false
    private var writeThread: Thread? = null
    private var audioDataCallback: ((ByteBuffer, Int) -> Int)? = null

    private val bytesPerSample = bitDepth / 8
    private val bytesPerFrame = bytesPerSample * channels

    // Statistics
    private var totalFramesWritten = 0L
    private var underrunCount = 0

    /**
     * Set the callback for requesting audio data.
     * Same signature as UsbIsoTransfer — (buffer, requestedBytes) → bytesWritten.
     */
    fun setAudioDataCallback(callback: (ByteBuffer, Int) -> Int) {
        audioDataCallback = callback
    }

    /**
     * Start streaming audio through the built-in DAC via AudioTrack.
     */
    fun start(): Boolean {
        if (isRunning) {
            Log.w(TAG, "Already running")
            return false
        }

        val isEmulator = android.os.Build.FINGERPRINT.contains("generic") ||
            android.os.Build.MODEL.contains("Emulator", ignoreCase = true) ||
            android.os.Build.MODEL.contains("sdk", ignoreCase = true)

        var isEmulatorFallback = false
        var encoding = when (bitDepth) {
            16 -> AudioFormat.ENCODING_PCM_16BIT
            24 -> ENCODING_PCM_24BIT_PACKED
            32 -> AudioFormat.ENCODING_PCM_FLOAT
            else -> {
                Log.w(TAG, "Unusual bit depth $bitDepth, using 16-bit encoding")
                AudioFormat.ENCODING_PCM_16BIT
            }
        }

        val channelMask = if (channels == 1)
            AudioFormat.CHANNEL_OUT_MONO
        else
            AudioFormat.CHANNEL_OUT_STEREO

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()

        if (encoding == ENCODING_PCM_24BIT_PACKED) {
            // Unconditionally force float fallback for ALL 24-bit ALAC.
            // This guarantees playback on all consumer phones that drop 24-bit packed streams.
            Log.w(TAG, "24-bit packed requested. Forcing Float fallback to guarantee playback.")
            encoding = AudioFormat.ENCODING_PCM_FLOAT
            isEmulatorFallback = true
        }

        try {
            val minBufferSize = AudioTrack.getMinBufferSize(sampleRate, channelMask, encoding)
            if (minBufferSize <= 0) {
                Log.e(TAG, "AudioTrack.getMinBufferSize returned $minBufferSize " +
                        "(rate=$sampleRate, ch=$channelMask, enc=$encoding) — " +
                        "DAC may not support this format natively")
                return false
            }

            // 3× minimum buffer for glitch-free, low-latency playback.
            val bufferSize = minBufferSize * 3

            val format = AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setEncoding(encoding)
                .setChannelMask(channelMask)
                .build()

            // On Android, high-res/float AudioTracks offloaded to the DSP can take
            // several milliseconds to be fully released by AudioFlinger.
            // If we try to create a new one instantly after stopping the old one, it may fail.
            // A simple retry loop guarantees we grab the resource as soon as it's free.
            var retries = 5
            while (retries > 0) {
                try {
                    audioTrack = AudioTrack.Builder()
                        .setAudioAttributes(attrs)
                        .setAudioFormat(format)
                        .setBufferSizeInBytes(bufferSize)
                        .setTransferMode(AudioTrack.MODE_STREAM)
                        .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_NONE)
                        .build()

                    if (audioTrack?.state == AudioTrack.STATE_INITIALIZED) {
                        break
                    }
                    audioTrack?.release()
                } catch (e: Exception) {
                    Log.w(TAG, "AudioTrack init exception: ${e.message}")
                }
                
                retries--
                if (retries > 0) {
                    Log.w(TAG, "AudioTrack initialization failed, retrying... ($retries left)")
                    Thread.sleep(100)
                }
            }

            if (audioTrack == null || audioTrack?.state != AudioTrack.STATE_INITIALIZED) {
                Log.e(TAG, "AudioTrack initialization definitively failed")
                return false
            }

            // Pre-fill the AudioTrack with silence before play() to prevent
            // the startup pop/click when the DAC powers up with no data.
            val preFillBytes = minOf(bufferSize / 2, minBufferSize * 2)
            if (encoding == AudioFormat.ENCODING_PCM_FLOAT) {
                val floatSilence = FloatArray(preFillBytes / 4)
                audioTrack?.write(floatSilence, 0, floatSilence.size, AudioTrack.WRITE_BLOCKING)
            } else if (encoding == ENCODING_PCM_24BIT_PACKED) {
                val bb = ByteBuffer.allocateDirect(preFillBytes).order(ByteOrder.LITTLE_ENDIAN)
                audioTrack?.write(bb, preFillBytes, AudioTrack.WRITE_BLOCKING)
            } else {
                val silence = ByteArray(preFillBytes)
                audioTrack?.write(silence, 0, preFillBytes)
            }

            audioTrack?.play()
            isRunning = true
            totalFramesWritten = 0
            underrunCount = 0
            startWriteThread(isEmulatorFallback)

            Log.i(TAG, "Started: ${sampleRate}Hz / ${bitDepth}bit / ${channels}ch, " +
                    "buffer=${bufferSize}B (${minBufferSize}B min), " +
                    "perfMode=NONE, preFill=${preFillBytes}B")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create AudioTrack: ${e.message}", e)
            return false
        }
    }

    /**
     * Stop audio streaming and release the AudioTrack.
     */
    fun stop() {
        Log.d(TAG, "Stopping. Frames written: $totalFramesWritten, Underruns: $underrunCount")
        isRunning = false

        val trackToRelease = audioTrack
        audioTrack = null
        val threadToJoin = writeThread
        writeThread = null

        // Execute AudioTrack stop and release in a background thread
        // to guarantee it never blocks the Flutter UI thread.
        Thread {
            try {
                trackToRelease?.pause()
                trackToRelease?.flush()
                trackToRelease?.stop()
            } catch (e: Exception) {
                Log.w(TAG, "AudioTrack stop error: ${e.message}")
            }

            try {
                threadToJoin?.join(1000)
            } catch (e: Exception) {}

            try {
                trackToRelease?.release()
            } catch (e: Exception) {
                Log.w(TAG, "AudioTrack release error: ${e.message}")
            }
        }.start()
    }

    fun isActive(): Boolean = isRunning

    fun getStats(): Map<String, Any> = mapOf(
        "totalFrames" to totalFramesWritten,
        "underruns" to underrunCount,
        "sampleRate" to sampleRate,
        "bitDepth" to bitDepth,
        "channels" to channels,
    )

    /**
     * Write thread — continuously pulls PCM from the ring buffer callback
     * and pushes it to AudioTrack.write(). Runs at max priority to match
     * the USB isochronous transfer thread's timing guarantees.
     */
    private fun startWriteThread(isEmulatorFallback: Boolean) {
        writeThread = thread(name = "AudioTrackWriter", priority = Thread.MAX_PRIORITY) {
            Log.d(TAG, "Write thread started")

            // Each write chunk ≈ 10ms of audio to balance latency vs. efficiency.
            val chunkFrames = sampleRate / 100
            val chunkBytes = chunkFrames * bytesPerFrame
            val packetBuffer = ByteBuffer.allocateDirect(chunkBytes)
                .order(ByteOrder.LITTLE_ENDIAN)

            val silenceBuf = ByteBuffer.allocateDirect(chunkBytes).order(ByteOrder.LITTLE_ENDIAN)
            
            // Pre-allocate conversion buffer arrays to avoid GC churn
            val convertBytes = if (isEmulatorFallback) ByteArray(chunkBytes) else null
            val convertFloats = if (isEmulatorFallback) FloatArray(chunkFrames * channels) else null
            val silenceFloats = if (isEmulatorFallback) FloatArray(chunkFrames * channels) else null

            while (isRunning) {
                try {
                    packetBuffer.clear()
                    val bytesRead = audioDataCallback?.invoke(packetBuffer, chunkBytes) ?: 0

                    if (bytesRead > 0) {
                        packetBuffer.flip()
                        packetBuffer.limit(bytesRead)

                        val written = if (isEmulatorFallback && convertBytes != null && convertFloats != null) {
                            packetBuffer.get(convertBytes, 0, bytesRead)
                            val numSamples = bytesRead / 3
                            var byteIdx = 0
                            for (i in 0 until numSamples) {
                                val b0 = convertBytes[byteIdx++].toInt() and 0xFF
                                val b1 = convertBytes[byteIdx++].toInt() and 0xFF
                                val b2 = convertBytes[byteIdx++].toInt()
                                var s24 = b0 or (b1 shl 8) or (b2 shl 16)
                                if ((s24 and 0x00800000) != 0) s24 = s24 or -16777216 // 0xFF000000
                                convertFloats[i] = s24.toFloat() / 8388608.0f
                            }
                            val w = audioTrack?.write(convertFloats, 0, numSamples, AudioTrack.WRITE_BLOCKING) ?: -1
                            if (w > 0) {
                                // Calculate written in terms of source bytes to match logic:
                                // w is the number of floats written, each sample is 4 bytes as float,
                                // but 3 bytes in 24-bit input. So (w * 3) is the equivalent source bytes written.
                                w * 3
                            } else w
                        } else {
                            audioTrack?.write(packetBuffer, bytesRead, AudioTrack.WRITE_BLOCKING) ?: -1
                        }

                        if (written < 0) {
                            Log.e(TAG, "AudioTrack.write error: $written")
                            break
                        }
                        totalFramesWritten += written / bytesPerFrame
                    } else {
                        // Ring buffer underrun — write silence to keep the
                        // AudioTrack stream continuous. Without this, the
                        // DAC's internal buffer drains and produces audible
                        // clicks/pops ("ngepret") when data resumes.
                        underrunCount++
                        if (isEmulatorFallback && silenceFloats != null) {
                            audioTrack?.write(silenceFloats, 0, silenceFloats.size, AudioTrack.WRITE_BLOCKING)
                        } else {
                            silenceBuf.clear()
                            audioTrack?.write(silenceBuf, chunkBytes, AudioTrack.WRITE_BLOCKING)
                        }
                    }
                } catch (e: Exception) {
                    if (isRunning) {
                        Log.e(TAG, "Write error: ${e.message}")
                        Thread.sleep(5)
                    }
                }
            }

            Log.d(TAG, "Write thread ended")
        }
    }
}
