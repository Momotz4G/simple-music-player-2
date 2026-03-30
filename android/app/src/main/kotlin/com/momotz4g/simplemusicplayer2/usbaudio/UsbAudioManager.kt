package com.momotz4g.simplemusicplayer2.usbaudio

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import android.util.Log

/**
 * UsbAudioManager - Handles USB Audio Class device detection, enumeration, and permission management.
 * This is the core manager for USB DAC access on Android < 14.
 *
 * Key responsibilities:
 * - Scan for USB Audio Class devices
 * - Parse USB Audio Class descriptors to determine supported formats
 * - Handle USB permission requests
 * - Manage device connections
 */
class UsbAudioManager(private val context: Context) {

    companion object {
        private const val TAG = "UsbAudioManager"
        private const val ACTION_USB_PERMISSION = "com.momotz4g.simplemusicplayer2.USB_PERMISSION"

        // USB Audio Class constants
        const val USB_CLASS_AUDIO = 1
        const val USB_SUBCLASS_AUDIOCONTROL = 1
        const val USB_SUBCLASS_AUDIOSTREAMING = 2

        // USB Audio Class descriptor subtypes (Audio Streaming)
        private const val AS_GENERAL = 0x01
        private const val FORMAT_TYPE = 0x02

        // USB Audio Format Type I descriptor fields
        private const val FORMAT_TYPE_I = 0x01
    }

    private val usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var permissionReceiver: BroadcastReceiver? = null
    private var permissionCallback: ((Boolean) -> Unit)? = null
    private var connectedDac: UsbAudioDevice? = null

    /**
     * Represents a detected USB Audio Device (DAC) with parsed format information
     */
    data class UsbAudioDevice(
        val usbDevice: UsbDevice,
        val deviceName: String,
        val vendorId: Int,
        val productId: Int,
        val audioStreamingInterfaces: List<AudioStreamingInterface>,
        val maxPacketSize: Int,
        val supportedSampleRates: List<Int>
    ) {
        /**
         * Get the best matching interface for a target format
         */
        fun findBestInterface(targetSampleRate: Int, targetBitDepth: Int, targetChannels: Int): AudioStreamingInterface? {
            // Prefer exact match
            return audioStreamingInterfaces.find { iface ->
                iface.bitDepth == targetBitDepth &&
                iface.channels == targetChannels &&
                iface.supportedSampleRates.contains(targetSampleRate)
            } ?: audioStreamingInterfaces.firstOrNull { iface ->
                // Fallback: any interface that supports the sample rate
                iface.supportedSampleRates.contains(targetSampleRate)
            } ?: audioStreamingInterfaces.firstOrNull()
        }
    }

    /**
     * Represents one audio streaming alternate setting with its format details
     */
    data class AudioStreamingInterface(
        val usbInterface: UsbInterface,
        val isochronousEndpoint: UsbEndpoint?,
        val interfaceNumber: Int,
        val alternateSetting: Int,
        val channels: Int,
        val bitDepth: Int,
        val subframeSize: Int,
        val supportedSampleRates: List<Int>
    )

    /**
     * Scan for connected USB Audio Class devices
     */
    fun getConnectedDacs(): List<UsbAudioDevice> {
        val dacs = mutableListOf<UsbAudioDevice>()

        for ((_, device) in usbManager.deviceList) {
            val audioDevice = parseUsbAudioDevice(device)
            if (audioDevice != null) {
                dacs.add(audioDevice)
                Log.d(TAG, "Found USB DAC: ${audioDevice.deviceName} " +
                        "(VID:${audioDevice.vendorId}, PID:${audioDevice.productId})")
                for (iface in audioDevice.audioStreamingInterfaces) {
                    Log.d(TAG, "  Interface #${iface.interfaceNumber} alt=${iface.alternateSetting}: " +
                            "${iface.channels}ch ${iface.bitDepth}bit, rates=${iface.supportedSampleRates}")
                }
            }
        }

        return dacs
    }

    /**
     * Parse a USB device to extract all Audio Class interface information.
     * Reads raw USB descriptors to determine supported formats and sample rates.
     */
    private fun parseUsbAudioDevice(device: UsbDevice): UsbAudioDevice? {
        val audioInterfaces = mutableListOf<AudioStreamingInterface>()
        var maxPacketSize = 0
        val allSampleRates = mutableSetOf<Int>()

        // Try to parse raw USB descriptors for detailed format info
        val rawDescriptors = try {
            val connection = usbManager.openDevice(device)
            val desc = connection?.rawDescriptors
            connection?.close()
            desc
        } catch (e: Exception) {
            null
        }

        // Parse each interface for Audio Streaming
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)

            if (iface.interfaceClass == USB_CLASS_AUDIO &&
                iface.interfaceSubclass == USB_SUBCLASS_AUDIOSTREAMING) {

                var isoEndpoint: UsbEndpoint? = null

                // Find isochronous OUT endpoint for audio playback
                for (j in 0 until iface.endpointCount) {
                    val endpoint = iface.getEndpoint(j)
                    if (endpoint.type == UsbConstants.USB_ENDPOINT_XFER_ISOC &&
                        endpoint.direction == UsbConstants.USB_DIR_OUT) {
                        isoEndpoint = endpoint
                        if (endpoint.maxPacketSize > maxPacketSize) {
                            maxPacketSize = endpoint.maxPacketSize
                        }
                        break
                    }
                }

                // Skip alternate setting 0 (zero-bandwidth / idle)
                if (isoEndpoint == null && iface.endpointCount == 0) {
                    continue
                }

                // Parse format details from raw descriptors
                val formatInfo = if (rawDescriptors != null) {
                    parseFormatDescriptor(rawDescriptors, iface.id, iface.alternateSetting)
                } else {
                    null
                }

                val channels = formatInfo?.channels ?: 2
                val bitDepth = formatInfo?.bitDepth ?: 16
                val subframeSize = formatInfo?.subframeSize ?: (bitDepth / 8)
                val sampleRates = formatInfo?.sampleRates
                    ?: inferSampleRates(maxPacketSize, channels, bitDepth)

                allSampleRates.addAll(sampleRates)

                if (isoEndpoint != null) {
                    audioInterfaces.add(AudioStreamingInterface(
                        usbInterface = iface,
                        isochronousEndpoint = isoEndpoint,
                        interfaceNumber = iface.id,
                        alternateSetting = iface.alternateSetting,
                        channels = channels,
                        bitDepth = bitDepth,
                        subframeSize = subframeSize,
                        supportedSampleRates = sampleRates
                    ))
                }
            }
        }

        if (audioInterfaces.isEmpty()) return null

        return UsbAudioDevice(
            usbDevice = device,
            deviceName = device.productName ?: device.deviceName,
            vendorId = device.vendorId,
            productId = device.productId,
            audioStreamingInterfaces = audioInterfaces,
            maxPacketSize = maxPacketSize,
            supportedSampleRates = allSampleRates.sorted()
        )
    }

    /**
     * Parse USB Audio Class Format Type I descriptor from raw USB descriptor bytes.
     *
     * USB Audio Class 1.0 Format Type I Descriptor layout:
     *   Byte 0: bLength
     *   Byte 1: bDescriptorType (0x24 = CS_INTERFACE)
     *   Byte 2: bDescriptorSubtype (0x02 = FORMAT_TYPE)
     *   Byte 3: bFormatType (0x01 = FORMAT_TYPE_I)
     *   Byte 4: bNrChannels
     *   Byte 5: bSubframeSize (bytes per sample, e.g., 2 for 16-bit, 3 for 24-bit)
     *   Byte 6: bBitResolution (actual bits, e.g., 16, 24)
     *   Byte 7: bSamFreqType (0 = continuous, N = number of discrete rates)
     *   Byte 8+: Sample rates (3 bytes each)
     */
    private data class FormatInfo(
        val channels: Int,
        val bitDepth: Int,
        val subframeSize: Int,
        val sampleRates: List<Int>
    )

    private fun parseFormatDescriptor(rawDescriptors: ByteArray, interfaceNum: Int, altSetting: Int): FormatInfo? {
        var pos = 0
        var currentInterfaceNum = -1
        var currentAltSetting = -1
        var inTargetInterface = false

        while (pos < rawDescriptors.size - 2) {
            val bLength = rawDescriptors[pos].toInt() and 0xFF
            if (bLength < 2) break
            if (pos + bLength > rawDescriptors.size) break

            val bDescriptorType = rawDescriptors[pos + 1].toInt() and 0xFF

            // Interface descriptor (type 0x04)
            if (bDescriptorType == 0x04 && bLength >= 9) {
                currentInterfaceNum = rawDescriptors[pos + 2].toInt() and 0xFF
                currentAltSetting = rawDescriptors[pos + 3].toInt() and 0xFF
                val interfaceClass = rawDescriptors[pos + 5].toInt() and 0xFF
                val interfaceSubclass = rawDescriptors[pos + 6].toInt() and 0xFF

                inTargetInterface = currentInterfaceNum == interfaceNum &&
                        currentAltSetting == altSetting &&
                        interfaceClass == USB_CLASS_AUDIO &&
                        interfaceSubclass == USB_SUBCLASS_AUDIOSTREAMING
            }

            // Class-specific interface descriptor (type 0x24)
            if (inTargetInterface && bDescriptorType == 0x24 && bLength >= 8) {
                val bDescriptorSubtype = rawDescriptors[pos + 2].toInt() and 0xFF

                // FORMAT_TYPE descriptor
                if (bDescriptorSubtype == FORMAT_TYPE) {
                    val bFormatType = rawDescriptors[pos + 3].toInt() and 0xFF

                    if (bFormatType == FORMAT_TYPE_I && bLength >= 8) {
                        val nrChannels = rawDescriptors[pos + 4].toInt() and 0xFF
                        val subframeSize = rawDescriptors[pos + 5].toInt() and 0xFF
                        val bitResolution = rawDescriptors[pos + 6].toInt() and 0xFF
                        val samFreqType = rawDescriptors[pos + 7].toInt() and 0xFF

                        val sampleRates = mutableListOf<Int>()

                        if (samFreqType == 0 && bLength >= 14) {
                            // Continuous: lower bound (3 bytes) + upper bound (3 bytes)
                            val lower = parse3ByteInt(rawDescriptors, pos + 8)
                            val upper = parse3ByteInt(rawDescriptors, pos + 11)
                            // Generate common rates within range
                            for (rate in listOf(8000, 11025, 16000, 22050, 32000, 44100, 48000,
                                88200, 96000, 176400, 192000, 352800, 384000)) {
                                if (rate in lower..upper) {
                                    sampleRates.add(rate)
                                }
                            }
                        } else {
                            // Discrete: samFreqType rates, 3 bytes each
                            for (r in 0 until samFreqType) {
                                val rateOffset = pos + 8 + (r * 3)
                                if (rateOffset + 3 <= rawDescriptors.size) {
                                    val rate = parse3ByteInt(rawDescriptors, rateOffset)
                                    sampleRates.add(rate)
                                }
                            }
                        }

                        Log.d(TAG, "Parsed Format Type I: ${nrChannels}ch, " +
                                "${bitResolution}bit (${subframeSize}B/sample), " +
                                "rates=$sampleRates")

                        return FormatInfo(
                            channels = nrChannels,
                            bitDepth = bitResolution,
                            subframeSize = subframeSize,
                            sampleRates = sampleRates
                        )
                    }
                }
            }

            pos += bLength
        }

        return null
    }

    /**
     * Parse a 3-byte little-endian integer (USB Audio Class sample rate format)
     */
    private fun parse3ByteInt(data: ByteArray, offset: Int): Int {
        return (data[offset].toInt() and 0xFF) or
                ((data[offset + 1].toInt() and 0xFF) shl 8) or
                ((data[offset + 2].toInt() and 0xFF) shl 16)
    }

    /**
     * Infer likely supported sample rates from max packet size when descriptors aren't parseable
     */
    private fun inferSampleRates(maxPacketSize: Int, channels: Int, bitDepth: Int): List<Int> {
        val bytesPerFrame = (bitDepth / 8) * channels
        val maxSamplesPerMs = maxPacketSize / bytesPerFrame

        val rates = mutableListOf<Int>()
        for (rate in listOf(44100, 48000, 88200, 96000, 176400, 192000)) {
            val samplesPerMs = rate / 1000
            if (samplesPerMs <= maxSamplesPerMs) {
                rates.add(rate)
            }
        }

        return rates.ifEmpty { listOf(44100, 48000) }
    }

    // ==================== Permission Management ====================

    /**
     * Check if we have permission to access the USB device
     */
    fun hasPermission(device: UsbDevice): Boolean {
        return usbManager.hasPermission(device)
    }

    /**
     * Request permission to access a USB device
     */
    fun requestPermission(device: UsbDevice, callback: (Boolean) -> Unit) {
        Log.i(TAG, "Requesting USB permission for: ${device.productName} " +
                "(VID:${device.vendorId} PID:${device.productId})")
        permissionCallback = callback

        // Register permission receiver if not already registered
        if (permissionReceiver == null) {
            permissionReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (ACTION_USB_PERMISSION == intent.action) {
                        synchronized(this) {
                            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                            Log.d(TAG, "USB Permission result: $granted")
                            permissionCallback?.invoke(granted)
                            permissionCallback = null

                            try {
                                context.unregisterReceiver(this)
                                permissionReceiver = null
                            } catch (e: Exception) {
                                Log.e(TAG, "Error unregistering permission receiver: ${e.message}")
                            }
                        }
                    }
                }
            }

            val filter = IntentFilter(ACTION_USB_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(permissionReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                context.registerReceiver(permissionReceiver, filter)
            }
        }

        val permissionIntent = Intent(ACTION_USB_PERMISSION).apply {
            setPackage(context.packageName)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            permissionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        usbManager.requestPermission(device, pendingIntent)
    }

    // ==================== Device Connection ====================

    /**
     * Open a connection to the USB device
     */
    fun openDevice(device: UsbDevice): UsbDeviceConnection? {
        return usbManager.openDevice(device)
    }

    /**
     * Get the currently connected/active DAC
     */
    fun getActiveDac(): UsbAudioDevice? {
        return connectedDac
    }

    /**
     * Set the active DAC
     */
    fun setActiveDac(dac: UsbAudioDevice?) {
        connectedDac = dac
    }

    /**
     * Cleanup resources
     */
    fun dispose() {
        try {
            permissionReceiver?.let {
                context.unregisterReceiver(it)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error unregistering receiver: ${e.message}")
        }
        permissionReceiver = null
        permissionCallback = null
        connectedDac = null
    }
}
