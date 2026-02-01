package com.momotz4g.simplemusicplayer2

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import com.momotz4g.simplemusicplayer2.usbaudio.UsbAudioPlugin

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.momotz4g.simplemusicplayer2/audio_settings"
    private var bitPerfectModeEnabled = false
    private var usbAudioPlugin: UsbAudioPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(YoutubeDLPlugin())
        
        // Register USB Audio Plugin for Android < 14 bit-perfect support
        usbAudioPlugin = UsbAudioPlugin(this).also {
            it.register(flutterEngine)
        }

        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setBitPerfectMode") {
                val enable = call.argument<Boolean>("enable") ?: false
                if (android.os.Build.VERSION.SDK_INT >= 34) { // Android 14 (Upside Down Cake)
                    setBitPerfectAudio(enable, result)
                } else {
                    result.error("UNSUPPORTED_VERSION", "Android 14+ required for bit-perfect audio", null)
                }
            } else {
                result.notImplemented()
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
}
