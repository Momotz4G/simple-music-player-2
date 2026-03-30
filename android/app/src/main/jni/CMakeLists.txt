cmake_minimum_required(VERSION 3.10)

project(usb_iso_jni)

# Build the JNI shared library for isochronous USB audio transfers
add_library(usb_iso_jni SHARED usb_iso_jni.c)

# Link against Android log library for __android_log_print
target_link_libraries(usb_iso_jni log)

# C11 standard
set_target_properties(usb_iso_jni PROPERTIES C_STANDARD 11)
