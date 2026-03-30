package com.momotz4g.simplemusicplayer2.usbaudio

import android.content.Context
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbInterface
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * UsbAudioPlayer - High-level audio playback engine for USB DACs.
 * Connects the audio decoder with USB isochronous transfer.
 *
 * Responsibilities:
 * - Open and manage USB device connection
 * - Decode audio files (WAV for Phase 1, FFmpeg for Phase 2) to raw PCM
 * - Stream decoded audio to USB DAC via isochronous transfer
 * - Handle format matching (sample rate, bit depth)
 * - Manage playback state and progress reporting
 */
class UsbAudioPlayer(private val context: Context) {

    companion object {
        private const val TAG = "UsbAudioPlayer"

        // Audio buffer configuration
        private const val RING_BUFFER_SIZE = 131072    // 128KB ring buffer
        private const val DECODE_CHUNK_SIZE = 8192     // Bytes per decode read
        private const val LOW_WATER_MARK = 16384       // Trigger decode when below this
    }

    enum class PlayerState {
        IDLE,
        PREPARING,
        PLAYING,
        PAUSED,
        STOPPED,
        ERROR
    }

    private val usbAudioManager = UsbAudioManager(context)
    private var deviceConnection: UsbDeviceConnection? = null
    private var isoTransfer: UsbIsoTransfer? = null
    private var selectedInterface: UsbAudioManager.AudioStreamingInterface? = null

    private var currentState = PlayerState.IDLE
    private var currentSampleRate = 44100
    private var currentBitDepth = 16
    private var currentChannels = 2

    // Ring buffer for decoded audio (producer: decode thread, consumer: transfer thread)
    private val ringBuffer = ByteArray(RING_BUFFER_SIZE)
    private var ringReadPos = 0
    private var ringWritePos = 0
    @Volatile private var ringAvailable = 0
    private val ringLock = Object()

    // Current audio source
    private var audioSource: AudioSource? = null

    // WAV file decoder state
    private var wavFile: RandomAccessFile? = null
    private var wavDataOffset = 0L     // Byte offset where PCM data starts
    private var wavDataLength = 0L     // Total PCM data length in bytes
    private var wavBytesRead = 0L      // How many PCM bytes we've decoded so far

    // Decode thread
    private var decodeThread: Thread? = null
    @Volatile private var decodeRunning = false

    // Playback callbacks
    private var onStateChange: ((PlayerState) -> Unit)? = null
    private var onProgress: ((Long, Long) -> Unit)? = null
    private var onError: ((String) -> Unit)? = null

    /**
     * Audio source abstraction
     */
    sealed class AudioSource {
        data class FilePath(val path: String) : AudioSource()
        data class RawPcm(
            val buffer: ByteBuffer,
            val sampleRate: Int,
            val bitDepth: Int,
            val channels: Int
        ) : AudioSource()
    }

    /**
     * Set callbacks for playback events
     */
    fun setCallbacks(
        onStateChange: ((PlayerState) -> Unit)? = null,
        onProgress: ((Long, Long) -> Unit)? = null,
        onError: ((String) -> Unit)? = null
    ) {
        this.onStateChange = onStateChange
        this.onProgress = onProgress
        this.onError = onError
    }

    /**
     * Get list of connected USB DACs
     */
    fun getConnectedDacs(): List<UsbAudioManager.UsbAudioDevice> {
        return usbAudioManager.getConnectedDacs()
    }

    /**
     * Check if USB DAC is available
     */
    fun isDacAvailable(): Boolean {
        return usbAudioManager.getConnectedDacs().isNotEmpty()
    }

    /**
     * Open connection to a specific DAC
     */
    fun openDac(dac: UsbAudioManager.UsbAudioDevice, callback: (Boolean) -> Unit) {
        val hasPerm = usbAudioManager.hasPermission(dac.usbDevice)
        Log.i(TAG, "Opening DAC: ${dac.deviceName}, Current permission: $hasPerm")

        if (!hasPerm) {
            Log.i(TAG, "Requesting USB permission...")
            usbAudioManager.requestPermission(dac.usbDevice) { granted ->
                if (granted) {
                    Log.i(TAG, "Permission granted. Connecting to DAC...")
                    val success = connectToDac(dac)
                    callback(success)
                } else {
                    Log.w(TAG, "USB permission denied")
                    callback(false)
                }
            }
        } else {
            Log.i(TAG, "Found existing permission. Connecting to DAC...")
            val success = connectToDac(dac)
            callback(success)
        }
    }

    /**
     * Connect to DAC after permission is granted
     */
    private fun connectToDac(dac: UsbAudioManager.UsbAudioDevice): Boolean {
        try {
            deviceConnection = usbAudioManager.openDevice(dac.usbDevice)
            if (deviceConnection == null) {
                Log.e(TAG, "Failed to open USB device connection")
                return false
            }

            usbAudioManager.setActiveDac(dac)
            Log.i(TAG, "Connected to DAC: ${dac.deviceName}")
            Log.i(TAG, "  Supported sample rates: ${dac.supportedSampleRates}")
            Log.i(TAG, "  ${dac.audioStreamingInterfaces.size} audio interface(s) available")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting to DAC: ${e.message}")
            return false
        }
    }

    /**
     * Prepare audio source for playback.
     * Parses the audio file header and determines the format.
     */
    fun prepare(source: AudioSource): Boolean {
        if (currentState == PlayerState.PLAYING) {
            stop()
        }

        updateState(PlayerState.PREPARING)
        resetRingBuffer()

        when (source) {
            is AudioSource.FilePath -> {
                if (!prepareFileSource(source.path)) {
                    updateState(PlayerState.ERROR)
                    return false
                }
            }
            is AudioSource.RawPcm -> {
                currentSampleRate = source.sampleRate
                currentBitDepth = source.bitDepth
                currentChannels = source.channels
            }
        }

        audioSource = source

        // Find the best matching interface for this format on the connected DAC
        val dac = usbAudioManager.getActiveDac()
        if (dac != null) {
            selectedInterface = dac.findBestInterface(currentSampleRate, currentBitDepth, currentChannels)
            if (selectedInterface != null) {
                Log.i(TAG, "Selected interface #${selectedInterface!!.interfaceNumber} " +
                        "alt=${selectedInterface!!.alternateSetting} for " +
                        "${currentSampleRate}Hz/${currentBitDepth}bit/${currentChannels}ch")
            } else {
                Log.w(TAG, "No suitable interface found for format, using first available")
                selectedInterface = dac.audioStreamingInterfaces.firstOrNull()
            }
        }

        updateState(PlayerState.IDLE)
        return true
    }

    /**
     * Start playback
     */
    fun play(): Boolean {
        val connection = deviceConnection
        val dac = usbAudioManager.getActiveDac()

        if (connection == null || dac == null) {
            onError?.invoke("No USB DAC connected")
            return false
        }

        val iface = selectedInterface
        if (iface == null) {
            onError?.invoke("No audio interface selected")
            return false
        }

        val endpoint = iface.isochronousEndpoint
        if (endpoint == null) {
            onError?.invoke("No audio endpoint found on DAC")
            return false
        }

        // Start the decode thread first to fill the ring buffer
        startDecodeThread()

        // Wait briefly for initial buffer fill
        Thread.sleep(50)

        // Create isochronous transfer handler with the selected interface
        isoTransfer = UsbIsoTransfer(
            connection = connection,
            endpoint = endpoint,
            audioInterface = iface.usbInterface,
            sampleRate = currentSampleRate,
            bitDepth = currentBitDepth,
            channels = currentChannels
        ).apply {
            setAudioDataCallback { buffer, requestedBytes ->
                provideAudioData(buffer, requestedBytes)
            }
        }

        if (isoTransfer?.start() == true) {
            updateState(PlayerState.PLAYING)
            return true
        } else {
            stopDecodeThread()
            onError?.invoke("Failed to start USB audio transfer")
            updateState(PlayerState.ERROR)
            return false
        }
    }

    /**
     * Pause playback
     */
    fun pause() {
        isoTransfer?.stop()
        decodeRunning = false
        updateState(PlayerState.PAUSED)
    }

    /**
     * Resume playback
     */
    fun resume(): Boolean {
        return if (currentState == PlayerState.PAUSED) {
            play()
        } else {
            false
        }
    }

    /**
     * Stop playback
     */
    fun stop() {
        isoTransfer?.stop()
        isoTransfer = null
        stopDecodeThread()
        closeWavFile()
        resetRingBuffer()
        updateState(PlayerState.STOPPED)
    }

    /**
     * Seek to position in milliseconds
     */
    fun seek(positionMs: Long) {
        val source = audioSource
        if (source !is AudioSource.FilePath) return

        val wasPlaying = currentState == PlayerState.PLAYING
        if (wasPlaying) {
            isoTransfer?.stop()
            decodeRunning = false
        }

        // Calculate byte offset from millisecond position
        val bytesPerSecond = currentSampleRate * currentChannels * (currentBitDepth / 8)
        val targetByteOffset = (positionMs * bytesPerSecond / 1000).coerceIn(0, wavDataLength)

        // Align to frame boundary
        val bytesPerFrame = currentChannels * (currentBitDepth / 8)
        val alignedOffset = (targetByteOffset / bytesPerFrame) * bytesPerFrame

        synchronized(ringLock) {
            ringReadPos = 0
            ringWritePos = 0
            ringAvailable = 0
            wavBytesRead = alignedOffset
        }

        // Seek the WAV file
        wavFile?.seek(wavDataOffset + alignedOffset)

        if (wasPlaying) {
            startDecodeThread()
            Thread.sleep(30)
            isoTransfer?.start()
        }

        // Report progress
        val currentMs = (alignedOffset * 1000) / bytesPerSecond
        val totalMs = (wavDataLength * 1000) / bytesPerSecond
        onProgress?.invoke(currentMs, totalMs)
    }

    /**
     * Close DAC connection
     */
    fun closeDac() {
        stop()
        deviceConnection?.close()
        deviceConnection = null
        selectedInterface = null
        usbAudioManager.setActiveDac(null)
        updateState(PlayerState.IDLE)
    }

    /**
     * Get current player state
     */
    fun getState(): PlayerState = currentState

    /**
     * Get current audio format
     */
    fun getAudioFormat(): Map<String, Any> {
        return mapOf(
            "sampleRate" to currentSampleRate,
            "bitDepth" to currentBitDepth,
            "channels" to currentChannels
        )
    }

    /**
     * Dispose all resources
     */
    fun dispose() {
        closeDac()
        usbAudioManager.dispose()
    }

    // ==================== Ring Buffer Operations ====================

    /**
     * Provide audio data to the USB transfer thread.
     * Called from the isochronous transfer thread.
     */
    private fun provideAudioData(buffer: ByteBuffer, requestedBytes: Int): Int {
        synchronized(ringLock) {
            if (ringAvailable < requestedBytes) {
                // Underrun — not enough decoded data
                return 0
            }

            val bytesToRead = minOf(requestedBytes, ringAvailable)
            for (i in 0 until bytesToRead) {
                buffer.put(ringBuffer[ringReadPos])
                ringReadPos = (ringReadPos + 1) % RING_BUFFER_SIZE
            }
            ringAvailable -= bytesToRead

            // Notify decode thread there's space available
            ringLock.notifyAll()

            return bytesToRead
        }
    }

    /**
     * Feed decoded audio data into the ring buffer.
     * Called from the decode thread.
     */
    private fun feedAudioData(data: ByteArray, offset: Int, length: Int): Int {
        synchronized(ringLock) {
            val spaceAvailable = RING_BUFFER_SIZE - ringAvailable
            if (spaceAvailable < length) {
                return 0 // Buffer full
            }

            val bytesToWrite = minOf(length, spaceAvailable)
            for (i in 0 until bytesToWrite) {
                ringBuffer[ringWritePos] = data[offset + i]
                ringWritePos = (ringWritePos + 1) % RING_BUFFER_SIZE
            }
            ringAvailable += bytesToWrite

            return bytesToWrite
        }
    }

    private fun resetRingBuffer() {
        synchronized(ringLock) {
            ringReadPos = 0
            ringWritePos = 0
            ringAvailable = 0
        }
    }

    // ==================== WAV Decoder ====================

    /**
     * Prepare file-based audio source.
     * Parses the WAV header and opens the file for streaming.
     */
    private fun prepareFileSource(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) {
            onError?.invoke("Audio file not found: $path")
            return false
        }

        val extension = file.extension.lowercase()

        when (extension) {
            "wav" -> return prepareWavFile(file)
            "flac", "mp3", "aac", "m4a", "ogg", "opus" -> {
                // Phase 2: FFmpeg decoding
                // For now, attempt WAV-like raw PCM or report unsupported
                Log.w(TAG, "Format '$extension' requires FFmpeg decoder (Phase 2)")
                onError?.invoke("Format '$extension' not yet supported in USB Direct mode. " +
                        "WAV files are supported. FFmpeg support coming in Phase 2.")
                return false
            }
            else -> {
                onError?.invoke("Unsupported audio format: $extension")
                return false
            }
        }
    }

    /**
     * Parse WAV file header and prepare for streaming.
     * Handles standard RIFF/WAVE, including files with extra chunks before 'data'.
     */
    private fun prepareWavFile(file: File): Boolean {
        try {
            closeWavFile()

            val raf = RandomAccessFile(file, "r")

            // Read RIFF header (12 bytes)
            val riffHeader = ByteArray(12)
            raf.readFully(riffHeader)

            // Verify RIFF/WAVE signature
            val riff = String(riffHeader, 0, 4)
            val wave = String(riffHeader, 8, 4)
            if (riff != "RIFF" || wave != "WAVE") {
                Log.e(TAG, "Not a valid WAV file: RIFF='$riff', WAVE='$wave'")
                raf.close()
                return false
            }

            // Parse chunks to find 'fmt ' and 'data'
            var foundFmt = false
            var foundData = false
            var filePos = 12L

            while (filePos < raf.length() - 8) {
                raf.seek(filePos)
                val chunkHeader = ByteArray(8)
                raf.readFully(chunkHeader)

                val chunkId = String(chunkHeader, 0, 4)
                val chunkSize = ByteBuffer.wrap(chunkHeader, 4, 4)
                    .order(ByteOrder.LITTLE_ENDIAN).int.toLong() and 0xFFFFFFFFL

                when (chunkId) {
                    "fmt " -> {
                        // Parse format chunk
                        val fmtData = ByteArray(chunkSize.toInt().coerceAtMost(40))
                        raf.readFully(fmtData)

                        val fmt = ByteBuffer.wrap(fmtData).order(ByteOrder.LITTLE_ENDIAN)
                        val audioFormat = fmt.short.toInt() and 0xFFFF  // 1 = PCM, 3 = IEEE float
                        currentChannels = fmt.short.toInt() and 0xFFFF
                        currentSampleRate = fmt.int
                        val byteRate = fmt.int
                        val blockAlign = fmt.short.toInt() and 0xFFFF
                        currentBitDepth = fmt.short.toInt() and 0xFFFF

                        if (audioFormat != 1 && audioFormat != 3) {
                            Log.w(TAG, "WAV audioFormat=$audioFormat (not PCM). May not play correctly.")
                        }

                        Log.i(TAG, "WAV format: ${currentSampleRate}Hz, ${currentBitDepth}bit, " +
                                "${currentChannels}ch, byteRate=$byteRate, blockAlign=$blockAlign")
                        foundFmt = true
                    }

                    "data" -> {
                        wavDataOffset = filePos + 8
                        wavDataLength = chunkSize
                        foundData = true
                        Log.i(TAG, "WAV data chunk: offset=$wavDataOffset, length=$wavDataLength")
                        break // Found what we need
                    }
                }

                // Move to next chunk (chunks are 2-byte aligned)
                filePos += 8 + chunkSize
                if (chunkSize % 2 != 0L) filePos += 1
            }

            if (!foundFmt || !foundData) {
                Log.e(TAG, "WAV file missing required chunks: fmt=$foundFmt, data=$foundData")
                raf.close()
                return false
            }

            // Position at start of PCM data
            raf.seek(wavDataOffset)
            wavFile = raf
            wavBytesRead = 0

            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing WAV file: ${e.message}", e)
            return false
        }
    }

    /**
     * Start the decode thread that reads PCM data from the WAV file
     * and feeds it into the ring buffer.
     */
    private fun startDecodeThread() {
        if (decodeRunning) return

        decodeRunning = true
        decodeThread = thread(name = "WavDecoder") {
            Log.d(TAG, "Decode thread started")

            val readBuffer = ByteArray(DECODE_CHUNK_SIZE)
            val bytesPerSecond = currentSampleRate * currentChannels * (currentBitDepth / 8)
            val totalDurationMs = if (bytesPerSecond > 0) (wavDataLength * 1000 / bytesPerSecond) else 0L

            while (decodeRunning && wavBytesRead < wavDataLength) {
                try {
                    // Wait if ring buffer is too full
                    synchronized(ringLock) {
                        while (decodeRunning && (RING_BUFFER_SIZE - ringAvailable) < DECODE_CHUNK_SIZE) {
                            ringLock.wait(50)
                        }
                    }

                    if (!decodeRunning) break

                    // Read PCM data from WAV file
                    val remaining = (wavDataLength - wavBytesRead).toInt()
                        .coerceAtMost(DECODE_CHUNK_SIZE)

                    val raf = wavFile ?: break
                    val bytesRead = raf.read(readBuffer, 0, remaining)

                    if (bytesRead <= 0) {
                        Log.d(TAG, "End of WAV data reached")
                        break
                    }

                    // Feed into ring buffer (may block if buffer full)
                    var offset = 0
                    while (offset < bytesRead && decodeRunning) {
                        val written = feedAudioData(readBuffer, offset, bytesRead - offset)
                        if (written > 0) {
                            offset += written
                            wavBytesRead += written
                        } else {
                            // Buffer full, wait
                            Thread.sleep(5)
                        }
                    }

                    // Report progress
                    if (bytesPerSecond > 0) {
                        val currentMs = wavBytesRead * 1000 / bytesPerSecond
                        onProgress?.invoke(currentMs, totalDurationMs)
                    }

                } catch (e: Exception) {
                    Log.e(TAG, "Decode error: ${e.message}", e)
                    if (!decodeRunning) break
                    Thread.sleep(10)
                }
            }

            Log.d(TAG, "Decode thread ended. Bytes decoded: $wavBytesRead / $wavDataLength")
        }
    }

    /**
     * Stop the decode thread
     */
    private fun stopDecodeThread() {
        decodeRunning = false
        synchronized(ringLock) {
            ringLock.notifyAll() // Wake up if waiting
        }
        decodeThread?.join(2000)
        decodeThread = null
    }

    /**
     * Close the WAV file handle
     */
    private fun closeWavFile() {
        try {
            wavFile?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error closing WAV file: ${e.message}")
        }
        wavFile = null
        wavBytesRead = 0
        wavDataOffset = 0
        wavDataLength = 0
    }

    /**
     * Update player state and notify listener
     */
    private fun updateState(newState: PlayerState) {
        if (currentState != newState) {
            Log.d(TAG, "State change: $currentState -> $newState")
            currentState = newState
            onStateChange?.invoke(newState)
        }
    }
}
