import Cocoa
import AVFoundation

class ViewController: NSViewController {
    
    @IBOutlet weak var loadVideoButton: NSButton!
    @IBOutlet weak var selectLUTButton: NSButton!
    @IBOutlet weak var selectSecondLUTButton: NSButton!
    @IBOutlet weak var toggleEncodingButton: NSButton!
    @IBOutlet weak var exportButton: NSButton!
    @IBOutlet weak var statusTextView: NSTextView!
    @IBOutlet weak var abortButton: NSButton!
    @IBOutlet weak var secondLUTOpacitySlider: NSSlider!
    @IBOutlet weak var opacityLabel: NSTextField!
    @IBOutlet weak var previewImageView: NSImageView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator! // Individual file progress indicator
    @IBOutlet weak var overallProgressIndicator: NSProgressIndicator! // Overall progress indicator
    
    var videoURLs: [URL] = []
    var primaryLUTURL: URL?
    var secondaryLUTURL: URL?
    var exportDirectoryURL: URL?
    var useGPU = true
    var secondLUTOpacity: Float = 1.0 // Default to full opacity
    var ffmpegProcess: Process?
    var previewProcess: Process?
    var totalFrames: Int = 0 // To store the total frame count for each video
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup statusTextView
        statusTextView.isEditable = false
        statusTextView.isSelectable = true
        statusTextView.enclosingScrollView?.hasVerticalScroller = true
        statusTextView.textContainer?.heightTracksTextView = false
        statusTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        statusTextView.isVerticallyResizable = true
        statusTextView.textColor = NSColor.white
        statusTextView.font = NSFont.systemFont(ofSize: 12)
        logMessage("App loaded")
        
        // Initialize opacity label and slider
        opacityLabel.stringValue = "Opacity: \(Int(secondLUTOpacity * 100))%"
        secondLUTOpacitySlider.floatValue = secondLUTOpacity
        
        // Initialize progress indicators
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        overallProgressIndicator.minValue = 0
        overallProgressIndicator.maxValue = 1
        overallProgressIndicator.doubleValue = 0
        
        // Set the initial button title based on the default mode
        toggleEncodingButton.title = "Switch to CPU Mode"
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = "Video LUT Converter"
    }
    
    func stripANSIColors(from text: String) -> String {
        return StringUtilities.stripANSIColors(from: text)
    }
    
    func logMessage(_ message: String) {
        let fullMessage = StringUtilities.createLogMessage(message)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: UIConstants.statusTextFontSize)
        ]
        let attributedString = NSAttributedString(string: fullMessage, attributes: attributes)
        
        statusTextView.textStorage?.append(attributedString)
        statusTextView.scrollToEndOfDocument(nil)
    }
    
    @IBAction func loadVideo(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.movie]
        openPanel.allowsMultipleSelection = true
        openPanel.begin { result in
            if result == .OK {
                self.videoURLs = openPanel.urls
                let videoNames = self.videoURLs.map { $0.lastPathComponent }.joined(separator: ", ")
                self.logMessage("Loaded video(s): \(videoNames)")
                self.updatePreview() // Update preview with the first frame of the selected video
            }
        }
    }
    
    @IBAction func selectLUT(_ sender: Any) {
        let openPanel = NSOpenPanel()
        if let cubeType = UTType(filenameExtension: "cube") {
            openPanel.allowedContentTypes = [cubeType]
        } else {
            self.logMessage("Unsupported LUT file type.")
            return
        }
        openPanel.begin { result in
            if result == .OK {
                self.primaryLUTURL = openPanel.url
                self.logMessage("Loaded primary LUT: \(self.primaryLUTURL!.lastPathComponent)")
                self.updatePreview() // Update preview after primary LUT selection
            }
        }
    }
    
    @IBAction func selectSecondLUT(_ sender: Any) {
        let openPanel = NSOpenPanel()
        if let cubeType = UTType(filenameExtension: "cube") {
            openPanel.allowedContentTypes = [cubeType]
        } else {
            self.logMessage("Unsupported LUT file type.")
            return
        }
        openPanel.begin { result in
            if result == .OK {
                self.secondaryLUTURL = openPanel.url
                self.logMessage("Loaded secondary LUT: \(self.secondaryLUTURL!.lastPathComponent)")
                self.updatePreview() // Update preview after secondary LUT selection
            }
        }
    }
    
    @IBAction func toggleEncodingMode(_ sender: Any) {
        useGPU.toggle()
        let mode = useGPU ? "GPU" : "CPU"
        toggleEncodingButton.title = "Switch to \(useGPU ? "CPU" : "GPU") Mode"
        logMessage("Switched to \(mode) encoding mode")
    }
    
    @IBAction func secondLUTOpacityChanged(_ sender: NSSlider) {
        secondLUTOpacity = sender.floatValue
        opacityLabel.stringValue = "Opacity: \(Int(secondLUTOpacity * 100))%"
        logMessage("Adjusted second LUT opacity to \(Int(secondLUTOpacity * 100))%")
        updatePreview() // Update preview after opacity adjustment
    }
    
    func updatePreview() {
        guard let videoURL = videoURLs.first else { return }
        generatePreviewImage(videoURL: videoURL)
    }
    
    func terminateProcess(_ process: Process?, completion: @escaping () -> Void) {
        guard let process = process, process.isRunning else {
            completion()
            return
        }
        
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
        process.terminate()
    }
    
    func generatePreviewImage(videoURL: URL) {
        // Terminate any existing preview process before starting a new one
        terminateProcess(previewProcess) {
            self.previewProcess = nil
            
            // Create a temporary file path for the preview image
            let tempDir = NSTemporaryDirectory()
            let tempImageURL = URL(fileURLWithPath: tempDir).appendingPathComponent("preview_image.png")
            
            // Build FFmpeg arguments to process the first frame and apply LUTs
            var arguments: [String] = []
            
            // Input file
            arguments += ["-ss", "0", "-i", videoURL.path]
            
            // Apply LUT filters using FilterBuilder
            let filterResult = FilterBuilder.buildPreviewFilter(
                primaryLUTPath: self.primaryLUTURL?.path,
                secondaryLUTPath: self.secondaryLUTURL?.path,
                opacity: self.secondLUTOpacity
            )
            
            arguments += filterResult.arguments
            
            // Output settings
            arguments += ["-y", "-f", "image2", tempImageURL.path]
            
            // Log the FFmpeg command for debugging
            self.logMessage("Generating preview image with FFmpeg command: ffmpeg \(arguments.joined(separator: " "))")
            
            let task = Process()
            if let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
                task.executableURL = URL(fileURLWithPath: ffmpegPath)
            } else {
                self.logMessage("FFmpeg executable not found in the app bundle.")
                return
            }
            task.arguments = arguments
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            self.previewProcess = task
            
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                    let cleanOutput = self?.stripANSIColors(from: output.trimmingCharacters(in: .whitespacesAndNewlines))
                    DispatchQueue.main.async {
                        self?.logMessage(cleanOutput ?? "")
                    }
                }
            }
            
            task.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        self?.logMessage("Preview image generated successfully.")
                        // Load the image and display it
                        if let previewImage = NSImage(contentsOf: tempImageURL) {
                            self?.previewImageView.image = previewImage
                            self?.previewImageView.needsDisplay = true
                        } else {
                            self?.logMessage("Failed to load preview image.")
                        }
                        // Remove the temporary image file
                        try? FileManager.default.removeItem(at: tempImageURL)
                    } else {
                        self?.logMessage("Failed to generate preview image.")
                    }
                    self?.previewProcess = nil
                }
            }
            
            do {
                try task.run()
                self.logMessage("FFmpeg process started for preview image generation.")
            } catch {
                self.logMessage("Failed to start FFmpeg process for preview image: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func exportVideo(_ sender: Any) {
        guard !videoURLs.isEmpty, primaryLUTURL != nil else {
            logMessage("Please load at least one video and a primary LUT before exporting.")
            return
        }
        
        let savePanel = NSOpenPanel()
        savePanel.canChooseDirectories = true
        savePanel.canCreateDirectories = true
        savePanel.message = "Select export directory"
        savePanel.begin { result in
            if result == .OK {
                self.exportDirectoryURL = savePanel.url
                self.logMessage("Export directory selected: \(self.exportDirectoryURL!.path)")
                self.processExport()
            }
        }
    }
    
    func processExport() {
        guard let exportDirectoryURL = exportDirectoryURL else {
            logMessage("No export directory selected.")
            return
        }
        
        logMessage("Starting export process with FFmpeg for \(videoURLs.count) video(s)...")
        
        // Update overall progress
        overallProgressIndicator.doubleValue = 0
        let totalVideos = videoURLs.count
        
        // A helper function to export each video in sequence
        func exportNextVideo(_ index: Int) {
            if index >= videoURLs.count {
                logMessage("All videos have been exported.")
                overallProgressIndicator.doubleValue = 1
                return
            }
            
            let videoURL = videoURLs[index]
            let filename = videoURL.deletingPathExtension().lastPathComponent
            let secondaryLUTName = secondaryLUTURL?.deletingPathExtension().lastPathComponent ?? "NoSecondLUT"
            let outputFileName = "\(filename)_converted_\(secondaryLUTName)_\(Int(secondLUTOpacity * 100))percent.mp4"
            let outputURL = exportDirectoryURL.appendingPathComponent(outputFileName)
            
            exportVideo(videoURL: videoURL, primaryLUTURL: primaryLUTURL!, secondaryLUTURL: secondaryLUTURL, exportURL: outputURL) {
                self.logMessage("Completed export for \(filename)")
                // Update overall progress indicator
                let overallProgress = Double(index + 1) / Double(totalVideos)
                self.overallProgressIndicator.doubleValue = overallProgress
                
                exportNextVideo(index + 1) // Proceed to the next video after the current one finishes
            }
        }
        
        // Start exporting the first video
        exportNextVideo(0)
    }
    
    func exportVideo(videoURL: URL, primaryLUTURL: URL, secondaryLUTURL: URL?, exportURL: URL, completion: @escaping () -> Void) {
        terminateProcess(previewProcess) {
            self.previewProcess = nil
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                self.terminateProcess(self.ffmpegProcess) {
                    self.ffmpegProcess = nil
                    
                    self.logMessage("Starting export for \(videoURL.lastPathComponent)...")
                    
                    // Calculate total frames using modern async APIs
                    let asset = AVURLAsset(url: videoURL)
                    Task {
                        do {
                            let tracks = try await asset.loadTracks(withMediaType: .video)
                            if let track = tracks.first {
                                let fps = try await track.load(.nominalFrameRate)
                                let duration = try await asset.load(.duration)
                                let totalFrames = Int(Double(fps) * CMTimeGetSeconds(duration))
                                
                                await MainActor.run {
                                    self.totalFrames = totalFrames
                                    self.progressIndicator.minValue = 0
                                    self.progressIndicator.maxValue = 1
                                    self.progressIndicator.doubleValue = 0
                                    
                                    // Continue with FFmpeg execution after metadata is loaded
                                    self.executeFFmpegExport(videoURL: videoURL, primaryLUTURL: primaryLUTURL, secondaryLUTURL: secondaryLUTURL, exportURL: exportURL, completion: completion)
                                }
                            } else {
                                await MainActor.run {
                                    self.logMessage("Failed to retrieve video track for \(videoURL.lastPathComponent).")
                                }
                                return
                            }
                        } catch {
                            await MainActor.run {
                                self.logMessage("Failed to load video metadata: \(error.localizedDescription)")
                            }
                            return
                        }
                    }
                }
            })
        }
    }
    
    private func executeFFmpegExport(videoURL: URL, primaryLUTURL: URL, secondaryLUTURL: URL?, exportURL: URL, completion: @escaping () -> Void) {
        var arguments: [String] = ["-y"]
        
        // Input file
        arguments += ["-i", videoURL.path]
        
        // Video encoding settings
        arguments += ["-fps_mode", "passthrough", "-ignore_editlist", "1"]
        
        // Configure video codec using FilterBuilder
        arguments += FilterBuilder.buildEncodingArguments(useGPU: self.useGPU)
        
        // Configure audio codec
        arguments += ["-c:a", "aac", "-b:a", "192k"]
        
        // Apply filter_complex using FilterBuilder
        let pixelFormat = self.useGPU ? "nv12" : "yuv422p"
        let filterComplex = FilterBuilder.buildExportFilter(
            primaryLUTPath: primaryLUTURL.path,
            secondaryLUTPath: secondaryLUTURL?.path,
            opacity: self.secondLUTOpacity,
            pixelFormat: pixelFormat
        )
        
        arguments += ["-filter_complex", filterComplex]
        arguments += ["-map", "[out]"]
        arguments += ["-map", "0:a?"] // Map audio if available
        
        arguments += [exportURL.path]
        
        // Log FFmpeg command for reference
        self.logMessage("Exporting with FFmpeg command: ffmpeg \(arguments.joined(separator: " "))")
        
        let task = Process()
        if let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            task.executableURL = URL(fileURLWithPath: ffmpegPath)
        } else {
            self.logMessage("FFmpeg executable not found in the app bundle.")
            return
        }
        
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        self.ffmpegProcess = task
        
        // Readability handler for progress parsing
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                let cleanOutput = self?.stripANSIColors(from: output.trimmingCharacters(in: .whitespacesAndNewlines))
                
                // Update log
                DispatchQueue.main.async {
                    self?.logMessage(cleanOutput ?? "")
                }
                
                // Progress parsing
                if let frameMatch = cleanOutput?.range(of: #"frame=\s*\d+"#, options: .regularExpression) {
                    let frameText = cleanOutput![frameMatch]
                    if let frameValue = Int(frameText.split(separator: "=")[1].trimmingCharacters(in: .whitespaces)) {
                        // Calculate progress fraction
                        let progressFraction = Double(frameValue) / Double(self?.totalFrames ?? 1)
                        DispatchQueue.main.async {
                            self?.progressIndicator.doubleValue = progressFraction
                        }
                    }
                }
            }
        }
        
        task.terminationHandler = { process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    self.logMessage("Export completed successfully for \(videoURL.lastPathComponent)!")
                } else {
                    self.logMessage("Export failed for \(videoURL.lastPathComponent).")
                }
                self.ffmpegProcess = nil
                completion()
            }
        }
        
        do {
            try task.run()
            self.logMessage("FFmpeg process started for \(videoURL.lastPathComponent).")
        } catch {
            self.logMessage("Failed to start FFmpeg process for \(videoURL.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    @IBAction func abortProcess(_ sender: Any) {
        terminateProcess(ffmpegProcess) {
            self.ffmpegProcess = nil
            
            self.terminateProcess(self.previewProcess) {
                self.previewProcess = nil
                
                self.logMessage("Process aborted by user.")
            }
        }
    }
}
