#include <iostream>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
}

int main() {
    std::cout << "Testing FFmpeg integration..." << std::endl;
    
    // 输出FFmpeg版本信息
    std::cout << "FFmpeg version: " << av_version_info() << std::endl;
    std::cout << "libavcodec version: " << avcodec_version() << std::endl;
    std::cout << "libavformat version: " << avformat_version() << std::endl;
    std::cout << "libavutil version: " << avutil_version() << std::endl;
    
    // 初始化FFmpeg
    avformat_network_init();
    
    std::cout << "FFmpeg initialization successful!" << std::endl;
    
    return 0;
}