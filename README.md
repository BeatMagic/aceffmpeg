# aceffmpeg

Precompiled FFmpeg libraries for ACE Studio.

**License:** LGPL v3 (no GPL components; dav1d is BSD)

## Version Info

- FFmpeg version: **8.1.2** (`ffmpeg-8.1.2.tar.xz` from https://ffmpeg.org)
- LAME (libmp3lame): **3.100**
- Opus (libopus): **1.5.2**
- dav1d (libdav1d, fast AV1 software decoder): **1.5.1** — **Windows** binaries

> **8.1 → 8.1.2** is a point release: the SONAMEs are unchanged
> (`avcodec-62`, `avutil-60`, `avformat-62`, `avfilter-11`, `swscale-9`,
> `swresample-6`, `avdevice-62`), so the DLL/dylib names are identical and the
> swap is drop-in — **no consumer code or CMake change is required**.
>
> **dav1d** is added so web/YouTube **AV1** import decodes fast (FFmpeg's native
> AV1 decoder is slow). It is pure BSD (no GPL) and ships as `dav1d.dll`, a new
> transitive runtime dependency of `avcodec-62.dll`. (libvpx is intentionally
> **not** added — native VP8/VP9 decode is already on par.) The Windows binaries
> in this tree are 8.1.2 + dav1d; the macOS binaries are refreshed to match via
> the in-house macOS build (same version bump + `--enable-libdav1d`).

## Platforms

| Platform | Architecture | Release | Debug |
|----------|-------------|---------|-------|
| Windows | x86_64 | Available | Available |
| macOS | arm64 | Available | Available |
| macOS | x86_64 | Available | Available |

## Windows Build

### Toolchain

Built with **MSVC** (cl.exe ≥ 19.44, Visual Studio 2022 or newer) via MSYS2 +
`--toolchain=msvc`. Run every step below from an **x64 Native Tools Command
Prompt** (or after `vcvars64.bat`).

NASM (≥ 2.13 for FFmpeg, ≥ 2.14 for dav1d) used for x86 assembly optimizations
(SIMD/SSE/AVX). dav1d's build system additionally needs **Python 3 + meson + ninja**.

In MSYS2, **rename/remove `/usr/bin/link.exe`** so MSVC's `link.exe` wins on `PATH`.

### Runtime Dependencies (verified with `dumpbin /dependents` / Dependencies.exe)

The produced DLLs depend **only** on:
- Other FFmpeg DLLs (avutil-60.dll, swresample-6.dll, etc.)
- `dav1d.dll` (AV1 software decoder, BSD) — imported by `avcodec-62.dll`
- `libmp3lame.dll` (LAME MP3 encoder, LGPL)
- `opus.dll` (Opus audio codec, BSD)
- Windows system DLLs: `KERNEL32.dll`, `ole32.dll`, `USER32.dll`, `mfplat.dll` (Media Foundation)
- MSVC runtime: `VCRUNTIME140.dll`, `api-ms-win-crt-*.dll` (Universal CRT)

**No** extra clang/gcc runtime dependencies (dav1d is pure BSD, no extra runtime).
Pure MSVC ABI.

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
  --enable-libdav1d \
  --extra-cflags='-MD -O2 -DHAVE_UNISTD_H=0 -I<lame_include_path> -I<opus_install_dir>/include -I<dav1d_install_dir>/include' \
  --extra-ldflags='-LIBPATH:<lame_lib_path> -LIBPATH:<opus_install_dir>/lib -LIBPATH:<dav1d_install_dir>/lib'
```

FFmpeg finds dav1d and opus through **pkg-config**, so point `PKG_CONFIG_PATH` at
their `.pc` directories before configuring (libmp3lame is detected by a plain
header/lib check via the `-I`/`-LIBPATH` above, not pkg-config):

```bash
export PKG_CONFIG_PATH="<dav1d_install_dir>/lib/pkgconfig:<opus_pkgconfig_dir>:$PKG_CONFIG_PATH"
```

Confirm the configure summary lists **`libdav1d`** under "External libraries" and
that the version is **8.1.2** (`config.h`: `CONFIG_LIBDAV1D 1`,
`CONFIG_LIBDAV1D_DECODER 1`). After `make`, `dumpbin /dependents avcodec-62.dll`
must list **`dav1d.dll`**, and `avcodec_configuration()` must contain
`--enable-libdav1d`.

### dav1d Build (Windows)

dav1d 1.5.1 built shared with MSVC (from an x64 Native Tools prompt, NASM on `PATH`):

```bat
git clone https://code.videolan.org/videolan/dav1d.git
cd dav1d
git checkout 1.5.1
meson setup build ^
  --buildtype release ^
  --default-library shared ^
  -Denable_tools=false ^
  -Denable_tests=false ^
  --prefix "<dav1d_install_dir>"
ninja -C build
ninja -C build install
```

This produces `bin/dav1d.dll` (the runtime DLL — bundled next to the FFmpeg DLLs),
`lib/dav1d.lib` (MSVC import lib, needed only at FFmpeg link time),
`include/dav1d/*.h`, and `lib/pkgconfig/dav1d.pc` (how FFmpeg finds it). meson's
MSVC output already names the import lib `dav1d.lib` (not `libdav1d.lib`), which is
what FFmpeg's `-ldav1d` → `dav1d.lib` mapping expects. FFmpeg 8.1.2 requires
`dav1d >= 1.0.0` (1.5.1 satisfies it).

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

### Windows Debug Build

Debug DLLs (`ffmpeg/lib/win/debug/`) are built with the **same flags as
release**, except `--disable-debug` is replaced by
`--enable-debug --disable-stripping`. FFmpeg's `--enable-debug` automatically
maps `-g` → MSVC `-Z7` (CodeView debug info) for the compiler, appends `/debug`
to the linker, and adds `-g` to NASM — so do **not** add `-Zi`/`-DEBUG`
yourself (that would conflict). `-O2` is still kept (required).

dav1d, Opus and LAME are likewise rebuilt with debug info + `-O2`:
- **dav1d**: `meson setup --buildtype debugoptimized -Db_vscrt=md` (O2 + debug info, `/MD`).
- **Opus**: CMake `-DCMAKE_BUILD_TYPE=RelWithDebInfo` (`/O2 /Zi /MD`).
- **LAME**: the `Makefile.MSVC` `Win64` profile already compiles `/Zi /O2`; copy
  `configMS.h` → `config.h` first, then link the DLL with `/DEBUG /LTCG` to emit
  `libmp3lame.pdb`.

The FFmpeg debug DLLs are unstripped (symbols inline), so — matching the
release layout's third-party deps — only `libmp3lame.pdb` is shipped alongside.

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

### Post-Build (Release)

Stripped with `strip -S` (removes debug symbols only, keeps function names for stack traces).

### macOS Debug Build

Debug dylibs are built with the same flags as release, plus:
- `--enable-debug --disable-stripping` (FFmpeg configure)
- `-g` added to `--extra-cflags` (DWARF debug symbols)
- **No** `strip -S` post-build step

FFmpeg still uses `-O2` (required — dead-code elimination patterns in FFmpeg source cause linker errors without optimization).

LAME and Opus are also rebuilt with `-g -O2` in CFLAGS for consistent debug symbols.

Output is placed in `ffmpeg/lib/macos/{arm64,x86_64}/debug/`.

A convenience script `build_macos_debug.sh` automates the full build:
```bash
./build_macos_debug.sh          # build both arm64 + x86_64
./build_macos_debug.sh arm64    # build arm64 only
./build_macos_debug.sh x86_64   # build x86_64 only
```

## DLL Version Numbers (FFmpeg 8.1.2)

| Library | SONAME | DLL Name |
|---------|--------|----------|
| libavcodec | 62 | avcodec-62.dll |
| libavdevice | 62 | avdevice-62.dll |
| libavfilter | 11 | avfilter-11.dll |
| libavformat | 62 | avformat-62.dll |
| libavutil | 60 | avutil-60.dll |
| libswresample | 6 | swresample-6.dll |
| libswscale | 9 | swscale-9.dll |

(SONAMEs unchanged from 8.1 — 8.1.2 is a drop-in point release.)

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
