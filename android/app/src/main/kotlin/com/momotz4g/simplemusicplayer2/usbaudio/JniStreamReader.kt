package com.momotz4g.simplemusicplayer2.usbaudio

import android.util.Log
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.max

/**
 * A network stream reader designed to be called directly from the C++ audio engine
 * via JNI to support bit-perfect HTTP streaming in miniaudio.
 */
class JniStreamReader(private val streamUrl: String) {

    companion object {
        private const val TAG = "JniStreamReader"
    }

    private var connection: HttpURLConnection? = null
    private var inputStream: InputStream? = null
    private var currentOffset: Long = 0
    private var totalContentLength: Long = -1

    /**
     * Called by C++ to determine the total size of the file (if known).
     * Returns -1 if unknown (e.g. chunked transfer).
     */
    fun getSize(): Long {
        if (totalContentLength == -1L) {
            // Do a HEAD request to get content length if not already known
            try {
                val url = URL(streamUrl)
                val headConn = url.openConnection() as HttpURLConnection
                headConn.requestMethod = "HEAD"
                headConn.connectTimeout = 5000
                headConn.readTimeout = 5000
                if (headConn.responseCode in 200..299) {
                    val lengthHeader = headConn.getHeaderField("Content-Length")
                    if (!lengthHeader.isNullOrEmpty()) {
                        totalContentLength = lengthHeader.toLong()
                    }
                }
                headConn.disconnect()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to get content length: \${e.message}")
            }
        }
        return totalContentLength
    }

    /**
     * Called by C++ when miniaudio requests [length] bytes.
     * Returns the number of bytes actually read, or 0 on EOF, or -1 on error.
     */
    fun read(buffer: ByteArray, length: Int): Int {
        try {
            if (inputStream == null) {
                if (!openConnection(currentOffset)) {
                    return -1
                }
            }

            var bytesRead = 0
            while (bytesRead < length) {
                val readResult = inputStream!!.read(buffer, bytesRead, length - bytesRead)
                if (readResult == -1) {
                    break // EOF
                }
                bytesRead += readResult
            }

            currentOffset += bytesRead
            return bytesRead
        } catch (e: Exception) {
            Log.e(TAG, "Error reading from stream at offset \$currentOffset: \${e.message}")
            closeConnection() // Force reconnect on next read
            return -1
        }
    }

    /**
     * Called by C++ when miniaudio needs to seek to a specific byte offset.
     * Returns true if successful, false otherwise.
     */
    fun seek(offset: Long): Boolean {
        if (offset == currentOffset) return true

        // For small forward seeks (e.g. skipping ID3 tags), we can just skip bytes
        if (offset > currentOffset && (offset - currentOffset) < 65536 && inputStream != null) {
            try {
                var bytesToSkip = offset - currentOffset
                while (bytesToSkip > 0) {
                    val skipped = inputStream!!.skip(bytesToSkip)
                    if (skipped <= 0) break
                    bytesToSkip -= skipped
                }
                currentOffset = offset - bytesToSkip
                if (currentOffset == offset) {
                    return true
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error skipping bytes: \${e.message}")
            }
        }

        // For large seeks or backward seeks, close and re-open with Range header
        closeConnection()
        return openConnection(offset)
    }

    private fun openConnection(offset: Long): Boolean {
        try {
            val url = URL(streamUrl)
            connection = url.openConnection() as HttpURLConnection
            connection!!.connectTimeout = 10000
            connection!!.readTimeout = 10000

            // If seeking, request a specific byte range
            if (offset > 0) {
                connection!!.setRequestProperty("Range", "bytes=\$offset-")
            }

            val responseCode = connection!!.responseCode
            if (responseCode !in 200..299) {
                Log.e(TAG, "Failed to open connection. HTTP \$responseCode")
                closeConnection()
                return false
            }

            // Update content length if we didn't have it
            if (totalContentLength == -1L && responseCode == 200) {
                val lengthHeader = connection!!.getHeaderField("Content-Length")
                if (!lengthHeader.isNullOrEmpty()) {
                    totalContentLength = lengthHeader.toLong()
                }
            }

            inputStream = connection!!.inputStream
            currentOffset = offset
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error opening connection: \${e.message}")
            closeConnection()
            return false
        }
    }

    fun closeConnection() {
        try {
            inputStream?.close()
        } catch (e: Exception) {
            // Ignored
        }
        inputStream = null

        try {
            connection?.disconnect()
        } catch (e: Exception) {
            // Ignored
        }
        connection = null
    }
}
