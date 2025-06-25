import Foundation

struct FilterBuilder {
    
    /// Formats opacity value for FFmpeg filters
    private static func formatOpacity(_ opacity: Float) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: opacity)) ?? "1.0"
    }
    
    /// Builds a filter complex string for preview image generation
    static func buildPreviewFilter(
        primaryLUTPath: String?,
        secondaryLUTPath: String?,
        opacity: Float
    ) -> (arguments: [String], hasFilter: Bool) {
        
        guard let primaryLUTPath = primaryLUTPath else {
            return (arguments: ["-frames:v", "1"], hasFilter: false)
        }
        
        if let secondaryLUTPath = secondaryLUTPath {
            let opacityString = formatOpacity(opacity)
            let filterComplex = """
            [0:v]lut3d='\(primaryLUTPath)'[primary];
            [0:v]lut3d='\(primaryLUTPath)',lut3d='\(secondaryLUTPath)'[secondary];
            [primary][secondary]blend=all_mode='overlay':all_opacity=\(opacityString)[out]
            """
            
            return (arguments: [
                "-frames:v", "1",
                "-filter_complex", filterComplex,
                "-map", "[out]"
            ], hasFilter: true)
        } else {
            return (arguments: [
                "-frames:v", "1",
                "-vf", "lut3d='\(primaryLUTPath)'"
            ], hasFilter: true)
        }
    }
    
    /// Builds a filter complex string for video export
    static func buildExportFilter(
        primaryLUTPath: String?,
        secondaryLUTPath: String?,
        opacity: Float,
        pixelFormat: String
    ) -> String {
        
        guard let primaryLUTPath = primaryLUTPath else {
            return "[0:v]format=\(pixelFormat)[out]"
        }
        
        if let secondaryLUTPath = secondaryLUTPath {
            let opacityString = formatOpacity(opacity)
            return """
            [0:v]lut3d='\(primaryLUTPath)'[primary];
            [0:v]lut3d='\(primaryLUTPath)',lut3d='\(secondaryLUTPath)'[secondary];
            [primary][secondary]blend=all_mode='overlay':all_opacity=\(opacityString),format=\(pixelFormat)[out]
            """
        } else {
            return "[0:v]lut3d='\(primaryLUTPath)',format=\(pixelFormat)[out]"
        }
    }
    
    /// Builds FFmpeg encoding arguments based on settings
    static func buildEncodingArguments(useGPU: Bool) -> [String] {
        if useGPU {
            return [
                "-c:v", "h264_videotoolbox",
                "-b:v", "140000k",
                "-profile:v", "high",
                "-level:v", "5.1",
                "-pix_fmt", "nv12"
            ]
        } else {
            return [
                "-c:v", "libx264",
                "-preset", "veryslow",
                "-crf", "0",
                "-pix_fmt", "yuv422p"
            ]
        }
    }
} 