/*
 * mf_decoder.h — Windows Media Foundation custom decoding backend for miniaudio.
 *
 * Adds M4A/AAC (and any other WMF-supported format) decoding to the C++ audio engine.
 * Uses Windows' built-in Media Foundation pipeline — no extra DLLs required.
 *
 * Usage:
 *   #include "mf_decoder.h"
 *
 *   // When creating a decoder config, register the WMF backend:
 *   ma_decoding_backend_vtable* pCustomBackends[] = { &g_ma_vtable_wmf };
 *   decoderConfig.ppCustomBackendVTables = pCustomBackends;
 *   decoderConfig.customBackendCount     = 1;
 */

#ifndef MF_DECODER_H
#define MF_DECODER_H

#include "miniaudio.h"

#ifdef _WIN32

#ifdef __cplusplus
extern "C" {
#endif

/* The vtable that miniaudio will call for formats it can't handle natively. */
extern ma_decoding_backend_vtable g_ma_vtable_wmf;

/* Must be called once before using the backend (pairs with mf_decoder_global_uninit). */
void mf_decoder_global_init(void);
void mf_decoder_global_uninit(void);

#ifdef __cplusplus
}
#endif

#endif /* _WIN32 */

#endif /* MF_DECODER_H */
