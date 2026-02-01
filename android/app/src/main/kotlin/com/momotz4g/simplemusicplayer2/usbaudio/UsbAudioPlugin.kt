package com.momotz4g.simplemusicplayer2.usbaudio

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.util.Log

/**
 * UsbAudioPlugin - Flutter plugin bridge for USB Audio functionality.
 * Exposes USB DAC detection, connection, and playback to Flutter/Dart code.
 */
class UsbAudioPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "UsbAudioPlugin"
        private const val METHOD_CHANNEL = "com.momotz4g.simplemusicplayer2/usb_audio"
        private const val EVENT_CHANNEL = "com.momotz4g.simplemusicplayer2/usb_audio_events"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    
    private val usbAudioPlayer: UsbAudioPlayer by lazy { UsbAudioPlayer(context) }

    /**
     * Register this plugin with the Flutter engine
     */
    fun register(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        )
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        )
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Set up player callbacks
        usbAudioPlayer.setCallbacks(
            onStateChange = { state ->
                sendEvent("stateChange", mapOf("state" to state.name))
            },
            onProgress = { current, total ->
                sendEvent("progress", mapOf("current" to current, "total" to total))
            },
            onError = { error ->
                sendEvent("error", mapOf("message" to error))
            }
        )

        Log.d(TAG, "USB Audio Plugin registered")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // ====== Device Discovery ======
            "getConnectedDacs" -> {
                val dacs = usbAudioPlayer.getConnectedDacs()
                val dacList = dacs.map { dac ->
                    mapOf(
                        "deviceName" to dac.deviceName,
                        "vendorId" to dac.vendorId,
                        "productId" to dac.productId,
                        "maxPacketSize" to dac.maxPacketSize,
                        "supportedSampleRates" to dac.supportedSampleRates
                    )
                }
                result.success(dacList)
            }

            "isDacAvailable" -> {
                result.success(usbAudioPlayer.isDacAvailable())
            }

            "isUsbAudioSupported" -> {
                // USB Audio is supported on Android 5.0+ (API 21)
                // But we target API 24+ based on minSdk
                result.success(android.os.Build.VERSION.SDK_INT >= 24)
            }

            // ====== Device Connection ======
            "openDac" -> {
                val vendorId = call.argument<Int>("vendorId")
                val productId = call.argument<Int>("productId")
                
                if (vendorId == null || productId == null) {
                    result.error("INVALID_ARGS", "vendorId and productId required", null)
                    return
                }

                val dacs = usbAudioPlayer.getConnectedDacs()
                val targetDac = dacs.find { it.vendorId == vendorId && it.productId == productId }
                
                if (targetDac == null) {
                    result.error("DAC_NOT_FOUND", "Specified DAC not found", null)
                    return
                }

                usbAudioPlayer.openDac(targetDac) { success ->
                    if (success) {
                        result.success(true)
                    } else {
                        result.error("OPEN_FAILED", "Failed to open DAC connection", null)
                    }
                }
            }

            "closeDac" -> {
                usbAudioPlayer.closeDac()
                result.success(true)
            }

            // ====== Playback Control ======
            "prepareFile" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGS", "path required", null)
                    return
                }
                
                val success = usbAudioPlayer.prepare(UsbAudioPlayer.AudioSource.FilePath(path))
                result.success(success)
            }

            "play" -> {
                val success = usbAudioPlayer.play()
                result.success(success)
            }

            "pause" -> {
                usbAudioPlayer.pause()
                result.success(true)
            }

            "resume" -> {
                val success = usbAudioPlayer.resume()
                result.success(success)
            }

            "stop" -> {
                usbAudioPlayer.stop()
                result.success(true)
            }

            // ====== Status & Info ======
            "getState" -> {
                result.success(usbAudioPlayer.getState().name)
            }

            "getAudioFormat" -> {
                result.success(usbAudioPlayer.getAudioFormat())
            }

            "getActiveDacInfo" -> {
                val activeDac = usbAudioPlayer.getConnectedDacs().firstOrNull()
                if (activeDac != null) {
                    result.success(mapOf(
                        "deviceName" to activeDac.deviceName,
                        "vendorId" to activeDac.vendorId,
                        "productId" to activeDac.productId,
                        "maxPacketSize" to activeDac.maxPacketSize
                    ))
                } else {
                    result.success(null)
                }
            }

            // ====== Cleanup ======
            "dispose" -> {
                usbAudioPlayer.dispose()
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Send event to Flutter via EventChannel
     */
    private fun sendEvent(type: String, data: Map<String, Any>) {
        eventSink?.success(mapOf(
            "type" to type,
            "data" to data
        ))
    }

    /**
     * Cleanup resources
     */
    fun dispose() {
        usbAudioPlayer.dispose()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
