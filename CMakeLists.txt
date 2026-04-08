cmake_minimum_required(VERSION 3.16)

project(aceffmpeg
    VERSION 8.1.0
    DESCRIPTION "Precompiled FFmpeg libraries for cross-platform development"
    LANGUAGES C CXX
)

# 设置包含目录
set(FFMPEG_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/include")

# 检测平台和架构，设置 release/debug 库路径
if(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
    set(FFMPEG_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/lib/win/release")
    set(FFMPEG_LIB_DEBUG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/lib/win/debug")
    set(LIB_SUFFIX ".lib")
    set(DLL_SUFFIX ".dll")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
    # 检测macOS架构
    if(CMAKE_OSX_ARCHITECTURES MATCHES "arm64")
        set(FFMPEG_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/lib/macos/arm64/release")
    else()
        set(FFMPEG_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/lib/macos/x86_64/release")
    endif()
    set(LIB_SUFFIX ".dylib")
elseif(UNIX)
    set(FFMPEG_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/lib/macos/x86_64/release")
    set(LIB_SUFFIX ".dylib")
endif()

# Check if debug libraries are available
if(EXISTS "${FFMPEG_LIB_DEBUG_DIR}")
    set(FFMPEG_HAS_DEBUG_LIBS TRUE)
else()
    set(FFMPEG_HAS_DEBUG_LIBS FALSE)
endif()

# FFmpeg核心库列表
set(FFMPEG_LIBRARIES
    avcodec
    avdevice
    avfilter
    avformat
    avutil
    swresample
    swscale
)

# 创建FFmpeg核心库导入目标
foreach(lib ${FFMPEG_LIBRARIES})
    add_library(FFmpeg::${lib} SHARED IMPORTED)

    set_target_properties(FFmpeg::${lib} PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
    )

    if(WIN32)
        # Release (default for all non-Debug configs)
        file(GLOB _release_dll "${FFMPEG_LIB_DIR}/${lib}-*.dll")
        if(_release_dll)
            set_target_properties(FFmpeg::${lib} PROPERTIES
                IMPORTED_LOCATION "${_release_dll}"
                IMPORTED_IMPLIB "${FFMPEG_LIB_DIR}/${lib}${LIB_SUFFIX}"
            )
        endif()

        # Debug config override
        if(FFMPEG_HAS_DEBUG_LIBS)
            file(GLOB _debug_dll "${FFMPEG_LIB_DEBUG_DIR}/${lib}-*.dll")
            if(_debug_dll)
                set_target_properties(FFmpeg::${lib} PROPERTIES
                    IMPORTED_LOCATION_DEBUG "${_debug_dll}"
                    IMPORTED_IMPLIB_DEBUG "${FFMPEG_LIB_DEBUG_DIR}/${lib}${LIB_SUFFIX}"
                )
            endif()
        endif()
    else()
        set_target_properties(FFmpeg::${lib} PROPERTIES
            IMPORTED_LOCATION "${FFMPEG_LIB_DIR}/lib${lib}${LIB_SUFFIX}"
        )
    endif()
endforeach()

# FFmpeg第三方依赖库
# opus
add_library(FFmpeg::opus SHARED IMPORTED)
set_target_properties(FFmpeg::opus PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
)
if(WIN32)
    set_target_properties(FFmpeg::opus PROPERTIES
        IMPORTED_IMPLIB "${FFMPEG_LIB_DIR}/opus${LIB_SUFFIX}"
        IMPORTED_LOCATION "${FFMPEG_LIB_DIR}/opus${DLL_SUFFIX}"
    )
    if(FFMPEG_HAS_DEBUG_LIBS)
        set_target_properties(FFmpeg::opus PROPERTIES
            IMPORTED_IMPLIB_DEBUG "${FFMPEG_LIB_DEBUG_DIR}/opus${LIB_SUFFIX}"
            IMPORTED_LOCATION_DEBUG "${FFMPEG_LIB_DEBUG_DIR}/opus${DLL_SUFFIX}"
        )
    endif()
else()
    set_target_properties(FFmpeg::opus PROPERTIES
        IMPORTED_LOCATION "${FFMPEG_LIB_DIR}/libopus${LIB_SUFFIX}"
    )
endif()

# mp3lame
add_library(FFmpeg::mp3lame SHARED IMPORTED)
set_target_properties(FFmpeg::mp3lame PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
)
if(WIN32)
    set_target_properties(FFmpeg::mp3lame PROPERTIES
        IMPORTED_IMPLIB "${FFMPEG_LIB_DIR}/libmp3lame${LIB_SUFFIX}"
        IMPORTED_LOCATION "${FFMPEG_LIB_DIR}/libmp3lame${DLL_SUFFIX}"
    )
    if(FFMPEG_HAS_DEBUG_LIBS)
        set_target_properties(FFmpeg::mp3lame PROPERTIES
            IMPORTED_IMPLIB_DEBUG "${FFMPEG_LIB_DEBUG_DIR}/libmp3lame${LIB_SUFFIX}"
            IMPORTED_LOCATION_DEBUG "${FFMPEG_LIB_DEBUG_DIR}/libmp3lame${DLL_SUFFIX}"
        )
    endif()
else()
    set_target_properties(FFmpeg::mp3lame PROPERTIES
        IMPORTED_LOCATION "${FFMPEG_LIB_DIR}/libmp3lame${LIB_SUFFIX}"
    )
endif()

# 第三方依赖库列表
set(FFMPEG_DEP_LIBRARIES opus mp3lame)

# 创建FFmpeg总目标
add_library(FFmpeg::FFmpeg INTERFACE IMPORTED)
set_target_properties(FFmpeg::FFmpeg PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "FFmpeg::avcodec;FFmpeg::avdevice;FFmpeg::avfilter;FFmpeg::avformat;FFmpeg::avutil;FFmpeg::swresample;FFmpeg::swscale;FFmpeg::opus;FFmpeg::mp3lame"
)

# 使导入目标在全局范围内可用
foreach(lib ${FFMPEG_LIBRARIES})
    set_target_properties(FFmpeg::${lib} PROPERTIES IMPORTED_GLOBAL TRUE)
endforeach()
foreach(lib ${FFMPEG_DEP_LIBRARIES})
    set_target_properties(FFmpeg::${lib} PROPERTIES IMPORTED_GLOBAL TRUE)
endforeach()
set_target_properties(FFmpeg::FFmpeg PROPERTIES IMPORTED_GLOBAL TRUE)

# 导出配置
include(CMakePackageConfigHelpers)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/FFmpegConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/FFmpegConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/FFmpegConfig.cmake"
    INSTALL_DESTINATION "lib/cmake/FFmpeg"
)

message(STATUS "FFmpeg libraries configured for platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "FFmpeg library directory: ${FFMPEG_LIB_DIR}")
if(FFMPEG_HAS_DEBUG_LIBS)
    message(STATUS "FFmpeg debug library directory: ${FFMPEG_LIB_DEBUG_DIR}")
endif()
message(STATUS "FFmpeg include directory: ${FFMPEG_INCLUDE_DIR}")
