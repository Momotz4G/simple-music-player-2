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
 */
class UsbAudioManager(private val context: Context) {

    companion object {
        private const val TAG = "UsbAudioManager"
        private const val ACTION_USB_PERMISSION = "com.momotz4g.simplemusicplayer2.USB_PERMISSION"
        
        // USB Audio Class constants
        const val USB_CLASS_AUDIO = 1
        const val USB_SUBCLASS_AUDIOSTREAMING = 2
        const val USB_SUBCLASS_AUDIOCONTROL = 1
        
        // USB Audio endpoint types
        const val USB_ENDPOINT_XFER_ISOC = 1 // Isochronous transfer
    }

    private val usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var permissionReceiver: BroadcastReceiver? = null
    private var permissionCallback: ((Boolean) -> Unit)? = null
    private var connectedDac: UsbAudioDevice? = null
    
    /**
     * Represents a detected USB Audio Device (DAC)
     */
    data class UsbAudioDevice(
        val usbDevice: UsbDevice,
        val deviceName: String,
        val vendorId: Int,
        val productId: Int,
        val audioInterface: UsbInterface?,
        val isochronousEndpoint: UsbEndpoint?,
        val supportedSampleRates: List<Int>,
        val maxPacketSize: Int
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
                Log.d(TAG, "Found USB DAC: ${audioDevice.deviceName} (VID:${audioDevice.vendorId}, PID:${audioDevice.productId})")
            }
        }
        
        return dacs
    }

    /**
     * Parse a USB device to check if it's a USB Audio Class device
     */
    private fun parseUsbAudioDevice(device: UsbDevice): UsbAudioDevice? {
        var audioInterface: UsbInterface? = null
        var isochronousEndpoint: UsbEndpoint? = null
        var maxPacketSize = 0
        
        // Iterate through all interfaces to find audio streaming interface
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            
            // Check if this is an Audio Class interface
            if (iface.interfaceClass == USB_CLASS_AUDIO) {
                Log.d(TAG, "Found Audio interface: subclass=${iface.interfaceSubclass}, endpoints=${iface.endpointCount}")
                
                // We want the Audio Streaming interface (subclass 2), not Audio Control (subclass 1)
                if (iface.interfaceSubclass == USB_SUBCLASS_AUDIOSTREAMING) {
                    audioInterface = iface
                    
                    // Find isochronous OUT endpoint for audio playback
                    for (j in 0 until iface.endpointCount) {
                        val endpoint = iface.getEndpoint(j)
                        
                        // Check for isochronous OUT endpoint
                        if (endpoint.type == UsbConstants.USB_ENDPOINT_XFER_ISOC &&
                            endpoint.direction == UsbConstants.USB_DIR_OUT) {
                            isochronousEndpoint = endpoint
                            maxPacketSize = endpoint.maxPacketSize
                            Log.d(TAG, "Found isochronous OUT endpoint: maxPacketSize=$maxPacketSize")
                            break
                        }
                    }
                }
            }
        }
        
        // Only return if we found an audio streaming interface
        if (audioInterface != null) {
            return UsbAudioDevice(
                usbDevice = device,
                deviceName = device.productName ?: device.deviceName,
                vendorId = device.vendorId,
                productId = device.productId,
                audioInterface = audioInterface,
                isochronousEndpoint = isochronousEndpoint,
                supportedSampleRates = listOf(44100, 48000, 96000, 192000), // Default, will be parsed from descriptor later
                maxPacketSize = maxPacketSize
            )
        }
        
        return null
    }

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
        Log.i(TAG, "Requesting USB permission for: ${device.productName} (VID:${device.vendorId} PID:${device.productId})")
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
                            
                            // Unregister after result to prevent memory leaks/redundant registrations
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
                // IMPORTANT: Use RECEIVER_EXPORTED so the system UsbManager service can send the broadcast to us
                context.registerReceiver(permissionReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                context.registerReceiver(permissionReceiver, filter)
            }
        }

        val permissionIntent = Intent(ACTION_USB_PERMISSION).apply {
            setPackage(context.packageName) // Ensure only our app receives the broadcast
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, 
            0, 
            permissionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        
        usbManager.requestPermission(device, pendingIntent)
    }

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
