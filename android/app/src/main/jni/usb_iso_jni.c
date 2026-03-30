/**
 * usb_iso_jni.c - Native JNI layer for isochronous USB audio transfers.
 *
 * Android's Java/Kotlin USB Host API does NOT expose isochronous transfers.
 * To achieve bit-perfect audio output to USB DACs on Android < 14,
 * we must use Linux usbdevfs IOCTLs directly:
 *   - USBDEVFS_SUBMITURB  (submit isochronous URB)
 *   - USBDEVFS_REAPURB    (harvest completed URB)
 *   - USBDEVFS_DISCARDURB (cancel pending URB)
 *   - USBDEVFS_SETINTERFACE (set alternate setting for audio format)
 *
 * The file descriptor is obtained from UsbDeviceConnection.getFileDescriptor().
 *
 * Reference: Linux kernel - include/uapi/linux/usbdevice_fs.h
 */

#include <jni.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <linux/usbdevice_fs.h>
#include <android/log.h>

#define TAG "UsbIsoJni"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, TAG, __VA_ARGS__)

/**
 * Maximum number of isochronous packets per URB.
 * USB Audio Class typically uses 1ms frames. For high-speed devices,
 * this translates to 8 microframes per frame (125µs each).
 */
#define MAX_ISO_PACKETS 8

/**
 * Number of URBs for double-buffering.
 * While one URB is being transferred, we prepare the next one.
 */
#define NUM_URBS 3

/**
 * URB context structure - tracks state for each in-flight URB
 */
typedef struct {
    struct usbdevfs_urb urb;
    struct usbdevfs_iso_packet_desc iso_packets[MAX_ISO_PACKETS];
    unsigned char *buffer;
    int buffer_size;
    int in_use;
} urb_context_t;

/**
 * Transfer context - manages the overall transfer session
 */
typedef struct {
    int fd;                          // USB device file descriptor
    int endpoint_addr;               // Endpoint address (e.g., 0x01 for OUT)
    int max_packet_size;             // Maximum bytes per isochronous packet
    int num_packets;                 // Number of packets per URB
    int packet_size;                 // Actual bytes per packet for current format
    urb_context_t urbs[NUM_URBS];    // URB pool
    int running;                     // Transfer active flag
} transfer_context_t;

// Global transfer context (one active transfer at a time)
static transfer_context_t *g_ctx = NULL;

/**
 * Allocate and initialize the transfer context
 */
static transfer_context_t* create_context(int fd, int endpoint_addr,
                                           int max_packet_size, int num_packets,
                                           int packet_size) {
    transfer_context_t *ctx = (transfer_context_t*)calloc(1, sizeof(transfer_context_t));
    if (!ctx) {
        LOGE("Failed to allocate transfer context");
        return NULL;
    }

    ctx->fd = fd;
    ctx->endpoint_addr = endpoint_addr;
    ctx->max_packet_size = max_packet_size;
    ctx->num_packets = num_packets < MAX_ISO_PACKETS ? num_packets : MAX_ISO_PACKETS;
    ctx->packet_size = packet_size < max_packet_size ? packet_size : max_packet_size;
    ctx->running = 0;

    // Allocate buffers for each URB
    int urb_buffer_size = ctx->packet_size * ctx->num_packets;
    for (int i = 0; i < NUM_URBS; i++) {
        ctx->urbs[i].buffer = (unsigned char*)calloc(1, urb_buffer_size);
        if (!ctx->urbs[i].buffer) {
            LOGE("Failed to allocate URB buffer %d", i);
            // Cleanup already allocated
            for (int j = 0; j < i; j++) {
                free(ctx->urbs[j].buffer);
            }
            free(ctx);
            return NULL;
        }
        ctx->urbs[i].buffer_size = urb_buffer_size;
        ctx->urbs[i].in_use = 0;
    }

    return ctx;
}

/**
 * Free the transfer context and all associated buffers
 */
static void destroy_context(transfer_context_t *ctx) {
    if (!ctx) return;

    for (int i = 0; i < NUM_URBS; i++) {
        if (ctx->urbs[i].buffer) {
            free(ctx->urbs[i].buffer);
            ctx->urbs[i].buffer = NULL;
        }
    }
    free(ctx);
}

/**
 * Submit an isochronous URB to the USB device
 */
static int submit_urb(transfer_context_t *ctx, int urb_index) {
    if (urb_index < 0 || urb_index >= NUM_URBS) return -1;

    urb_context_t *uc = &ctx->urbs[urb_index];

    // Zero out the URB structure
    memset(&uc->urb, 0, sizeof(struct usbdevfs_urb));

    // Configure the URB for isochronous transfer
    uc->urb.type = USBDEVFS_URB_TYPE_ISO;
    uc->urb.endpoint = ctx->endpoint_addr;
    uc->urb.buffer = uc->buffer;
    uc->urb.buffer_length = ctx->packet_size * ctx->num_packets;
    uc->urb.number_of_packets = ctx->num_packets;

    // USBDEVFS_URB_ISO_ASAP: let the kernel schedule the transfer ASAP
    // This is important for maintaining timing without manual scheduling
    uc->urb.flags = USBDEVFS_URB_ISO_ASAP;

    // Set up individual packet descriptors
    for (int i = 0; i < ctx->num_packets; i++) {
        uc->urb.iso_frame_desc[i].length = ctx->packet_size;
    }

    // Submit the URB
    int ret = ioctl(ctx->fd, USBDEVFS_SUBMITURB, &uc->urb);
    if (ret < 0) {
        LOGE("USBDEVFS_SUBMITURB failed for URB %d: %s (errno=%d)",
             urb_index, strerror(errno), errno);
        uc->in_use = 0;
        return -errno;
    }

    uc->in_use = 1;
    return 0;
}

/**
 * Reap (wait for) a completed URB
 * Returns the URB index that was completed, or -1 on error
 */
static int reap_urb(transfer_context_t *ctx) {
    struct usbdevfs_urb *urb = NULL;

    int ret = ioctl(ctx->fd, USBDEVFS_REAPURB, &urb);
    if (ret < 0) {
        if (errno != EAGAIN && errno != EINTR) {
            LOGE("USBDEVFS_REAPURB failed: %s (errno=%d)", strerror(errno), errno);
        }
        return -errno;
    }

    if (!urb) return -1;

    // Find which URB context this belongs to
    for (int i = 0; i < NUM_URBS; i++) {
        if (&ctx->urbs[i].urb == urb) {
            ctx->urbs[i].in_use = 0;

            // Check for transfer errors in individual packets
            if (urb->status != 0) {
                LOGW("URB %d completed with status: %d", i, urb->status);
            }

            return i;
        }
    }

    LOGE("Reaped unknown URB");
    return -1;
}

/**
 * Discard all pending URBs
 */
static void discard_all_urbs(transfer_context_t *ctx) {
    for (int i = 0; i < NUM_URBS; i++) {
        if (ctx->urbs[i].in_use) {
            int ret = ioctl(ctx->fd, USBDEVFS_DISCARDURB, &ctx->urbs[i].urb);
            if (ret < 0 && errno != EINVAL) {
                LOGW("USBDEVFS_DISCARDURB failed for URB %d: %s", i, strerror(errno));
            }
            // Reap the discarded URB to clean up
            struct usbdevfs_urb *urb = NULL;
            ioctl(ctx->fd, USBDEVFS_REAPURB, &urb);
            ctx->urbs[i].in_use = 0;
        }
    }
}

// ==================== JNI Methods ====================

/**
 * Initialize the isochronous transfer context.
 *
 * @param fd              File descriptor from UsbDeviceConnection.getFileDescriptor()
 * @param endpointAddr    USB endpoint address (e.g., 0x01 for first OUT endpoint)
 * @param maxPacketSize   Maximum packet size from the endpoint descriptor
 * @param numPackets      Number of isochronous packets per URB (typically 1-8)
 * @param packetSize      Actual data size per packet for current audio format
 * @return true if initialization succeeded
 */
JNIEXPORT jboolean JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeInit(
    JNIEnv *env, jobject thiz,
    jint fd, jint endpointAddr, jint maxPacketSize, jint numPackets, jint packetSize) {

    LOGI("nativeInit: fd=%d, ep=0x%02x, maxPkt=%d, numPkt=%d, pktSize=%d",
         fd, endpointAddr, maxPacketSize, numPackets, packetSize);

    // Cleanup existing context if any
    if (g_ctx) {
        discard_all_urbs(g_ctx);
        destroy_context(g_ctx);
        g_ctx = NULL;
    }

    g_ctx = create_context(fd, endpointAddr, maxPacketSize, numPackets, packetSize);
    if (!g_ctx) {
        LOGE("Failed to create transfer context");
        return JNI_FALSE;
    }

    return JNI_TRUE;
}

/**
 * Submit a URB filled with audio data.
 *
 * @param urbIndex  Index of the URB to submit (0 to NUM_URBS-1)
 * @param data      Audio data to send
 * @param length    Number of bytes of audio data
 * @return 0 on success, negative errno on failure
 */
JNIEXPORT jint JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeSubmitUrb(
    JNIEnv *env, jobject thiz,
    jint urbIndex, jbyteArray data, jint length) {

    if (!g_ctx) return -EINVAL;
    if (urbIndex < 0 || urbIndex >= NUM_URBS) return -EINVAL;

    urb_context_t *uc = &g_ctx->urbs[urbIndex];

    // Copy audio data from Java array into URB buffer
    int copy_len = length < uc->buffer_size ? length : uc->buffer_size;
    jbyte *dataPtr = (*env)->GetByteArrayElements(env, data, NULL);
    if (!dataPtr) return -ENOMEM;

    memcpy(uc->buffer, dataPtr, copy_len);

    // Zero-fill remaining buffer if data is shorter
    if (copy_len < uc->buffer_size) {
        memset(uc->buffer + copy_len, 0, uc->buffer_size - copy_len);
    }

    (*env)->ReleaseByteArrayElements(env, data, dataPtr, JNI_ABORT);

    return submit_urb(g_ctx, urbIndex);
}

/**
 * Submit a URB from a direct ByteBuffer (zero-copy).
 *
 * @param urbIndex  Index of the URB to submit
 * @param buffer    Direct ByteBuffer containing audio data
 * @param offset    Offset into the buffer
 * @param length    Number of bytes to send
 * @return 0 on success, negative errno on failure
 */
JNIEXPORT jint JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeSubmitUrbDirect(
    JNIEnv *env, jobject thiz,
    jint urbIndex, jobject buffer, jint offset, jint length) {

    if (!g_ctx) return -EINVAL;
    if (urbIndex < 0 || urbIndex >= NUM_URBS) return -EINVAL;

    urb_context_t *uc = &g_ctx->urbs[urbIndex];

    // Get direct buffer address
    unsigned char *bufAddr = (unsigned char*)(*env)->GetDirectBufferAddress(env, buffer);
    if (!bufAddr) {
        LOGE("Failed to get direct buffer address");
        return -EINVAL;
    }

    int copy_len = length < uc->buffer_size ? length : uc->buffer_size;
    memcpy(uc->buffer, bufAddr + offset, copy_len);

    if (copy_len < uc->buffer_size) {
        memset(uc->buffer + copy_len, 0, uc->buffer_size - copy_len);
    }

    return submit_urb(g_ctx, urbIndex);
}

/**
 * Wait for and reap a completed URB.
 *
 * @return URB index that completed (0 to NUM_URBS-1), or negative errno on error
 */
JNIEXPORT jint JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeReapUrb(
    JNIEnv *env, jobject thiz) {

    if (!g_ctx) return -EINVAL;
    return reap_urb(g_ctx);
}

/**
 * Cancel all pending URBs and stop transfers.
 */
JNIEXPORT void JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeCancelAll(
    JNIEnv *env, jobject thiz) {

    if (!g_ctx) return;
    discard_all_urbs(g_ctx);
}

/**
 * Set alternate interface setting for selecting audio format.
 *
 * @param fd                  USB device file descriptor
 * @param interfaceNumber     USB interface number
 * @param alternateSetting    Alternate setting index
 * @return 0 on success, negative errno on failure
 */
JNIEXPORT jint JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeSetInterface(
    JNIEnv *env, jobject thiz,
    jint fd, jint interfaceNumber, jint alternateSetting) {

    LOGI("nativeSetInterface: fd=%d, iface=%d, alt=%d", fd, interfaceNumber, alternateSetting);

    struct usbdevfs_setinterface si;
    si.interface = interfaceNumber;
    si.altsetting = alternateSetting;

    int ret = ioctl(fd, USBDEVFS_SETINTERFACE, &si);
    if (ret < 0) {
        LOGE("USBDEVFS_SETINTERFACE failed: %s (errno=%d)", strerror(errno), errno);
        return -errno;
    }

    return 0;
}

/**
 * Claim a USB interface.
 *
 * @param fd               USB device file descriptor
 * @param interfaceNumber  Interface number to claim
 * @return 0 on success, negative errno on failure
 */
JNIEXPORT jint JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeClaimInterface(
    JNIEnv *env, jobject thiz,
    jint fd, jint interfaceNumber) {

    LOGI("nativeClaimInterface: fd=%d, iface=%d", fd, interfaceNumber);

    int ret = ioctl(fd, USBDEVFS_CLAIMINTERFACE, &interfaceNumber);
    if (ret < 0) {
        LOGE("USBDEVFS_CLAIMINTERFACE failed: %s (errno=%d)", strerror(errno), errno);
        return -errno;
    }

    return 0;
}

/**
 * Release a USB interface.
 *
 * @param fd               USB device file descriptor
 * @param interfaceNumber  Interface number to release
 * @return 0 on success, negative errno on failure
 */
JNIEXPORT jint JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeReleaseInterface(
    JNIEnv *env, jobject thiz,
    jint fd, jint interfaceNumber) {

    int ret = ioctl(fd, USBDEVFS_RELEASEINTERFACE, &interfaceNumber);
    if (ret < 0) {
        LOGE("USBDEVFS_RELEASEINTERFACE failed: %s (errno=%d)", strerror(errno), errno);
        return -errno;
    }

    return 0;
}

/**
 * Get the number of available URB slots.
 */
JNIEXPORT jint JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeGetNumUrbs(
    JNIEnv *env, jobject thiz) {
    return NUM_URBS;
}

/**
 * Get the buffer size for each URB.
 */
JNIEXPORT jint JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeGetUrbBufferSize(
    JNIEnv *env, jobject thiz) {
    if (!g_ctx) return 0;
    return g_ctx->urbs[0].buffer_size;
}

/**
 * Clean up and release all native resources.
 */
JNIEXPORT void JNICALL
Java_com_momotz4g_simplemusicplayer2_usbaudio_UsbIsoJni_nativeDispose(
    JNIEnv *env, jobject thiz) {

    LOGI("nativeDispose");

    if (g_ctx) {
        discard_all_urbs(g_ctx);
        destroy_context(g_ctx);
        g_ctx = NULL;
    }
}
