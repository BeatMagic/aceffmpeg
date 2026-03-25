cmake_minimum_required(VERSION 3.16)

project(test_ffmpeg_usage)

# 使用FetchContent获取FFmpeg库
include(FetchContent)

FetchContent_Declare(
    aceffmpeg
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.."  # 指向父目录，实际使用时应该是git仓库URL
)

FetchContent_MakeAvailable(aceffmpeg)

# 创建测试可执行文件
add_executable(test_ffmpeg test_ffmpeg.cpp)

# 链接FFmpeg库
target_link_libraries(test_ffmpeg PRIVATE FFmpeg::FFmpeg)

# 设置C++标准
set_property(TARGET test_ffmpeg PROPERTY CXX_STANDARD 11)