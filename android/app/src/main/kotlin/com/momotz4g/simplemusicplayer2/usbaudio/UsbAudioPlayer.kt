package com.momotz4g.simplemusicplayer2.usbaudio

import android.content.Context
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbInterface
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * UsbAudioPlayer - High-level audio playback engine for USB DACs.
 * Connects the audio decoder with USB isochronous transfer.
 * 
 * Responsibilities:
 * - Open and manage USB device connection
 * - Decode audio files (FLAC, WAV, MP3) to PCM
 * - Stream decoded audio to USB DAC via isochronous transfer
 * - Handle format matching (sample rate, bit depth conversion if needed)
 */
class UsbAudioPlayer(private val context: Context) {

    companion object {
        private const val TAG = "UsbAudioPlayer"
        
        // Audio buffer configuration
        private const val DECODE_BUFFER_SIZE = 8192 // Bytes per decode chunk
        private const val RING_BUFFER_SIZE = 65536 // 64KB ring buffer for decoded audio
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
    private var audioInterface: UsbInterface? = null
    
    private var currentState = PlayerState.IDLE
    private var currentSampleRate = 44100
    private var currentBitDepth = 16
    private var currentChannels = 2
    
    // Ring buffer for decoded audio
    private val ringBuffer = ByteBuffer.allocateDirect(RING_BUFFER_SIZE).order(ByteOrder.LITTLE_ENDIAN)
    private var ringBufferReadPos = 0
    private var ringBufferWritePos = 0
    private var ringBufferAvailable = 0
    
    // Current audio source
    private var audioSource: AudioSource? = null
    
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
        if (!usbAudioManager.hasPermission(dac.usbDevice)) {
            usbAudioManager.requestPermission(dac.usbDevice) { granted ->
                if (granted) {
                    val success = connectToDac(dac)
                    callback(success)
                } else {
                    Log.w(TAG, "USB permission denied")
                    callback(false)
                }
            }
        } else {
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

            audioInterface = dac.audioInterface
            usbAudioManager.setActiveDac(dac)
            
            Log.i(TAG, "Connected to DAC: ${dac.deviceName}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting to DAC: ${e.message}")
            return false
        }
    }

    /**
     * Prepare audio source for playback
     * This will decode the audio header and set up the stream
     */
    fun prepare(source: AudioSource): Boolean {
        if (currentState == PlayerState.PLAYING) {
            stop()
        }

        updateState(PlayerState.PREPARING)
        
        when (source) {
            is AudioSource.FilePath -> {
                // For file-based audio, we need to decode it
                // This is a simplified implementation - in production, use FFmpeg or similar
                if (!prepareFileSource(source.path)) {
                    updateState(PlayerState.ERROR)
                    return false
                }
            }
            is AudioSource.RawPcm -> {
                // For raw PCM, use the buffer directly
                currentSampleRate = source.sampleRate
                currentBitDepth = source.bitDepth
                currentChannels = source.channels
            }
        }
        
        audioSource = source
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

        val endpoint = dac.isochronousEndpoint
        if (endpoint == null) {
            onError?.invoke("No audio endpoint found on DAC")
            return false
        }

        // Create isochronous transfer handler
        isoTransfer = UsbIsoTransfer(
            connection,
            endpoint,
            currentSampleRate,
            currentBitDepth,
            currentChannels
        ).apply {
            setAudioDataCallback { buffer, requestedBytes ->
                provideAudioData(buffer, requestedBytes)
            }
        }

        // Set sample rate on device
        isoTransfer?.setSampleRate(currentSampleRate)

        if (isoTransfer?.start() == true) {
            updateState(PlayerState.PLAYING)
            return true
        } else {
            onError?.invoke("Failed to start USB audio transfer")
            return false
        }
    }

    /**
     * Pause playback
     */
    fun pause() {
        isoTransfer?.stop()
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
        
        // Clear ring buffer
        ringBufferReadPos = 0
        ringBufferWritePos = 0
        ringBufferAvailable = 0
        
        updateState(PlayerState.STOPPED)
    }

    /**
     * Close DAC connection
     */
    fun closeDac() {
        stop()
        
        audioInterface?.let { iface ->
            deviceConnection?.releaseInterface(iface)
        }
        
        deviceConnection?.close()
        deviceConnection = null
        audioInterface = null
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

    /**
     * Provide audio data to the USB transfer
     * Called from the transfer thread
     */
    private fun provideAudioData(buffer: ByteBuffer, requestedBytes: Int): Int {
        // This is where we'd provide decoded audio data
        // For now, return silence if no data available
        
        if (ringBufferAvailable < requestedBytes) {
            // Underrun - need more decoded data
            return 0
        }
        
        val bytesToRead = minOf(requestedBytes, ringBufferAvailable)
        
        synchronized(ringBuffer) {
            for (i in 0 until bytesToRead) {
                buffer.put(ringBuffer.get(ringBufferReadPos))
                ringBufferReadPos = (ringBufferReadPos + 1) % RING_BUFFER_SIZE
            }
            ringBufferAvailable -= bytesToRead
        }
        
        return bytesToRead
    }

    /**
     * Feed decoded audio data into the ring buffer
     * This should be called from the decoding thread
     */
    fun feedAudioData(data: ByteArray, offset: Int, length: Int): Int {
        val spaceAvailable = RING_BUFFER_SIZE - ringBufferAvailable
        if (spaceAvailable < length) {
            return 0 // Buffer full
        }
        
        synchronized(ringBuffer) {
            for (i in 0 until length) {
                ringBuffer.put(ringBufferWritePos, data[offset + i])
                ringBufferWritePos = (ringBufferWritePos + 1) % RING_BUFFER_SIZE
            }
            ringBufferAvailable += length
        }
        
        return length
    }

    /**
     * Prepare file-based audio source
     * In production, this would use FFmpeg for decoding
     */
    private fun prepareFileSource(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) {
            onError?.invoke("Audio file not found: $path")
            return false
        }

        // Detect format from extension
        val extension = file.extension.lowercase()
        
        when (extension) {
            "wav" -> {
                // Parse WAV header
                try {
                    FileInputStream(file).use { input ->
                        val header = ByteArray(44)
                        input.read(header)
                        
                        // Parse WAV header
                        val channels = ((header[23].toInt() and 0xFF) shl 8) or (header[22].toInt() and 0xFF)
                        val sampleRate = ((header[27].toInt() and 0xFF) shl 24) or
                                        ((header[26].toInt() and 0xFF) shl 16) or
                                        ((header[25].toInt() and 0xFF) shl 8) or
                                        (header[24].toInt() and 0xFF)
                        val bitsPerSample = ((header[35].toInt() and 0xFF) shl 8) or (header[34].toInt() and 0xFF)
                        
                        currentSampleRate = sampleRate
                        currentBitDepth = bitsPerSample
                        currentChannels = channels
                        
                        Log.d(TAG, "WAV format: ${currentSampleRate}Hz, ${currentBitDepth}bit, ${currentChannels}ch")
                        return true
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing WAV: ${e.message}")
                    return false
                }
            }
            "flac", "mp3", "aac", "m4a" -> {
                // These formats require FFmpeg for decoding
                // For now, use default settings
                Log.w(TAG, "Format $extension requires decoder integration (FFmpeg)")
                // Assume common format for testing
                currentSampleRate = 44100
                currentBitDepth = 16
                currentChannels = 2
                return true
            }
            else -> {
                onError?.invoke("Unsupported audio format: $extension")
                return false
            }
        }
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
