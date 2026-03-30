#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
#include "audio_engine.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#include <windows.h>
#endif

typedef struct {
    ma_decoder decoder;
    ma_device device;
    ma_biquad eq_bands[10];
    bool is_initialized;
    bool is_playing;
    bool is_completed;
    bool has_device;  // true after a file has been successfully loaded
    float volume;
    ma_mutex eq_lock;
} AudioEngine;

static void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    AudioEngine* pEngine = (AudioEngine*)pDevice->pUserData;
    if (pEngine == NULL || !pEngine->is_playing) return;

    ma_uint64 framesRead;
    ma_result result = ma_decoder_read_pcm_frames(&pEngine->decoder, pOutput, frameCount, &framesRead);
    
    if (result == MA_AT_END || framesRead == 0) {
        pEngine->is_completed = true;
        pEngine->is_playing = false;
        return;
    }

    // Apply EQ (10-band peaking filters in series)
    ma_mutex_lock(&pEngine->eq_lock);
    for (int i = 0; i < 10; ++i) {
        ma_biquad_process_pcm_frames(&pEngine->eq_bands[i], pOutput, pOutput, framesRead);
    }
    ma_mutex_unlock(&pEngine->eq_lock);
    
    // Apply Volume
    float* pOutputF32 = (float*)pOutput;
    for (ma_uint64 i = 0; i < framesRead * pDevice->playback.channels; ++i) {
        pOutputF32[i] *= pEngine->volume;
    }

    (void)pInput;
}

ENGINE_API AudioHandle Engine_Create(void) {
    AudioEngine* pEngine = (AudioEngine*)calloc(1, sizeof(AudioEngine));
    if (pEngine == NULL) return NULL;
    
    pEngine->volume = 1.0f;
    pEngine->is_initialized = true;
    pEngine->has_device = false;
    ma_mutex_init(&pEngine->eq_lock);
    return (AudioHandle)pEngine;
}

ENGINE_API void Engine_Dispose(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return;
    
    if (pEngine->has_device) {
        ma_device_uninit(&pEngine->device);
        ma_decoder_uninit(&pEngine->decoder);
    }
    
    ma_mutex_uninit(&pEngine->eq_lock);
    free(pEngine);
}

ENGINE_API bool Engine_PlayFile(AudioHandle handle, const char* filepath) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return false;

    // Stop and uninit previous if exists
    if (pEngine->has_device) {
        ma_device_uninit(&pEngine->device);
        ma_decoder_uninit(&pEngine->decoder);
        pEngine->is_playing = false;
        pEngine->has_device = false;
    }

    ma_decoder_config decoderConfig = ma_decoder_config_init(ma_format_f32, 0, 0);
    ma_result result;

#ifdef _WIN32
    // Convert UTF-8 path to wide chars for proper Unicode support on Windows
    int wlen = MultiByteToWideChar(CP_UTF8, 0, filepath, -1, NULL, 0);
    if (wlen <= 0) return false;
    wchar_t* wpath = (wchar_t*)malloc(wlen * sizeof(wchar_t));
    if (wpath == NULL) return false;
    MultiByteToWideChar(CP_UTF8, 0, filepath, -1, wpath, wlen);
    result = ma_decoder_init_file_w(wpath, &decoderConfig, &pEngine->decoder);
    free(wpath);
#else
    result = ma_decoder_init_file(filepath, &decoderConfig, &pEngine->decoder);
#endif

    if (result != MA_SUCCESS) return false;
    ma_decoder_seek_to_pcm_frame(&pEngine->decoder, 0);

    ma_device_config deviceConfig = ma_device_config_init(ma_device_type_playback);
    deviceConfig.playback.format   = ma_format_f32;
    deviceConfig.playback.channels = pEngine->decoder.outputChannels;
    deviceConfig.sampleRate        = pEngine->decoder.outputSampleRate;
    deviceConfig.dataCallback      = data_callback;
    deviceConfig.pUserData         = pEngine;

    if (ma_device_init(NULL, &deviceConfig, &pEngine->device) != MA_SUCCESS) {
        ma_decoder_uninit(&pEngine->decoder);
        return false;
    }

    // Initialize EQ bands (default to flat)
    ma_mutex_lock(&pEngine->eq_lock);
    for (int i = 0; i < 10; ++i) {
        ma_biquad_config config = ma_biquad_config_init(ma_format_f32, pEngine->device.playback.channels, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
        config.format = ma_format_f32;
        ma_biquad_init(&config, NULL, &pEngine->eq_bands[i]);
    }
    ma_mutex_unlock(&pEngine->eq_lock);

    pEngine->has_device = true;
    pEngine->is_playing = false;
    pEngine->is_completed = false;
    return true;
}

static void reinit_band(AudioEngine* pEngine, int index, float freq, float gain, float q) {
    if (pEngine == NULL || !pEngine->has_device) return;
    
    double sr = (double)pEngine->device.sampleRate;
    double f0 = (double)freq;
    
    // Safety: Frequency must be less than Nyquist frequency (sr/2)
    // If freq is too high for current sample rate, we just cap it or bypass
    if (f0 >= sr * 0.49) {
        f0 = sr * 0.49;
    }
    
    double A = pow(10.0, (double)gain / 40.0);
    double w0 = 2.0 * 3.14159265358979323846 * f0 / sr;
    double alpha = sin(w0) / (2.0 * (double)q);
    
    double b0 = 1.0 + alpha * A;
    double b1 = -2.0 * cos(w0);
    double b2 = 1.0 - alpha * A;
    double a0 = 1.0 + alpha / A;
    double a1 = -2.0 * cos(w0);
    double a2 = 1.0 - alpha / A;
    
    // Safety: Avoid division by zero and extreme values
    if (fabs(a0) < 0.000001) a0 = 1.0;
    
    float fb0 = (float)(b0/a0);
    float fb1 = (float)(b1/a0);
    float fb2 = (float)(b2/a0);
    float fa1 = (float)(a1/a0);
    float fa2 = (float)(a2/a0);

    // Final safety check for NaN/Inf
    if (!isfinite(fb0) || !isfinite(fb1) || !isfinite(fb2) || !isfinite(fa1) || !isfinite(fa2)) {
        fb0 = 1.0f; fb1 = 0.0f; fb2 = 0.0f; fa1 = 0.0f; fa2 = 0.0f; // Bypass
    }
    
    ma_biquad_config config = ma_biquad_config_init(
        ma_format_f32,
        pEngine->device.playback.channels,
        fb0, fb1, fb2,
        1.0f, fa1, fa2
    );
    config.format = ma_format_f32;
    
    ma_mutex_lock(&pEngine->eq_lock);
    ma_biquad_init(&config, NULL, &pEngine->eq_bands[index]);
    ma_mutex_unlock(&pEngine->eq_lock);
}

ENGINE_API void Engine_SetEQBand(AudioHandle handle, int band_index, float frequency, float gain, float q_factor) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL || band_index < 0 || band_index >= 10) return;
    reinit_band(pEngine, band_index, frequency, gain, q_factor);
}

ENGINE_API void Engine_Play(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine != NULL && pEngine->has_device && !pEngine->is_playing) {
        ma_device_start(&pEngine->device);
        pEngine->is_playing = true;
    }
}

ENGINE_API void Engine_Pause(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine != NULL && pEngine->has_device && pEngine->is_playing) {
        ma_device_stop(&pEngine->device);
        pEngine->is_playing = false;
    }
}

ENGINE_API void Engine_Stop(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine != NULL && pEngine->has_device) {
        ma_device_stop(&pEngine->device);
        ma_decoder_seek_to_pcm_frame(&pEngine->decoder, 0);
        pEngine->is_playing = false;
    }
}

ENGINE_API void Engine_SetVolume(AudioHandle handle, float volume) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine != NULL) {
        pEngine->volume = volume;
    }
}

ENGINE_API float Engine_GetPosition(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return 0.0f;
    ma_uint64 pos;
    ma_decoder_get_cursor_in_pcm_frames(&pEngine->decoder, &pos);
    return (float)pos / (float)pEngine->decoder.outputSampleRate;
}

ENGINE_API void Engine_SetPosition(AudioHandle handle, float position_seconds) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine != NULL) {
        ma_decoder_seek_to_pcm_frame(&pEngine->decoder, (ma_uint64)(position_seconds * pEngine->decoder.outputSampleRate));
    }
}

ENGINE_API float Engine_GetDuration(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return 0.0f;
    ma_uint64 len;
    ma_decoder_get_length_in_pcm_frames(&pEngine->decoder, &len);
    return (float)len / (float)pEngine->decoder.outputSampleRate;
}

ENGINE_API bool Engine_IsPlaying(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    return pEngine != NULL && pEngine->is_playing;
}

ENGINE_API bool Engine_IsCompleted(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    return pEngine != NULL && pEngine->is_completed;
}
