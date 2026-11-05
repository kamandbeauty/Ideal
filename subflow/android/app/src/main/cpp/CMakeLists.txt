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

add_compile_options(-Wall -Wextra -Wpedantic)

set(SF_CORE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/core)
set(SF_WHISPER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party/whisper.cpp)

add_library(subflow_core SHARED
    core/sf_time.cpp
    core/sf_silence.cpp
    core/sf_timeline.cpp
    core/sf_subtitle.cpp
    core/sf_quality.cpp
    jni/sf_jni.cpp
)

target_include_directories(subflow_core PRIVATE ${SF_CORE_DIR})
target_link_libraries(subflow_core PRIVATE log)

# ---------------------------------------------------------------------------
# Whisper (Phase 2). Enabled with -DSF_ENABLE_WHISPER=ON once whisper.cpp is
# vendored into subflow/third_party/whisper.cpp. The CMake guards keep Phase 1
# building without the model runtime present - no stub, no fake engine.
# ---------------------------------------------------------------------------
option(SF_ENABLE_WHISPER "Build the whisper.cpp speech engine" OFF)
if(SF_ENABLE_WHISPER)
    if(NOT EXISTS ${SF_WHISPER_DIR}/CMakeLists.txt)
        message(FATAL_ERROR
            "SF_ENABLE_WHISPER=ON but whisper.cpp is missing at ${SF_WHISPER_DIR}. "
            "Run subflow/tools/fetch-whisper.sh first.")
    endif()
    set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
    set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
    add_subdirectory(${SF_WHISPER_DIR} ${CMAKE_BINARY_DIR}/whisper EXCLUDE_FROM_ALL)
    target_link_libraries(subflow_core PRIVATE whisper)
    target_compile_definitions(subflow_core PRIVATE SF_HAVE_WHISPER=1)
endif()
