#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
#include "audio_engine.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#include "mf_decoder.h"
#endif

#ifdef _WIN32
#include <windows.h>
#endif

// WMF custom backend table — used by both decoder init calls
#ifdef _WIN32
static ma_decoding_backend_vtable* g_pCustomBackends[] = { &g_ma_vtable_wmf };
#endif

// We define a buffer for the absolute path in Documents.
static char ENGINE_LOG_PATH[512] = "engine_log.txt";

typedef struct {
    ma_decoder decoder;
    ma_device device;
    ma_context context;    // Explicit WASAPI-only context for exclusive mode
    ma_biquad eq_bands[10];
    bool is_initialized;
    bool is_playing;
    bool is_completed;
    bool has_device;      // true after a file has been successfully loaded
    bool has_context;     // true if context was explicitly initialized
    bool bit_perfect;     // true = bypass all DSP, use native format for WASAPI exclusive
    float volume;
    char custom_device_id[256]; // Store explicit Windows MMDevice string
    ma_mutex engine_lock;
} AudioEngine;

static void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    AudioEngine* pEngine = (AudioEngine*)pDevice->pUserData;
    if (pEngine == NULL || !pEngine->is_playing) return;

    ma_mutex_lock(&pEngine->engine_lock);
    ma_uint64 framesRead;
    ma_result result = ma_decoder_read_pcm_frames(&pEngine->decoder, pOutput, frameCount, &framesRead);
    
    if (result == MA_AT_END || framesRead == 0) {
        pEngine->is_completed = true;
        pEngine->is_playing = false;
        ma_mutex_unlock(&pEngine->engine_lock);
        return;
    }

    // Bit-perfect mode: skip EQ, but apply volume scaling on the negotiated format
    // EQ is bypassed for signal purity; volume control is retained for usability.
    if (pEngine->bit_perfect) {
        if (pEngine->volume < 0.999f) {
            double vol = (double)pEngine->volume;
            if (pDevice->playback.format == ma_format_s16) {
                ma_int16* pOutputS16 = (ma_int16*)pOutput;
                for (ma_uint64 i = 0; i < framesRead * pDevice->playback.channels; ++i) {
                    double sample = (double)pOutputS16[i] * vol;
                    if (sample > 32767.0) sample = 32767.0;
                    if (sample < -32768.0) sample = -32768.0;
                    pOutputS16[i] = (ma_int16)sample;
                }
            } else if (pDevice->playback.format == ma_format_s24) {
                // Miniaudio represents s24 as exactly 3 bytes per sample packed.
                ma_uint8* pOutputS24 = (ma_uint8*)pOutput;
                for (ma_uint64 i = 0; i < framesRead * pDevice->playback.channels; ++i) {
                    // Reconstruct 24-bit signed integer (little endian)
                    ma_int32 sampleS24 = (pOutputS24[i*3] | (pOutputS24[i*3+1] << 8) | (pOutputS24[i*3+2] << 16));
                    // Sign extend from 24-bit to 32-bit for math
                    if (sampleS24 & 0x00800000) sampleS24 |= 0xFF000000;
                    
                    double sample = (double)sampleS24 * vol;
                    if (sample > 8388607.0) sample = 8388607.0;
                    if (sample < -8388608.0) sample = -8388608.0;
                    
                    ma_int32 sVolS24 = (ma_int32)sample;
                    pOutputS24[i*3]   = (ma_uint8)(sVolS24 & 0xFF);
                    pOutputS24[i*3+1] = (ma_uint8)((sVolS24 >> 8) & 0xFF);
                    pOutputS24[i*3+2] = (ma_uint8)((sVolS24 >> 16) & 0xFF);
                }
            } else if (pDevice->playback.format == ma_format_s32) {
                ma_int32* pOutputS32 = (ma_int32*)pOutput;
                for (ma_uint64 i = 0; i < framesRead * pDevice->playback.channels; ++i) {
                    double sample = (double)pOutputS32[i] * vol;
                    if (sample > 2147483647.0) sample = 2147483647.0;
                    if (sample < -2147483648.0) sample = -2147483648.0;
                    pOutputS32[i] = (ma_int32)sample;
                }
            } else if (pDevice->playback.format == ma_format_f32) {
                float* pOutputF32 = (float*)pOutput;
                for (ma_uint64 i = 0; i < framesRead * pDevice->playback.channels; ++i) {
                    pOutputF32[i] *= (float)vol;
                }
            }
        }
        (void)pInput;
        return;
    }

    // Apply EQ (10-band peaking filters in series)
    for (int i = 0; i < 10; ++i) {
        ma_biquad_process_pcm_frames(&pEngine->eq_bands[i], pOutput, pOutput, framesRead);
    }
    
    // Apply Volume
    float* pOutputF32 = (float*)pOutput;
    for (ma_uint64 i = 0; i < framesRead * pDevice->playback.channels; ++i) {
        pOutputF32[i] *= pEngine->volume;
    }

    ma_mutex_unlock(&pEngine->engine_lock);

    (void)pInput;
}

ENGINE_API AudioHandle Engine_Create(void) {
#ifdef _WIN32
    if (getenv("USERPROFILE") != NULL) {
        snprintf(ENGINE_LOG_PATH, sizeof(ENGINE_LOG_PATH), "%s\\Documents\\SimpleMusicDB\\logs\\engine_log.txt", getenv("USERPROFILE"));
        
        char dir_path[512];
        snprintf(dir_path, sizeof(dir_path), "%s\\Documents\\SimpleMusicDB", getenv("USERPROFILE"));
        CreateDirectoryA(dir_path, NULL);
        snprintf(dir_path, sizeof(dir_path), "%s\\Documents\\SimpleMusicDB\\logs", getenv("USERPROFILE"));
        CreateDirectoryA(dir_path, NULL);
    }

    // Initialize Windows Media Foundation for M4A/AAC decoding
    mf_decoder_global_init();
#endif

    AudioEngine* pEngine = (AudioEngine*)calloc(1, sizeof(AudioEngine));
    if (pEngine == NULL) return NULL;
    
    pEngine->volume = 1.0f;
    pEngine->is_initialized = true;
    if (pEngine != NULL) {
        ma_mutex_init(&pEngine->engine_lock);
        memset(pEngine->custom_device_id, 0, sizeof(pEngine->custom_device_id));
        return (AudioHandle)pEngine;
    }
    return NULL;
}

ENGINE_API void Engine_SetOutputDevice(AudioHandle handle, const char* deviceId) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return;
    
    if (deviceId != NULL && strlen(deviceId) > 0) {
        strncpy(pEngine->custom_device_id, deviceId, 255);
        pEngine->custom_device_id[255] = '\0';
    } else {
        memset(pEngine->custom_device_id, 0, sizeof(pEngine->custom_device_id));
    }
}

ENGINE_API void Engine_Dispose(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return;
    
    if (pEngine->has_device) {
        ma_device_uninit(&pEngine->device);
        ma_decoder_uninit(&pEngine->decoder);
        pEngine->has_device = false;
    }
    
    if (pEngine->has_context) {
        ma_context_uninit(&pEngine->context);
        pEngine->has_context = false;
    }
    
    ma_mutex_uninit(&pEngine->engine_lock);
    free(pEngine);

#ifdef _WIN32
    mf_decoder_global_uninit();
#endif
}

ENGINE_API void Engine_ReleaseDevice(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return;
    
    if (pEngine->has_device) {
        ma_device_stop(&pEngine->device);
        ma_device_uninit(&pEngine->device);
        ma_decoder_uninit(&pEngine->decoder);
        pEngine->has_device = false;
        pEngine->is_playing = false;
        pEngine->is_completed = false;
    }
    
    if (pEngine->has_context) {
        ma_context_uninit(&pEngine->context);
        pEngine->has_context = false;
    }
}

ENGINE_API bool Engine_PlayFile(AudioHandle handle, const char* filepath, bool bit_perfect) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return false;

    // Stop and uninit previous if exists
    if (pEngine->has_device) {
        ma_mutex_lock(&pEngine->engine_lock);
        ma_device_uninit(&pEngine->device);
        ma_decoder_uninit(&pEngine->decoder);
        pEngine->is_playing = false;
        pEngine->has_device = false;
        ma_mutex_unlock(&pEngine->engine_lock);
    }
    
    // Tear down previous context (forces full WASAPI session release)
    if (pEngine->has_context) {
        ma_context_uninit(&pEngine->context);
        pEngine->has_context = false;
    }

    pEngine->bit_perfect = bit_perfect;

    // STEP 1: INITIAL DECODER PASS to discover true file sample rate & channels
    // We let miniaudio use its default format just so we can read the header.
    ma_decoder_config decoderConfig = ma_decoder_config_init(ma_format_unknown, 0, 0);
#ifdef _WIN32
    // Register WMF backend so miniaudio can decode M4A/AAC/WMA via Media Foundation
    decoderConfig.ppCustomBackendVTables = g_pCustomBackends;
    decoderConfig.customBackendCount     = 1;
#endif
    ma_result result;

    wchar_t* wpath = NULL;
#ifdef _WIN32
    int wlen = MultiByteToWideChar(CP_UTF8, 0, filepath, -1, NULL, 0);
    if (wlen > 0) {
        wpath = (wchar_t*)malloc(wlen * sizeof(wchar_t));
        MultiByteToWideChar(CP_UTF8, 0, filepath, -1, wpath, wlen);
        result = ma_decoder_init_file_w(wpath, &decoderConfig, &pEngine->decoder);
    } else {
        result = MA_ERROR;
    }
#else
    result = ma_decoder_init_file(filepath, &decoderConfig, &pEngine->decoder);
#endif

    if (result != MA_SUCCESS) {
        if (wpath) free(wpath);
        return false;
    }

    // STEP 2: CONFIGURE THE DEVICE WITH FILE'S SAMPLE RATE
    ma_device_config deviceConfig = ma_device_config_init(ma_device_type_playback);
    deviceConfig.playback.channels = pEngine->decoder.outputChannels;
    deviceConfig.sampleRate        = pEngine->decoder.outputSampleRate;
    deviceConfig.dataCallback      = data_callback;
    deviceConfig.pUserData         = pEngine;

    ma_result initResult = MA_ERROR;
    const char* initMode = "unknown";  // Track which mode succeeded for logging

    if (bit_perfect) {
        // Conservative buffer for DAC hardware stabilization (matches mpv's approach)
        deviceConfig.periodSizeInMilliseconds = 50;
        deviceConfig.performanceProfile = ma_performance_profile_conservative;
        
        // Create an explicit WASAPI-only context to ensure no backend fallback.
        ma_backend backends[] = { ma_backend_wasapi };
        ma_result ctxResult = ma_context_init(backends, 1, NULL, &pEngine->context);
        if (ctxResult != MA_SUCCESS) {
            // Log context failure
            FILE* err_f = fopen(ENGINE_LOG_PATH, "a");
            if (err_f) { fprintf(err_f, "[C++ Engine] ERROR: WASAPI context init failed (code=%d)\n", ctxResult); fclose(err_f); }
            ma_decoder_uninit(&pEngine->decoder);
            if (wpath) free(wpath);
            return false;
        }
        pEngine->has_context = true;
        
        // Convert the string device ID to a WASAPI GUID ID for Miniaudio
        ma_device_id customId;
        memset(&customId, 0, sizeof(customId));
        bool hasCustomId = false;
        if (strlen(pEngine->custom_device_id) > 0) {
#ifdef _WIN32
            const char* idToUse = pEngine->custom_device_id;
            if (strncmp(idToUse, "wasapi/", 7) == 0) {
                idToUse += 7;
            }
            
            char formattedId[256];
            formattedId[0] = '\0';
            
            // If the ID is missing the {0.0.0.00000000}. prefix that Windows/Miniaudio requires, add it
            if (idToUse[0] == '{' && strncmp(idToUse, "{0.0.0", 6) != 0) {
                snprintf(formattedId, sizeof(formattedId), "{0.0.0.00000000}.%s", idToUse);
                idToUse = formattedId;
            }

            int len = MultiByteToWideChar(CP_UTF8, 0, idToUse, -1, customId.wasapi, 256);
            if (len > 0) {
                deviceConfig.playback.pDeviceID = &customId;
                hasCustomId = true;
                FILE* dbg_f = fopen(ENGINE_LOG_PATH, "a");
                if (dbg_f) { fprintf(dbg_f, "[C++ Engine] Using Custom Device ID: %s (wide array populated)\n", idToUse); fclose(dbg_f); }
            } else {
                FILE* dbg_f = fopen(ENGINE_LOG_PATH, "a");
                if (dbg_f) { fprintf(dbg_f, "[C++ Engine] ERROR: Failed to convert custom device ID: %s\n", idToUse); fclose(dbg_f); }
            }
#endif
        } else {
            FILE* dbg_f = fopen(ENGINE_LOG_PATH, "a");
            if (dbg_f) { fprintf(dbg_f, "[C++ Engine] Using DEFAULT system device (no custom ID provided)\n"); fclose(dbg_f); }
        }

        // ============================================================
        // TIER 1: STRICT EXCLUSIVE (true bit-perfect)
        // noAutoConvertSRC prevents Windows from silently resampling.
        // This is the ideal path — DAC gets the exact native signal.
        // ============================================================
        deviceConfig.playback.shareMode = ma_share_mode_exclusive;
        deviceConfig.wasapi.noAutoConvertSRC    = MA_TRUE;
        deviceConfig.wasapi.noHardwareOffloading = MA_TRUE;
        deviceConfig.wasapi.noAutoStreamRouting  = MA_TRUE;
        
        // Critical Fix: Do not force an arbitrary 50ms period! 
        // Force Miniaudio to query IAudioClient->GetDevicePeriod() to prevent
        // AUDCLNT_E_INVALID_DEVICE_PERIOD rejection on fixed clock drivers (e.g. FiiO)
        deviceConfig.periodSizeInMilliseconds = 0;
        deviceConfig.performanceProfile = ma_performance_profile_low_latency;
        
        ma_format exclusiveFormats[] = { ma_format_s32, ma_format_s24, ma_format_f32, ma_format_s16 };
        for (int i = 0; i < 4; i++) {
            deviceConfig.playback.format = exclusiveFormats[i];
            initResult = ma_device_init(&pEngine->context, &deviceConfig, &pEngine->device);
            
            if (initResult == MA_SUCCESS) {
                // VERY IMPORTANT: Miniaudio might return SUCCESS but silently fall back
                // to a different hardware sample rate (e.g. 44100) if the DAC rejects this
                // specific format at exactly 96000Hz. If that happens, we MUST reject it
                // and try the next format (e.g. s24 at 96000Hz).
                if (pEngine->device.playback.internalSampleRate == deviceConfig.sampleRate) {
                    initMode = "STRICT_EXCLUSIVE";
                    break;
                } else {
                    FILE* t_f = fopen(ENGINE_LOG_PATH, "a");
                    if (t_f) { fprintf(t_f, "[C++ Engine] WARN: Format %d succeeded but HW rate fell back to %d. Trying next format...\n", exclusiveFormats[i], pEngine->device.playback.internalSampleRate); fclose(t_f); }
                    
                    ma_device_uninit(&pEngine->device);
                    initResult = MA_ERROR; // Force failure so we keep searching
                }
            }
        }

        // ============================================================
        // TIER 2: LENIENT EXCLUSIVE (exclusive mode but allow WASAPI SRC)
        // Some devices/drivers reject strict mode. This still gets exclusive
        // access (no other apps can use the device) but lets WASAPI do
        // format negotiation. Better than shared mode.
        // ============================================================
        if (initResult != MA_SUCCESS) {
            FILE* t2_f = fopen(ENGINE_LOG_PATH, "a");
            if (t2_f) { fprintf(t2_f, "[C++ Engine] WARN: Strict exclusive failed for all exact formats. Trying lenient exclusive...\n"); fclose(t2_f); }
            
            deviceConfig.wasapi.noAutoConvertSRC    = MA_FALSE;  // Let WASAPI handle SRC
            deviceConfig.wasapi.noHardwareOffloading = MA_FALSE;
            // Keep noAutoStreamRouting TRUE — we still want device stability
            
            for (int i = 0; i < 4; i++) {
                deviceConfig.playback.format = exclusiveFormats[i];
                initResult = ma_device_init(&pEngine->context, &deviceConfig, &pEngine->device);
                if (initResult == MA_SUCCESS) {
                    if (pEngine->device.playback.internalSampleRate == deviceConfig.sampleRate) {
                        initMode = "LENIENT_EXCLUSIVE";
                        break;
                    } else {
                        ma_device_uninit(&pEngine->device);
                        initResult = MA_ERROR;
                    }
                }
            }
        }

        // ============================================================
        // TIER 3: SHARED MODE FALLBACK
        // If exclusive mode is completely unavailable, tear down the
        // WASAPI-only context and use the default system context.
        // ============================================================
        if (initResult != MA_SUCCESS) {
            FILE* t3_f = fopen(ENGINE_LOG_PATH, "a");
            if (t3_f) { fprintf(t3_f, "[C++ Engine] WARN: Exclusive mode unavailable (last error=%d). Falling back to shared mode with default context.\n", initResult); fclose(t3_f); }
            
            // Tear down the WASAPI-only context — it can't do shared mode reliably
            if (pEngine->has_context) {
                ma_context_uninit(&pEngine->context);
                pEngine->has_context = false;
            }
            
            deviceConfig.playback.shareMode = ma_share_mode_shared;
            deviceConfig.playback.pDeviceID = NULL; // Use default device
            deviceConfig.wasapi.noAutoConvertSRC    = MA_FALSE;
            deviceConfig.wasapi.noHardwareOffloading = MA_FALSE;
            deviceConfig.wasapi.noAutoStreamRouting  = MA_FALSE;
            deviceConfig.playback.format = ma_format_f32;
            deviceConfig.periodSizeInMilliseconds = 0; // Let system choose
            deviceConfig.performanceProfile = ma_performance_profile_low_latency;
            
            initResult = ma_device_init(NULL, &deviceConfig, &pEngine->device);
            if (initResult == MA_SUCCESS) {
                initMode = "SHARED_FALLBACK";
            } else {
                FILE* t4_f = fopen(ENGINE_LOG_PATH, "a");
                if (t4_f) { fprintf(t4_f, "[C++ Engine] ERROR: Even shared mode failed (error=%d). All init paths exhausted.\n", initResult); fclose(t4_f); }
            }
        }
    } else {
        deviceConfig.playback.format = ma_format_f32; // Normal DSP format
        initResult = ma_device_init(NULL, &deviceConfig, &pEngine->device);
        initMode = "SHARED_NORMAL";
    }

    // STEP 3: HANDLE INITIALIZATION FAILURE
    if (initResult != MA_SUCCESS) {
        ma_decoder_uninit(&pEngine->decoder);
        if (pEngine->has_context) {
            ma_context_uninit(&pEngine->context);
            pEngine->has_context = false;
        }
        if (wpath) free(wpath);
        return false;
    }

    // STEP 4: RE-INITIALIZE DECODER TO MATCH THE DEVICE'S NEGOTIATED FORMAT
    // This removes internal miniaudio format conversions!
    ma_format negotiatedFormat = pEngine->device.playback.format;
    ma_decoder_uninit(&pEngine->decoder); // Uninit the probe decoder
    
    decoderConfig = ma_decoder_config_init(negotiatedFormat, pEngine->device.playback.channels, pEngine->device.sampleRate);
#ifdef _WIN32
    decoderConfig.ppCustomBackendVTables = g_pCustomBackends;
    decoderConfig.customBackendCount     = 1;
#endif

#ifdef _WIN32
    result = ma_decoder_init_file_w(wpath, &decoderConfig, &pEngine->decoder);
    free(wpath);
#else
    result = ma_decoder_init_file(filepath, &decoderConfig, &pEngine->decoder);
#endif

    if (result != MA_SUCCESS) {
        ma_device_uninit(&pEngine->device);
        return false;
    }

    pEngine->has_device = true;

    FILE* log_f = fopen(ENGINE_LOG_PATH, "a");
    if (log_f) {
        const char* fmtName = "unknown";
        switch (pEngine->decoder.outputFormat) {
            case ma_format_u8:  fmtName = "u8";  break;
            case ma_format_s16: fmtName = "s16"; break;
            case ma_format_s24: fmtName = "s24"; break;
            case ma_format_s32: fmtName = "s32"; break;
            case ma_format_f32: fmtName = "f32"; break;
            default: break;
        }
        const char* devFmtName = "unknown";
        switch (pEngine->device.playback.internalFormat) {
            case ma_format_u8:  devFmtName = "u8";  break;
            case ma_format_s16: devFmtName = "s16"; break;
            case ma_format_s24: devFmtName = "s24"; break;
            case ma_format_s32: devFmtName = "s32"; break;
            case ma_format_f32: devFmtName = "f32"; break;
            default: break;
        }
        fprintf(log_f, "========================================\n");
        fprintf(log_f, "[C++ Engine] Init Mode: %s\n", initMode);
        fprintf(log_f, "[C++ Engine] Decoder: fmt=%s, rate=%d, ch=%d\n",
                fmtName, pEngine->decoder.outputSampleRate, pEngine->decoder.outputChannels);
        fprintf(log_f, "[C++ Engine] App -> Engine: fmt=%s, rate=%d\n",
                fmtName, pEngine->device.sampleRate);
        fprintf(log_f, "[C++ Engine] Engine -> DAC: fmt=%s, HW_RATE=%d\n",
                devFmtName, pEngine->device.playback.internalSampleRate);
        fprintf(log_f, "[C++ Engine] Exclusive: target=%d, actual=%d\n",
                bit_perfect, pEngine->device.playback.shareMode == ma_share_mode_exclusive);
        fprintf(log_f, "[C++ Engine] WASAPI: noAutoConvertSRC=%d, noHWOffload=%d, noAutoRoute=%d\n",
                deviceConfig.wasapi.noAutoConvertSRC,
                deviceConfig.wasapi.noHardwareOffloading,
                deviceConfig.wasapi.noAutoStreamRouting);
        fprintf(log_f, "[C++ Engine] Context: explicit_wasapi=%d\n", pEngine->has_context ? 1 : 0);
        fprintf(log_f, "========================================\n");
        fclose(log_f);
    }

    // Initialize EQ bands (default to flat)
    ma_mutex_lock(&pEngine->engine_lock);
    for (int i = 0; i < 10; ++i) {
        ma_biquad_config config = ma_biquad_config_init(ma_format_f32, pEngine->device.playback.channels, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
        config.format = ma_format_f32;
        ma_biquad_init(&config, NULL, &pEngine->eq_bands[i]);
    }
    ma_mutex_unlock(&pEngine->engine_lock);

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
    
    ma_mutex_lock(&pEngine->engine_lock);
    ma_biquad_init(&config, NULL, &pEngine->eq_bands[index]);
    ma_mutex_unlock(&pEngine->engine_lock);
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
        ma_mutex_lock(&pEngine->engine_lock);
        ma_decoder_seek_to_pcm_frame(&pEngine->decoder, 0);
        pEngine->is_playing = false;
        ma_mutex_unlock(&pEngine->engine_lock);
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
    ma_uint64 pos = 0;
    ma_mutex_lock(&pEngine->engine_lock);
    ma_decoder_get_cursor_in_pcm_frames(&pEngine->decoder, &pos);
    float position = (float)pos / (float)pEngine->decoder.outputSampleRate;
    ma_mutex_unlock(&pEngine->engine_lock);
    return position;
}

ENGINE_API void Engine_SetPosition(AudioHandle handle, float position_seconds) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine != NULL) {
        ma_mutex_lock(&pEngine->engine_lock);
        ma_decoder_seek_to_pcm_frame(&pEngine->decoder, (ma_uint64)(position_seconds * pEngine->decoder.outputSampleRate));
        ma_mutex_unlock(&pEngine->engine_lock);
    }
}

ENGINE_API float Engine_GetDuration(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return 0.0f;
    ma_uint64 len = 0;
    ma_mutex_lock(&pEngine->engine_lock);
    ma_decoder_get_length_in_pcm_frames(&pEngine->decoder, &len);
    float duration = (float)len / (float)pEngine->decoder.outputSampleRate;
    ma_mutex_unlock(&pEngine->engine_lock);
    return duration;
}

ENGINE_API bool Engine_IsPlaying(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    return pEngine != NULL && pEngine->is_playing;
}

ENGINE_API bool Engine_IsCompleted(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    return pEngine != NULL && pEngine->is_completed;
}
