package com.momotz4g.simplemusicplayer2.usbaudio

import android.content.Context
import android.hardware.usb.UsbDeviceConnection
import android.util.Log
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * UsbAudioPlayer — high-level audio playback engine for USB DACs.
 *
 * The decoding + DSP pipeline is delegated to the C audio engine
 * (`cpp_audio_engine`) via [EngineJni]. The same engine that powers
 * Windows playback runs on Android too, which means we get FLAC, MP3,
 * AAC/M4A, OGG, Vorbis, and WAV support "for free" without depending on
 * ExoPlayer's codec coverage.
 *
 * Pipeline:
 *
 *   File → EngineJni (decode + EQ + volume) → ring buffer
 *                                                  ↓
 *                                    UsbIsoTransfer (isochronous URBs)
 *                                                  ↓
 *                                              USB DAC
 *
 * Public API surface is identical to the previous WAV-only implementation
 * so [UsbAudioPlugin] stays untouched.
 */
class UsbAudioPlayer(private val context: Context) {

    companion object {
        private const val TAG = "UsbAudioPlayer"

        // Audio buffer configuration. The ring buffer sits between the
        // decode thread and UsbIsoTransfer's audio data callback.
        private const val RING_BUFFER_SIZE = 8388608    // 8 MB (supports up to 32-bit/384kHz)
        private const val DECODE_CHUNK_FRAMES = 1024   // frames per engine read

    }

    enum class PlayerState {
        IDLE,
        PREPARING,
        PLAYING,
        PAUSED,
        STOPPED,
        ERROR,
    }

    sealed class AudioSource {
        data class FilePath(val path: String) : AudioSource()
        data class RawPcm(
            val buffer: ByteBuffer,
            val sampleRate: Int,
            val bitDepth: Int,
            val channels: Int,
        ) : AudioSource()
        data class StreamUrl(val url: String) : AudioSource()
    }

    private val usbAudioManager = UsbAudioManager(context)
    private var deviceConnection: UsbDeviceConnection? = null
    private var isoTransfer: UsbIsoTransfer? = null
    private var audioTrackOutput: AudioTrackOutput? = null
    private var selectedInterface: UsbAudioManager.AudioStreamingInterface? = null

    // DAP mode: when true, output goes to AudioTrack (built-in DAC)
    // instead of USB isochronous transfers.
    private var isDapMode = false

    // Engine that owns the decoder + DSP. One instance per UsbAudioPlayer.
    private val engine = EngineJni()

    private var currentState = PlayerState.IDLE
    private var currentSampleRate = 44100
    private var currentBitDepth = 16
    private var currentChannels = 2
    private var currentVolume = 1.0f

    // Ring buffer between decode thread (producer) and transfer (consumer).
    private val ringBuffer = ByteArray(RING_BUFFER_SIZE)
    private var ringReadPos = 0
    private var ringWritePos = 0
    @Volatile private var ringAvailable = 0
    private val ringLock = Object()

    private var audioSource: AudioSource? = null

    // Decode thread state
    private var decodeThread: Thread? = null
    @Volatile private var decodeRunning = false
    @Volatile private var decoderEof = false

    // Progress timer state
    private var progressThread: Thread? = null
    @Volatile private var progressRunning = false

    // Callbacks back to UsbAudioPlugin
    private var onStateChange: ((PlayerState) -> Unit)? = null
    private var onProgress: ((Long, Long) -> Unit)? = null
    private var onError: ((String) -> Unit)? = null

    fun setCallbacks(
        onStateChange: ((PlayerState) -> Unit)? = null,
        onProgress: ((Long, Long) -> Unit)? = null,
        onError: ((String) -> Unit)? = null,
    ) {
        this.onStateChange = onStateChange
        this.onProgress = onProgress
        this.onError = onError
    }

    // ==================== Discovery ====================

    fun getConnectedDacs(): List<UsbAudioManager.UsbAudioDevice> =
        usbAudioManager.getConnectedDacs()

    fun isDacAvailable(): Boolean =
        usbAudioManager.getConnectedDacs().isNotEmpty()

    // ==================== Connection ====================

    fun openDac(dac: UsbAudioManager.UsbAudioDevice, callback: (Boolean) -> Unit) {
        val hasPerm = usbAudioManager.hasPermission(dac.usbDevice)
        Log.i(TAG, "Opening DAC: ${dac.deviceName}, current permission=$hasPerm")

        if (!hasPerm) {
            Log.i(TAG, "Requesting USB permission...")
            usbAudioManager.requestPermission(dac.usbDevice) { granted ->
                if (granted) {
                    Log.i(TAG, "Permission granted; connecting")
                    callback(connectToDac(dac))
                } else {
                    Log.w(TAG, "USB permission denied")
                    callback(false)
                }
            }
        } else {
            Log.i(TAG, "Permission already granted; connecting")
            callback(connectToDac(dac))
        }
    }

    private fun connectToDac(dac: UsbAudioManager.UsbAudioDevice): Boolean {
        return try {
            deviceConnection = usbAudioManager.openDevice(dac.usbDevice)
            if (deviceConnection == null) {
                Log.e(TAG, "Failed to open USB device connection")
                return false
            }
            usbAudioManager.setActiveDac(dac)
            Log.i(TAG, "Connected to DAC: ${dac.deviceName}, " +
                    "rates=${dac.supportedSampleRates}, " +
                    "${dac.audioStreamingInterfaces.size} iface(s)")

            // Lazily create the engine on first DAC open. We keep the engine
            // alive across prepare/stop cycles to avoid repeatedly paying
            // miniaudio init cost.
            if (!engine.isCreated) {
                if (!EngineJni.isAvailable) {
                    Log.e(TAG, "Native audio engine library not loaded; " +
                            "USB bypass will not function")
                    return false
                }
                if (!engine.create()) {
                    Log.e(TAG, "EngineJni.create() failed")
                    return false
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting to DAC: ${e.message}", e)
            false
        }
    }

    private var isKnownDap = false

    /**
     * Set up for playback via Android's AudioTrack (bypassing USB).
     * Used for devices like DAPs where the internal DAC is high-end.
     * We only need the C++ engine for decoding.
     */
    fun openBuiltInDac(knownDap: Boolean = false): Boolean {
        isDapMode = true
        isKnownDap = knownDap
        Log.i(TAG, "Opening built-in DAC (DAP mode, knownDap=$knownDap)")

        if (!engine.isCreated) {
            if (!EngineJni.isAvailable) {
                Log.e(TAG, "Native audio engine library not loaded")
                return false
            }
            if (!engine.create()) {
                Log.e(TAG, "EngineJni.create() failed")
                return false
            }
        }
        return true
    }

    // ==================== Prepare ====================

    fun prepare(source: AudioSource): Boolean {
        if (currentState == PlayerState.PLAYING) {
            stop()
        }
        updateState(PlayerState.PREPARING)
        resetRingBuffer()
        decoderEof = false

        when (source) {
            is AudioSource.FilePath -> {
                if (!prepareFileSource(source.path)) {
                    updateState(PlayerState.ERROR)
                    return false
                }
            }
            is AudioSource.StreamUrl -> {
                if (!prepareUrlSource(source.url)) {
                    updateState(PlayerState.ERROR)
                    return false
                }
            }
            is AudioSource.RawPcm -> {
                // Raw PCM path bypasses the engine — the caller already has
                // decoded frames. Used for diagnostic/test playback only.
                currentSampleRate = source.sampleRate
                currentBitDepth = source.bitDepth
                currentChannels = source.channels
            }
        }

        audioSource = source

        // DAP mode: no USB interface selection needed — AudioTrack handles
        // the format negotiation with the built-in DAC driver.
        if (!isDapMode) {
            val dac = usbAudioManager.getActiveDac()
            if (dac != null) {
                selectedInterface = dac.findBestInterface(
                    currentSampleRate, currentBitDepth, currentChannels
                ) ?: dac.audioStreamingInterfaces.firstOrNull()

                selectedInterface?.let {
                    Log.i(TAG, "USB DAC negotiated: alt=${it.alternateSetting} " +
                            "ch=${it.channels} bit=${it.bitDepth} " +
                            "rate=${currentSampleRate}")
                }
            }
        } else {
            Log.i(TAG, "DAP mode: will use AudioTrack at " +
                    "${currentSampleRate}Hz / ${currentBitDepth}bit / ${currentChannels}ch")
        }

        updateState(PlayerState.IDLE)
        return true
    }

    /**
     * Hand the file off to the engine, then read the negotiated format
     * back so we can pick a matching USB alt setting.
     *
     * `bitPerfect = true` → engine bypasses EQ in [EngineJni.readFrames];
     * only volume scaling stays so the user can still adjust loudness.
     */
    private fun prepareFileSource(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) {
            onError?.invoke("Audio file not found: $path")
            return false
        }
        if (!EngineJni.isAvailable || !engine.isCreated) {
            onError?.invoke("USB audio engine not available on this device")
            return false
        }

        // Hand 0/0/0 hints so the engine uses the file's native format —
        // that gives us the cleanest match against DAC alternate settings.
        val ok = engine.prepareFile(
            path = path,
            sampleRate = 0,
            bitDepth = 0,
            channels = 0,
            bitPerfect = true,
        )
        if (!ok) {
            onError?.invoke("Engine failed to decode: ${file.name}")
            return false
        }

        engine.seek(0f) // FORCE NATIVE DECODER TO RESET CURSOR (Fixes no-sound on next song)

        val (sr, ch, bd) = engine.getFormat()
        if (sr == 0 || ch == 0) {
            onError?.invoke("Engine reported invalid format for ${file.name}")
            engine.releaseRawSink()
            return false
        }
        currentSampleRate = sr
        currentChannels = ch
        currentBitDepth = if (bd > 0) bd else 16
        Log.i(TAG, "Engine prepared $path → ${sr}Hz / ${bd}bit / ${ch}ch")
        return true
    }

    private var currentStreamReader: JniStreamReader? = null

    private fun prepareUrlSource(url: String): Boolean {
        if (!EngineJni.isAvailable || !engine.isCreated) {
            onError?.invoke("USB audio engine not available on this device")
            return false
        }

        val reader = JniStreamReader(url)
        currentStreamReader = reader

        val ok = engine.prepareUrl(
            url = url,
            reader = reader,
            sampleRate = 0,
            bitDepth = 0,
            channels = 0,
            bitPerfect = true,
        )
        if (!ok) {
            onError?.invoke("Engine failed to prepare stream")
            return false
        }

        val (sr, ch, bd) = engine.getFormat()
        if (sr == 0 || ch == 0) {
            onError?.invoke("Engine reported invalid format for stream")
            engine.releaseRawSink()
            return false
        }
        currentSampleRate = sr
        currentChannels = ch
        currentBitDepth = if (bd > 0) bd else 16
        Log.i(TAG, "Engine prepared stream → ${sr}Hz / ${bd}bit / ${ch}ch")
        return true
    }

    // ==================== Playback control ====================

    fun play(): Boolean {
        // Sync volume before decode thread starts to ensure ring buffer is filled at correct volume.
        engine.setVolume(currentVolume)

        // Flush any stale PCM data from a previous session, but NOT when resuming from pause.
        if (currentState != PlayerState.PAUSED) {
            resetRingBuffer()
        }
        decoderEof = false

        // Prime the ring buffer before the output thread starts pulling.
        // DAP mode (AudioTrack) needs more priming than USB isochronous
        // because the AudioTrack internal buffer is larger and starts
        // pulling data immediately on play().
        startDecodeThread()
        startDecodeThread()
        val primeMs = if (isDapMode) 300L else 120L
        Thread.sleep(primeMs)

        // Safety net: pad with silence if decode thread hasn't filled enough.
        // 20ms of audio ensures at least 2 write chunks are available before
        // the output thread starts, preventing startup underruns.
        val minPrimeBytesNeeded = currentChannels * (currentBitDepth / 8) * (currentSampleRate / 1000) * 20  // ~20ms
        synchronized(ringLock) {
            if (ringAvailable < minPrimeBytesNeeded) {
                Log.w(TAG, "Ring buffer under-primed ($ringAvailable < $minPrimeBytesNeeded), padding silence")
                val silenceNeeded = minPrimeBytesNeeded - ringAvailable
                ringAvailable += silenceNeeded
                ringWritePos = (ringWritePos + silenceNeeded) % RING_BUFFER_SIZE
            }
        }

        // ── DAP MODE: AudioTrack output ──────────────────────────────────
        if (isDapMode) {
            audioTrackOutput = AudioTrackOutput(
                sampleRate = currentSampleRate,
                bitDepth = currentBitDepth,
                channels = currentChannels,
                isKnownDap = isKnownDap
            ).apply {
                setAudioDataCallback { buffer, requested -> provideAudioData(buffer, requested) }
            }

            return if (audioTrackOutput?.start() == true) {
                updateState(PlayerState.PLAYING)
                startProgressTimer()
                true
            } else {
                stopDecodeThread()
                onError?.invoke("Failed to start AudioTrack (built-in DAC)")
                updateState(PlayerState.ERROR)
                false
            }
        }

        // ── USB MODE: Isochronous transfer ──────────────────────────────
        val connection = deviceConnection
        val dac = usbAudioManager.getActiveDac()
        if (connection == null || dac == null) {
            onError?.invoke("No USB DAC connected")
            stopDecodeThread()
            return false
        }
        val iface = selectedInterface ?: run {
            onError?.invoke("No audio interface selected")
            stopDecodeThread()
            return false
        }
        val endpoint = iface.isochronousEndpoint ?: run {
            onError?.invoke("No isochronous endpoint on DAC")
            stopDecodeThread()
            return false
        }

        isoTransfer = UsbIsoTransfer(
            connection = connection,
            endpoint = endpoint,
            audioInterface = iface.usbInterface,
            sampleRate = currentSampleRate,
            bitDepth = currentBitDepth,
            channels = currentChannels,
        ).apply {
            setAudioDataCallback { buffer, requested -> provideAudioData(buffer, requested) }
        }

        return if (isoTransfer?.start() == true) {
            updateState(PlayerState.PLAYING)
            startProgressTimer()
            true
        } else {
            stopDecodeThread()
            onError?.invoke("Failed to start USB audio transfer")
            updateState(PlayerState.ERROR)
            false
        }
    }

    fun pause() {
        if (isDapMode) audioTrackOutput?.stop() else isoTransfer?.stop()
        decodeRunning = false
        stopProgressTimer()
        updateState(PlayerState.PAUSED)
    }

    fun resume(): Boolean = if (currentState == PlayerState.PAUSED) play() else false

    fun stop() {
        if (isDapMode) {
            audioTrackOutput?.stop()
            audioTrackOutput = null
        } else {
            isoTransfer?.stop()
            isoTransfer = null
        }
        
        // CRITICAL FIX: The native C++ readFrames() can deadlock at EOF or track transitions.
        // Calling engine.seek(0f) BEFORE joining unblocks the native mutex instantly,
        // preventing the 2-second UI freeze and stopping the old thread from blocking the new one!
        decodeRunning = false
        stopProgressTimer()
        synchronized(ringLock) { ringLock.notifyAll() }
        engine.seek(0f) 
        
        decodeThread?.join(2000)
        decodeThread = null

        engine.releaseRawSink()
        currentStreamReader?.closeConnection()
        currentStreamReader = null
        audioSource = null
        resetRingBuffer()
        updateState(PlayerState.STOPPED)
    }

    /**
     * Stop playback without emitting the STOPPED state callback.
     * Used by [closeDac] during user-initiated disable so the
     * Flutter side doesn't misinterpret it as end-of-stream and
     * auto-advance to the next track.
     */
    private fun forceStop() {
        if (isDapMode) {
            audioTrackOutput?.stop()
            audioTrackOutput = null
        } else {
            isoTransfer?.stop()
            isoTransfer = null
        }
        stopDecodeThread()
        stopProgressTimer()
        engine.releaseRawSink()
        resetRingBuffer()
        // Deliberately DO NOT call updateState(STOPPED) here —
        // the caller handles the state transition.
        currentState = PlayerState.IDLE
    }

    fun seek(positionMs: Long) {
        val source = audioSource as? AudioSource.FilePath ?: return
        val wasPlaying = decodeRunning
        val positionSeconds = positionMs / 1000f

        // Pause transport while the decoder cursor moves, then refill the
        // ring buffer from the new position.
        if (wasPlaying) {
            if (isDapMode) audioTrackOutput?.stop() else isoTransfer?.stop()
            decodeRunning = false
            synchronized(ringLock) { ringLock.notifyAll() }
            engine.seek(positionSeconds) // Unblock native readFrames INSTANTLY
            decodeThread?.join(2000)
            decodeThread = null
        } else {
            engine.seek(positionSeconds)
        }

        resetRingBuffer()
        decoderEof = false

        // Notify UI right away with the new cursor.
        val totalSec = engine.getDuration()
        if (totalSec > 0f) {
            onProgress?.invoke(positionMs, (totalSec * 1000).toLong())
        }

        if (wasPlaying) {
            startDecodeThread()
            Thread.sleep(30)
            if (isDapMode) audioTrackOutput?.start() else isoTransfer?.start()
        }

        // Suppress unused warning while the source field is part of the
        // sealed-class contract for future expansion.
        @Suppress("UNUSED_EXPRESSION")
        source
    }

    fun closeDac() {
        // Use forceStop() instead of stop() to avoid emitting a STOPPED
        // state event — the Flutter layer interprets STOPPED as end-of-stream
        // and auto-advances to the next track, which is wrong during a
        // user-initiated disable toggle.
        forceStop()
        if (isDapMode) {
            isDapMode = false
            Log.i(TAG, "Built-in DAC (DAP mode) closed")
        } else {
            deviceConnection?.close()
            deviceConnection = null
            selectedInterface = null
            usbAudioManager.setActiveDac(null)
        }
        updateState(PlayerState.IDLE)
    }

    fun getState(): PlayerState = currentState

    fun isDapMode(): Boolean = isDapMode

    fun getAudioFormat(): Map<String, Any> = mapOf(
        "sampleRate" to currentSampleRate,
        "bitDepth" to currentBitDepth,
        "channels" to currentChannels,
    )

    fun setVolume(volume: Float) {
        currentVolume = volume.coerceIn(0f, 1f)
        if (engine.isCreated) {
            engine.setVolume(currentVolume)
        }
    }

    fun setEqBand(bandIndex: Int, frequency: Float, gain: Float, q: Float) {
        engine.setEQBand(bandIndex, frequency, gain, q)
    }

    fun dispose() {
        closeDac()
        engine.dispose()
        usbAudioManager.dispose()
    }

    // ==================== Ring buffer ====================

    /** Called from the UsbIsoTransfer thread. */
    private fun provideAudioData(buffer: ByteBuffer, requestedBytes: Int): Int {
        synchronized(ringLock) {
            if (ringAvailable < requestedBytes) {
                // Underrun — caller will pad with silence.
                return 0
            }
            val toRead = minOf(requestedBytes, ringAvailable)
            val endLen = RING_BUFFER_SIZE - ringReadPos
            if (toRead <= endLen) {
                buffer.put(ringBuffer, ringReadPos, toRead)
                ringReadPos = (ringReadPos + toRead) % RING_BUFFER_SIZE
            } else {
                buffer.put(ringBuffer, ringReadPos, endLen)
                val remaining = toRead - endLen
                buffer.put(ringBuffer, 0, remaining)
                ringReadPos = remaining
            }
            ringAvailable -= toRead
            ringLock.notifyAll()
            return toRead
        }
    }

    /** Called from the decode thread. */
    private fun feedAudioData(data: ByteArray, offset: Int, length: Int): Int {
        synchronized(ringLock) {
            val space = RING_BUFFER_SIZE - ringAvailable
            if (space < length) return 0
            val toWrite = minOf(length, space)
            val endLen = RING_BUFFER_SIZE - ringWritePos
            if (toWrite <= endLen) {
                System.arraycopy(data, offset, ringBuffer, ringWritePos, toWrite)
                ringWritePos = (ringWritePos + toWrite) % RING_BUFFER_SIZE
            } else {
                System.arraycopy(data, offset, ringBuffer, ringWritePos, endLen)
                val remaining = toWrite - endLen
                System.arraycopy(data, offset + endLen, ringBuffer, 0, remaining)
                ringWritePos = remaining
            }
            ringAvailable += toWrite
            return toWrite
        }
    }


    private fun resetRingBuffer() {
        synchronized(ringLock) {
            // Zero-fill the buffer to prevent stale PCM data from being
            // sent to the DAC as a startup glitch ("Preett..." sound).
            ringBuffer.fill(0)
            ringReadPos = 0
            ringWritePos = 0
            ringAvailable = 0
        }
    }

    // ==================== Decode thread ====================

    private fun startDecodeThread() {
        if (decodeRunning) return
        decodeRunning = true
        decodeThread = thread(name = "EngineDecoder") {
            Log.d(TAG, "Decode thread started")
            val bytesPerFrame = currentChannels * (currentBitDepth / 8)
            if (bytesPerFrame <= 0) {
                Log.e(TAG, "Decode thread bailing — invalid bytesPerFrame")
                decodeRunning = false
                return@thread
            }

            val chunkBytes = DECODE_CHUNK_FRAMES * bytesPerFrame
            val direct = ByteBuffer.allocateDirect(chunkBytes)
                .order(ByteOrder.LITTLE_ENDIAN)
            val staging = ByteArray(chunkBytes)

            // Buffer up to 0.25 seconds of audio, with a minimum of 65536 bytes to prevent underruns
            val maxBufferedBytes = if (bytesPerFrame > 0 && currentSampleRate > 0) {
                (currentSampleRate * bytesPerFrame * 0.25f).toInt().coerceIn(65536, RING_BUFFER_SIZE)
            } else {
                RING_BUFFER_SIZE
            }

            while (decodeRunning) {
                try {
                    // Wait until there's room for at least one chunk.
                    synchronized(ringLock) {
                        while (decodeRunning &&
                            (maxBufferedBytes - ringAvailable) < chunkBytes) {
                            ringLock.wait(50)
                        }
                    }
                    if (!decodeRunning) break

                    direct.clear()
                    val framesRead = engine.readFrames(direct, DECODE_CHUNK_FRAMES)
                    if (framesRead <= 0) {
                        // 0 = EOS, negative = error/no source. Either way, stop.
                        decoderEof = true
                        Log.d(TAG, "Engine returned $framesRead — end of stream")
                        break
                    }
                    val bytesProduced = (framesRead.toInt() * bytesPerFrame)
                    direct.position(0)
                    direct.get(staging, 0, bytesProduced)

                    // Feed the ring buffer. Block briefly if it filled up
                    // while we were decoding.
                    var offset = 0
                    while (offset < bytesProduced && decodeRunning) {
                        val written = feedAudioData(staging, offset, bytesProduced - offset)
                        if (written > 0) {
                            offset += written
                        } else {
                            Thread.sleep(5)
                        }
                    }

                    // Push progress periodically from ProgressTimer thread instead.
                } catch (e: InterruptedException) {
                    if (!decodeRunning) break
                } catch (e: Exception) {
                    Log.e(TAG, "Decode error: ${e.message}", e)
                    if (!decodeRunning) break
                    Thread.sleep(10)
                }
            }
            Log.d(TAG, "Decode thread ended (eof=$decoderEof)")
        }
    }

    private fun stopDecodeThread() {
        decodeRunning = false
        synchronized(ringLock) { ringLock.notifyAll() }
        engine.seek(0f) // Interrupt native readFrames block
        decodeThread?.join(2000)
        decodeThread = null
    }

    // ==================== Progress timer thread ====================

    private fun startProgressTimer() {
        if (progressRunning) return
        progressRunning = true
        progressThread = thread(name = "ProgressTimer") {
            Log.d(TAG, "Progress timer thread started")
            while (progressRunning) {
                try {
                    Thread.sleep(250)
                    if (!progressRunning) break

                    if (currentState == PlayerState.PLAYING) {
                        val pos = engine.getPosition()
                        val dur = engine.getDuration()
                        if (dur > 0f) {
                            val bytesPerFrame = currentChannels * (currentBitDepth / 8)
                            val bufferedSeconds = if (bytesPerFrame > 0 && currentSampleRate > 0) {
                                ringAvailable.toFloat() / bytesPerFrame / currentSampleRate
                            } else {
                                0f
                            }
                            // Smoothly decrease offset down to 0 at EOF as the ring buffer drains
                            val actualPlaybackPos = maxOf(0f, pos - bufferedSeconds)
                            onProgress?.invoke((actualPlaybackPos * 1000).toLong(), (dur * 1000).toLong())
                        }
                    }
                } catch (e: InterruptedException) {
                    break
                } catch (e: Exception) {
                    // Ignore
                }
            }
            Log.d(TAG, "Progress timer thread ended")
        }
    }

    private fun stopProgressTimer() {
        progressRunning = false
        progressThread?.interrupt()
        progressThread = null
    }

    // ==================== State ====================

    private fun updateState(newState: PlayerState) {
        if (currentState != newState) {
            Log.d(TAG, "State change: $currentState → $newState")
            currentState = newState
            onStateChange?.invoke(newState)
        }
    }
}
