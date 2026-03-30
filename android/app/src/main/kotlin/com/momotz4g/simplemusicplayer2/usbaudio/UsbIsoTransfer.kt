package com.momotz4g.simplemusicplayer2.usbaudio

import android.hardware.usb.*
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * UsbIsoTransfer - Handles isochronous USB transfers for real-time audio streaming to USB DACs.
 *
 * Uses native JNI (UsbIsoJni) to submit isochronous URBs via Linux usbdevfs IOCTLs,
 * since Android's Java USB Host API does not expose isochronous transfers.
 *
 * Architecture:
 *   Transfer Thread:
 *     1. Fill URB buffer with audio data (via callback)
 *     2. Submit URB to kernel via JNI
 *     3. Reap completed URB
 *     4. Repeat with next URB slot (triple-buffered)
 */
class UsbIsoTransfer(
    private val connection: UsbDeviceConnection,
    private val endpoint: UsbEndpoint,
    private val audioInterface: UsbInterface,
    private val sampleRate: Int,
    private val bitDepth: Int = 16,
    private val channels: Int = 2
) {
    companion object {
        private const val TAG = "UsbIsoTransfer"

        // USB Audio timing: 1ms frame interval for full-speed, 125µs for high-speed
        // We use 1 packet per URB for simplest timing
        private const val PACKETS_PER_URB = 1
    }

    private val isoJni = UsbIsoJni()
    private var isRunning = false
    private var transferThread: Thread? = null

    // Audio format calculations
    private val bytesPerSample = bitDepth / 8
    private val bytesPerFrame = bytesPerSample * channels  // "frame" = one sample across all channels
    private val samplesPerPacket = sampleRate / 1000        // Samples per 1ms USB frame
    private val bytesPerPacket = samplesPerPacket * bytesPerFrame

    // Callback for requesting more audio data
    private var audioDataCallback: ((ByteBuffer, Int) -> Int)? = null

    // Statistics
    private var totalFramesTransferred = 0L
    private var underrunCount = 0

    /**
     * Set the callback for requesting audio data.
     * The callback should fill the provided buffer and return the number of bytes written.
     */
    fun setAudioDataCallback(callback: (ByteBuffer, Int) -> Int) {
        audioDataCallback = callback
    }

    /**
     * Start isochronous audio streaming via JNI.
     */
    fun start(): Boolean {
        if (isRunning) {
            Log.w(TAG, "Transfer already running")
            return false
        }

        val fd = connection.fileDescriptor
        if (fd < 0) {
            Log.e(TAG, "Invalid USB device file descriptor: $fd")
            return false
        }

        Log.i(TAG, "Starting isochronous transfer: ${sampleRate}Hz, ${bitDepth}bit, ${channels}ch")
        Log.i(TAG, "Bytes per packet: $bytesPerPacket, Max packet size: ${endpoint.maxPacketSize}")
        Log.i(TAG, "Interface: #${audioInterface.id}, Endpoint: 0x${endpoint.address.toString(16)}")

        // Step 1: Claim the audio interface via JNI (bypasses Android's claimInterface)
        val claimResult = isoJni.claimInterface(fd, audioInterface.id)
        if (claimResult < 0) {
            Log.e(TAG, "Failed to claim interface ${audioInterface.id}: error $claimResult")
            // Try Android API as fallback
            if (!connection.claimInterface(audioInterface, true)) {
                Log.e(TAG, "Fallback claimInterface also failed")
                return false
            }
            Log.i(TAG, "Claimed interface via Android API fallback")
        }

        // Step 2: Set alternate setting if needed (alternate setting 1 is typically the active audio setting)
        // Alternate setting 0 = zero-bandwidth (idle), setting 1+ = active with specific format
        val altResult = isoJni.setInterface(fd, audioInterface.id, audioInterface.alternateSetting.coerceAtLeast(1))
        if (altResult < 0) {
            Log.w(TAG, "setInterface failed (may be OK for some DACs): error $altResult")
        }

        // Step 3: Initialize isochronous transfer context
        val actualPacketSize = bytesPerPacket.coerceAtMost(endpoint.maxPacketSize)
        val initResult = isoJni.init(
            fd = fd,
            endpointAddr = endpoint.address,
            maxPacketSize = endpoint.maxPacketSize,
            numPackets = PACKETS_PER_URB,
            packetSize = actualPacketSize
        )

        if (!initResult) {
            Log.e(TAG, "Failed to initialize native isochronous context")
            return false
        }

        // Step 4: Set sample rate on the endpoint via USB Audio Class control request
        setSampleRate(sampleRate)

        // Step 5: Start the transfer thread
        isRunning = true
        totalFramesTransferred = 0
        underrunCount = 0
        startTransferThread()

        return true
    }

    /**
     * Stop isochronous audio streaming.
     */
    fun stop() {
        Log.d(TAG, "Stopping transfer. Frames: $totalFramesTransferred, Underruns: $underrunCount")
        isRunning = false

        // Cancel pending URBs
        isoJni.cancelAll()

        // Wait for transfer thread to finish
        transferThread?.join(2000)
        transferThread = null

        // Release interface
        val fd = connection.fileDescriptor
        if (fd >= 0) {
            // Set alternate setting 0 (zero-bandwidth / idle)
            isoJni.setInterface(fd, audioInterface.id, 0)
            isoJni.releaseInterface(fd, audioInterface.id)
        }

        // Clean up native resources
        isoJni.dispose()
    }

    /**
     * Check if transfer is currently active
     */
    fun isActive(): Boolean = isRunning

    /**
     * Get transfer statistics
     */
    fun getStats(): Map<String, Any> {
        return mapOf(
            "totalFrames" to totalFramesTransferred,
            "underruns" to underrunCount,
            "sampleRate" to sampleRate,
            "bitDepth" to bitDepth,
            "channels" to channels
        )
    }

    /**
     * Main transfer thread - continuously sends audio data to USB device via isochronous URBs.
     *
     * Uses a triple-buffered approach:
     * 1. Fill URB N with audio data
     * 2. Submit URB N
     * 3. While URB N is transferring, fill URB N+1
     * 4. Reap completed URB (gets recycled)
     * 5. Repeat
     */
    private fun startTransferThread() {
        transferThread = thread(name = "UsbIsoTransfer", priority = Thread.MAX_PRIORITY) {
            Log.d(TAG, "Transfer thread started (priority: ${Thread.currentThread().priority})")

            val numUrbs = isoJni.getNumUrbs()
            val urbBufferSize = isoJni.getUrbBufferSize()
            val packetBuffer = ByteBuffer.allocateDirect(urbBufferSize).order(ByteOrder.LITTLE_ENDIAN)
            val silencePacket = ByteArray(urbBufferSize) // Pre-allocated silence buffer

            // Prime the pump: submit initial URBs
            var initialSubmits = 0
            for (i in 0 until numUrbs) {
                packetBuffer.clear()
                val bytesRead = audioDataCallback?.invoke(packetBuffer, bytesPerPacket) ?: 0

                val data = if (bytesRead > 0) {
                    val arr = ByteArray(bytesRead)
                    packetBuffer.flip()
                    packetBuffer.get(arr)
                    arr
                } else {
                    silencePacket
                }

                val submitResult = isoJni.submitUrb(i, data, data.size)
                if (submitResult < 0) {
                    Log.e(TAG, "Initial submit failed for URB $i: $submitResult")
                    break
                }
                initialSubmits++
            }

            if (initialSubmits == 0) {
                Log.e(TAG, "Failed to submit any initial URBs")
                isRunning = false
                return@thread
            }

            Log.d(TAG, "Primed $initialSubmits URBs, entering transfer loop")

            // Main transfer loop
            while (isRunning) {
                try {
                    // Reap a completed URB
                    val completedUrb = isoJni.reapUrb()
                    if (completedUrb < 0) {
                        if (isRunning) {
                            Log.w(TAG, "reapUrb failed: $completedUrb")
                            Thread.sleep(1)
                        }
                        continue
                    }

                    totalFramesTransferred += bytesPerPacket / bytesPerFrame

                    // Fill the completed URB with new audio data and resubmit
                    packetBuffer.clear()
                    val bytesRead = audioDataCallback?.invoke(packetBuffer, bytesPerPacket) ?: 0

                    val data: ByteArray
                    val dataLen: Int

                    if (bytesRead > 0) {
                        data = ByteArray(bytesRead)
                        packetBuffer.flip()
                        packetBuffer.get(data)
                        dataLen = bytesRead
                    } else {
                        // Underrun - send silence
                        underrunCount++
                        data = silencePacket
                        dataLen = bytesPerPacket
                    }

                    val submitResult = isoJni.submitUrb(completedUrb, data, dataLen)
                    if (submitResult < 0) {
                        Log.e(TAG, "Re-submit failed for URB $completedUrb: $submitResult")
                        if (isRunning) {
                            // Try to recover by re-initializing
                            Thread.sleep(10)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Transfer error: ${e.message}")
                    if (!isRunning) break
                    Thread.sleep(10)
                }
            }

            Log.d(TAG, "Transfer thread ended. Total frames: $totalFramesTransferred")
        }
    }

    /**
     * Set the sample rate on the USB device endpoint.
     * Uses USB Audio Class SET_CUR request for Sampling Frequency Control.
     */
    fun setSampleRate(targetSampleRate: Int): Boolean {
        // Pack sample rate as 3 bytes (USB Audio Class 1.0 format)
        val sampleRateData = ByteArray(3)
        sampleRateData[0] = (targetSampleRate and 0xFF).toByte()
        sampleRateData[1] = ((targetSampleRate shr 8) and 0xFF).toByte()
        sampleRateData[2] = ((targetSampleRate shr 16) and 0xFF).toByte()

        // Control transfer: SET_CUR for Sampling Frequency Control
        // bmRequestType: Class-specific, Endpoint, Host-to-Device (0x22)
        // bRequest: SET_CUR (0x01)
        // wValue: 0x0100 (Sampling Frequency Control selector)
        // wIndex: Endpoint address
        val result = connection.controlTransfer(
            0x22,  // USB_TYPE_CLASS | USB_RECIP_ENDPOINT | USB_DIR_OUT
            0x01,  // SET_CUR
            0x0100, // Sampling Frequency Control
            endpoint.address,
            sampleRateData,
            sampleRateData.size,
            1000
        )

        if (result >= 0) {
            Log.i(TAG, "Set sample rate to $targetSampleRate Hz")
        } else {
            Log.w(TAG, "Failed to set sample rate (may be fixed-rate DAC): result=$result")
        }

        return result >= 0
    }
}
