// native_src/chromaprint_wrapper.h

#ifndef CHROMAPRINT_WRAPPER_H
#define CHROMAPRINT_WRAPPER_H

extern "C" {
    /**
     * @brief Generates an AcoustID fingerprint string from a local file path.
     * * @param file_path The path to the audio file (MP3, FLAC, etc.).
     * @return A C string containing the fingerprint, or NULL on failure.
     */
    const char* get_fingerprint_from_file(const char* file_path);
}

#endif // CHROMAPRINT_WRAPPER_H