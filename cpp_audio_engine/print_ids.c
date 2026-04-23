#define MINIAUDIO_IMPLEMENTATION
#include "include/miniaudio.h"
#include <stdio.h>
#include <string.h>

int main() {
    ma_context context;
    ma_backend backends[] = { ma_backend_wasapi };
    
    if (ma_context_init(backends, 1, NULL, &context) != MA_SUCCESS) {
        printf("Failed to init context.\n");
        return -1;
    }

    ma_device_info* pInfos;
    ma_uint32 count;
    ma_context_get_devices(&context, &pInfos, &count, NULL, NULL);

    printf("Miniaudio Available WASAPI Devices:\n");
    for (ma_uint32 i = 0; i < count; ++i) {
        wprintf(L"Name: %S\n  Format ID (wasapi): %s\n", pInfos[i].name, pInfos[i].id.wasapi);
    }

    ma_context_uninit(&context);
    return 0;
}
