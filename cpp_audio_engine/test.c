#define MINIAUDIO_IMPLEMENTATION
#include "include/miniaudio.h"
#include <stdio.h>

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
    if (ma_context_get_devices(&context, &pPlaybackInfos, &playbackCount, NULL, NULL) != MA_SUCCESS) {
        printf("Failed to get devices.\n");
        return -1;
    }

    printf("--- PLAYBACK DEVICES ---\n");
    for (ma_uint32 i = 0; i < playbackCount; ++i) {
        printf("%d: %s\n", i, pPlaybackInfos[i].name);
        
        // Try all formats at 96kHz Exclusive
        ma_format formats[] = { ma_format_s16, ma_format_s24, ma_format_s32, ma_format_f32 };
        const char* formatNames[] = { "s16", "s24", "s32", "f32" };
        
        for (int f = 0; f < 4; ++f) {
            ma_device_config config = ma_device_config_init(ma_device_type_playback);
            config.playback.pDeviceID = &pPlaybackInfos[i].id;
            config.playback.format = formats[f];
            config.sampleRate = 96000;
            config.playback.shareMode = ma_share_mode_exclusive;
            config.dataCallback = data_callback;
            
            ma_device device;
            if (ma_device_init(&context, &config, &device) == MA_SUCCESS) {
                printf("  [SUCCESS] Exclusive 96kHz %s supported!\n", formatNames[f]);
                ma_device_uninit(&device);
            } else {
                printf("  [FAILED]  Exclusive 96kHz %s\n", formatNames[f]);
            }
        }
    }

    ma_context_uninit(&context);
    return 0;
}
