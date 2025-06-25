import Foundation

struct StringUtilities {
    
    /// Removes ANSI color codes from text
    static func stripANSIColors(from text: String) -> String {
        let pattern = "\u{001B}\\[[0-9;]*m"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression, range: nil)
    }
    
    /// Creates a formatted opacity string for FFmpeg filters
    static func formatOpacity(_ opacity: Float) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: opacity)) ?? "1.0"
    }
    
    /// Creates a timestamped log message
    static func createLogMessage(_ message: String) -> String {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        return "[\(timestamp)] \(message)\n"
    }
    
    /// Creates output filename for converted videos
    static func createOutputFileName(
        originalName: String,
        secondaryLUTName: String?,
        opacityPercentage: Int,
        outputFormat: String = "mp4"
    ) -> String {
        let lutName = secondaryLUTName ?? "NoSecondLUT"
        return "\(originalName)_converted_\(lutName)_\(opacityPercentage)percent.\(outputFormat)"
    }
} 