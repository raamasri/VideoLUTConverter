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
    @IBOutlet weak var whiteBalanceSlider: NSSlider!
    @IBOutlet weak var whiteBalanceLabel: NSTextField!
    @IBOutlet weak var previewImageView: NSImageView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator! // Individual file progress indicator
    @IBOutlet weak var overallProgressIndicator: NSProgressIndicator! // Overall progress indicator
    
    var videoURLs: [URL] = []
    var primaryLUTURL: URL?
    var secondaryLUTURL: URL?
    var exportDirectoryURL: URL?
    var useGPU = true
    var secondLUTOpacity: Float = 1.0 // Default to full opacity
    var whiteBalanceValue: Float = 0.0 // Default to neutral (5500K), range -10 to +10
    var ffmpegProcess: Process?
    var previewProcess: Process?
    var totalFrames: Int = 0 // To store the total frame count for each video
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupVisualEffects()
        
        statusTextView.isEditable = false
        statusTextView.isSelectable = true
        statusTextView.enclosingScrollView?.hasVerticalScroller = true
        statusTextView.textContainer?.heightTracksTextView = false
        statusTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        statusTextView.isVerticallyResizable = true
        statusTextView.font = NSFont.systemFont(ofSize: 12)
        logMessage("App loaded")
        
        // Initialize opacity label and slider
        opacityLabel.stringValue = "Opacity: \(Int(secondLUTOpacity * 100))%"
        secondLUTOpacitySlider.floatValue = secondLUTOpacity
        
        // Initialize white balance label and slider
        whiteBalanceLabel.stringValue = "White Balance: \(formatTemperature(whiteBalanceValue))K"
        whiteBalanceSlider.floatValue = whiteBalanceValue
        
        // Initialize progress indicators
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        overallProgressIndicator.minValue = 0
        overallProgressIndicator.maxValue = 1
        overallProgressIndicator.doubleValue = 0
        
        // Set the initial button title based on the default mode
        toggleEncodingButton.title = "Switch to CPU Mode"
        
        // Setup drag and drop
        setupDragAndDrop()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = "Video LUT Converter"
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        cleanupTemporaryFiles()
    }
    
    private func setupVisualEffects() {
        let effectView = NSVisualEffectView()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        if #available(macOS 14.0, *) {
            effectView.material = .contentBackground
        } else {
            effectView.material = .sidebar
        }
        
        view.addSubview(effectView, positioned: .below, relativeTo: view.subviews.first)
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: view.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        statusTextView.drawsBackground = false
        statusTextView.enclosingScrollView?.drawsBackground = false
        statusTextView.textColor = NSColor.labelColor
    }
    
    /// Cleans up any temporary preview images
    func cleanupTemporaryFiles() {
        let tempDir = NSTemporaryDirectory()
        let tempImageURL = URL(fileURLWithPath: tempDir).appendingPathComponent("preview_image.png")
        
        do {
            if FileManager.default.fileExists(atPath: tempImageURL.path) {
                try FileManager.default.removeItem(at: tempImageURL)
                logMessage("Cleaned up temporary files on exit.")
            }
        } catch {
            // Silently ignore cleanup errors on exit
        }
    }
    
    func stripANSIColors(from text: String) -> String {
        return StringUtilities.stripANSIColors(from: text)
    }
    
    func formatTemperature(_ value: Float) -> Int {
        // Convert slider value (-10 to +10) to temperature (2400K to 8000K)
        // 0 = 5500K, -10 = 2400K, +10 = 8000K
        let baseTemp = 5500
        let tempChange = Int(value * 280) // 280K per step to cover the range
        return baseTemp + tempChange
    }
    
    func logMessage(_ message: String) {
        let fullMessage = StringUtilities.createLogMessage(message)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
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
                // Validate video files before accepting them
                let validVideos = openPanel.urls.filter { self.validateVideoFile($0) }
                let invalidCount = openPanel.urls.count - validVideos.count
                
                if validVideos.isEmpty {
                    self.showAlert(title: "Invalid Video Files", 
                                 message: "None of the selected files appear to be valid video files. Please select valid video files.")
                    self.logMessage("ERROR: No valid video files selected.")
                    return
                }
                
                if invalidCount > 0 {
                    self.logMessage("WARNING: Skipped \(invalidCount) invalid video file(s).")
                }
                
                self.videoURLs = validVideos
                let videoNames = validVideos.map { $0.lastPathComponent }.joined(separator: ", ")
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
            if result == .OK, let lutURL = openPanel.url {
                // Validate LUT file before accepting it
                if self.validateLUTFile(lutURL) {
                    self.primaryLUTURL = lutURL
                    self.logMessage("Loaded primary LUT: \(lutURL.lastPathComponent)")
                    self.updatePreview() // Update preview after primary LUT selection
                } else {
                    self.showAlert(title: "Invalid LUT File", 
                                 message: "The selected file '\(lutURL.lastPathComponent)' does not appear to be a valid .cube LUT file. Please select a valid LUT file.")
                    self.logMessage("ERROR: Invalid LUT file rejected: \(lutURL.lastPathComponent)")
                }
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
            if result == .OK, let lutURL = openPanel.url {
                // Validate LUT file before accepting it
                if self.validateLUTFile(lutURL) {
                    self.secondaryLUTURL = lutURL
                    self.logMessage("Loaded secondary LUT: \(lutURL.lastPathComponent)")
                    self.updatePreview() // Update preview after secondary LUT selection
                } else {
                    self.showAlert(title: "Invalid LUT File", 
                                 message: "The selected file '\(lutURL.lastPathComponent)' does not appear to be a valid .cube LUT file. Please select a valid LUT file.")
                    self.logMessage("ERROR: Invalid LUT file rejected: \(lutURL.lastPathComponent)")
                }
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
    
    @IBAction func whiteBalanceChanged(_ sender: NSSlider) {
        whiteBalanceValue = sender.floatValue
        let temperature = formatTemperature(whiteBalanceValue)
        whiteBalanceLabel.stringValue = "White Balance: \(temperature)K"
        logMessage("Adjusted white balance to \(temperature)K")
        updatePreview() // Update preview after white balance adjustment
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
        
        logMessage("Terminating process...")
        
        // Set up termination handler
        let originalHandler = process.terminationHandler
        process.terminationHandler = { [weak self] terminatedProcess in
            DispatchQueue.main.async {
                self?.logMessage("Process terminated gracefully.")
                completion()
            }
            originalHandler?(terminatedProcess)
        }
        
        // Terminate the process
        process.terminate()
        
        // Force kill if it doesn't terminate within 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if process.isRunning {
                self?.logMessage("Force killing unresponsive process...")
                kill(process.processIdentifier, SIGKILL)
                // Still call completion in case termination handler doesn't fire
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion()
                }
            }
        }
    }
    
    func generatePreviewImage(videoURL: URL) {
        // Terminate any existing preview process before starting a new one
        terminateProcess(previewProcess) {
            self.previewProcess = nil
            
            // Create a temporary file path for the preview image
            let tempDir = NSTemporaryDirectory()
            let tempImageURL = URL(fileURLWithPath: tempDir).appendingPathComponent("preview_image.png")
            
            // Clean up any existing preview image
            try? FileManager.default.removeItem(at: tempImageURL)
            
            // Build FFmpeg arguments to process the first frame and apply LUTs
            var arguments: [String] = []
            
            // Input file
            arguments += ["-ss", "0", "-i", videoURL.path]
            
            // Apply LUT filters using FilterBuilder
            let filterResult = FilterBuilder.buildPreviewFilter(
                primaryLUTPath: self.primaryLUTURL?.path,
                secondaryLUTPath: self.secondaryLUTURL?.path,
                opacity: self.secondLUTOpacity,
                whiteBalance: self.whiteBalanceValue
            )
            
            arguments += filterResult.arguments
            
            // Output settings
            arguments += ["-y", "-f", "image2", tempImageURL.path]
            
            // Log the FFmpeg command for debugging
            self.logMessage("Generating preview image with FFmpeg command: ffmpeg \(arguments.joined(separator: " "))")
            
            let task = Process()
            do {
                let ffmpegPath = try FFmpegManager.getFFmpegPath()
                task.executableURL = URL(fileURLWithPath: ffmpegPath)
            } catch {
                self.logMessage("FFmpeg error: \(error.localizedDescription)")
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
                    } else {
                        self?.logMessage("Failed to generate preview image (exit code: \(process.terminationStatus)).")
                    }
                    
                    // Always clean up the temporary file, regardless of success or failure
                    do {
                        try FileManager.default.removeItem(at: tempImageURL)
                        self?.logMessage("Cleaned up temporary preview image.")
                    } catch {
                        // File might not exist or already cleaned up, which is fine
                        self?.logMessage("Preview cleanup note: \(error.localizedDescription)")
                    }
                    
                    self?.previewProcess = nil
                }
            }
            
            do {
                try task.run()
                self.logMessage("FFmpeg process started for preview image generation.")
            } catch {
                self.logMessage("Failed to start FFmpeg process for preview image: \(error.localizedDescription)")
                // Clean up temp file if process failed to start
                try? FileManager.default.removeItem(at: tempImageURL)
            }
        }
    }
    
    @IBAction func exportVideo(_ sender: Any) {
        guard !videoURLs.isEmpty, primaryLUTURL != nil else {
            showAlert(title: "Missing Required Files", 
                     message: "Please load at least one video and a primary LUT before exporting.")
            logMessage("Export cancelled: Missing video or primary LUT.")
            return
        }
        
        let savePanel = NSOpenPanel()
        savePanel.canChooseDirectories = true
        savePanel.canCreateDirectories = true
        savePanel.canChooseFiles = false
        savePanel.message = "Select export directory"
        savePanel.begin { result in
            if result == .OK, let selectedURL = savePanel.url {
                // Validate export directory before proceeding
                if self.validateExportDirectory(selectedURL) {
                    self.exportDirectoryURL = selectedURL
                    self.logMessage("Export directory selected: \(selectedURL.path)")
                    self.processExport()
                } else {
                    self.showAlert(title: "Invalid Export Directory", 
                                 message: "The selected directory '\(selectedURL.path)' is not writable. Please select a different location or check your permissions.")
                    self.logMessage("ERROR: Export directory not writable: \(selectedURL.path)")
                }
            }
        }
    }
    
    func processExport() {
        guard let exportDirectoryURL = exportDirectoryURL else {
            logMessage("No export directory selected.")
            return
        }
        
        // Check disk space before starting export
        if !validateDiskSpace(for: videoURLs, in: exportDirectoryURL) {
            showAlert(title: "Insufficient Disk Space", 
                     message: "There may not be enough free disk space to export these videos. The export may fail if disk space runs out. Please free up some space or choose a different export location.")
            logMessage("WARNING: Insufficient disk space detected, but allowing user to proceed.")
            // Don't return - let user decide to proceed with warning
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
                    
                    // Calculate total frames using compatible APIs
                    let asset = AVURLAsset(url: videoURL)
                    
                    // Use older API compatible with macOS 11.0
                    if #available(macOS 12.0, *) {
                        // Use modern async APIs for macOS 12.0+
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
                                        
                                        self.executeFFmpegExport(videoURL: videoURL, primaryLUTURL: primaryLUTURL, secondaryLUTURL: secondaryLUTURL, exportURL: exportURL, completion: completion)
                                    }
                                } else {
                                    await MainActor.run {
                                        self.logMessage("Failed to retrieve video track for \(videoURL.lastPathComponent).")
                                        completion()
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    self.logMessage("Failed to load video metadata: \(error.localizedDescription)")
                                    completion()
                                }
                            }
                        }
                    } else {
                        // Use legacy API for macOS 11.0
                        DispatchQueue.global(qos: .userInitiated).async {
                            let tracks = asset.tracks(withMediaType: .video)
                            if let track = tracks.first {
                                let fps = track.nominalFrameRate
                                let duration = asset.duration
                                let totalFrames = Int(Double(fps) * CMTimeGetSeconds(duration))
                                
                                DispatchQueue.main.async {
                                    self.totalFrames = totalFrames
                                    self.progressIndicator.minValue = 0
                                    self.progressIndicator.maxValue = 1
                                    self.progressIndicator.doubleValue = 0
                                    
                                    self.executeFFmpegExport(videoURL: videoURL, primaryLUTURL: primaryLUTURL, secondaryLUTURL: secondaryLUTURL, exportURL: exportURL, completion: completion)
                                }
                            } else {
                                DispatchQueue.main.async {
                                    self.logMessage("Failed to retrieve video track for \(videoURL.lastPathComponent).")
                                    completion()
                                }
                            }
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
            whiteBalance: self.whiteBalanceValue,
            pixelFormat: pixelFormat
        )
        
        arguments += ["-filter_complex", filterComplex]
        arguments += ["-map", "[out]"]
        arguments += ["-map", "0:a?"] // Map audio if available
        
        arguments += [exportURL.path]
        
        // Log FFmpeg command for reference
        self.logMessage("Exporting with FFmpeg command: ffmpeg \(arguments.joined(separator: " "))")
        
        let task = Process()
        do {
            let ffmpegPath = try FFmpegManager.getFFmpegPath()
            task.executableURL = URL(fileURLWithPath: ffmpegPath)
        } catch {
            self.logMessage("FFmpeg error: \(error.localizedDescription)")
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
        
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion()
                    return
                }
                if process.terminationStatus == 0 {
                    self.logMessage("Export completed successfully for \(videoURL.lastPathComponent)!")
                } else {
                    let errorMessage = "Export failed for \(videoURL.lastPathComponent) with exit code \(process.terminationStatus)."
                    self.logMessage(errorMessage)
                    
                    var errorGuidance = "The video conversion encountered an error. "
                    switch process.terminationStatus {
                    case 1:
                        errorGuidance += "This may be due to an invalid LUT file or incompatible video codec."
                    case -11, -9, -4:
                        errorGuidance += "The process was terminated or crashed. This may be due to insufficient memory or disk space."
                    default:
                        errorGuidance += "Check the log for details. Common issues: corrupt video file, invalid LUT, or insufficient disk space."
                    }
                    
                    self.showAlert(title: "Export Failed", message: errorGuidance)
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
    
    // MARK: - LUT File Validation
    
    /// Validates that a video file can be read by AVFoundation
    func validateVideoFile(_ url: URL) -> Bool {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            logMessage("Video file does not exist: \(url.path)")
            return false
        }
        
        // Try to create AVAsset to validate it's a readable video
        let asset = AVURLAsset(url: url)
        let tracks = asset.tracks(withMediaType: .video)
        
        if tracks.isEmpty {
            logMessage("File has no video tracks: \(url.lastPathComponent)")
            return false
        }
        
        // Check if file size is reasonable (> 0 bytes)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64, fileSize == 0 {
                logMessage("Video file is empty (0 bytes): \(url.lastPathComponent)")
                return false
            }
        } catch {
            logMessage("Could not read video file attributes: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
    /// Validates that a .cube file contains valid LUT data
    func validateLUTFile(_ url: URL) -> Bool {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            var hasLUTSize = false
            var hasDataLines = false
            var lineCount = 0
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Skip empty lines and comments
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    continue
                }
                
                // Check for LUT_3D_SIZE declaration
                if trimmed.hasPrefix("LUT_3D_SIZE") || trimmed.hasPrefix("LUT_1D_SIZE") {
                    hasLUTSize = true
                    continue
                }
                
                // Check for valid data lines (three numbers separated by spaces)
                let components = trimmed.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                
                if components.count == 3 {
                    // Try to parse as floating point numbers
                    if let _ = Float(components[0]),
                       let _ = Float(components[1]),
                       let _ = Float(components[2]) {
                        hasDataLines = true
                        lineCount += 1
                    }
                }
            }
            
            // Valid LUT should have size declaration and at least some data
            let isValid = hasLUTSize && hasDataLines && lineCount >= 8
            
            if !isValid {
                logMessage("LUT validation failed: hasLUTSize=\(hasLUTSize), hasDataLines=\(hasDataLines), lineCount=\(lineCount)")
            }
            
            return isValid
            
        } catch {
            logMessage("Failed to read LUT file: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Shows an alert dialog to the user
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // MARK: - Export Directory Validation
    
    /// Validates that the export directory exists and is writable
    func validateExportDirectory(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        // Check if path exists
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            logMessage("Export directory does not exist: \(url.path)")
            return false
        }
        
        // Check if it's actually a directory
        guard isDirectory.boolValue else {
            logMessage("Export path is not a directory: \(url.path)")
            return false
        }
        
        // Check if directory is writable by attempting to create a test file
        let testFile = url.appendingPathComponent(".write_test_\(UUID().uuidString)")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
            logMessage("Export directory validated: \(url.path)")
            return true
        } catch {
            logMessage("Export directory not writable: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Checks if there's sufficient disk space for exporting videos
    /// Returns true if there's enough space, false if space is insufficient
    func validateDiskSpace(for videoURLs: [URL], in exportDirectory: URL) -> Bool {
        let fileManager = FileManager.default
        
        // Calculate total size of input videos
        var totalInputSize: Int64 = 0
        for videoURL in videoURLs {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: videoURL.path)
                if let fileSize = attributes[.size] as? Int64 {
                    totalInputSize += fileSize
                }
            } catch {
                logMessage("Warning: Could not get size of \(videoURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Estimate output size (assuming 1.5x input size for safety margin)
        // Lossless or high-quality encoding can sometimes increase file size
        let estimatedOutputSize = Int64(Double(totalInputSize) * 1.5)
        
        // Get available disk space on the export volume
        do {
            let values = try exportDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableCapacity = values.volumeAvailableCapacityForImportantUsage {
                let availableCapacityMB = availableCapacity / (1024 * 1024)
                let requiredCapacityMB = estimatedOutputSize / (1024 * 1024)
                
                logMessage("Disk space check: Available=\(availableCapacityMB)MB, Required~\(requiredCapacityMB)MB")
                
                // Require at least 500MB buffer beyond estimated size
                let bufferSize: Int64 = 500 * 1024 * 1024
                let hasSufficientSpace = availableCapacity >= (estimatedOutputSize + bufferSize)
                
                if !hasSufficientSpace {
                    logMessage("WARNING: Insufficient disk space (need ~\(requiredCapacityMB + 500)MB, have \(availableCapacityMB)MB)")
                }
                
                return hasSufficientSpace
            }
        } catch {
            logMessage("Warning: Could not determine available disk space: \(error.localizedDescription)")
        }
        
        // If we can't determine disk space, assume it's okay but log warning
        return true
    }
    
    // MARK: - Drag and Drop Support
    
    private func setupDragAndDrop() {
        // Register the main view for drag and drop
        view.registerForDraggedTypes([.fileURL])
    }
    
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return []
        }
        
        // Check if we have video or LUT files
        let hasVideoFiles = fileURLs.contains { isVideoFile($0) }
        let hasLUTFiles = fileURLs.contains { isLUTFile($0) }
        
        if hasVideoFiles || hasLUTFiles {
            return .copy
        }
        
        return []
    }
    
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        // Separate video and LUT files
        let videoFiles = fileURLs.filter { isVideoFile($0) }
        let lutFiles = fileURLs.filter { isLUTFile($0) }
        
        // Handle video files
        if !videoFiles.isEmpty {
            // Validate video files before accepting
            let validVideos = videoFiles.filter { validateVideoFile($0) }
            let invalidCount = videoFiles.count - validVideos.count
            
            if validVideos.isEmpty {
                showAlert(title: "Invalid Video Files", 
                         message: "None of the dropped files appear to be valid video files.")
                logMessage("ERROR: No valid video files in drop.")
                return false
            }
            
            if invalidCount > 0 {
                logMessage("WARNING: Skipped \(invalidCount) invalid video file(s) from drag & drop.")
            }
            
            videoURLs = validVideos
            let videoNames = validVideos.map { $0.lastPathComponent }.joined(separator: ", ")
            logMessage("Loaded video(s) via drag & drop: \(videoNames)")
        }
        
        // Handle LUT files
        if !lutFiles.isEmpty {
            // If we don't have a primary LUT, assign the first one as primary
            if primaryLUTURL == nil {
                let firstLUT = lutFiles.first!
                if validateLUTFile(firstLUT) {
                    primaryLUTURL = firstLUT
                    logMessage("Loaded primary LUT via drag & drop: \(firstLUT.lastPathComponent)")
                    
                    // If there's a second LUT file, assign it as secondary
                    if lutFiles.count > 1 {
                        let secondLUT = lutFiles[1]
                        if validateLUTFile(secondLUT) {
                            secondaryLUTURL = secondLUT
                            logMessage("Loaded secondary LUT via drag & drop: \(secondLUT.lastPathComponent)")
                        } else {
                            showAlert(title: "Invalid LUT File", 
                                    message: "The secondary LUT file '\(secondLUT.lastPathComponent)' is not valid and was skipped.")
                        }
                    }
                } else {
                    showAlert(title: "Invalid LUT File", 
                            message: "The LUT file '\(firstLUT.lastPathComponent)' is not valid.")
                    logMessage("ERROR: Invalid LUT file rejected: \(firstLUT.lastPathComponent)")
                }
            } else {
                // If we already have a primary LUT, assign as secondary
                let lutFile = lutFiles.first!
                if validateLUTFile(lutFile) {
                    secondaryLUTURL = lutFile
                    logMessage("Loaded secondary LUT via drag & drop: \(lutFile.lastPathComponent)")
                } else {
                    showAlert(title: "Invalid LUT File", 
                            message: "The LUT file '\(lutFile.lastPathComponent)' is not valid.")
                    logMessage("ERROR: Invalid LUT file rejected: \(lutFile.lastPathComponent)")
                }
            }
        }
        
        // Update preview if we have both video and LUT
        if !videoFiles.isEmpty || !lutFiles.isEmpty {
            updatePreview()
            return true
        }
        
        return false
    }
    
    // MARK: - File Type Validation
    private func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mov", "mp4", "avi", "mkv", "m4v", "wmv", "flv", "webm", "3gp", "mts", "m2ts"]
        let fileExtension = url.pathExtension.lowercased()
        return videoExtensions.contains(fileExtension)
    }
    
    private func isLUTFile(_ url: URL) -> Bool {
        let lutExtensions = ["cube", "3dl", "lut"]
        let fileExtension = url.pathExtension.lowercased()
        return lutExtensions.contains(fileExtension)
    }
}
