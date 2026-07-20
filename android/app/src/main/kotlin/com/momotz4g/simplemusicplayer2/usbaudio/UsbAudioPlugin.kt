package com.momotz4g.simplemusicplayer2.usbaudio

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
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

    private val playerExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val method = call.method

        // Quick synchronous methods that don't block
        when (method) {
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
                return
            }
            "isDacAvailable" -> {
                result.success(usbAudioPlayer.isDacAvailable())
                return
            }
            "isUsbAudioSupported" -> {
                result.success(android.os.Build.VERSION.SDK_INT >= 24)
                return
            }
            "isDapDevice" -> {
                result.success(isDapDevice())
                return
            }
            "getState" -> {
                result.success(usbAudioPlayer.getState().name)
                return
            }
            "getAudioFormat" -> {
                result.success(usbAudioPlayer.getAudioFormat())
                return
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
                return
            }
            "setVolume" -> {
                val volume = (call.argument<Number>("volume") ?: 1.0f).toFloat()
                usbAudioPlayer.setVolume(volume)
                result.success(true)
                return
            }
            "setEqBand" -> {
                val bandIndex = call.argument<Int>("bandIndex") ?: -1
                val frequency = (call.argument<Number>("frequency") ?: 0).toFloat()
                val gain = (call.argument<Number>("gain") ?: 0).toFloat()
                val q = (call.argument<Number>("q") ?: 1.41).toFloat()
                if (bandIndex !in 0..9) {
                    result.error("INVALID_ARGS", "bandIndex must be 0..9", null)
                    return
                }
                usbAudioPlayer.setEqBand(bandIndex, frequency, gain, q)
                result.success(true)
                return
            }
            "setEqBypass" -> {
                for (i in 0 until 10) {
                    usbAudioPlayer.setEqBand(i, 1000f, 0f, 1.41f)
                }
                result.success(true)
                return
            }
        }

        // Heavy / Blocking methods executed sequentially on background thread
        playerExecutor.execute {
            try {
                when (method) {
                    "openDac" -> {
                        val vendorId = call.argument<Int>("vendorId")
                        val productId = call.argument<Int>("productId")
                        if (vendorId == null || productId == null) {
                            mainHandler.post { result.error("INVALID_ARGS", "vendorId and productId required", null) }
                            return@execute
                        }

                        val targetDac = usbAudioPlayer.getConnectedDacs().find {
                            it.vendorId == vendorId && it.productId == productId
                        }
                        if (targetDac == null) {
                            mainHandler.post { result.error("NOT_FOUND", "DAC not found", null) }
                            return@execute
                        }

                        usbAudioPlayer.openDac(targetDac) { success ->
                            mainHandler.post { 
                                if (success) result.success(true) 
                                else result.error("OPEN_FAILED", "Failed to open DAC", null) 
                            }
                        }
                    }
                    "closeDac" -> {
                        usbAudioPlayer.closeDac()
                        mainHandler.post { result.success(true) }
                    }
                    "openBuiltInDac" -> {
                        val success = usbAudioPlayer.openBuiltInDac(isDapDevice())
                        mainHandler.post { 
                            if (success) result.success(true) 
                            else result.error("ENGINE_FAILED", "Failed to init built-in DAC", null) 
                        }
                    }
                    "prepareFile" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            mainHandler.post { result.error("INVALID_ARGS", "path required", null) }
                            return@execute
                        }
                        val success = usbAudioPlayer.prepare(UsbAudioPlayer.AudioSource.FilePath(path))
                        mainHandler.post { result.success(success) }
                    }
                    "prepareUrl" -> {
                        val url = call.argument<String>("url")
                        if (url == null) {
                            mainHandler.post { result.error("INVALID_ARGS", "url required", null) }
                            return@execute
                        }
                        val success = usbAudioPlayer.prepare(UsbAudioPlayer.AudioSource.StreamUrl(url))
                        mainHandler.post { result.success(success) }
                    }
                    "play" -> {
                        val success = usbAudioPlayer.play()
                        mainHandler.post { result.success(success) }
                    }
                    "pause" -> {
                        usbAudioPlayer.pause()
                        mainHandler.post { result.success(true) }
                    }
                    "resume" -> {
                        val success = usbAudioPlayer.resume()
                        mainHandler.post { result.success(success) }
                    }
                    "stop" -> {
                        usbAudioPlayer.stop()
                        mainHandler.post { result.success(true) }
                    }
                    "seek" -> {
                        val positionMs = call.argument<Int>("positionMs")?.toLong()
                        if (positionMs == null) {
                            mainHandler.post { result.error("INVALID_ARGS", "positionMs required", null) }
                            return@execute
                        }
                        usbAudioPlayer.seek(positionMs)
                        mainHandler.post { result.success(true) }
                    }
                    "dispose" -> {
                        usbAudioPlayer.dispose()
                        mainHandler.post { result.success(true) }
                    }
                    else -> {
                        mainHandler.post { result.notImplemented() }
                    }
                }
            } catch (e: Exception) {
                mainHandler.post { result.error("EXECUTION_ERROR", e.message, null) }
            }
        }
    }

    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    /**
     * Send event to Flutter via EventChannel
     */
    private fun sendEvent(type: String, data: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(mapOf(
                "type" to type,
                "data" to data
            ))
        }
    }

    /**
     * Cleanup resources
     */
    fun dispose() {
        usbAudioPlayer.dispose()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    // ==================== DAP Detection ====================

    /**
     * Detect if this device is a DAP (Digital Audio Player).
     *
     * Primary check: no telephony capability — DAPs don't have cellular modems.
     * Fallback: known DAP manufacturer names for edge cases where telephony
     * might be reported incorrectly by custom ROMs.
     *
     * Compatible brands detected:
     *  - FiiO (M11, M15, M21, M23, etc.)
     *  - HiBy (R3, R5, R6, R8, RS6, etc.)
     *  - Shanling (M0, M3X, M6, M8, M9, etc.)
     *  - iBasso (DX160, DX170, DX240, DX300, DX320, etc.)
     *  - Cayin (N3Pro, N6ii, N7, N8, etc.)
     *  - Astell&Kern (A&norma, A&futura, A&ultima, SP3000, etc.)
     *  - HiDizs (AP80, AP200, DH80, etc.)
     *  - Lotoo (PAW Gold, PAW 6000, etc.)
     *  - Tempotec (V1-A, V3, V6, etc.)
     *  - Questyle (QP2R, QPM, etc.)
     *  - Sony Walkman (NW-A300, NW-WM1A, NW-ZX707, etc.)
     *  - Luxury & Precision (LP6, P6 Pro, W4, etc.)
     *  - AUNE (M1p, M1s, etc.)
     *  - xDuoo (X10T II, X20, etc.)
     *  - Colorfly (U8, C4, etc.)
     *  - Zishan (Z1, Z3, DSD, etc.)
     *  - Any Android device without telephony (e.g. custom ROMs on DAP)
     */
    private fun isDapDevice(): Boolean {
        val pm = context.packageManager
        
        // Exclude devices that aren't phones but definitely aren't DAPs either.
        val isTv = pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        val isAuto = pm.hasSystemFeature(PackageManager.FEATURE_AUTOMOTIVE)
        val isWatch = pm.hasSystemFeature(PackageManager.FEATURE_WATCH)
        
        if (isTv || isAuto || isWatch) {
            Log.i(TAG, "Not a DAP: Device is TV/Auto/Watch")
            return false
        }

        // Primary: no telephony = not a phone = likely a DAP (or Wi-Fi tablet)
        val hasTelephony = pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
        if (!hasTelephony) {
            Log.i(TAG, "DAP detected: no telephony feature (and not TV/Auto/Watch)")
            return true
        }

        // Fallback: some DAPs include telephony in their ROM but are
        // definitely audio players. Check known manufacturer names.
        val mfr = Build.MANUFACTURER.lowercase()
        val knownDapManufacturers = listOf(
            "fiio", "hiby", "shanling", "ibasso", "cayin",
            "astell", "iriver",  // Astell&Kern uses "iriver" as Build.MANUFACTURER
            "hidizs", "lotoo", "tempotec", "questyle",
            "luxury", "aune", "xduoo", "colorfly", "zishan",
        )
        for (dap in knownDapManufacturers) {
            if (mfr.contains(dap)) {
                Log.i(TAG, "DAP detected: manufacturer \"$mfr\" matches \"$dap\"")
                return true
            }
        }

        // Also check Build.BRAND (some OEMs set brand differently from manufacturer)
        val brand = Build.BRAND.lowercase()
        for (dap in knownDapManufacturers) {
            if (brand.contains(dap)) {
                Log.i(TAG, "DAP detected: brand \"$brand\" matches \"$dap\"")
                return true
            }
        }

        return false
    }

    /**
     * Best-effort USB DAC release for app backgrounding.
     *
     * Stops the URB pump, closes the DAC connection, and releases the
     * USB interface claim — but does NOT dispose the engine handle or
     * unregister channels. The Flutter engine + native audio engine
     * stay alive so we can re-attach instantly when the app foregrounds
     * again.
     *
     * Notifies Dart via the existing event channel with a "background"
     * stateChange so PlayerProvider can persist a "should resume"
     * marker for the next launch.
     */
    fun releaseUsbForBackground() {
        // Snapshot whether we were active before tearing down so we can
        // tell Dart whether to flag a resume on the next launch.
        val wasActive = usbAudioPlayer.getState() == UsbAudioPlayer.PlayerState.PLAYING
                || usbAudioPlayer.getState() == UsbAudioPlayer.PlayerState.PAUSED

        usbAudioPlayer.closeDac()

        if (wasActive) {
            sendEvent("backgroundRelease", mapOf("wasActive" to true))
        }
    }
}
