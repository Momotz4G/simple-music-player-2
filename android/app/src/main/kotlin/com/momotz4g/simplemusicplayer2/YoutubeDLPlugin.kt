package com.momotz4g.simplemusicplayer2

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.ffmpeg.FFmpeg
import java.io.File

class YoutubeDLPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val scope = CoroutineScope(Dispatchers.IO)
    private val TAG = "YtDlpPlugin"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.momotz4g.simplemusicplayer2/ytdlp")
        channel.setMethodCallHandler(this)
        Log.d(TAG, "Attached to Engine")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "Method Call: ${call.method}")
        when (call.method) {
            "initialize" -> initialize(result)
            "getAudioUrl" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    getAudioUrl(url, result)
                } else {
                    result.error("INVALID_ARGUMENT", "URL is missing", null)
                }
            }
            "download" -> {
                val url = call.argument<String>("url")
                val filePath = call.argument<String>("filePath")
                if (url != null && filePath != null) {
                    downloadVideo(url, filePath, result)
                } else {
                    result.error("INVALID_ARGUMENT", "URL or filePath is missing", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun initialize(result: Result) {
        scope.launch {
            try {
                Log.d(TAG, "Initializing libraries...")
                withContext(Dispatchers.Main) {
                    YoutubeDL.getInstance().init(context)
                    FFmpeg.getInstance().init(context)
                }
                Log.d(TAG, "Initialization Success")
                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Init Failed: $e")
                withContext(Dispatchers.Main) {
                    result.error("INIT_ERROR", e.message, null)
                }
            }
        }
    }

    private fun getAudioUrl(url: String, result: Result) {
        scope.launch {
            try {
                Log.d(TAG, "Getting URL for: $url")
                val request = YoutubeDLRequest(url)
                request.addOption("-f", "bestaudio/best")
                request.addOption("--get-url") 
                request.addOption("-v")
                
                val info = YoutubeDL.getInstance().getInfo(request)
                Log.d(TAG, "URL Found: ${info.url}")
                withContext(Dispatchers.Main) {
                    result.success(info.url)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Get URL Failed: $e")
                withContext(Dispatchers.Main) {
                    result.error("YTDLP_ERROR", e.message, null)
                }
            }
        }
    }

    private fun downloadVideo(url: String, filePath: String, result: Result) {
        scope.launch {
            try {
                Log.d(TAG, "Starting Download: $url to $filePath")
                val file = File(filePath)
                val dir = file.parentFile
                if (dir != null && !dir.exists()) {
                    dir.mkdirs()
                }

                val request = YoutubeDLRequest(url)
                request.addOption("-o", filePath)
                request.addOption("-f", "bestaudio[ext=m4a]/bestaudio/best")
                request.addOption("--no-mtime")
                request.addOption("-v")
                
                Log.d(TAG, "Executing yt-dlp...")
                YoutubeDL.getInstance().execute(request) { progress, etaInSeconds, line ->
                    Log.d(TAG, "Progress: $progress% (ETA: $etaInSeconds) - $line")
                }

                Log.d(TAG, "Download Finished Success")
                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Download Error: $e")
                withContext(Dispatchers.Main) {
                    result.error("DOWNLOAD_ERROR", e.message, null)
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
