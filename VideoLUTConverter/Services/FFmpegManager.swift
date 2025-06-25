import Foundation

/// Manages FFmpeg binary selection and validation for universal compatibility
class FFmpegManager {
    
    enum Architecture: String {
        case x86_64 = "x86_64"
        case arm64 = "arm64"
        
        static var current: Architecture {
            #if arch(arm64)
            return .arm64
            #elseif arch(x86_64)
            return .x86_64
            #else
            return .arm64 // Default to arm64 for future compatibility
            #endif
        }
    }
    
    enum FFmpegSource {
        case systemInstalled(String)    // Path to system-installed FFmpeg
        case bundledUniversal(String)   // Path to bundled universal binary
        case bundledArchSpecific(String) // Path to architecture-specific binary
        case notFound
    }
    
    enum FFmpegError: LocalizedError {
        case binaryNotFound
        case unsupportedArchitecture(Architecture)
        case executionPermissionDenied(String)
        case validationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "FFmpeg binary not found. Please ensure FFmpeg is installed or bundled with the app."
            case .unsupportedArchitecture(let arch):
                return "FFmpeg binary doesn't support \(arch.rawValue) architecture"
            case .executionPermissionDenied(let path):
                return "FFmpeg binary at \(path) lacks execution permissions"
            case .validationFailed(let reason):
                return "FFmpeg validation failed: \(reason)"
            }
        }
    }
    
    static let shared = FFmpegManager()
    
    private var cachedFFmpegPath: String?
    private var cachedSource: FFmpegSource = .notFound
    private let currentArchitecture = Architecture.current
    
    private init() {
        detectFFmpegBinary()
    }
    
    /// Gets the validated FFmpeg executable path
    static func getFFmpegPath() throws -> String {
        if let path = shared.cachedFFmpegPath {
            return path
        }
        throw FFmpegError.binaryNotFound
    }
    
    /// Validates that FFmpeg binary is available and executable
    static func validateFFmpegBinary() -> Bool {
        return shared.cachedFFmpegPath != nil
    }
    
    /// Gets detailed system information for debugging
    static func getSystemInfo() -> String {
        let manager = shared
        let sourceDescription: String
        
        switch manager.cachedSource {
        case .systemInstalled(let path):
            sourceDescription = "System installed at \(path)"
        case .bundledUniversal(let path):
            sourceDescription = "Bundled universal binary at \(path)"
        case .bundledArchSpecific(let path):
            sourceDescription = "Bundled \(manager.currentArchitecture.rawValue) binary at \(path)"
        case .notFound:
            sourceDescription = "Not found"
        }
        
        return """
        === FFmpeg Manager Status ===
        Current Architecture: \(manager.currentArchitecture.rawValue)
        FFmpeg Source: \(sourceDescription)
        FFmpeg Path: \(manager.cachedFFmpegPath ?? "none")
        Bundle Path: \(Bundle.main.bundlePath)
        """
    }
    
    private func detectFFmpegBinary() {
        // Strategy 1: Try bundled universal binary FIRST (highest priority)
        if let universalPath = Bundle.main.path(forResource: "ffmpeg-universal", ofType: nil) {
            if validateBinary(at: universalPath) {
                self.cachedFFmpegPath = universalPath
                self.cachedSource = .bundledUniversal(universalPath)
                NSLog("FFmpeg found: bundled universal binary")
                return
            }
        }
        
        // Strategy 2: Try default bundled binary (statically linked)
        if let defaultPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            if validateBinary(at: defaultPath) {
                self.cachedFFmpegPath = defaultPath
                self.cachedSource = .bundledArchSpecific(defaultPath)
                NSLog("FFmpeg found: default bundled binary (statically linked)")
                return
            }
        }
        
        // Strategy 3: Try architecture-specific bundled binary
        let archSpecificName = "ffmpeg-\(currentArchitecture.rawValue)"
        if let archPath = Bundle.main.path(forResource: archSpecificName, ofType: nil) {
            if validateBinary(at: archPath) {
                self.cachedFFmpegPath = archPath
                self.cachedSource = .bundledArchSpecific(archPath)
                NSLog("FFmpeg found: bundled \(currentArchitecture.rawValue) binary")
                return
            }
        }
        
        // Strategy 4: Try system-installed FFmpeg as FALLBACK ONLY
        if let systemPath = findSystemFFmpeg() {
            if validateBinary(at: systemPath) {
                self.cachedFFmpegPath = systemPath
                self.cachedSource = .systemInstalled(systemPath)
                NSLog("FFmpeg found via system installation (fallback): \(systemPath)")
                return
            }
        }
        
        // Log detailed error information
        NSLog("FFmpeg detection failed for architecture: \(currentArchitecture.rawValue)")
        logAvailableResources()
        self.cachedSource = .notFound
    }
    
    private func findSystemFFmpeg() -> String? {
        let commonPaths = [
            "/opt/homebrew/bin/ffmpeg",           // Homebrew on Apple Silicon
            "/usr/local/bin/ffmpeg",              // Homebrew on Intel
            "/opt/local/bin/ffmpeg",              // MacPorts
            "/usr/bin/ffmpeg",                    // System installation
            "/usr/local/Cellar/ffmpeg/*/bin/ffmpeg" // Homebrew cellar
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try to find via PATH
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["ffmpeg"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Suppress error output
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    return output
                }
            }
        } catch {
            // Ignore errors, fall back to bundled binary
        }
        
        return nil
    }
    
    private func validateBinary(at path: String) -> Bool {
        let fileManager = FileManager.default
        
        // Check if file exists
        guard fileManager.fileExists(atPath: path) else {
            return false
        }
        
        // Check if file is executable
        guard fileManager.isExecutableFile(atPath: path) else {
            NSLog("FFmpeg binary is not executable: \(path)")
            return false
        }
        
        // Validate architecture compatibility (for bundled binaries)
        if path.contains(Bundle.main.bundlePath) {
            return validateArchitecture(at: path)
        }
        
        // For system binaries, assume they're compatible (the system should handle this)
        return true
    }
    
    private func validateArchitecture(at path: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        task.arguments = [path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Check if binary supports current architecture
            switch currentArchitecture {
            case .arm64:
                return output.contains("arm64") || output.contains("universal")
            case .x86_64:
                return output.contains("x86_64") || output.contains("universal")
            }
        } catch {
            NSLog("Architecture validation failed for \(path): \(error)")
            return false
        }
    }
    
    private func logAvailableResources() {
        guard let resourcePath = Bundle.main.resourcePath else {
            NSLog("Bundle resource path not found")
            return
        }
        
        do {
            let resources = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
            let ffmpegResources = resources.filter { $0.contains("ffmpeg") }
            NSLog("Available FFmpeg resources in bundle: \(ffmpegResources)")
            
            // Also log system paths
            NSLog("Checking system FFmpeg paths...")
            let systemPaths = [
                "/opt/homebrew/bin/ffmpeg",
                "/usr/local/bin/ffmpeg",
                "/opt/local/bin/ffmpeg"
            ]
            
            for path in systemPaths {
                let exists = FileManager.default.fileExists(atPath: path)
                NSLog("  \(path): \(exists ? "EXISTS" : "not found")")
            }
        } catch {
            NSLog("Failed to list bundle resources: \(error)")
        }
    }
    
    /// Creates a universal binary from separate architecture binaries
    static func createUniversalBinary(x86Path: String, armPath: String, outputPath: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        task.arguments = ["-create", x86Path, armPath, "-output", outputPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            NSLog("Failed to create universal binary: \(error)")
            return false
        }
    }
} 