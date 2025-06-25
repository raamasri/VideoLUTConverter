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
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

