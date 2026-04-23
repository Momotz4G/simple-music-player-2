#define MINIAUDIO_IMPLEMENTATION
#include "include/miniaudio.h"
#include <stdio.h>

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

    FILE* f = fopen("wasapi_devices.txt", "w");
    if (!f) return -1;

    fprintf(f, "--- WASAPI PLAYBACK DEVICES ---\n");
    for (ma_uint32 i = 0; i < playbackCount; ++i) {
        fprintf(f, "[%d] %s\n", i, pPlaybackInfos[i].name);
        
        // Output the specific GUID or ID
        fprintf(f, "    ID (wchar_t): %ws\n", (wchar_t*)&pPlaybackInfos[i].id.wasapi);
    }
    
    fclose(f);
    ma_context_uninit(&context);
    return 0;
}
