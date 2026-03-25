# aceffmpeg

Precompiled FFmpeg 8.1 libraries for ACE Studio.

**License:** LGPL v3 (no GPL components)

## Version Info

- FFmpeg version: **8.1** (tag `n8.1` from https://ffmpeg.org)
- LAME (libmp3lame): **3.100**

## Platforms

| Platform | Architecture | Status |
|----------|-------------|--------|
| Windows | x86_64 | Available |
| macOS | arm64 | Pending |
| macOS | x86_64 | Pending |

## Windows Build

### Toolchain

Built with **MSVC** (cl.exe 19.44, Visual Studio 2022) via MSYS2 + `--toolchain=msvc`.

NASM 3.01 used for x86 assembly optimizations (SIMD/SSE/AVX).

### Runtime Dependencies (verified with Dependencies.exe)

The produced DLLs depend **only** on:
- Other FFmpeg DLLs (avutil-60.dll, swresample-6.dll, etc.)
- `libmp3lame.dll` (LAME MP3 encoder, LGPL)
- Windows system DLLs: `KERNEL32.dll`, `ole32.dll`, `USER32.dll`, `mfplat.dll` (Media Foundation)
- MSVC runtime: `VCRUNTIME140.dll`, `api-ms-win-crt-*.dll` (Universal CRT)

**No** extra clang/gcc runtime dependencies. Pure MSVC ABI.

### Configure Flags (Windows)

```bash
./configure \
  --arch=x86_64 \
  --target-os=win32 \
  --toolchain=msvc \
  --enable-version3 \
  --enable-shared \
  --disable-static \
  --disable-programs \
  --disable-doc \
  --enable-w32threads \
  --enable-network \
  --disable-debug \
  --disable-bzlib \
  --enable-libmp3lame \
  --enable-dxva2 \
  --enable-d3d11va \
  --enable-mediafoundation \
  --extra-cflags='-MD -O2 -DHAVE_UNISTD_H=0 -I<lame_include_path>' \
  --extra-ldflags='-LIBPATH:<lame_lib_path>'
```

### Patches Applied

The following patches from vcpkg (microsoft/vcpkg ports/ffmpeg) are needed for MSVC:

1. **`0046-fix-msvc-detection.patch`** - Case-insensitive MSVC compiler detection in configure
2. **`0002-fix-msvc-link.patch`** - Debug symbols for NASM assembly on Windows
3. **`0005-fix-nasm.patch`** - Fix empty NASM object files on 32-bit MSVC
4. **`0007-fix-lib-naming.patch`** - MSVC library name mapping (`-lmp3lame` -> `libmp3lame.lib`)
5. **`0013-define-WINVER.patch`** - Define `WINVER=0x0602` for Media Foundation

### LAME Build (Windows)

LAME 3.100 built with MSVC nmake:
```
nmake -f Makefile.MSVC MSVCVER=Win64 ASM=NO MACHINE=/machine:x64 libmp3lame-static.lib
link /DLL /machine:x64 /DEF:"include\lame.def" /OUT:"output\libmp3lame.dll" /IMPLIB:"output\libmp3lame.lib" output\libmp3lame-static.lib libmp3lame\version.obj
```

### Important Build Notes

- FFmpeg **requires** `-O2` optimization even for debug builds (dead-code elimination patterns in FFmpeg source cause linker errors without optimization)
- MSYS2's `/usr/bin/link.exe` must be renamed/removed to avoid conflict with MSVC's `link.exe`
- `-DHAVE_UNISTD_H=0` prevents configure from detecting MSYS2's unistd.h as Windows-native

## DLL Version Numbers (FFmpeg 8.1)

| Library | SONAME | DLL Name |
|---------|--------|----------|
| libavcodec | 62 | avcodec-62.dll |
| libavdevice | 62 | avdevice-62.dll |
| libavfilter | 11 | avfilter-11.dll |
| libavformat | 62 | avformat-62.dll |
| libavutil | 60 | avutil-60.dll |
| libswresample | 6 | swresample-6.dll |
| libswscale | 9 | swscale-9.dll |

**Note:** `libpostproc` is not included as it requires GPL license.

## CMake Integration

### Using FetchContent

```cmake
include(FetchContent)
FetchContent_Declare(
    aceffmpeg
    GIT_REPOSITORY https://github.com/BeatMagic/aceffmpeg.git
    GIT_TAG ace8
)
FetchContent_MakeAvailable(aceffmpeg)

target_link_libraries(your_app PRIVATE FFmpeg::FFmpeg)
```

### Available CMake Targets

- `FFmpeg::FFmpeg` - All FFmpeg libraries
- `FFmpeg::avcodec`, `FFmpeg::avdevice`, `FFmpeg::avfilter`, `FFmpeg::avformat`
- `FFmpeg::avutil`, `FFmpeg::swresample`, `FFmpeg::swscale`

## Migration from FFmpeg 4.4

Key API changes:
- `AVCodecContext::channels` / `channel_layout` -> `ch_layout` (AVChannelLayout struct)
- `av_get_default_channel_layout()` -> `av_channel_layout_default()`
- `swr_alloc_set_opts()` -> `swr_alloc_set_opts2()`
- `AV_CH_LAYOUT_MONO` -> `AV_CHANNEL_LAYOUT_MONO` (struct macro)
- `frame->channels` / `frame->channel_layout` -> `av_channel_layout_copy(&frame->ch_layout, ...)`
