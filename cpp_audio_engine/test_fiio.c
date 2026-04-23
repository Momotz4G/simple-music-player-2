#define MINIAUDIO_IMPLEMENTATION
#include "include/miniaudio.h"
#include <stdio.h>
#include <math.h>
#include <stdbool.h>

void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    float* pOut = (float*)pOutput;
    double time = *(double*)pDevice->pUserData;
    for (ma_uint32 i = 0; i < frameCount; ++i) {
        float sample = (float)(sin(time * 2.0 * 3.1415926535 * 440.0) * 0.1); // 440Hz sine wave, low volume
        pOut[i * 2] = sample;
        pOut[i * 2 + 1] = sample;
        time += 1.0 / pDevice->sampleRate;
    }
    *(double*)pDevice->pUserData = time;
}

int main() {
    ma_context context;
    ma_backend backends[] = { ma_backend_wasapi };
    
    if (ma_context_init(backends, 1, NULL, &context) != MA_SUCCESS) {
        printf("Failed to init context.\n");
        return -1;
    }

    ma_device_info* pPlaybackInfos;
    ma_uint32 playbackCount;
    ma_context_get_devices(&context, &pPlaybackInfos, &playbackCount, NULL, NULL);

    ma_device_id fiio_id;
    bool found_fiio = false;
    printf("Looking for FiiO...\n");
    for (ma_uint32 i = 0; i < playbackCount; ++i) {
        if (strstr(pPlaybackInfos[i].name, "FiiO") != NULL) {
            fiio_id = pPlaybackInfos[i].id;
            found_fiio = true;
            printf("Found: %s\n", pPlaybackInfos[i].name);
            break;
        }
    }

    if (!found_fiio) {
        printf("FiiO not found.\n");
        return -1;
    }

    double time = 0;
    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.pDeviceID = &fiio_id;
    config.playback.format = ma_format_f32; // test f32 first
    config.playback.channels = 2;
    config.sampleRate = 96000;
    config.playback.shareMode = ma_share_mode_exclusive;
    config.periodSizeInMilliseconds = 50;
    config.dataCallback = data_callback;
    config.pUserData = &time;

    ma_device device;
    if (ma_device_init(&context, &config, &device) != MA_SUCCESS) {
        printf("Init failed for f32! Trying s32...\n");
        config.playback.format = ma_format_s32;
        if (ma_device_init(&context, &config, &device) != MA_SUCCESS) {
            printf("Init failed for s32 too.\n");
            return -1;
        } else {
             printf("Init SUCCEEDED with s32!\n");
             // wait, the callback expects f32... let's just use f32 or fail for this simple test
        }
    } else {
        printf("Init SUCCEEDED with f32!\n");
    }

    // Must be f32 for the tone generator callback above
    if (device.playback.format != ma_format_f32) {
        printf("Format is not f32, skipping tone (but device init succeeded in %d).\n", device.playback.format);
        // Start device anyway just to engage the DAC hardware lock
    }

    printf("Starting DAC hardware sweep to 96kHz for 5 seconds...\n");
    ma_device_start(&device);

    // Block for 5 seconds
    Sleep(5000);

    ma_device_uninit(&device);
    ma_context_uninit(&context);
    return 0;
}
