cmake_minimum_required(VERSION 3.10)
project(audio_engine LANGUAGES C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)

# Source files: WMF backend is Windows-only; MediaCodec backend is
# Android-only. Each is gated by the host platform check so the same
# CMakeLists builds the matching backend without dragging in symbols
# from the wrong toolchain.
set(AUDIO_ENGINE_SOURCES
    src/audio_engine.c
)
if(WIN32)
    list(APPEND AUDIO_ENGINE_SOURCES src/mf_decoder.cpp)
endif()
if(ANDROID)
    list(APPEND AUDIO_ENGINE_SOURCES
        src/mediacodec_decoder.c
        src/alac_fallback.cpp
        src/alac_decoder_wrapper.cpp
        src/alac/ALACDecoder.cpp
        src/alac/ALACBitUtilities.c
        src/alac/ag_dec.c
        src/alac/dp_dec.c
        src/alac/matrix_dec.c
        src/alac/EndianPortable.c
    )
endif()

add_library(audio_engine SHARED ${AUDIO_ENGINE_SOURCES})

target_include_directories(audio_engine PRIVATE include src)

if(MSVC)
    target_compile_definitions(audio_engine PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

if(WIN32)
    # Windows: needs Media Foundation for M4A/AAC and winmm for clocks.
    target_link_libraries(audio_engine PRIVATE winmm mfplat mfreadwrite mfuuid)
endif()

if(ANDROID)
    # Android: link log + mediandk (AMediaCodec / AMediaExtractor) so the
    # MediaCodec backend can decode AAC universally and ALAC on Android 12+.
    find_library(LOG_LIB log)
    find_library(MEDIANDK_LIB mediandk)
    target_link_libraries(audio_engine PRIVATE ${LOG_LIB} ${MEDIANDK_LIB})
    set_property(TARGET audio_engine PROPERTY POSITION_INDEPENDENT_CODE ON)
endif()
