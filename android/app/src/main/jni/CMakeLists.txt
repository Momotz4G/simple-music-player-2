cmake_minimum_required(VERSION 3.10)

project(usb_iso_jni)

# Resolve project root (3 levels up from app/src/main/jni → app/src/main →
# app/src → app → android → repo root) so we can locate cpp_audio_engine/.
get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CPP_ENGINE_DIR "${REPO_ROOT}/cpp_audio_engine")

# ============================================================================
# libusb_iso_jni.so — isochronous USB audio transfer JNI (existing)
# ============================================================================
add_library(usb_iso_jni SHARED usb_iso_jni.c)
target_link_libraries(usb_iso_jni log)
set_target_properties(usb_iso_jni PROPERTIES C_STANDARD 11)

# ============================================================================
# libaudio_engine.so — custom C audio engine (cross-platform with Windows DLL)
# Built directly here (rather than via add_subdirectory) so we don't fight the
# top-level cpp_audio_engine/CMakeLists.txt when Gradle invokes us.
#
# Android sources include the MediaCodec backend so AAC/ALAC files inside
# .m4a / .mp4 containers can be decoded — miniaudio doesn't ship those.
#
# ALAC fallback (Android 7-11): When the system has no ALAC MediaCodec decoder,
# we use the vendored Apple ALAC reference decoder (Apache-2.0). The fallback
# pipeline is: AMediaExtractor (demux) → alac_fallback.cpp → alac_decoder_wrapper.cpp
# → ALACDecoder.cpp (Apple reference).
# ============================================================================
add_library(audio_engine SHARED
    "${CPP_ENGINE_DIR}/src/audio_engine.c"
    "${CPP_ENGINE_DIR}/src/mediacodec_decoder.c"
    # ALAC fallback: C++ wrapper + demuxer
    "${CPP_ENGINE_DIR}/src/alac_fallback.cpp"
    "${CPP_ENGINE_DIR}/src/alac_decoder_wrapper.cpp"
    # Vendored Apple ALAC reference decoder (decode-only)
    "${CPP_ENGINE_DIR}/src/alac/ALACDecoder.cpp"
    "${CPP_ENGINE_DIR}/src/alac/ALACBitUtilities.c"
    "${CPP_ENGINE_DIR}/src/alac/ag_dec.c"
    "${CPP_ENGINE_DIR}/src/alac/dp_dec.c"
    "${CPP_ENGINE_DIR}/src/alac/matrix_dec.c"
    "${CPP_ENGINE_DIR}/src/alac/EndianPortable.c"
)
target_include_directories(audio_engine PRIVATE
    "${CPP_ENGINE_DIR}/include"
    "${CPP_ENGINE_DIR}/src"
)
find_library(LOG_LIB log)
find_library(MEDIANDK_LIB mediandk)
target_link_libraries(audio_engine ${LOG_LIB} ${MEDIANDK_LIB})
set_property(TARGET audio_engine PROPERTY POSITION_INDEPENDENT_CODE ON)
set_target_properties(audio_engine PROPERTIES C_STANDARD 99 CXX_STANDARD 17)

# ============================================================================
# libengine_jni.so — JNI bridge from Kotlin to the C audio engine.
# Created in Phase 3 of the usb-dac-bypass-android spec; absent for now,
# guarded to keep the build green during Phase 1+2 rollout.
# ============================================================================
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/engine_jni.c")
    add_library(engine_jni SHARED engine_jni.c)
    target_include_directories(engine_jni PRIVATE
        "${CPP_ENGINE_DIR}/include"
    )
    target_link_libraries(engine_jni audio_engine ${LOG_LIB})
    set_target_properties(engine_jni PROPERTIES C_STANDARD 99)
endif()
