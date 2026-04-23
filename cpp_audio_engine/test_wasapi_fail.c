#define MINIAUDIO_IMPLEMENTATION
#include "include/miniaudio.h"
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    (void)pDevice; (void)pOutput; (void)pInput; (void)frameCount;
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

    ma_device_id* pDeviceId = NULL;
    for (ma_uint32 i = 0; i < playbackCount; ++i) {
        // Find default or FiiO
        if (pPlaybackInfos[i].isDefault) {
            printf("Default Device: %s\n", pPlaybackInfos[i].name);
            pDeviceId = &pPlaybackInfos[i].id;
        }
    }

    // Try to init what failed
    ma_device_config deviceConfig = ma_device_config_init(ma_device_type_playback);
    deviceConfig.playback.pDeviceID = pDeviceId;
    deviceConfig.playback.channels = 2;
    deviceConfig.sampleRate = 96000;
    deviceConfig.dataCallback = data_callback;
    deviceConfig.pUserData = NULL;
    deviceConfig.playback.shareMode = ma_share_mode_exclusive;
    
    deviceConfig.wasapi.noAutoConvertSRC = MA_TRUE;
    deviceConfig.wasapi.noHardwareOffloading = MA_TRUE;
    deviceConfig.wasapi.noAutoStreamRouting = MA_TRUE;
    deviceConfig.periodSizeInMilliseconds = 50;
    deviceConfig.performanceProfile = ma_performance_profile_conservative;

    ma_format exclusiveFormats[] = { ma_format_s32, ma_format_s24, ma_format_f32, ma_format_s16 };
    printf("Testing STRICT EXCLUSIVE:\n");
    for (int i = 0; i < 4; i++) {
        deviceConfig.playback.format = exclusiveFormats[i];
        ma_device device;
        ma_result res = ma_device_init(&context, &deviceConfig, &device);
        printf("  Format %d -> Result: %d\n", exclusiveFormats[i], res);
        if (res == MA_SUCCESS) ma_device_uninit(&device);
    }

    printf("Testing LENIENT EXCLUSIVE:\n");
    deviceConfig.wasapi.noAutoConvertSRC = MA_FALSE;
    for (int i = 0; i < 4; i++) {
        deviceConfig.playback.format = exclusiveFormats[i];
        ma_device device;
        ma_result res = ma_device_init(&context, &deviceConfig, &device);
        printf("  Format %d -> Result: %d\n", exclusiveFormats[i], res);
        if (res == MA_SUCCESS) ma_device_uninit(&device);
    }

    // Try without periodSize requirement
    printf("Testing STRICT with NO PERIOD REQUIREMENT:\n");
    deviceConfig.wasapi.noAutoConvertSRC = MA_TRUE;
    deviceConfig.periodSizeInMilliseconds = 0;
    deviceConfig.performanceProfile = ma_performance_profile_low_latency;
    for (int i = 0; i < 4; i++) {
        deviceConfig.playback.format = exclusiveFormats[i];
        ma_device device;
        ma_result res = ma_device_init(&context, &deviceConfig, &device);
        printf("  Format %d -> Result: %d\n", exclusiveFormats[i], res);
        if (res == MA_SUCCESS) ma_device_uninit(&device);
    }

    ma_context_uninit(&context);
    return 0;
}
