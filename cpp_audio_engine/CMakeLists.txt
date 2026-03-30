cmake_minimum_required(VERSION 3.10)
project(audio_engine LANGUAGES C)

set(CMAKE_C_STANDARD 99)

add_library(audio_engine SHARED src/audio_engine.c)

target_include_directories(audio_engine PRIVATE include)

if(MSVC)
    target_compile_definitions(audio_engine PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

if(WIN32)
    target_link_libraries(audio_engine PRIVATE winmm)
endif()
