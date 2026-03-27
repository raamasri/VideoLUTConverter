import Foundation

struct FFmpegConstants {
    static let defaultBitrate = "140000k"
    static let audioCodec = "aac"
    static let audioBitrate = "192k"
    static let profileHigh = "high"
    static let levelHigh = "5.1"
    static let presetVerySlow = "veryslow"
    static let crfLossless = "0"
    static let pixelFormatNV12 = "nv12"
    static let pixelFormatYUV422P = "yuv422p"
}

struct UIConstants {
    static let statusTextFontSize: CGFloat = 12
    static let defaultOpacity: Float = 1.0
    static let progressMinValue: Double = 0
    static let progressMaxValue: Double = 1
}

struct FileConstants {
    static let lutFileExtension = "cube"
    static let outputFileExtension = "mp4"
    static let previewImageName = "preview_image.png"
    static let ffmpegResourceName = "ffmpeg"
}

struct FilterConstants {
    static let lutFilterName = "lut3d"
    static let blendFilterName = "blend"
    static let formatFilterName = "format"
    static let overlayMode = "overlay"
} 