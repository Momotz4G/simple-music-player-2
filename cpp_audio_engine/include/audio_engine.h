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

#ifdef __cplusplus
}
#endif

#endif // AUDIO_ENGINE_H
