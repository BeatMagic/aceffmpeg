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
