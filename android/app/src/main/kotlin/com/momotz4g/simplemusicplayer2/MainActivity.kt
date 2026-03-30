package com.momotz4g.simplemusicplayer2

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import com.momotz4g.simplemusicplayer2.usbaudio.UsbAudioPlugin
import android.media.audiofx.DynamicsProcessing
import android.util.Log

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.momotz4g.simplemusicplayer2/audio_settings"
    private val EQ_CHANNEL = "com.momotz4g.simple_music_player/equalizer"
    private var bitPerfectModeEnabled = false
    private var usbAudioPlugin: UsbAudioPlugin? = null
    private val dynamicsProcessingMap = mutableMapOf<Int, DynamicsProcessing>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(YoutubeDLPlugin())
        
        // Register USB Audio Plugin for Android < 14 bit-perfect support
        usbAudioPlugin = UsbAudioPlugin(this).also {
            it.register(flutterEngine)
        }

        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBitPerfectMode" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    if (android.os.Build.VERSION.SDK_INT >= 34) {
                        setBitPerfectAudio(enable, result)
                    } else {
                        result.error("UNSUPPORTED_VERSION", "Android 14+ required for bit-perfect audio", null)
                    }
                }
                "getNativeOutputSampleRate" -> {
                    try {
                        val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
                        val nativeRate = audioManager.getProperty(android.media.AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)
                        val framesPerBuffer = audioManager.getProperty(android.media.AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)
                        
                        // Get active output device info
                        val devices = audioManager.getDevices(android.media.AudioManager.GET_DEVICES_OUTPUTS)
                        val activeDevice = devices.firstOrNull { 
                            it.type == android.media.AudioDeviceInfo.TYPE_USB_DEVICE || 
                            it.type == android.media.AudioDeviceInfo.TYPE_USB_HEADSET 
                        } ?: devices.firstOrNull {
                            it.type == android.media.AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                            it.type == android.media.AudioDeviceInfo.TYPE_WIRED_HEADSET
                        } ?: devices.firstOrNull {
                            it.type == android.media.AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                        }
                        
                        val deviceName = activeDevice?.productName?.toString() ?: "Unknown"
                        val deviceType = when (activeDevice?.type) {
                            android.media.AudioDeviceInfo.TYPE_USB_DEVICE -> "USB DAC"
                            android.media.AudioDeviceInfo.TYPE_USB_HEADSET -> "USB Headset"
                            android.media.AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Wired Headphones"
                            android.media.AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired Headset"
                            android.media.AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth A2DP"
                            android.media.AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth SCO"
                            android.media.AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Built-in Speaker"
                            else -> "Audio Output"
                        }
                        
                        // Get supported sample rates from active device
                        val supportedRates = activeDevice?.sampleRates?.toList() ?: emptyList()
                        
                        result.success(mapOf(
                            "nativeSampleRate" to (nativeRate?.toIntOrNull() ?: 48000),
                            "framesPerBuffer" to (framesPerBuffer?.toIntOrNull() ?: 256),
                            "deviceName" to deviceName,
                            "deviceType" to deviceType,
                            "supportedRates" to supportedRates,
                            "bitPerfectEnabled" to bitPerfectModeEnabled
                        ))
                    } catch (e: Exception) {
                        result.error("NATIVE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EQ_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "apply" -> {
                    val sessionId = call.argument<Int>("sessionId") ?: return@setMethodCallHandler
                    val gains = call.argument<List<Double>>("gains") ?: return@setMethodCallHandler
                    val preamp = call.argument<Double>("preamp") ?: 0.0
                    applyEQ(sessionId, gains, preamp)
                    result.success(true)
                }
                "bypass" -> {
                    val sessionId = call.argument<Int>("sessionId") ?: return@setMethodCallHandler
                    bypassEQ(sessionId)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onDestroy() {
        usbAudioPlugin?.dispose()
        super.onDestroy()
    }

    private fun setBitPerfectAudio(enable: Boolean, result: io.flutter.plugin.common.MethodChannel.Result) {
        try {
            val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
            
            // Find USB device
            val devices = audioManager.getDevices(android.media.AudioManager.GET_DEVICES_OUTPUTS)
            val usbDevice = devices.firstOrNull { 
                it.type == android.media.AudioDeviceInfo.TYPE_USB_DEVICE || 
                it.type == android.media.AudioDeviceInfo.TYPE_USB_HEADSET 
            }

            if (usbDevice == null) {
                 // Even if no USB device is found, we permit "disabling" the mode gracefully
                if (!enable) {
                     // We can't clear attributes for a specific device if it's gone, 
                     // but generally we don't need to do anything if it's disconnected.
                     // However, better safe implementation:
                     bitPerfectModeEnabled = false
                     result.success(true)
                     return
                }
                result.error("NO_USB_DEVICE", "No USB DAC/Headset connected", null)
                return
            }

            // Common AudioAttributes for media playback
            val audioAttributes = android.media.AudioAttributes.Builder()
                .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()

            if (enable) {
                val mixerAttributes = android.media.AudioMixerAttributes.Builder(android.media.AudioFormat.Builder().build())
                    .setMixerBehavior(android.media.AudioMixerAttributes.MIXER_BEHAVIOR_BIT_PERFECT)
                    .build()
                
                // Correct signature: setPreferredMixerAttributes(AudioAttributes, AudioDeviceInfo, AudioMixerAttributes)
                audioManager.setPreferredMixerAttributes(audioAttributes, usbDevice, mixerAttributes)
                bitPerfectModeEnabled = true
            } else {
                // Correct signature: clearPreferredMixerAttributes(AudioAttributes, AudioDeviceInfo)
                audioManager.clearPreferredMixerAttributes(audioAttributes, usbDevice)
                bitPerfectModeEnabled = false
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("NATIVE_ERROR", e.message, null)
        }
    }

    private fun applyEQ(sessionId: Int, gains: List<Double>, preamp: Double) {
        try {
            var dp = dynamicsProcessingMap[sessionId]
            if (dp == null) {
                // Initialize DynamicsProcessing for this session
                // We use 10 bands.
                val channelCount = 2 // Stereo
                val setPreEq = true
                val setPostEq = false
                val setLimiter = true // Good for preventing clipping with positive gains
                
                val builder = DynamicsProcessing.Config.Builder(
                    0, // variant
                    channelCount,
                    setPreEq,
                    10, // pre-EQ bands
                    false, // mbc
                    0, // mbc bands
                    setPostEq,
                    0, // post-EQ bands
                    setLimiter
                )
                
                val config = builder.build()
                dp = DynamicsProcessing(0, sessionId, config)
                dp.enabled = true
                dynamicsProcessingMap[sessionId] = dp
                Log.d("EQ", "Initialized DynamicsProcessing for session $sessionId")
            }

            // Sync bands if needed (first time or if config changed)
            // Center frequencies for our 10 bands
            val frequencies = floatArrayOf(31f, 62f, 125f, 250f, 500f, 1000f, 2000f, 4000f, 8000f, 16000f)
            
            val eq = dp.getConfig().getPreEqByChannelIndex(0) // Get first channel to check band count
            // Note: In 0-variant, we apply same settings to all channels
            
            for (ch in 0 until 2) {
                for (i in 0 until 10) {
                    val band = dp.getPreEqBandByChannelIndex(ch, i)
                    band.isEnabled = true
                    band.cutoffFrequency = frequencies[i]
                    band.gain = gains[i].toFloat()
                    dp.setPreEqBandByChannelIndex(ch, i, band)
                }
            }
            
            // Pre-amp adjustment
            // Apply input gain to all channels
            dp.setInputGainAllChannelsTo(preamp.toFloat())
            
            dp.enabled = true

        } catch (e: Exception) {
            Log.e("EQ", "Error applying EQ: ${e.message}")
        }
    }

    private fun bypassEQ(sessionId: Int) {
        dynamicsProcessingMap[sessionId]?.let {
            it.enabled = false
            it.release()
            dynamicsProcessingMap.remove(sessionId)
            Log.d("EQ", "Bypassed and released EQ for session $sessionId")
        }
    }
}
