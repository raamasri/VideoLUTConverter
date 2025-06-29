//
//  AppDelegate.swift
//  VideoLUTConverter
//
//  Created by raama srivatsan on 10/25/24.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let initialSize = NSSize(width: 1475, height: 700)
        let minSize = NSSize(width: 900, height: 600)
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(initialSize)
            window.minSize = minSize
            window.center() // Optional: center the window on screen
        }
        
        // Log application startup information
        NSLog("=== Video LUT Converter v2.0 Started ===")
        NSLog("Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        NSLog("Architecture: \(getSystemArchitecture())")
        
        // Log FFmpeg Manager status
        NSLog(FFmpegManager.getSystemInfo())
        
        // Validate FFmpeg binary availability
        if !FFmpegManager.validateFFmpegBinary() {
            NSLog("WARNING: FFmpeg binary validation failed!")
            showFFmpegWarning()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        NSLog("Video LUT Converter terminating")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    private func getSystemArchitecture() -> String {
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        var result: Int32 = 0
        sysctlbyname("hw.optional.arm64", &result, &size, nil, 0)
        return result == 1 ? "Apple Silicon (arm64)" : "Intel (x86_64)"
    }
    
    // Removed validateFFmpegBinary() - now handled by FFmpegManager
    
    private func showFFmpegWarning() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Video Processing Unavailable"
            alert.informativeText = "The video processing engine may not work correctly on this system. Some features may be limited."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Continue")
            alert.runModal()
        }
    }
}

