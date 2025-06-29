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
    
    /// Converts white balance slider value to temperature in Kelvin
    private static func sliderToTemperature(_ value: Float) -> Int {
        // Convert slider value (-10 to +10) to temperature (2400K to 8000K)
        // 0 = 5500K, -10 = 2400K, +10 = 8000K
        let baseTemp = 5500
        let tempChange = Int(value * 280) // 280K per step to cover the range
        return baseTemp + tempChange
    }
    
    /// Builds white balance filter string for FFmpeg
    private static func buildWhiteBalanceFilter(_ whiteBalanceValue: Float) -> String {
        if whiteBalanceValue == 0.0 {
            return "" // No white balance adjustment needed
        }
        
        let temperature = sliderToTemperature(whiteBalanceValue)
        
        // Convert temperature to RGB multipliers
        // This is a simplified conversion for demonstration
        // For more accurate conversion, you might want to use a proper color temperature algorithm
        var rMult: Float = 1.0
        var gMult: Float = 1.0
        var bMult: Float = 1.0
        
        if temperature < 5500 { // Warmer
            let factor = Float(5500 - temperature) / 3100.0 // 3100 = 5500 - 2400
            rMult = 1.0 + (factor * 0.3) // Increase red
            bMult = 1.0 - (factor * 0.4) // Decrease blue
        } else { // Cooler
            let factor = Float(temperature - 5500) / 2500.0 // 2500 = 8000 - 5500
            rMult = 1.0 - (factor * 0.3) // Decrease red
            bMult = 1.0 + (factor * 0.4) // Increase blue
        }
        
        return "colorbalance=rs=\(formatOpacity(rMult - 1.0)):bs=\(formatOpacity(bMult - 1.0))"
    }
    
    /// Builds a filter complex string for preview image generation
    static func buildPreviewFilter(
        primaryLUTPath: String?,
        secondaryLUTPath: String?,
        opacity: Float,
        whiteBalance: Float
    ) -> (arguments: [String], hasFilter: Bool) {
        
        let whiteBalanceFilter = buildWhiteBalanceFilter(whiteBalance)
        let hasWhiteBalance = !whiteBalanceFilter.isEmpty
        
        guard let primaryLUTPath = primaryLUTPath else {
            if hasWhiteBalance {
                return (arguments: [
                    "-frames:v", "1",
                    "-vf", whiteBalanceFilter
                ], hasFilter: true)
            } else {
                return (arguments: ["-frames:v", "1"], hasFilter: false)
            }
        }
        
        if let secondaryLUTPath = secondaryLUTPath {
            let opacityString = formatOpacity(opacity)
            var filterComplex = """
            [0:v]lut3d='\(primaryLUTPath)'[primary];
            [0:v]lut3d='\(primaryLUTPath)',lut3d='\(secondaryLUTPath)'[secondary];
            [primary][secondary]blend=all_mode='overlay':all_opacity=\(opacityString)
            """
            
            if hasWhiteBalance {
                filterComplex += ",\(whiteBalanceFilter)[out]"
            } else {
                filterComplex += "[out]"
            }
            
            return (arguments: [
                "-frames:v", "1",
                "-filter_complex", filterComplex,
                "-map", "[out]"
            ], hasFilter: true)
        } else {
            var vfFilter = "lut3d='\(primaryLUTPath)'"
            if hasWhiteBalance {
                vfFilter += ",\(whiteBalanceFilter)"
            }
            
            return (arguments: [
                "-frames:v", "1",
                "-vf", vfFilter
            ], hasFilter: true)
        }
    }
    
    /// Builds a filter complex string for video export
    static func buildExportFilter(
        primaryLUTPath: String?,
        secondaryLUTPath: String?,
        opacity: Float,
        whiteBalance: Float,
        pixelFormat: String
    ) -> String {
        
        let whiteBalanceFilter = buildWhiteBalanceFilter(whiteBalance)
        let hasWhiteBalance = !whiteBalanceFilter.isEmpty
        
        guard let primaryLUTPath = primaryLUTPath else {
            if hasWhiteBalance {
                return "[0:v]\(whiteBalanceFilter),format=\(pixelFormat)[out]"
            } else {
                return "[0:v]format=\(pixelFormat)[out]"
            }
        }
        
        if let secondaryLUTPath = secondaryLUTPath {
            let opacityString = formatOpacity(opacity)
            var filterString = """
            [0:v]lut3d='\(primaryLUTPath)'[primary];
            [0:v]lut3d='\(primaryLUTPath)',lut3d='\(secondaryLUTPath)'[secondary];
            [primary][secondary]blend=all_mode='overlay':all_opacity=\(opacityString)
            """
            
            if hasWhiteBalance {
                filterString += ",\(whiteBalanceFilter),format=\(pixelFormat)[out]"
            } else {
                filterString += ",format=\(pixelFormat)[out]"
            }
            
            return filterString
        } else {
            var filterString = "[0:v]lut3d='\(primaryLUTPath)'"
            if hasWhiteBalance {
                filterString += ",\(whiteBalanceFilter)"
            }
            filterString += ",format=\(pixelFormat)[out]"
            return filterString
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