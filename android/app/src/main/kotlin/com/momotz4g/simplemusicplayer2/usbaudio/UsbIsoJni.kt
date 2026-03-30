package com.momotz4g.simplemusicplayer2.usbaudio

import android.util.Log
import java.nio.ByteBuffer

/**
 * UsbIsoJni - Kotlin JNI bridge to native isochronous USB transfer code.
 *
 * Android's Java/Kotlin USB Host API does not expose isochronous transfers,
 * which are required for USB Audio Class devices. This bridge calls into
 * native C code that uses Linux usbdevfs IOCTLs directly.
 *
 * Usage:
 *   1. init(fd, endpointAddr, maxPacketSize, numPackets, packetSize)
 *   2. claimInterface(fd, interfaceNumber)
 *   3. setInterface(fd, interfaceNumber, alternateSetting)
 *   4. Loop: submitUrb() -> reapUrb() -> fill buffer -> submitUrb() ...
 *   5. cancelAll() + releaseInterface() + dispose()
 */
class UsbIsoJni {

    companion object {
        private const val TAG = "UsbIsoJni"

        init {
            try {
                System.loadLibrary("usb_iso_jni")
                Log.i(TAG, "Native library loaded successfully")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load native library: ${e.message}")
            }
        }
    }

    // ==================== Lifecycle ====================

    /**
     * Initialize the isochronous transfer context.
     *
     * @param fd             File descriptor from UsbDeviceConnection.getFileDescriptor()
     * @param endpointAddr   USB endpoint address (e.g., 0x01 for first OUT endpoint)
     * @param maxPacketSize  Maximum packet size from endpoint descriptor
     * @param numPackets     Number of isochronous packets per URB (typically 1-8)
     * @param packetSize     Actual data size per packet for current audio format
     * @return true if initialization succeeded
     */
    fun init(fd: Int, endpointAddr: Int, maxPacketSize: Int, numPackets: Int, packetSize: Int): Boolean {
        Log.i(TAG, "init: fd=$fd, ep=0x${endpointAddr.toString(16)}, " +
                "maxPkt=$maxPacketSize, numPkt=$numPackets, pktSize=$packetSize")
        return nativeInit(fd, endpointAddr, maxPacketSize, numPackets, packetSize)
    }

    /**
     * Clean up all native resources.
     */
    fun dispose() {
        Log.i(TAG, "dispose")
        nativeDispose()
    }

    // ==================== URB Operations ====================

    /**
     * Submit a URB with audio data from a byte array.
     *
     * @param urbIndex  URB slot index (0 to getNumUrbs()-1)
     * @param data      Audio data to transmit
     * @param length    Number of valid bytes in data
     * @return 0 on success, negative errno on failure
     */
    fun submitUrb(urbIndex: Int, data: ByteArray, length: Int): Int {
        return nativeSubmitUrb(urbIndex, data, length)
    }

    /**
     * Submit a URB with audio data from a direct ByteBuffer (zero-copy path).
     *
     * @param urbIndex  URB slot index
     * @param buffer    Direct ByteBuffer containing audio data
     * @param offset    Byte offset into the buffer
     * @param length    Number of bytes to send
     * @return 0 on success, negative errno on failure
     */
    fun submitUrbDirect(urbIndex: Int, buffer: ByteBuffer, offset: Int, length: Int): Int {
        if (!buffer.isDirect) {
            Log.e(TAG, "submitUrbDirect requires a direct ByteBuffer")
            return -22 // EINVAL
        }
        return nativeSubmitUrbDirect(urbIndex, buffer, offset, length)
    }

    /**
     * Wait for and reap a completed URB.
     * This call blocks until a URB completes.
     *
     * @return URB index that completed (0 to getNumUrbs()-1), or negative errno on error
     */
    fun reapUrb(): Int {
        return nativeReapUrb()
    }

    /**
     * Cancel all pending URBs.
     */
    fun cancelAll() {
        Log.i(TAG, "cancelAll")
        nativeCancelAll()
    }

    // ==================== Interface Control ====================

    /**
     * Set alternate interface setting (selects audio format on DAC).
     *
     * @param fd               USB device file descriptor
     * @param interfaceNumber  USB interface number
     * @param alternateSetting Alternate setting index
     * @return 0 on success, negative errno on failure
     */
    fun setInterface(fd: Int, interfaceNumber: Int, alternateSetting: Int): Int {
        Log.i(TAG, "setInterface: iface=$interfaceNumber, alt=$alternateSetting")
        return nativeSetInterface(fd, interfaceNumber, alternateSetting)
    }

    /**
     * Claim a USB interface for exclusive access.
     *
     * @param fd               USB device file descriptor
     * @param interfaceNumber  Interface number to claim
     * @return 0 on success, negative errno on failure
     */
    fun claimInterface(fd: Int, interfaceNumber: Int): Int {
        return nativeClaimInterface(fd, interfaceNumber)
    }

    /**
     * Release a previously claimed USB interface.
     *
     * @param fd               USB device file descriptor
     * @param interfaceNumber  Interface number to release
     * @return 0 on success, negative errno on failure
     */
    fun releaseInterface(fd: Int, interfaceNumber: Int): Int {
        return nativeReleaseInterface(fd, interfaceNumber)
    }

    // ==================== Info ====================

    /**
     * Get the number of available URB slots.
     */
    fun getNumUrbs(): Int = nativeGetNumUrbs()

    /**
     * Get the buffer size for each URB in bytes.
     */
    fun getUrbBufferSize(): Int = nativeGetUrbBufferSize()

    // ==================== Native Methods ====================

    private external fun nativeInit(
        fd: Int, endpointAddr: Int, maxPacketSize: Int,
        numPackets: Int, packetSize: Int
    ): Boolean

    private external fun nativeSubmitUrb(urbIndex: Int, data: ByteArray, length: Int): Int
    private external fun nativeSubmitUrbDirect(urbIndex: Int, buffer: ByteBuffer, offset: Int, length: Int): Int
    private external fun nativeReapUrb(): Int
    private external fun nativeCancelAll()
    private external fun nativeSetInterface(fd: Int, interfaceNumber: Int, alternateSetting: Int): Int
    private external fun nativeClaimInterface(fd: Int, interfaceNumber: Int): Int
    private external fun nativeReleaseInterface(fd: Int, interfaceNumber: Int): Int
    private external fun nativeGetNumUrbs(): Int
    private external fun nativeGetUrbBufferSize(): Int
    private external fun nativeDispose()
}
