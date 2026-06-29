#!/bin/bash
set -euo pipefail

# Build FFmpeg debug variant for macOS (arm64 + x86_64)
# Usage: ./build_macos_debug.sh [arm64|x86_64|all]
#
# Builds dav1d 1.5.1, LAME 3.100, Opus 1.5.2, and FFmpeg 8.1.2 with debug
# symbols (-g). Unlike the release build, the output is NOT stripped — symbols
# are preserved for stack traces. FFmpeg still uses -O2 (required to avoid
# linker errors from dead-code elimination patterns).
#
# Requires: clang/Xcode, autoconf/automake/libtool, nasm (x86_64 asm), and
# python3 + meson + ninja (dav1d build system).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_BASE="${SCRIPT_DIR}/ffmpeg/lib/macos"
BUILD_BASE="${TMPDIR:-/tmp}/ffmpeg_debug_build"

FFMPEG_VERSION="8.1.2"
LAME_VERSION="3.100"
OPUS_VERSION="1.5.2"
DAV1D_VERSION="1.5.1"

MIN_MACOS_VERSION="13.0"

# What to build
ARCH="${1:-all}"

mkdir -p "$BUILD_BASE"
cd "$BUILD_BASE"

# ──────────────────────────────────────────────
# Download sources if not present
# ──────────────────────────────────────────────
download_sources() {
    echo "=== Downloading sources ==="

    if [ ! -f "ffmpeg-${FFMPEG_VERSION}.tar.xz" ]; then
        echo "Downloading FFmpeg ${FFMPEG_VERSION}..."
        curl -L -o "ffmpeg-${FFMPEG_VERSION}.tar.xz" \
            "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
    fi

    if [ ! -f "lame-${LAME_VERSION}.tar.gz" ]; then
        echo "Downloading LAME ${LAME_VERSION}..."
        curl -L -o "lame-${LAME_VERSION}.tar.gz" \
            "https://sourceforge.net/projects/lame/files/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz/download"
    fi

    if [ ! -f "opus-${OPUS_VERSION}.tar.gz" ]; then
        echo "Downloading Opus ${OPUS_VERSION}..."
        curl -L -o "opus-${OPUS_VERSION}.tar.gz" \
            "https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz"
    fi

    if [ ! -f "dav1d-${DAV1D_VERSION}.tar.xz" ]; then
        echo "Downloading dav1d ${DAV1D_VERSION}..."
        curl -L -o "dav1d-${DAV1D_VERSION}.tar.xz" \
            "https://downloads.videolan.org/pub/videolan/dav1d/${DAV1D_VERSION}/dav1d-${DAV1D_VERSION}.tar.xz"
    fi

    echo "=== All sources downloaded ==="
}

# ──────────────────────────────────────────────
# Build dav1d (fast AV1 software decoder, BSD) for a given architecture.
# Uses meson/ninja. buildtype=debugoptimized -> -O2 + debug info.
# ──────────────────────────────────────────────
build_dav1d() {
    local arch="$1"
    local install_dir="${BUILD_BASE}/install-${arch}"
    local src_dir="${BUILD_BASE}/dav1d-${DAV1D_VERSION}-${arch}"
    local build_dir="${src_dir}/build"

    echo "=== Building dav1d ${DAV1D_VERSION} (${arch}, debug) ==="

    rm -rf "$src_dir"
    tar xf "dav1d-${DAV1D_VERSION}.tar.xz"
    mv "dav1d-${DAV1D_VERSION}" "$src_dir"

    local meson_cross=()
    if [ "$arch" = "arm64" ]; then
        meson setup "$build_dir" "$src_dir" \
            --prefix="$install_dir" --libdir=lib --buildtype=debugoptimized \
            --default-library=shared -Denable_tools=false -Denable_tests=false \
            "-Dc_args=-mmacosx-version-min=${MIN_MACOS_VERSION}" \
            "-Dc_link_args=-mmacosx-version-min=${MIN_MACOS_VERSION}"
    else
        cat > "${BUILD_BASE}/dav1d-cross-x86_64.txt" <<EOF
[binaries]
c = ['clang', '-arch', 'x86_64']
cpp = ['clang++', '-arch', 'x86_64']
objc = ['clang', '-arch', 'x86_64']
ar = 'ar'
strip = 'strip'
nasm = 'nasm'

[built-in options]
c_args = ['-mmacosx-version-min=${MIN_MACOS_VERSION}']
c_link_args = ['-mmacosx-version-min=${MIN_MACOS_VERSION}', '-arch', 'x86_64']

[host_machine]
system = 'darwin'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF
        meson setup "$build_dir" "$src_dir" \
            --prefix="$install_dir" --libdir=lib --buildtype=debugoptimized \
            --default-library=shared -Denable_tools=false -Denable_tests=false \
            --cross-file "${BUILD_BASE}/dav1d-cross-x86_64.txt"
    fi

    meson compile -C "$build_dir"
    meson install -C "$build_dir"

    # Fix install name -> @rpath (versioned real dylib, e.g. libdav1d.7.dylib)
    local dav_real
    dav_real=$(cd "${install_dir}/lib" && ls libdav1d.*.dylib | grep -E '^libdav1d\.[0-9]+\.dylib$' | head -1)
    install_name_tool -id "@rpath/${dav_real}" "${install_dir}/lib/${dav_real}"

    cd "$BUILD_BASE"
    echo "=== dav1d (${arch}, debug) done: ${dav_real} ==="
}

# ──────────────────────────────────────────────
# Build LAME for a given architecture
# ──────────────────────────────────────────────
build_lame() {
    local arch="$1"
    local install_dir="${BUILD_BASE}/install-${arch}"
    local src_dir="${BUILD_BASE}/lame-${LAME_VERSION}-${arch}"

    echo "=== Building LAME ${LAME_VERSION} (${arch}, debug) ==="

    rm -rf "$src_dir"
    tar xf "lame-${LAME_VERSION}.tar.gz"
    mv "lame-${LAME_VERSION}" "$src_dir"
    cd "$src_dir"

    # Patch: remove lame_init_old (undefined symbol)
    sed -i.bak '/lame_init_old/d' include/libmp3lame.sym

    local host
    if [ "$arch" = "arm64" ]; then
        host="aarch64-apple-darwin"
    else
        host="x86_64-apple-darwin"
    fi

    ./configure \
        --prefix="$install_dir" \
        --enable-shared \
        --disable-static \
        --disable-frontend \
        --disable-gtktest \
        --host="$host" \
        CFLAGS="-arch ${arch} -mmacosx-version-min=${MIN_MACOS_VERSION} -O2 -g" \
        LDFLAGS="-arch ${arch} -mmacosx-version-min=${MIN_MACOS_VERSION}"

    make -j"$(sysctl -n hw.ncpu)" && make install

    # Fix install name
    install_name_tool -id "@rpath/libmp3lame.0.dylib" "${install_dir}/lib/libmp3lame.0.dylib"

    cd "$BUILD_BASE"
    echo "=== LAME (${arch}, debug) done ==="
}

# ──────────────────────────────────────────────
# Build Opus for a given architecture
# ──────────────────────────────────────────────
build_opus() {
    local arch="$1"
    local install_dir="${BUILD_BASE}/install-${arch}"
    local src_dir="${BUILD_BASE}/opus-${OPUS_VERSION}-${arch}"

    echo "=== Building Opus ${OPUS_VERSION} (${arch}, debug) ==="

    rm -rf "$src_dir"
    tar xf "opus-${OPUS_VERSION}.tar.gz"
    mv "opus-${OPUS_VERSION}" "$src_dir"
    cd "$src_dir"

    local host
    if [ "$arch" = "arm64" ]; then
        host="aarch64-apple-darwin"
    else
        host="x86_64-apple-darwin"
    fi

    ./configure \
        --prefix="$install_dir" \
        --enable-shared \
        --disable-static \
        --disable-doc \
        --disable-extra-programs \
        --host="$host" \
        CFLAGS="-arch ${arch} -mmacosx-version-min=${MIN_MACOS_VERSION} -O2 -g" \
        LDFLAGS="-arch ${arch} -mmacosx-version-min=${MIN_MACOS_VERSION}"

    make -j"$(sysctl -n hw.ncpu)" && make install

    # Fix install name
    install_name_tool -id "@rpath/libopus.0.dylib" "${install_dir}/lib/libopus.0.dylib"

    cd "$BUILD_BASE"
    echo "=== Opus (${arch}, debug) done ==="
}

# ──────────────────────────────────────────────
# Build FFmpeg for a given architecture
# ──────────────────────────────────────────────
build_ffmpeg() {
    local arch="$1"
    local install_dir="${BUILD_BASE}/install-${arch}"
    local ffmpeg_install="${BUILD_BASE}/ffmpeg-install-${arch}"
    local src_dir="${BUILD_BASE}/ffmpeg-${FFMPEG_VERSION}-${arch}"

    echo "=== Building FFmpeg ${FFMPEG_VERSION} (${arch}, debug) ==="

    rm -rf "$src_dir"
    tar xf "ffmpeg-${FFMPEG_VERSION}.tar.xz"
    mv "ffmpeg-${FFMPEG_VERSION}" "$src_dir"
    cd "$src_dir"

    # FFmpeg finds dav1d (and opus) through pkg-config.
    export PKG_CONFIG_PATH="${install_dir}/lib/pkgconfig"

    local extra_configure_flags=()
    if [ "$arch" = "arm64" ]; then
        extra_configure_flags+=(
            --enable-neon
        )
    else
        extra_configure_flags+=(
            --enable-cross-compile
            "--cc=clang -arch x86_64"
            --enable-x86asm
        )
    fi

    ./configure \
        --prefix="$ffmpeg_install" \
        --arch="$arch" \
        --target-os=darwin \
        --enable-shared \
        --disable-static \
        --enable-version3 \
        --disable-gpl \
        --disable-programs \
        --disable-doc \
        --enable-debug \
        --disable-stripping \
        --enable-videotoolbox \
        --enable-audiotoolbox \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libdav1d \
        --disable-xlib \
        --disable-libxcb \
        --disable-libxcb-shm \
        --disable-libxcb-xfixes \
        --disable-libxcb-shape \
        --disable-sdl2 \
        --extra-cflags="-mmacosx-version-min=${MIN_MACOS_VERSION} -g -I${install_dir}/include" \
        --extra-ldflags="-mmacosx-version-min=${MIN_MACOS_VERSION} -L${install_dir}/lib $([ "$arch" = "x86_64" ] && echo "-arch x86_64" || true)" \
        --install-name-dir='@rpath' \
        "${extra_configure_flags[@]}"

    make -j"$(sysctl -n hw.ncpu)" && make install

    cd "$BUILD_BASE"
    echo "=== FFmpeg (${arch}, debug) done ==="
}

# ──────────────────────────────────────────────
# Fix install names for FFmpeg dylibs referencing lame/opus
# ──────────────────────────────────────────────
fix_install_names() {
    local arch="$1"
    local install_dir="${BUILD_BASE}/install-${arch}"
    local ffmpeg_install="${BUILD_BASE}/ffmpeg-install-${arch}"

    echo "=== Fixing install names (${arch}) ==="

    # Fix lame references in FFmpeg libs
    for dylib in "${ffmpeg_install}"/lib/lib*.dylib; do
        [ -L "$dylib" ] && continue  # skip symlinks
        local old
        old=$(otool -L "$dylib" | grep libmp3lame | awk '{print $1}' || true)
        if [ -n "$old" ] && [ "$old" != "@rpath/libmp3lame.0.dylib" ]; then
            install_name_tool -change "$old" "@rpath/libmp3lame.0.dylib" "$dylib"
            echo "  Fixed lame ref in $(basename "$dylib")"
        fi
        old=$(otool -L "$dylib" | grep libopus | awk '{print $1}' || true)
        if [ -n "$old" ] && [ "$old" != "@rpath/libopus.0.dylib" ]; then
            install_name_tool -change "$old" "@rpath/libopus.0.dylib" "$dylib"
            echo "  Fixed opus ref in $(basename "$dylib")"
        fi
        old=$(otool -L "$dylib" | grep libdav1d | awk '{print $1}' || true)
        if [ -n "$old" ] && [ "${old##*/}" != "$old" ] && [ "${old#@rpath/}" = "$old" ]; then
            install_name_tool -change "$old" "@rpath/${old##*/}" "$dylib"
            echo "  Fixed dav1d ref in $(basename "$dylib")"
        fi
    done

    echo "=== Install names fixed (${arch}) ==="
}

# ──────────────────────────────────────────────
# Copy debug dylibs to destination
# ──────────────────────────────────────────────
install_to_repo() {
    local arch="$1"
    local install_dir="${BUILD_BASE}/install-${arch}"
    local ffmpeg_install="${BUILD_BASE}/ffmpeg-install-${arch}"
    local dest="${DEST_BASE}/${arch}/debug"

    echo "=== Installing debug dylibs to ${dest} ==="

    rm -rf "$dest"
    mkdir -p "$dest"

    # Copy FFmpeg dylibs (versioned real files + symlinks)
    for lib in avcodec avdevice avfilter avformat avutil swresample swscale; do
        # Find the fully versioned real file
        local real_file
        real_file=$(find "${ffmpeg_install}/lib" -maxdepth 1 -name "lib${lib}.*.*.*.dylib" -not -type l | head -1)
        if [ -z "$real_file" ]; then
            echo "WARNING: lib${lib} versioned dylib not found!"
            continue
        fi
        local real_name
        real_name=$(basename "$real_file")
        cp "$real_file" "${dest}/${real_name}"

        # Extract SOVERSION (e.g., "62" from "libavcodec.62.28.100.dylib")
        local soversion
        soversion=$(echo "$real_name" | sed "s/lib${lib}\.\([0-9]*\)\..*/\1/")

        # Create symlinks
        ln -sf "$real_name" "${dest}/lib${lib}.${soversion}.dylib"
        ln -sf "$real_name" "${dest}/lib${lib}.dylib"
    done

    # Copy LAME
    cp "${install_dir}/lib/libmp3lame.0.dylib" "${dest}/libmp3lame.0.dylib"
    ln -sf "libmp3lame.0.dylib" "${dest}/libmp3lame.dylib"

    # Copy Opus
    cp "${install_dir}/lib/libopus.0.dylib" "${dest}/libopus.0.dylib"
    ln -sf "libopus.0.dylib" "${dest}/libopus.dylib"

    # Copy dav1d (versioned real file + unversioned symlink)
    local dav_real
    dav_real=$(cd "${install_dir}/lib" && ls libdav1d.*.dylib | grep -E '^libdav1d\.[0-9]+\.dylib$' | head -1)
    cp "${install_dir}/lib/${dav_real}" "${dest}/${dav_real}"
    ln -sf "${dav_real}" "${dest}/libdav1d.dylib"

    echo "=== Installed to ${dest} ==="
    echo "Files:"
    ls -lh "$dest"
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
build_arch() {
    local arch="$1"
    echo ""
    echo "============================================"
    echo "  Building debug FFmpeg for macOS ${arch}"
    echo "============================================"
    echo ""

    build_dav1d "$arch"
    build_lame "$arch"
    build_opus "$arch"
    build_ffmpeg "$arch"
    fix_install_names "$arch"
    install_to_repo "$arch"

    echo ""
    echo "=== macOS ${arch} debug build complete ==="
    echo ""
}

download_sources

if [ "$ARCH" = "all" ]; then
    build_arch arm64
    build_arch x86_64
elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "x86_64" ]; then
    build_arch "$ARCH"
else
    echo "Usage: $0 [arm64|x86_64|all]"
    exit 1
fi

echo ""
echo "==============================="
echo "  All builds complete!"
echo "==============================="
echo "Debug dylibs installed to:"
if [ "$ARCH" = "all" ] || [ "$ARCH" = "arm64" ]; then
    echo "  ${DEST_BASE}/arm64/debug/"
fi
if [ "$ARCH" = "all" ] || [ "$ARCH" = "x86_64" ]; then
    echo "  ${DEST_BASE}/x86_64/debug/"
fi
