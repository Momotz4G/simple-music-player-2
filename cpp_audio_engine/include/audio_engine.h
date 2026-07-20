#ifndef AUDIO_ENGINE_H
#define AUDIO_ENGINE_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// We need to export these symbols so Dart FFI can find them
#ifdef _WIN32
    #define ENGINE_API __declspec(dllexport)
#else
    #define ENGINE_API __attribute__((visibility("default")))
#endif

typedef void* AudioHandle;

ENGINE_API AudioHandle Engine_Create(void);
ENGINE_API void Engine_SetOutputDevice(AudioHandle handle, const char* deviceId);
ENGINE_API void Engine_Dispose(AudioHandle handle);
ENGINE_API void Engine_ReleaseDevice(AudioHandle handle);
ENGINE_API bool Engine_PlayFile(AudioHandle handle, const char* filepath, bool bit_perfect);
ENGINE_API void Engine_Play(AudioHandle handle);
ENGINE_API void Engine_Pause(AudioHandle handle);
ENGINE_API void Engine_Stop(AudioHandle handle);
ENGINE_API void Engine_SetVolume(AudioHandle handle, float volume);
ENGINE_API void Engine_SetEQBand(AudioHandle handle, int band_index, float frequency, float gain, float q_factor);
ENGINE_API float Engine_GetPosition(AudioHandle handle);
ENGINE_API void Engine_SetPosition(AudioHandle handle, float position_seconds);
ENGINE_API float Engine_GetDuration(AudioHandle handle);
ENGINE_API bool Engine_IsPlaying(AudioHandle handle);
ENGINE_API bool Engine_IsCompleted(AudioHandle handle);

// ============================================================================
// Raw output sink API (used on Android; available on all platforms).
//
// Whereas Engine_PlayFile owns a ma_device that pulls audio via callback,
// the raw-sink API lets the caller drive decoding by pulling PCM frames on
// demand. This is required for Android USB DAC bypass where the output
// destination is the isochronous USB transfer pipeline (UsbIsoTransfer)
// rather than a system audio device.
//
// Lifecycle:
//   1. Engine_Create()
//   2. Engine_PrepareRawSink(handle, path, sample_rate, channels, bit_depth, bit_perfect)
//   3. Loop: Engine_ReadRawFrames(handle, buffer, frames)
//   4. Engine_ReleaseRawSink(handle) when done
//   5. Engine_Dispose(handle)
//
// Engine_PrepareRawSink and Engine_PlayFile are mutually exclusive on the
// same handle: starting one tears down the other.
//
// Implementation note: stubs land in audio_engine.c during Phase 3 of the
// usb-dac-bypass-android spec. Declarations exist now so callers in Kotlin
// can compile against the header without source dependency on the impl.
// ============================================================================

/**
 * Initialize a decoder for the given file with the requested target format.
 * No ma_device is opened.
 *
 * @param handle           Engine handle returned by Engine_Create.
 * @param filepath         UTF-8 path to the audio file.
 * @param sample_rate_hint Desired output sample rate (e.g. 44100, 48000, 96000).
 *                         Pass 0 to use the file's native rate.
 * @param channels_hint    Desired output channel count. Pass 0 for native.
 * @param bit_depth_hint   16, 24, or 32. Pass 0 for native (engine picks
 *                         f32 in non-bitperfect mode, native in bitperfect).
 * @param bit_perfect      If true, EQ is bypassed, only volume is applied.
 * @return true on success.
 */
ENGINE_API bool Engine_PrepareRawSink(AudioHandle handle, const char* filepath,
                                      int sample_rate_hint,
                                      int channels_hint,
                                      int bit_depth_hint,
                                      bool bit_perfect);

typedef size_t (*EngineReadCallback)(void* user_data, void* buffer, size_t size);
typedef bool (*EngineSeekCallback)(void* user_data, long long offset);
typedef long long (*EngineGetSizeCallback)(void* user_data);

ENGINE_API bool Engine_PrepareRawSinkCustom(AudioHandle handle,
                                            EngineReadCallback on_read,
                                            EngineSeekCallback on_seek,
                                            EngineGetSizeCallback on_get_size,
                                            void* user_data,
                                            int sample_rate_hint,
                                            int channels_hint,
                                            int bit_depth_hint,
                                            bool bit_perfect);

ENGINE_API void* Engine_GetRawSinkUserData(AudioHandle handle);

/**
 * Decode and apply DSP, writing interleaved PCM frames to output_buffer.
 *
 * @param output_buffer Caller-allocated buffer at least
 *                      frame_count * channels * bytes_per_sample bytes.
 * @param frame_count   Number of frames the buffer can hold.
 * @return Number of frames written. Negative value on EOF or error.
 */
ENGINE_API long long Engine_ReadRawFrames(AudioHandle handle,
                                          void* output_buffer,
                                          unsigned int frame_count);

/**
 * Query the negotiated output format. All out pointers may be NULL.
 *
 * @return 0 on success, negative on error.
 */
ENGINE_API int Engine_GetRawFormat(AudioHandle handle,
                                   int* out_sample_rate,
                                   int* out_channels,
                                   int* out_bit_depth);

/**
 * Tear down the raw-sink decoder. Safe to call repeatedly. Does not free
 * the engine handle (use Engine_Dispose for that).
 */
ENGINE_API void Engine_ReleaseRawSink(AudioHandle handle);

#ifdef __cplusplus
}
#endif

#endif // AUDIO_ENGINE_H
