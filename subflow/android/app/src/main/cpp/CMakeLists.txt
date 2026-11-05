# SubFlow native build.
#
# Builds libsubflow_core.so: the deterministic C++ core used by the Kotlin
# exporter (subtitle codecs, timeline remap, VAD, export planning) and, from
# Phase 2 on, whisper.cpp for offline speech recognition.
#
# The same sources are compiled for the host and unit-tested from
# subflow/tools/native-core (make test) so behaviour is verified on x86_64
# before it ever reaches a device.
cmake_minimum_required(VERSION 3.22.1)
project(subflow_core LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(SF_CORE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/core)
set(SF_WHISPER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party/whisper.cpp)

add_library(subflow_core SHARED
    core/sf_time.cpp
    core/sf_silence.cpp
    core/sf_timeline.cpp
    core/sf_subtitle.cpp
    core/sf_quality.cpp
    core/sf_asr.cpp
    jni/sf_jni.cpp
)

# Warnings are set per target, not per directory: whisper.cpp/ggml are vendored
# third-party code and must not inherit our warning set (they build with their
# own, much louder, flags otherwise).
target_compile_options(subflow_core PRIVATE -Wall -Wextra -Wpedantic)

target_include_directories(subflow_core PRIVATE ${SF_CORE_DIR})
target_link_libraries(subflow_core PRIVATE log)

# ---------------------------------------------------------------------------
# Whisper (Phase 2). Enabled with -DSF_ENABLE_WHISPER=ON once whisper.cpp is
# vendored into subflow/third_party/whisper.cpp. The CMake guards keep Phase 1
# building without the model runtime present - no stub, no fake engine.
# ---------------------------------------------------------------------------
option(SF_ENABLE_WHISPER "Build the whisper.cpp speech engine" ON)
if(SF_ENABLE_WHISPER)
    if(NOT EXISTS ${SF_WHISPER_DIR}/CMakeLists.txt)
        message(FATAL_ERROR
            "SF_ENABLE_WHISPER=ON but whisper.cpp is missing at ${SF_WHISPER_DIR}. "
            "Run subflow/tools/fetch-whisper.sh first.")
    endif()
    # A static lib linked into libsubflow_core.so: one .so on disk, one load.
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_IS_DEV OFF CACHE BOOL "" FORCE)
    set(WHISPER_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
    set(WHISPER_ALL_WARNINGS_3RD_PARTY OFF CACHE BOOL "" FORCE)
    set(WHISPER_FATAL_WARNINGS OFF CACHE BOOL "" FORCE)
    # Threads: ggml's own thread pool, no OpenMP (NDK ships no libgomp) and no
    # -march=native for a cross build.
    set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
    set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
    set(GGML_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
    set(GGML_FATAL_WARNINGS OFF CACHE BOOL "" FORCE)
    set(GGML_CCACHE OFF CACHE BOOL "" FORCE)
    set(GGML_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(GGML_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    add_subdirectory(${SF_WHISPER_DIR} ${CMAKE_BINARY_DIR}/whisper EXCLUDE_FROM_ALL)
    target_link_libraries(subflow_core PRIVATE whisper)
    target_compile_definitions(subflow_core PRIVATE SF_HAVE_WHISPER=1)
    target_include_directories(subflow_core PRIVATE ${SF_WHISPER_DIR}/include)
endif()
