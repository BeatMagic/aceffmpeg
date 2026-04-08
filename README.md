# aceffmpeg

官方原版tag n8.1  : 
Precompiled FFmpeg 8.1 libraries for ACE Studio.

9047fa1b084f76b1b4d065af2d743df1b40dfb56
**License:** LGPL v3 (no GPL components)

## Version Info

- FFmpeg version: **8.1** (tag `n8.1` from https://ffmpeg.org)
- LAME (libmp3lame): **3.100**
- Opus (libopus): **1.5.2**

## Platforms

| Platform | Architecture | Status |
|----------|-------------|--------|
| Windows | x86_64 | Available |
| macOS | arm64 | Available |
| macOS | x86_64 | Available |

## Windows Build

### Toolchain

Built with **MSVC** (cl.exe 19.44, Visual Studio 2022) via MSYS2 + `--toolchain=msvc`.

NASM 3.01 used for x86 assembly optimizations (SIMD/SSE/AVX).

### Runtime Dependencies (verified with Dependencies.exe)

The produced DLLs depend **only** on:
- Other FFmpeg DLLs (avutil-60.dll, swresample-6.dll, etc.)
- `libmp3lame.dll` (LAME MP3 encoder, LGPL)
- `opus.dll` (Opus audio codec, BSD)
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
  --enable-libopus \
  --enable-dxva2 \
  --enable-d3d11va \
  --enable-mediafoundation \
  --extra-cflags='-MD -O2 -DHAVE_UNISTD_H=0 -I<lame_include_path> -I<opus_install_dir>/include' \
  --extra-ldflags='-LIBPATH:<lame_lib_path> -LIBPATH:<opus_install_dir>/lib'
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

### Opus Build (Windows)

Opus 1.5.2 from https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz

Use CMake for the MSVC build (autotools doesn't work well with MSVC):
```bash
tar xf opus-1.5.2.tar.gz
cd opus-1.5.2
mkdir build && cd build
cmake .. -G "NMake Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=<opus_install_dir> \
  -DBUILD_SHARED_LIBS=ON \
  -DOPUS_BUILD_TESTING=OFF \
  -DOPUS_BUILD_PROGRAMS=OFF
nmake
nmake install
```

This produces `opus.dll` + `opus.lib`. Copy both to `ffmpeg/lib/win/`.

### Important Build Notes

- FFmpeg **requires** `-O2` optimization even for debug builds (dead-code elimination patterns in FFmpeg source cause linker errors without optimization)
- MSYS2's `/usr/bin/link.exe` must be renamed/removed to avoid conflict with MSVC's `link.exe`
- `-DHAVE_UNISTD_H=0` prevents configure from detecting MSYS2's unistd.h as Windows-native

## macOS Build

### Toolchain

Built with **Apple clang 21.0** (Xcode). Deployment target: **macOS 13.0** (`-mmacosx-version-min=13.0`).

NASM 3.01 used for x86_64 assembly optimizations.

### Runtime Dependencies

The produced dylibs depend **only** on:
- Other FFmpeg dylibs (via `@rpath`)
- `libmp3lame.0.dylib` (LAME MP3 encoder, LGPL, via `@rpath`)
- `libopus.0.dylib` (Opus audio codec, BSD, via `@rpath`)
- System frameworks: AudioToolbox, VideoToolbox, CoreFoundation, CoreMedia, CoreVideo, CoreServices
- System libs: libSystem.B.dylib, libiconv.2.dylib, libz.1.dylib, libbz2.1.0.dylib

All dylib install names use `@rpath/lib<name>.<SOVERSION>.dylib` pattern.

### Configure Flags (macOS arm64)

```bash
./configure \
  --prefix=<install_dir> \
  --arch=arm64 \
  --target-os=darwin \
  --enable-shared \
  --disable-static \
  --enable-version3 \
  --disable-gpl \
  --disable-programs \
  --disable-doc \
  --enable-neon \
  --enable-videotoolbox \
  --enable-audiotoolbox \
  --enable-libmp3lame \
  --enable-libopus \
  --disable-xlib \
  --disable-libxcb \
  --disable-libxcb-shm \
  --disable-libxcb-xfixes \
  --disable-libxcb-shape \
  --disable-sdl2 \
  --extra-cflags="-mmacosx-version-min=13.0 -I<lame_include_path> -I<opus_install_dir>/include" \
  --extra-ldflags="-mmacosx-version-min=13.0 -L<lame_lib_path> -L<opus_install_dir>/lib" \
  --install-name-dir='@rpath'
```

### Configure Flags (macOS x86_64, cross-compiled from arm64)

```bash
./configure \
  --prefix=<install_dir> \
  --arch=x86_64 \
  --target-os=darwin \
  --enable-cross-compile \
  --cc='clang -arch x86_64' \
  --enable-shared \
  --disable-static \
  --enable-version3 \
  --disable-gpl \
  --disable-programs \
  --disable-doc \
  --enable-x86asm \
  --enable-videotoolbox \
  --enable-audiotoolbox \
  --enable-libmp3lame \
  --enable-libopus \
  --disable-xlib \
  --disable-libxcb \
  --disable-libxcb-shm \
  --disable-libxcb-xfixes \
  --disable-libxcb-shape \
  --disable-sdl2 \
  --extra-cflags="-mmacosx-version-min=13.0 -I<lame_include_path> -I<opus_install_dir>/include" \
  --extra-ldflags="-mmacosx-version-min=13.0 -L<lame_lib_path> -L<opus_install_dir>/lib -arch x86_64" \
  --install-name-dir='@rpath'
```

### LAME Build (macOS)

LAME 3.100 built from source (not Homebrew) to control deployment target:
```bash
# Patch: remove lame_init_old from include/libmp3lame.sym (undefined symbol)
sed -i.bak '/lame_init_old/d' include/libmp3lame.sym

./configure \
  --prefix=<install_dir> \
  --enable-shared \
  --disable-static \
  --disable-frontend \
  --disable-gtktest \
  --host=aarch64-apple-darwin \   # or x86_64-apple-darwin
  CFLAGS="-arch arm64 -mmacosx-version-min=13.0 -O2" \
  LDFLAGS="-arch arm64 -mmacosx-version-min=13.0"
```

After building, fix the install name:
```bash
install_name_tool -id "@rpath/libmp3lame.0.dylib" <install_dir>/lib/libmp3lame.0.dylib
```

Also fix all FFmpeg dylibs that reference lame (avcodec, avdevice, avfilter, avformat):
```bash
OLD=$(otool -L <dylib> | grep libmp3lame | awk '{print $1}')
install_name_tool -change "$OLD" "@rpath/libmp3lame.0.dylib" <dylib>
```

### Opus Build (macOS)

Opus 1.5.2 from https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz

```bash
tar xf opus-1.5.2.tar.gz
cd opus-1.5.2

./configure \
  --prefix=<install_dir> \
  --enable-shared \
  --disable-static \
  --disable-doc \
  --disable-extra-programs \
  --host=aarch64-apple-darwin \   # or x86_64-apple-darwin
  CFLAGS="-arch arm64 -mmacosx-version-min=13.0 -O2" \
  LDFLAGS="-arch arm64 -mmacosx-version-min=13.0"

make -j$(sysctl -n hw.ncpu) && make install
```

Fix the install name:
```bash
install_name_tool -id "@rpath/libopus.0.dylib" <install_dir>/lib/libopus.0.dylib
```

**Why libopus is required:** FFmpeg's native Opus encoder (`opus/enc.c`) uses a 64-entry `FFBufQueue` that silently drops audio frames on long files (>~1.3s of buffered audio). The `libopus` wrapper (`libopusenc.c`) uses the external libopus library which handles buffering correctly. With `--enable-libopus`, `avcodec_find_encoder(AV_CODEC_ID_OPUS)` picks `libopus` by default.

### Post-Build

Stripped with `strip -S` (removes debug symbols only, keeps function names for stack traces).

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
