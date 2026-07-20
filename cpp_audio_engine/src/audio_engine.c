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

#ifdef __ANDROID__
#include "mediacodec_decoder.h"
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
    bool has_raw_sink;    // true while raw-sink decoder is active (no ma_device)
    bool bit_perfect;     // true = bypass all DSP, use native format for WASAPI exclusive
    float volume;
    char custom_device_id[256]; // Store explicit Windows MMDevice string
    ma_mutex engine_lock;

    // Raw-sink negotiated format (used by Engine_GetRawFormat).
    int raw_sample_rate;
    int raw_channels;
    int raw_bit_depth;

    void* custom_user_data;
    EngineReadCallback on_read;
    EngineSeekCallback on_seek;
    EngineGetSizeCallback on_get_size;

#ifdef __ANDROID__
    // When non-NULL the raw sink is decoding via Android NDK MediaCodec
    // instead of miniaudio (used for .m4a / .mp4 / .aac files where
    // miniaudio has no AAC/ALAC decoder).
    mc_decoder_t *mc_dec;
#endif
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

    if (pEngine->has_raw_sink) {
#ifdef __ANDROID__
        if (pEngine->mc_dec != NULL) {
            mc_decoder_close(pEngine->mc_dec);
            pEngine->mc_dec = NULL;
        } else {
            ma_decoder_uninit(&pEngine->decoder);
        }
#else
        ma_decoder_uninit(&pEngine->decoder);
#endif
        pEngine->has_raw_sink = false;
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
    if (pEngine == NULL) return;
    if (!pEngine->has_device && !pEngine->has_raw_sink) return;

    // Pull sample rate + channels from whichever path is active so the EQ
    // stays consistent for both Windows (device) and Android (raw sink).
    double sr;
    int channels;
    if (pEngine->has_device) {
        sr = (double)pEngine->device.sampleRate;
        channels = (int)pEngine->device.playback.channels;
    } else {
        sr = (double)pEngine->raw_sample_rate;
        channels = pEngine->raw_channels;
    }
    if (sr <= 0.0 || channels <= 0) return;

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
        channels,
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
    if (!pEngine->has_device && !pEngine->has_raw_sink) return 0.0f;
#ifdef __ANDROID__
    if (pEngine->mc_dec != NULL) {
        return mc_decoder_get_position(pEngine->mc_dec);
    }
#endif
    ma_uint64 pos = 0;
    ma_mutex_lock(&pEngine->engine_lock);
    ma_decoder_get_cursor_in_pcm_frames(&pEngine->decoder, &pos);
    float position = pEngine->decoder.outputSampleRate > 0
        ? (float)pos / (float)pEngine->decoder.outputSampleRate
        : 0.0f;
    ma_mutex_unlock(&pEngine->engine_lock);
    return position;
}

ENGINE_API void Engine_SetPosition(AudioHandle handle, float position_seconds) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return;
    if (!pEngine->has_device && !pEngine->has_raw_sink) return;
#ifdef __ANDROID__
    if (pEngine->mc_dec != NULL) {
        mc_decoder_seek(pEngine->mc_dec, position_seconds);
        return;
    }
#endif
    ma_mutex_lock(&pEngine->engine_lock);
    ma_decoder_seek_to_pcm_frame(
        &pEngine->decoder,
        (ma_uint64)(position_seconds * pEngine->decoder.outputSampleRate));
    ma_mutex_unlock(&pEngine->engine_lock);
}

ENGINE_API float Engine_GetDuration(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return 0.0f;
    if (!pEngine->has_device && !pEngine->has_raw_sink) return 0.0f;
#ifdef __ANDROID__
    if (pEngine->mc_dec != NULL) {
        return mc_decoder_get_duration(pEngine->mc_dec);
    }
#endif
    ma_uint64 len = 0;
    ma_mutex_lock(&pEngine->engine_lock);
    ma_decoder_get_length_in_pcm_frames(&pEngine->decoder, &len);
    float duration = pEngine->decoder.outputSampleRate > 0
        ? (float)len / (float)pEngine->decoder.outputSampleRate
        : 0.0f;
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

// ============================================================================
// Raw output sink — used by the Android USB DAC bypass and any caller that
// needs decoded PCM frames without miniaudio opening a ma_device.
// EQ + volume application logic mirrors data_callback() so behavior is
// consistent between the device-driven path and the pull-driven path.
// ============================================================================

static ma_format format_from_bit_depth(int bit_depth) {
    switch (bit_depth) {
        case 16: return ma_format_s16;
        case 24: return ma_format_s24;
        case 32: return ma_format_s32;
        default: return ma_format_f32;
    }
}

static int bit_depth_from_format(ma_format fmt) {
    switch (fmt) {
        case ma_format_u8:  return 8;
        case ma_format_s16: return 16;
        case ma_format_s24: return 24;
        case ma_format_s32: return 32;
        case ma_format_f32: return 32; // float, but report 32 for downstream compatibility
        default: return 0;
    }
}

ENGINE_API bool Engine_PrepareRawSink(AudioHandle handle, const char* filepath,
                                      int sample_rate_hint,
                                      int channels_hint,
                                      int bit_depth_hint,
                                      bool bit_perfect) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL || filepath == NULL) return false;

    // Tear down whatever is active so raw-sink and device-sink stay mutually exclusive.
    if (pEngine->has_device) {
        ma_mutex_lock(&pEngine->engine_lock);
        ma_device_uninit(&pEngine->device);
        ma_decoder_uninit(&pEngine->decoder);
        pEngine->is_playing = false;
        pEngine->has_device = false;
        ma_mutex_unlock(&pEngine->engine_lock);
    }
    if (pEngine->has_context) {
        ma_context_uninit(&pEngine->context);
        pEngine->has_context = false;
    }
    if (pEngine->has_raw_sink) {
        ma_mutex_lock(&pEngine->engine_lock);
#ifdef __ANDROID__
        if (pEngine->mc_dec != NULL) {
            mc_decoder_close(pEngine->mc_dec);
            pEngine->mc_dec = NULL;
        } else {
            ma_decoder_uninit(&pEngine->decoder);
        }
#else
        ma_decoder_uninit(&pEngine->decoder);
#endif
        pEngine->has_raw_sink = false;
        ma_mutex_unlock(&pEngine->engine_lock);
    }

    pEngine->custom_user_data = NULL;
    pEngine->on_read = NULL;
    pEngine->on_seek = NULL;
    pEngine->on_get_size = NULL;

    pEngine->bit_perfect = bit_perfect;

#ifdef __ANDROID__
    // Android: route MP4-family files to the NDK MediaCodec backend.
    // miniaudio doesn't ship an AAC/ALAC decoder, so .m4a etc. fail
    // there. MediaCodec gives us AAC universally and ALAC on Android 12+.
    if (mc_decoder_path_looks_like_mp4(filepath)) {
        mc_decoder_t *mc = mc_decoder_open(filepath, pEngine->bit_perfect);
        if (mc == NULL) {
            // Soft failure — could be ALAC on pre-12 device, or a corrupt
            // container. Caller (UsbAudioPlayer) reports an error to the user.
            return false;
        }
        int sr = 0, ch = 0, bd = 0;
        mc_decoder_get_format(mc, &sr, &ch, &bd);
        if (sr <= 0 || ch <= 0) {
            mc_decoder_close(mc);
            return false;
        }
        pEngine->mc_dec = mc;
        pEngine->has_raw_sink = true;
        pEngine->raw_sample_rate = sr;
        pEngine->raw_channels    = ch;
        pEngine->raw_bit_depth   = bd;

        // EQ bands at the negotiated rate (still s16 path; biquad runs on
        // f32 only, so EQ is effectively bypassed for MP4 unless we add
        // s16↔f32 conversion — kept off for now to preserve bit-perfect).
        ma_mutex_lock(&pEngine->engine_lock);
        for (int i = 0; i < 10; ++i) {
            ma_biquad_config config = ma_biquad_config_init(
                ma_format_f32, ch,
                1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
            config.format = ma_format_f32;
            ma_biquad_init(&config, NULL, &pEngine->eq_bands[i]);
        }
        pEngine->is_completed = false;
        ma_mutex_unlock(&pEngine->engine_lock);

        // Hint suppression: caller may have asked for a specific sr/ch/bd
        // but MediaCodec dictates what comes out. The sr/ch/bd above are
        // already authoritative.
        (void)sample_rate_hint;
        (void)channels_hint;
        (void)bit_depth_hint;
        return true;
    }
#endif

    // Resolve target format. Hints of 0 mean "use the file's native value",
    // so we first probe with format_unknown then re-init with concrete values.
    ma_format target_format = (bit_depth_hint > 0)
        ? format_from_bit_depth(bit_depth_hint)
        : ma_format_unknown;
    ma_uint32 target_sr = (sample_rate_hint > 0) ? (ma_uint32)sample_rate_hint : 0;
    ma_uint32 target_ch = (channels_hint > 0) ? (ma_uint32)channels_hint : 0;

    ma_decoder_config decoderConfig = ma_decoder_config_init(target_format, target_ch, target_sr);
#ifdef _WIN32
    decoderConfig.ppCustomBackendVTables = g_pCustomBackends;
    decoderConfig.customBackendCount     = 1;
#endif

    ma_result result;
#ifdef _WIN32
    int wlen = MultiByteToWideChar(CP_UTF8, 0, filepath, -1, NULL, 0);
    if (wlen > 0) {
        wchar_t* wpath = (wchar_t*)malloc(wlen * sizeof(wchar_t));
        MultiByteToWideChar(CP_UTF8, 0, filepath, -1, wpath, wlen);
        result = ma_decoder_init_file_w(wpath, &decoderConfig, &pEngine->decoder);
        free(wpath);
    } else {
        result = MA_ERROR;
    }
#else
    result = ma_decoder_init_file(filepath, &decoderConfig, &pEngine->decoder);
#endif

    if (result != MA_SUCCESS) return false;

    pEngine->has_raw_sink = true;
    pEngine->raw_sample_rate = (int)pEngine->decoder.outputSampleRate;
    pEngine->raw_channels    = (int)pEngine->decoder.outputChannels;
    pEngine->raw_bit_depth   = bit_depth_from_format(pEngine->decoder.outputFormat);

    // Initialize EQ bands to flat at the negotiated sample rate. The host can
    // tweak per-band gains with Engine_SetEQBand.
    ma_mutex_lock(&pEngine->engine_lock);
    for (int i = 0; i < 10; ++i) {
        ma_biquad_config config = ma_biquad_config_init(
            ma_format_f32, pEngine->decoder.outputChannels,
            1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
        config.format = ma_format_f32;
        ma_biquad_init(&config, NULL, &pEngine->eq_bands[i]);
    }
    pEngine->is_completed = false;
    ma_mutex_unlock(&pEngine->engine_lock);

    return true;
}

static ma_result custom_ma_read(ma_decoder* pDecoder, void* pBufferOut, size_t bytesToRead, size_t* pBytesRead) {
    AudioEngine* pEngine = (AudioEngine*)pDecoder->pUserData;
    if (pEngine && pEngine->on_read) {
        size_t read = pEngine->on_read(pEngine->custom_user_data, pBufferOut, bytesToRead);
        if (pBytesRead) *pBytesRead = read;
        return (read > 0 || bytesToRead == 0) ? MA_SUCCESS : MA_AT_END;
    }
    return MA_ERROR;
}

static ma_result custom_ma_seek(ma_decoder* pDecoder, ma_int64 byteOffset, ma_seek_origin origin) {
    AudioEngine* pEngine = (AudioEngine*)pDecoder->pUserData;
    if (pEngine && pEngine->on_seek && pEngine->on_get_size) {
        long long target = byteOffset;
        if (origin == ma_seek_origin_current) {
            // Not easily supported without keeping track of current offset
            return MA_NOT_IMPLEMENTED; 
        } else if (origin == ma_seek_origin_end) {
            long long size = pEngine->on_get_size(pEngine->custom_user_data);
            if (size < 0) return MA_ERROR;
            target = size + byteOffset;
        }
        return pEngine->on_seek(pEngine->custom_user_data, target) ? MA_SUCCESS : MA_ERROR;
    }
    return MA_ERROR;
}

static ma_result custom_ma_tell(ma_decoder* pDecoder, ma_int64* pCursor) {
    // We'd have to track the cursor, but miniaudio often works without seek/tell for basic streaming,
    // or we can just return MA_NOT_IMPLEMENTED if miniaudio can handle it.
    // However, if seeking is requested, miniaudio needs tell. But for internet streams it's tricky.
    // Since we don't have a tell callback, let's just fail it and see if miniaudio falls back.
    return MA_NOT_IMPLEMENTED;
}

ENGINE_API bool Engine_PrepareRawSinkCustom(AudioHandle handle,
                                            EngineReadCallback on_read,
                                            EngineSeekCallback on_seek,
                                            EngineGetSizeCallback on_get_size,
                                            void* user_data,
                                            int sample_rate_hint,
                                            int channels_hint,
                                            int bit_depth_hint,
                                            bool bit_perfect) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return false;

    // Tear down whatever is active
    if (pEngine->has_device) {
        ma_mutex_lock(&pEngine->engine_lock);
        ma_device_uninit(&pEngine->device);
        ma_decoder_uninit(&pEngine->decoder);
        pEngine->is_playing = false;
        pEngine->has_device = false;
        ma_mutex_unlock(&pEngine->engine_lock);
    }
    if (pEngine->has_context) {
        ma_context_uninit(&pEngine->context);
        pEngine->has_context = false;
    }
    if (pEngine->has_raw_sink) {
        ma_mutex_lock(&pEngine->engine_lock);
#ifdef __ANDROID__
        if (pEngine->mc_dec != NULL) {
            mc_decoder_close(pEngine->mc_dec);
            pEngine->mc_dec = NULL;
        } else {
            ma_decoder_uninit(&pEngine->decoder);
        }
#else
        ma_decoder_uninit(&pEngine->decoder);
#endif
        pEngine->has_raw_sink = false;
        ma_mutex_unlock(&pEngine->engine_lock);
    }

    pEngine->bit_perfect = bit_perfect;
    pEngine->custom_user_data = user_data;
    pEngine->on_read = on_read;
    pEngine->on_seek = on_seek;
    pEngine->on_get_size = on_get_size;

    ma_format target_format = (bit_depth_hint > 0)
        ? format_from_bit_depth(bit_depth_hint)
        : ma_format_unknown;
    ma_uint32 target_sr = (sample_rate_hint > 0) ? (ma_uint32)sample_rate_hint : 0;
    ma_uint32 target_ch = (channels_hint > 0) ? (ma_uint32)channels_hint : 0;

    ma_decoder_config decoderConfig = ma_decoder_config_init(target_format, target_ch, target_sr);
    
    ma_result result = ma_decoder_init(custom_ma_read, custom_ma_seek, pEngine, &decoderConfig, &pEngine->decoder);
    
    if (result != MA_SUCCESS) {
        return false;
    }

    pEngine->has_raw_sink = true;
    pEngine->raw_sample_rate = (int)pEngine->decoder.outputSampleRate;
    pEngine->raw_channels    = (int)pEngine->decoder.outputChannels;
    pEngine->raw_bit_depth   = bit_depth_from_format(pEngine->decoder.outputFormat);

    ma_mutex_lock(&pEngine->engine_lock);
    for (int i = 0; i < 10; ++i) {
        ma_biquad_config config = ma_biquad_config_init(
            ma_format_f32, pEngine->decoder.outputChannels,
            1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
        config.format = ma_format_f32;
        ma_biquad_init(&config, NULL, &pEngine->eq_bands[i]);
    }
    pEngine->is_completed = false;
    ma_mutex_unlock(&pEngine->engine_lock);

    return true;
}

ENGINE_API void* Engine_GetRawSinkUserData(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL) return NULL;
    return pEngine->custom_user_data;
}

ENGINE_API long long Engine_ReadRawFrames(AudioHandle handle,
                                          void* output_buffer,
                                          unsigned int frame_count) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL || output_buffer == NULL) return -1;
    if (!pEngine->has_raw_sink) return -1;

#ifdef __ANDROID__
    // Android MediaCodec / ALAC fallback path.
    //
    // Two sub-paths depending on the decoder backend:
    //
    //   1. MediaCodec (Android 12+ ALAC, all AAC): emits f32 PCM. We apply
    //      EQ + volume in float domain, then convert to the target bit depth.
    //
    //   2. Apple ALAC fallback (Android 7-11): emits interleaved integer PCM
    //      at the source bit depth (s16 or s24 packed). We write directly to
    //      the output buffer and apply volume in the integer domain. This
    //      avoids the lossy int→f32→int round-trip and preserves bit-perfect
    //      quality for the fallback path.
    if (pEngine->mc_dec != NULL) {
        ma_mutex_lock(&pEngine->engine_lock);

        ma_uint32 channels = (ma_uint32)pEngine->raw_channels;
        ma_uint32 bd = (ma_uint32)pEngine->raw_bit_depth;
        if (bd != 16 && bd != 24 && bd != 32) bd = 16;

        // Cap chunk size so scratch stays bounded.
        if (frame_count > 4096) frame_count = 4096;

        // ────────────────────────────────────────────────────────────────────
        // PATH A: ALAC fallback — integer PCM direct to output
        // ────────────────────────────────────────────────────────────────────
        if (mc_decoder_is_integer_output(pEngine->mc_dec)) {
            // The fallback decoder writes interleaved integer PCM at the
            // source bit depth directly into output_buffer.
            long long framesRead = mc_decoder_read_frames(
                pEngine->mc_dec, output_buffer, frame_count);
            if (framesRead == 0) {
                pEngine->is_completed = true;
                ma_mutex_unlock(&pEngine->engine_lock);
                return -1;
            }
            if (framesRead < 0) {
                ma_mutex_unlock(&pEngine->engine_lock);
                return -1;
            }

            // Apply volume in the integer domain (EQ is bypassed for integer
            // output — biquad requires f32. This matches the bit-perfect
            // Windows WASAPI path behavior).
            if (pEngine->volume < 0.999f) {
                double vol = (double)pEngine->volume;
                size_t total_samples = (size_t)(framesRead * channels);

                if (bd == 24) {
                    ma_uint8 *p = (ma_uint8 *)output_buffer;
                    for (size_t i = 0; i < total_samples; ++i) {
                        // Reconstruct 24-bit signed integer (little-endian packed)
                        int32_t s24 = (p[i*3] | (p[i*3+1] << 8) | (p[i*3+2] << 16));
                        if (s24 & 0x00800000) s24 |= (int32_t)0xFF000000; // sign-extend
                        double s = (double)s24 * vol;
                        if (s > 8388607.0) s = 8388607.0;
                        if (s < -8388608.0) s = -8388608.0;
                        int32_t r = (int32_t)s;
                        p[i*3]   = (ma_uint8)(r & 0xFF);
                        p[i*3+1] = (ma_uint8)((r >> 8) & 0xFF);
                        p[i*3+2] = (ma_uint8)((r >> 16) & 0xFF);
                    }
                } else if (bd == 32) {
                    int32_t *p = (int32_t *)output_buffer;
                    for (size_t i = 0; i < total_samples; ++i) {
                        double s = (double)p[i] * vol;
                        if (s > 2147483647.0) s = 2147483647.0;
                        if (s < -2147483648.0) s = -2147483648.0;
                        p[i] = (int32_t)s;
                    }
                } else {
                    int16_t *p = (int16_t *)output_buffer;
                    for (size_t i = 0; i < total_samples; ++i) {
                        double s = (double)p[i] * vol;
                        if (s > 32767.0) s = 32767.0;
                        if (s < -32768.0) s = -32768.0;
                        p[i] = (int16_t)s;
                    }
                }
            }

            ma_mutex_unlock(&pEngine->engine_lock);
            return framesRead;
        }

        // ────────────────────────────────────────────────────────────────────
        // PATH B: MediaCodec f32 — scratch buffer + convert
        // ────────────────────────────────────────────────────────────────────
        size_t scratch_floats = (size_t)frame_count * channels;
        float *scratch = (float *)malloc(scratch_floats * sizeof(float));
        if (scratch == NULL) {
            ma_mutex_unlock(&pEngine->engine_lock);
            return -1;
        }

        long long framesRead = mc_decoder_read_frames(
            pEngine->mc_dec, scratch, frame_count);
        if (framesRead == 0) {
            free(scratch);
            pEngine->is_completed = true;
            ma_mutex_unlock(&pEngine->engine_lock);
            return -1;
        }
        if (framesRead < 0) {
            free(scratch);
            ma_mutex_unlock(&pEngine->engine_lock);
            return -1;
        }

        // Apply EQ in float domain when not bit-perfect (preserves
        // precision). Skipped in bit-perfect mode for true bypass.
        if (!pEngine->bit_perfect) {
            for (int i = 0; i < 10; ++i) {
                ma_biquad_process_pcm_frames(&pEngine->eq_bands[i],
                                             scratch, scratch, framesRead);
            }
        }

        // Apply volume in float domain (always — non-destructive in f32).
        if (pEngine->volume < 0.999f) {
            float vol = pEngine->volume;
            for (size_t i = 0; i < (size_t)(framesRead * channels); ++i) {
                scratch[i] *= vol;
            }
        }

        // Convert f32 → output bit depth.
        //
        // Use lrintf() for rounding (not truncation). The C cast (int32_t)
        // truncates toward zero, creating correlated quantization distortion
        // that sensitive IEMs can pick up as a subtle noise floor. lrintf()
        // rounds to nearest even, distributing the error symmetrically.
        //
        // Scale factor matches MediaCodec's normalization: the system
        // divides by 2^(bits-1), so we multiply by the same value.
        size_t total_samples = (size_t)(framesRead * channels);
        if (bd == 24) {
            ma_uint8 *p = (ma_uint8 *)output_buffer;
            const float scale = 8388608.0f; // 2^23
            for (size_t i = 0; i < total_samples; ++i) {
                float s = scratch[i];
                if (s > 1.0f) s = 1.0f;
                if (s < -1.0f) s = -1.0f;
                int32_t sample24 = (int32_t)lrintf(s * scale);
                if (sample24 > 8388607) sample24 = 8388607;
                if (sample24 < -8388608) sample24 = -8388608;
                p[i*3]   = (ma_uint8)(sample24 & 0xFF);
                p[i*3+1] = (ma_uint8)((sample24 >> 8) & 0xFF);
                p[i*3+2] = (ma_uint8)((sample24 >> 16) & 0xFF);
            }
        } else {
            int16_t *p = (int16_t *)output_buffer;
            const float scale = 32768.0f; // 2^15
            for (size_t i = 0; i < total_samples; ++i) {
                float s = scratch[i];
                if (s > 1.0f) s = 1.0f;
                if (s < -1.0f) s = -1.0f;
                int32_t sample16 = (int32_t)lrintf(s * scale);
                if (sample16 > 32767) sample16 = 32767;
                if (sample16 < -32768) sample16 = -32768;
                p[i] = (int16_t)sample16;
            }
        }

        free(scratch);
        ma_mutex_unlock(&pEngine->engine_lock);
        return framesRead;
    }
#endif

    ma_mutex_lock(&pEngine->engine_lock);
    ma_uint64 framesRead = 0;
    ma_result result = ma_decoder_read_pcm_frames(
        &pEngine->decoder, output_buffer, frame_count, &framesRead);

    if (result == MA_AT_END || framesRead == 0) {
        pEngine->is_completed = true;
        ma_mutex_unlock(&pEngine->engine_lock);
        return framesRead == 0 ? -1 : (long long)framesRead;
    }

    // EQ + volume only make sense for f32 frames (biquad is f32 here).
    // For non-f32 (s16/s24/s32) we currently apply only volume to keep parity
    // with the WASAPI bit-perfect Windows path.
    ma_format fmt = pEngine->decoder.outputFormat;
    ma_uint32 channels = pEngine->decoder.outputChannels;

    if (pEngine->bit_perfect) {
        // Volume only — same per-format scaling as data_callback().
        if (pEngine->volume < 0.999f) {
            double vol = (double)pEngine->volume;
            if (fmt == ma_format_s16) {
                ma_int16* p = (ma_int16*)output_buffer;
                for (ma_uint64 i = 0; i < framesRead * channels; ++i) {
                    double s = (double)p[i] * vol;
                    if (s > 32767.0) s = 32767.0;
                    if (s < -32768.0) s = -32768.0;
                    p[i] = (ma_int16)s;
                }
            } else if (fmt == ma_format_s24) {
                ma_uint8* p = (ma_uint8*)output_buffer;
                for (ma_uint64 i = 0; i < framesRead * channels; ++i) {
                    ma_int32 s24 = (p[i*3] | (p[i*3+1] << 8) | (p[i*3+2] << 16));
                    if (s24 & 0x00800000) s24 |= 0xFF000000;
                    double s = (double)s24 * vol;
                    if (s > 8388607.0) s = 8388607.0;
                    if (s < -8388608.0) s = -8388608.0;
                    ma_int32 r = (ma_int32)s;
                    p[i*3]   = (ma_uint8)(r & 0xFF);
                    p[i*3+1] = (ma_uint8)((r >> 8) & 0xFF);
                    p[i*3+2] = (ma_uint8)((r >> 16) & 0xFF);
                }
            } else if (fmt == ma_format_s32) {
                ma_int32* p = (ma_int32*)output_buffer;
                for (ma_uint64 i = 0; i < framesRead * channels; ++i) {
                    double s = (double)p[i] * vol;
                    if (s > 2147483647.0) s = 2147483647.0;
                    if (s < -2147483648.0) s = -2147483648.0;
                    p[i] = (ma_int32)s;
                }
            } else if (fmt == ma_format_f32) {
                float* p = (float*)output_buffer;
                for (ma_uint64 i = 0; i < framesRead * channels; ++i) {
                    p[i] *= (float)vol;
                }
            }
        }
    } else if (fmt == ma_format_f32) {
        // Full DSP: EQ chain + volume (only when f32).
        for (int i = 0; i < 10; ++i) {
            ma_biquad_process_pcm_frames(&pEngine->eq_bands[i],
                                         output_buffer, output_buffer, framesRead);
        }
        float* p = (float*)output_buffer;
        for (ma_uint64 i = 0; i < framesRead * channels; ++i) {
            p[i] *= pEngine->volume;
        }
    }
    // Non-bitperfect with non-f32 format: leave PCM untouched. The host should
    // request f32 (bit_depth_hint=0) when EQ is desired.

    ma_mutex_unlock(&pEngine->engine_lock);
    return (long long)framesRead;
}

ENGINE_API int Engine_GetRawFormat(AudioHandle handle,
                                   int* out_sample_rate,
                                   int* out_channels,
                                   int* out_bit_depth) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL || !pEngine->has_raw_sink) return -1;

    if (out_sample_rate) *out_sample_rate = pEngine->raw_sample_rate;
    if (out_channels)    *out_channels    = pEngine->raw_channels;
    if (out_bit_depth)   *out_bit_depth   = pEngine->raw_bit_depth;
    return 0;
}

ENGINE_API void Engine_ReleaseRawSink(AudioHandle handle) {
    AudioEngine* pEngine = (AudioEngine*)handle;
    if (pEngine == NULL || !pEngine->has_raw_sink) return;

    ma_mutex_lock(&pEngine->engine_lock);
#ifdef __ANDROID__
    if (pEngine->mc_dec != NULL) {
        mc_decoder_close(pEngine->mc_dec);
        pEngine->mc_dec = NULL;
    } else {
        ma_decoder_uninit(&pEngine->decoder);
    }
#else
    ma_decoder_uninit(&pEngine->decoder);
#endif
    pEngine->has_raw_sink = false;
    pEngine->is_completed = false;
    pEngine->raw_sample_rate = 0;
    pEngine->raw_channels = 0;
    pEngine->raw_bit_depth = 0;
    ma_mutex_unlock(&pEngine->engine_lock);
}
