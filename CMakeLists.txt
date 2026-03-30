cmake_minimum_required(VERSION 3.16)

project(aceffmpeg 
    VERSION 8.1.0
    DESCRIPTION "Precompiled FFmpeg libraries for cross-platform development"
    LANGUAGES C CXX
)

# 设置包含目录
set(FFMPEG_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/include")

# 检测平台和架构
if(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
    set(FFMPEG_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/lib/win")
    set(LIB_SUFFIX ".lib")
    set(DLL_SUFFIX ".dll")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
    # 检测macOS架构
    if(CMAKE_OSX_ARCHITECTURES MATCHES "arm64")
        set(FFMPEG_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/lib/macos/arm64")
    else()
        set(FFMPEG_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/lib/macos/x86_64")
    endif()
    set(LIB_SUFFIX ".dylib")
elseif(UNIX)
    # 对于其他Unix系统，暂时使用macOS x86_64路径作为fallback
    set(FFMPEG_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/lib/macos/x86_64")
    set(LIB_SUFFIX ".dylib")
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
    
    # 设置头文件目录
    set_target_properties(FFmpeg::${lib} PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
    )
    
    if(WIN32)
        # Windows平台设置
        set_target_properties(FFmpeg::${lib} PROPERTIES
            IMPORTED_LOCATION "${FFMPEG_LIB_DIR}/${lib}-*.dll"
            IMPORTED_IMPLIB "${FFMPEG_LIB_DIR}/${lib}${LIB_SUFFIX}"
        )
        # 查找实际的DLL文件
        file(GLOB DLL_FILE "${FFMPEG_LIB_DIR}/${lib}-*.dll")
        if(DLL_FILE)
            set_target_properties(FFmpeg::${lib} PROPERTIES
                IMPORTED_LOCATION "${DLL_FILE}"
            )
        endif()
    else()
        # macOS/Linux平台设置
        set_target_properties(FFmpeg::${lib} PROPERTIES
            IMPORTED_LOCATION "${FFMPEG_LIB_DIR}/lib${lib}${LIB_SUFFIX}"
        )
    endif()
endforeach()

# FFmpeg第三方依赖库（命名规则与核心库不同，需单独处理）
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
else()
    set_target_properties(FFmpeg::mp3lame PROPERTIES
        IMPORTED_LOCATION "${FFMPEG_LIB_DIR}/libmp3lame${LIB_SUFFIX}"
    )
endif()

# 第三方依赖库列表（用于遍历设置全局属性等）
set(FFMPEG_DEP_LIBRARIES opus mp3lame)

# 创建FFmpeg总目标，包含所有核心库和第三方依赖库
add_library(FFmpeg::FFmpeg INTERFACE IMPORTED)
set_target_properties(FFmpeg::FFmpeg PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "FFmpeg::avcodec;FFmpeg::avdevice;FFmpeg::avfilter;FFmpeg::avformat;FFmpeg::avutil;FFmpeg::swresample;FFmpeg::swscale;FFmpeg::opus;FFmpeg::mp3lame"
)

# 使导入目标在全局范围内可用
foreach(lib ${FFMPEG_LIBRARIES})
    set_target_properties(FFmpeg::${lib} PROPERTIES
        IMPORTED_GLOBAL TRUE
    )
endforeach()
foreach(lib ${FFMPEG_DEP_LIBRARIES})
    set_target_properties(FFmpeg::${lib} PROPERTIES
        IMPORTED_GLOBAL TRUE
    )
endforeach()
set_target_properties(FFmpeg::FFmpeg PROPERTIES
    IMPORTED_GLOBAL TRUE
)

# 导出配置
include(CMakePackageConfigHelpers)

# 创建版本文件
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/FFmpegConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

# 创建配置文件
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/FFmpegConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/FFmpegConfig.cmake"
    INSTALL_DESTINATION "lib/cmake/FFmpeg"
)

# # 安装配置（可选）
# if(NOT CMAKE_SKIP_INSTALL_RULES)
#     install(DIRECTORY "${FFMPEG_INCLUDE_DIR}/" 
#         DESTINATION "include"
#         FILES_MATCHING PATTERN "*.h"
#     )
    
#     install(DIRECTORY "${FFMPEG_LIB_DIR}/"
#         DESTINATION "lib"
#         FILES_MATCHING 
#         PATTERN "*.dylib"
#         PATTERN "*.dll" 
#         PATTERN "*.lib"
#     )
    
#     install(FILES
#         "${CMAKE_CURRENT_BINARY_DIR}/FFmpegConfig.cmake"
#         "${CMAKE_CURRENT_BINARY_DIR}/FFmpegConfigVersion.cmake"
#         DESTINATION "lib/cmake/FFmpeg"
#     )
# endif()

# 提供使用信息
message(STATUS "FFmpeg libraries configured for platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "FFmpeg library directory: ${FFMPEG_LIB_DIR}")
message(STATUS "FFmpeg include directory: ${FFMPEG_INCLUDE_DIR}")