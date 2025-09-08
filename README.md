# aceffmpeg

官方原版tag4.4: 
7ffb7d4b04e392edd7bdb7b28107e39bc349b589 

编译参数：
win:
```
./configure --disable-doc --enable-cross-compile --disable-x86asm --arch=x86_64 --enable-gpl --enable-version3 --enable-shared --disable-static --disable-programs --prefix=ffmpeglib  --toolchain=msvc --disable-network --disable-debug --enable-libmp3lame
```
mac:
```
./configure \
'--disable-doc' \
'--enable-cross-compile' \
'--enable-gpl' \
'--enable-version3' \
'--enable-shared' \
'--disable-static' \
'--target-os=darwin' \
'--arch=x86_64' \
'--disable-programs' \
'--disable-network' \
'--disable-debug' \
'--prefix=./ffmpeglib' \
'--install-name-dir=@rpath' \
'--extra-cflags=-mmacosx-version-min=10.14 -arch x86_64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk -I./libmp3lame/include' \
'--extra-ldflags=-mmacosx-version-min=10.14 -arch x86_64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk -L./libmp3lame/lib' \
'--enable-libmp3lame' 
```

## 使用 CMake FetchContent 集成

本仓库已配置为支持 CMake 的 FetchContent 功能，使其他项目可以轻松集成预编译的 FFmpeg 库。

### 基本用法

在您的 CMakeLists.txt 文件中添加以下内容：

```cmake
cmake_minimum_required(VERSION 3.16)

project(your_project)

# 使用 FetchContent 获取 FFmpeg
include(FetchContent)

FetchContent_Declare(
    aceffmpeg
    GIT_REPOSITORY https://github.com/your-username/aceffmpeg.git
    GIT_TAG main  # 或者指定特定的标签/分支
)

FetchContent_MakeAvailable(aceffmpeg)

# 创建您的可执行文件
add_executable(your_app main.cpp)

# 链接 FFmpeg 库
target_link_libraries(your_app PRIVATE FFmpeg::FFmpeg)

# 或者链接特定的 FFmpeg 库
# target_link_libraries(your_app PRIVATE
#     FFmpeg::avcodec
#     FFmpeg::avformat
#     FFmpeg::avutil
# )
```

### C++ 代码示例

在 C++ 中使用 FFmpeg 时，需要使用 `extern "C"` 包装 FFmpeg 头文件：

```cpp
#include <iostream>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
}

int main() {
    std::cout << "FFmpeg version: " << av_version_info() << std::endl;
    
    // 初始化 FFmpeg
    avformat_network_init();
    
    std::cout << "FFmpeg initialization successful!" << std::endl;
    
    return 0;
}
```

### 可用的 CMake 目标

本库提供以下 CMake 目标：

- `FFmpeg::FFmpeg` - 包含所有 FFmpeg 库的总目标
- `FFmpeg::avcodec` - 音视频编解码库
- `FFmpeg::avdevice` - 设备访问库
- `FFmpeg::avfilter` - 音视频滤镜库
- `FFmpeg::avformat` - 音视频格式库
- `FFmpeg::avutil` - 通用工具库
- `FFmpeg::postproc` - 后处理库
- `FFmpeg::swresample` - 音频重采样库
- `FFmpeg::swscale` - 视频缩放库

### 支持的平台

- **Windows**: x86_64 架构
- **macOS**: x86_64 和 arm64 (Apple Silicon) 架构
- **Linux**: 使用 macOS x86_64 库作为 fallback

CMake 会自动检测您的平台和架构，并选择合适的库文件。

### 直接下载使用

您也可以直接下载此仓库并在本地项目中使用：

```cmake
# 假设您将 aceffmpeg 放在项目的 third_party 目录中
add_subdirectory(third_party/aceffmpeg)

target_link_libraries(your_app PRIVATE FFmpeg::FFmpeg)
```

### 故障排除

1. **链接错误**: 确保在 C++ 中使用 `extern "C"` 包装 FFmpeg 头文件
2. **找不到库**: 检查您的平台是否受支持，以及库文件是否存在
3. **架构不匹配**: 确保您的项目架构与可用的库架构匹配

### 版本信息

- FFmpeg 版本: 4.4.2
- 基于官方 tag: 7ffb7d4b04e392edd7bdb7b28107e39bc349b589




```
创建的文件
CMakeLists.txt - 主要的CMake配置文件

支持Windows、macOS (x86_64和arm64)平台自动检测
为所有FFmpeg库创建导入目标（FFmpeg::avcodec、FFmpeg::avformat等）
提供统一的FFmpeg::FFmpeg目标包含所有库
cmake/FFmpegConfig.cmake.in - 包配置模板文件

支持find_package机制
自动检测库文件存在性
提供向后兼容的变量设置
test_example/ - 测试示例项目

演示如何使用FetchContent集成FFmpeg
包含C++使用示例代码
更新的文件
README.md - 添加了详细的使用说明
FetchContent集成方法
C++代码示例
可用CMake目标说明
故障排除指南
使用方法
其他项目现在可以通过以下方式使用您的FFmpeg库：

include(FetchContent)

FetchContent_Declare(
    aceffmpeg
    GIT_REPOSITORY https://github.com/your-username/aceffmpeg.git
    GIT_TAG main
)

FetchContent_MakeAvailable(aceffmpeg)

target_link_libraries(your_app PRIVATE FFmpeg::FFmpeg)

cmake


配置已经过测试验证，能够在macOS arm64平台上成功编译和运行。现在您的仓库完全支持CMake FetchContent功能了。
```




