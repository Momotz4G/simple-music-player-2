/*
 * mf_decoder.cpp — Windows Media Foundation decoding backend for miniaudio.
 *
 * Implements a custom ma_data_source that uses IMFSourceReader to decode
 * M4A/AAC (and any other WMF-supported format like WMA, MP4 audio, etc.)
 * into raw PCM for consumption by the miniaudio pipeline.
 *
 * Compiled as C++ for COM convenience, but exposes a C-linkage vtable.
 */

#ifdef _WIN32

#define COBJMACROS
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mferror.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "miniaudio.h"
#include "mf_decoder.h"

#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")

/* ============================================================
   Global MF startup / shutdown (lazy — called on first use)
   ============================================================ */
static int g_mfInitCount = 0;
static int g_mfStartedOk = 0;

/* Ensures MFStartup is called exactly once, on first actual decode attempt. */
static void mf_ensure_started(void) {
    if (g_mfStartedOk) return;
    HRESULT hr = MFStartup(MF_VERSION, MFSTARTUP_LITE);
    if (SUCCEEDED(hr)) {
        g_mfStartedOk = 1;
    } else {
        fprintf(stderr, "[MF Decoder] MFStartup failed: 0x%08lX\n", hr);
    }
}

void mf_decoder_global_init(void) {
    /* No-op — initialization is deferred to first decode attempt
       to avoid blocking Flutter's message pump at startup. */
    g_mfInitCount++;
}

void mf_decoder_global_uninit(void) {
    g_mfInitCount--;
    if (g_mfInitCount <= 0) {
        if (g_mfStartedOk) {
            MFShutdown();
            g_mfStartedOk = 0;
        }
        g_mfInitCount = 0;
    }
}

/* ============================================================
   MF Data Source — wraps IMFSourceReader as a ma_data_source
   ============================================================ */
typedef struct {
    ma_data_source_base ds;       /* Must be first member */
    IMFSourceReader*    pReader;
    ma_format           format;
    ma_uint32           channels;
    ma_uint32           sampleRate;
    ma_uint32           bytesPerFrame;
    ma_uint64           totalFrames;
    ma_uint64           cursor;   /* Current position in PCM frames */

    /* Leftover buffer from partial MF sample reads */
    ma_uint8*           pLeftover;
    ma_uint32           leftoverSize;     /* Bytes remaining */
    ma_uint32           leftoverOffset;   /* Read offset into leftover */
} mf_data_source;

/* Forward declarations for the ma_data_source_vtable */
static ma_result mf_ds_read(ma_data_source* pDS, void* pFramesOut, ma_uint64 frameCount, ma_uint64* pFramesRead);
static ma_result mf_ds_seek(ma_data_source* pDS, ma_uint64 frameIndex);
static ma_result mf_ds_get_data_format(ma_data_source* pDS, ma_format* pFormat, ma_uint32* pChannels, ma_uint32* pSampleRate, ma_channel* pChannelMap, size_t channelMapCap);
static ma_result mf_ds_get_cursor(ma_data_source* pDS, ma_uint64* pCursor);
static ma_result mf_ds_get_length(ma_data_source* pDS, ma_uint64* pLength);

static ma_data_source_vtable g_mf_ds_vtable = {
    mf_ds_read,
    mf_ds_seek,
    mf_ds_get_data_format,
    mf_ds_get_cursor,
    mf_ds_get_length,
    NULL, /* onSetLooping */
    0     /* flags */
};

/* ---- Helpers ---- */

static ma_uint64 mf_get_duration_in_frames(IMFSourceReader* pReader, ma_uint32 sampleRate) {
    PROPVARIANT var;
    PropVariantInit(&var);

    HRESULT hr = pReader->GetPresentationAttribute(
        (DWORD)MF_SOURCE_READER_MEDIASOURCE, MF_PD_DURATION, &var);

    if (SUCCEEDED(hr) && var.vt == VT_UI8) {
        /* Duration is in 100-nanosecond units */
        ma_uint64 durationHns = var.uhVal.QuadPart;
        PropVariantClear(&var);
        return (ma_uint64)((double)durationHns / 10000000.0 * sampleRate);
    }

    PropVariantClear(&var);
    return 0; /* Unknown length */
}

static ma_result mf_init_reader_from_file_w(const wchar_t* pFilePath, mf_data_source* pMF,
                                             const ma_decoding_backend_config* pConfig) {
    HRESULT hr;
    IMFSourceReader* pReader = NULL;

    hr = MFCreateSourceReaderFromURL(pFilePath, NULL, &pReader);
    if (FAILED(hr)) {
        return MA_ERROR;
    }

    /* Configure the reader to output PCM audio */
    IMFMediaType* pPartialType = NULL;
    hr = MFCreateMediaType(&pPartialType);
    if (FAILED(hr)) { pReader->Release(); return MA_ERROR; }

    pPartialType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
    pPartialType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);

    /* Request f32 output for best quality (matches miniaudio's preferred DSP format) */
    /* WMF will convert AAC/M4A → PCM for us */
    ma_format targetFormat = ma_format_f32;
    UINT32 bitsPerSample = 32;

    if (pConfig != NULL && pConfig->preferredFormat != ma_format_unknown) {
        switch (pConfig->preferredFormat) {
            case ma_format_s16: bitsPerSample = 16; targetFormat = ma_format_s16; break;
            case ma_format_s24: bitsPerSample = 24; targetFormat = ma_format_s24; break;
            case ma_format_s32: bitsPerSample = 32; targetFormat = ma_format_s32;
                                pPartialType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM); break;
            case ma_format_f32: bitsPerSample = 32; targetFormat = ma_format_f32;
                                pPartialType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_Float); break;
            default:            bitsPerSample = 32; targetFormat = ma_format_f32;
                                pPartialType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_Float); break;
        }
    } else {
        pPartialType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_Float);
    }

    pPartialType->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, bitsPerSample);

    hr = pReader->SetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM,
                                       NULL, pPartialType);
    pPartialType->Release();
    if (FAILED(hr)) { pReader->Release(); return MA_ERROR; }

    /* Select only the audio stream */
    pReader->SetStreamSelection((DWORD)MF_SOURCE_READER_ALL_STREAMS, FALSE);
    pReader->SetStreamSelection((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, TRUE);

    /* Read back the actual output format */
    IMFMediaType* pOutputType = NULL;
    hr = pReader->GetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, &pOutputType);
    if (FAILED(hr)) { pReader->Release(); return MA_ERROR; }

    UINT32 channels = 0, sampleRate = 0, bits = 0;
    pOutputType->GetUINT32(MF_MT_AUDIO_NUM_CHANNELS, &channels);
    pOutputType->GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, &sampleRate);
    pOutputType->GetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, &bits);

    /* Detect if MF gave us float or integer */
    GUID subType = {0};
    pOutputType->GetGUID(MF_MT_SUBTYPE, &subType);
    if (IsEqualGUID(subType, MFAudioFormat_Float)) {
        targetFormat = ma_format_f32;
    } else {
        /* PCM integer — use bits to determine format */
        switch (bits) {
            case 16: targetFormat = ma_format_s16; break;
            case 24: targetFormat = ma_format_s24; break;
            case 32: targetFormat = ma_format_s32; break;
            default: targetFormat = ma_format_s16; break;
        }
    }

    pOutputType->Release();

    if (channels == 0 || sampleRate == 0 || bits == 0) {
        pReader->Release();
        return MA_ERROR;
    }

    /* Fill in our data source struct */
    pMF->pReader       = pReader;
    pMF->format        = targetFormat;
    pMF->channels      = channels;
    pMF->sampleRate    = sampleRate;
    pMF->bytesPerFrame = (bits / 8) * channels;
    pMF->totalFrames   = mf_get_duration_in_frames(pReader, sampleRate);
    pMF->cursor        = 0;
    pMF->pLeftover      = NULL;
    pMF->leftoverSize   = 0;
    pMF->leftoverOffset = 0;

    return MA_SUCCESS;
}

/* ---- Data Source Implementation ---- */

static ma_result mf_ds_read(ma_data_source* pDS, void* pFramesOut, ma_uint64 frameCount, ma_uint64* pFramesRead) {
    mf_data_source* pMF = (mf_data_source*)pDS;
    if (pMF == NULL || pMF->pReader == NULL) return MA_INVALID_ARGS;

    ma_uint64 totalFramesRead = 0;
    ma_uint8* pOut = (ma_uint8*)pFramesOut;

    while (totalFramesRead < frameCount) {
        /* Drain leftover buffer first */
        if (pMF->leftoverSize > 0) {
            ma_uint64 framesRemaining = frameCount - totalFramesRead;
            ma_uint32 leftoverFrames = pMF->leftoverSize / pMF->bytesPerFrame;
            ma_uint32 framesToCopy = (ma_uint32)(framesRemaining < leftoverFrames ? framesRemaining : leftoverFrames);
            ma_uint32 bytesToCopy = framesToCopy * pMF->bytesPerFrame;

            if (pOut != NULL) {
                memcpy(pOut + totalFramesRead * pMF->bytesPerFrame,
                       pMF->pLeftover + pMF->leftoverOffset,
                       bytesToCopy);
            }

            totalFramesRead += framesToCopy;
            pMF->leftoverOffset += bytesToCopy;
            pMF->leftoverSize -= bytesToCopy;

            if (pMF->leftoverSize == 0) {
                free(pMF->pLeftover);
                pMF->pLeftover = NULL;
                pMF->leftoverOffset = 0;
            }
            continue;
        }

        /* Read next sample from MF */
        DWORD flags = 0;
        IMFSample* pSample = NULL;
        HRESULT hr = pMF->pReader->ReadSample(
            (DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM,
            0, NULL, &flags, NULL, &pSample);

        if (FAILED(hr) || (flags & MF_SOURCE_READERF_ENDOFSTREAM)) {
            if (pSample) pSample->Release();
            break; /* End of stream */
        }

        if (pSample == NULL) continue; /* No sample yet, try again */

        IMFMediaBuffer* pBuffer = NULL;
        hr = pSample->ConvertToContiguousBuffer(&pBuffer);
        if (FAILED(hr)) { pSample->Release(); continue; }

        BYTE* pAudioData = NULL;
        DWORD audioDataLen = 0;
        hr = pBuffer->Lock(&pAudioData, NULL, &audioDataLen);
        if (FAILED(hr)) { pBuffer->Release(); pSample->Release(); continue; }

        ma_uint32 sampleFrames = audioDataLen / pMF->bytesPerFrame;
        ma_uint64 framesRemaining = frameCount - totalFramesRead;

        if (sampleFrames <= framesRemaining) {
            /* All frames fit directly into output */
            if (pOut != NULL) {
                memcpy(pOut + totalFramesRead * pMF->bytesPerFrame,
                       pAudioData,
                       sampleFrames * pMF->bytesPerFrame);
            }
            totalFramesRead += sampleFrames;
        } else {
            /* Partial fit — copy what we can, buffer the rest */
            ma_uint32 framesToCopy = (ma_uint32)framesRemaining;
            ma_uint32 leftoverFrames = sampleFrames - framesToCopy;
            ma_uint32 leftoverBytes = leftoverFrames * pMF->bytesPerFrame;

            if (pOut != NULL) {
                memcpy(pOut + totalFramesRead * pMF->bytesPerFrame,
                       pAudioData,
                       framesToCopy * pMF->bytesPerFrame);
            }
            totalFramesRead += framesToCopy;

            /* Store leftover */
            pMF->pLeftover = (ma_uint8*)malloc(leftoverBytes);
            if (pMF->pLeftover != NULL) {
                memcpy(pMF->pLeftover,
                       pAudioData + framesToCopy * pMF->bytesPerFrame,
                       leftoverBytes);
                pMF->leftoverSize = leftoverBytes;
                pMF->leftoverOffset = 0;
            }
        }

        pBuffer->Unlock();
        pBuffer->Release();
        pSample->Release();
    }

    pMF->cursor += totalFramesRead;

    if (pFramesRead) *pFramesRead = totalFramesRead;

    return (totalFramesRead == 0) ? MA_AT_END : MA_SUCCESS;
}

static ma_result mf_ds_seek(ma_data_source* pDS, ma_uint64 frameIndex) {
    mf_data_source* pMF = (mf_data_source*)pDS;
    if (pMF == NULL || pMF->pReader == NULL) return MA_INVALID_ARGS;

    /* Convert frames to 100-nanosecond units */
    LONGLONG posHns = (LONGLONG)((double)frameIndex / pMF->sampleRate * 10000000.0);

    PROPVARIANT var;
    PropVariantInit(&var);
    var.vt = VT_I8;
    var.hVal.QuadPart = posHns;

    HRESULT hr = pMF->pReader->SetCurrentPosition(GUID_NULL, var);
    PropVariantClear(&var);

    if (FAILED(hr)) return MA_ERROR;

    /* Clear leftover buffer on seek */
    if (pMF->pLeftover) {
        free(pMF->pLeftover);
        pMF->pLeftover = NULL;
        pMF->leftoverSize = 0;
        pMF->leftoverOffset = 0;
    }

    pMF->cursor = frameIndex;
    return MA_SUCCESS;
}

static ma_result mf_ds_get_data_format(ma_data_source* pDS, ma_format* pFormat, ma_uint32* pChannels, ma_uint32* pSampleRate, ma_channel* pChannelMap, size_t channelMapCap) {
    mf_data_source* pMF = (mf_data_source*)pDS;
    if (pMF == NULL) return MA_INVALID_ARGS;

    if (pFormat)     *pFormat     = pMF->format;
    if (pChannels)   *pChannels   = pMF->channels;
    if (pSampleRate) *pSampleRate = pMF->sampleRate;

    if (pChannelMap != NULL) {
        ma_channel_map_init_standard(ma_standard_channel_map_microsoft, pChannelMap, channelMapCap, pMF->channels);
    }

    return MA_SUCCESS;
}

static ma_result mf_ds_get_cursor(ma_data_source* pDS, ma_uint64* pCursor) {
    mf_data_source* pMF = (mf_data_source*)pDS;
    if (pMF == NULL) return MA_INVALID_ARGS;
    if (pCursor) *pCursor = pMF->cursor;
    return MA_SUCCESS;
}

static ma_result mf_ds_get_length(ma_data_source* pDS, ma_uint64* pLength) {
    mf_data_source* pMF = (mf_data_source*)pDS;
    if (pMF == NULL) return MA_INVALID_ARGS;
    if (pLength) *pLength = pMF->totalFrames;
    return (pMF->totalFrames > 0) ? MA_SUCCESS : MA_NOT_IMPLEMENTED;
}

/* ============================================================
   Decoding Backend VTable Implementation
   ============================================================ */

/* Returns true if the file extension requires WMF decoding.
   Formats that miniaudio handles natively (MP3, FLAC, WAV, OGG)
   must NOT be intercepted — they're faster through built-in decoders
   and attempting them here would trigger MFStartup unnecessarily. */
static int mf_is_wmf_extension_w(const wchar_t* pFilePath) {
    if (pFilePath == NULL) return 0;
    const wchar_t* dot = wcsrchr(pFilePath, L'.');
    if (dot == NULL) return 0;
    return (_wcsicmp(dot, L".m4a") == 0 ||
            _wcsicmp(dot, L".aac") == 0 ||
            _wcsicmp(dot, L".wma") == 0 ||
            _wcsicmp(dot, L".mp4") == 0 ||
            _wcsicmp(dot, L".m4b") == 0 ||
            _wcsicmp(dot, L".opus") == 0 ||
            _wcsicmp(dot, L".ogg") == 0);
}

static int mf_is_wmf_extension(const char* pFilePath) {
    if (pFilePath == NULL) return 0;
    const char* dot = strrchr(pFilePath, '.');
    if (dot == NULL) return 0;
    return (_stricmp(dot, ".m4a") == 0 ||
            _stricmp(dot, ".aac") == 0 ||
            _stricmp(dot, ".wma") == 0 ||
            _stricmp(dot, ".mp4") == 0 ||
            _stricmp(dot, ".m4b") == 0 ||
            _stricmp(dot, ".opus") == 0 ||
            _stricmp(dot, ".ogg") == 0);
}

static ma_result mf_backend_init_file_w(void* pUserData, const wchar_t* pFilePath,
                                         const ma_decoding_backend_config* pConfig,
                                         const ma_allocation_callbacks* pAllocationCallbacks,
                                         ma_data_source** ppBackend) {
    (void)pUserData;
    (void)pAllocationCallbacks;

    if (ppBackend == NULL) return MA_INVALID_ARGS;

    /* Fast reject: only handle formats that miniaudio can't decode natively.
       This avoids calling MFStartup for MP3/FLAC/WAV/OGG files. */
    if (!mf_is_wmf_extension_w(pFilePath)) {
        return MA_NOT_IMPLEMENTED;
    }

    /* Lazy MF init — only start Media Foundation when we actually need it */
    mf_ensure_started();
    if (!g_mfStartedOk) return MA_ERROR;

    mf_data_source* pMF = (mf_data_source*)calloc(1, sizeof(mf_data_source));
    if (pMF == NULL) return MA_OUT_OF_MEMORY;

    /* Initialize the base data source */
    ma_data_source_config dsConfig = ma_data_source_config_init();
    dsConfig.vtable = &g_mf_ds_vtable;
    ma_result result = ma_data_source_init(&dsConfig, &pMF->ds);
    if (result != MA_SUCCESS) {
        free(pMF);
        return result;
    }

    result = mf_init_reader_from_file_w(pFilePath, pMF, pConfig);
    if (result != MA_SUCCESS) {
        ma_data_source_uninit(&pMF->ds);
        free(pMF);
        return result;
    }

    *ppBackend = (ma_data_source*)pMF;
    return MA_SUCCESS;
}

static ma_result mf_backend_init_file(void* pUserData, const char* pFilePath,
                                       const ma_decoding_backend_config* pConfig,
                                       const ma_allocation_callbacks* pAllocationCallbacks,
                                       ma_data_source** ppBackend) {
    /* Fast reject before doing any UTF-8→wide conversion */
    if (!mf_is_wmf_extension(pFilePath)) {
        return MA_NOT_IMPLEMENTED;
    }

    /* Convert UTF-8 to wide string */
    int wlen = MultiByteToWideChar(CP_UTF8, 0, pFilePath, -1, NULL, 0);
    if (wlen <= 0) return MA_ERROR;

    wchar_t* wpath = (wchar_t*)malloc(wlen * sizeof(wchar_t));
    if (wpath == NULL) return MA_OUT_OF_MEMORY;

    MultiByteToWideChar(CP_UTF8, 0, pFilePath, -1, wpath, wlen);
    ma_result result = mf_backend_init_file_w(pUserData, wpath, pConfig, pAllocationCallbacks, ppBackend);
    free(wpath);
    return result;
}

static void mf_backend_uninit(void* pUserData, ma_data_source* pBackend,
                               const ma_allocation_callbacks* pAllocationCallbacks) {
    (void)pUserData;
    (void)pAllocationCallbacks;

    mf_data_source* pMF = (mf_data_source*)pBackend;
    if (pMF == NULL) return;

    if (pMF->pLeftover) {
        free(pMF->pLeftover);
        pMF->pLeftover = NULL;
    }

    if (pMF->pReader) {
        pMF->pReader->Release();
        pMF->pReader = NULL;
    }

    ma_data_source_uninit(&pMF->ds);
    free(pMF);
}

/* The global vtable exposed to audio_engine.c */
extern "C" ma_decoding_backend_vtable g_ma_vtable_wmf = {
    NULL,                    /* onInit (from data source — not needed, we use file paths) */
    mf_backend_init_file,    /* onInitFile */
    mf_backend_init_file_w,  /* onInitFileW */
    NULL,                    /* onInitMemory */
    mf_backend_uninit        /* onUninit */
};

#endif /* _WIN32 */
