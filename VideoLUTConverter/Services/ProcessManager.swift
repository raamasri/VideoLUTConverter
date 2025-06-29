import Foundation

protocol ProcessManagerDelegate: AnyObject {
    func processManager(_ manager: ProcessManager, didLogMessage message: String)
    func processManager(_ manager: ProcessManager, didUpdateProgress progress: Double)
    func processManager(_ manager: ProcessManager, didCompleteWithSuccess success: Bool)
}

class ProcessManager {
    weak var delegate: ProcessManagerDelegate?
    
    private var currentProcess: Process?
    private var isProcessRunning: Bool = false
    
    var hasRunningProcess: Bool {
        return isProcessRunning && currentProcess != nil
    }
    
    func executeFFmpeg(with arguments: [String], completion: @escaping (Bool) -> Void) {
        // Terminate any existing process first
        terminateCurrentProcess { [weak self] in
            self?.startFFmpegProcess(with: arguments, completion: completion)
        }
    }
    
    private func startFFmpegProcess(with arguments: [String], completion: @escaping (Bool) -> Void) {
        do {
            let ffmpegPath = try FFmpegManager.getFFmpegPath()
            startFFmpegProcessWithPath(ffmpegPath, arguments: arguments, completion: completion)
        } catch {
            delegate?.processManager(self, didLogMessage: "FFmpeg error: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    private func startFFmpegProcessWithPath(_ ffmpegPath: String, arguments: [String], completion: @escaping (Bool) -> Void) {
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: ffmpegPath)
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        // Set up output handling
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                let cleanOutput = self?.stripANSIColors(from: output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? output
                
                DispatchQueue.main.async {
                    self?.delegate?.processManager(self!, didLogMessage: cleanOutput)
                }
                
                // Parse progress if available
                self?.parseProgressFromOutput(cleanOutput)
            }
        }
        
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isProcessRunning = false
                self.currentProcess = nil
                
                let success = process.terminationStatus == 0
                self.delegate?.processManager(self, didCompleteWithSuccess: success)
                completion(success)
            }
        }
        
        do {
            try task.run()
            currentProcess = task
            isProcessRunning = true
            delegate?.processManager(self, didLogMessage: "FFmpeg process started with arguments: \(arguments.joined(separator: " "))")
        } catch {
            delegate?.processManager(self, didLogMessage: "Failed to start FFmpeg process: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func terminateCurrentProcess(completion: @escaping () -> Void) {
        guard let process = currentProcess, isProcessRunning else {
            completion()
            return
        }
        
        delegate?.processManager(self, didLogMessage: "Terminating current process...")
        
        // Set up completion handler
        let originalHandler = process.terminationHandler
        process.terminationHandler = { [weak self] terminatedProcess in
            DispatchQueue.main.async {
                self?.isProcessRunning = false
                self?.currentProcess = nil
                self?.delegate?.processManager(self!, didLogMessage: "Process terminated.")
                completion()
            }
            originalHandler?(terminatedProcess)
        }
        
        // Terminate the process
        if process.isRunning {
            process.terminate()
            
            // Force kill if it doesn't terminate within 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if process.isRunning {
                    self.delegate?.processManager(self, didLogMessage: "Force killing unresponsive process...")
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        } else {
            completion()
        }
    }
    
    private func stripANSIColors(from text: String) -> String {
        let pattern = "\\u{001B}\\[[0-9;]*m"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression, range: nil)
    }
    
    private func parseProgressFromOutput(_ output: String) {
        // Parse frame progress for video processing
        if let frameMatch = output.range(of: #"frame=\s*\d+"#, options: .regularExpression) {
            let frameText = output[frameMatch]
            if let frameValue = Int(frameText.split(separator: "=")[1].trimmingCharacters(in: .whitespaces)) {
                // This would need total frames to calculate progress
                // For now, just report that progress is being made
                DispatchQueue.main.async {
                    // The delegate can handle frame-based progress calculation
                    // by storing total frames and calculating percentage
                }
            }
        }
        
        // Parse time-based progress
        if let timeMatch = output.range(of: #"time=\d{2}:\d{2}:\d{2}\.\d{2}"#, options: .regularExpression) {
            let timeText = output[timeMatch]
            // This could be used for time-based progress calculation
            // if total duration is known
        }
    }
}

// MARK: - Convenience Methods
extension ProcessManager {
    func generatePreviewImage(from videoURL: URL, 
                            primaryLUTPath: String?,
                            secondaryLUTPath: String?,
                            opacity: Float,
                            whiteBalance: Float,
                            completion: @escaping (Bool) -> Void) {
        
        let filterResult = FilterBuilder.buildPreviewFilter(
            primaryLUTPath: primaryLUTPath,
            secondaryLUTPath: secondaryLUTPath,
            opacity: opacity,
            whiteBalance: whiteBalance
        )
        
        var arguments = ["-y", "-i", videoURL.path]
        arguments += filterResult.arguments
        
        let outputPath = NSTemporaryDirectory() + "preview_image.png"
        arguments.append(outputPath)
        
        executeFFmpeg(with: arguments, completion: completion)
    }
    
    func exportVideo(from videoURL: URL,
                   to outputURL: URL,
                   primaryLUTPath: String,
                   secondaryLUTPath: String?,
                   opacity: Float,
                   whiteBalance: Float,
                   useGPU: Bool,
                   completion: @escaping (Bool) -> Void) {
        
        var arguments = ["-y", "-i", videoURL.path]
        
        // Video encoding settings
        arguments += ["-fps_mode", "passthrough", "-ignore_editlist", "1"]
        arguments += FilterBuilder.buildEncodingArguments(useGPU: useGPU)
        arguments += ["-c:a", "aac", "-b:a", "192k"]
        
        // Apply filter complex
        let pixelFormat = useGPU ? "nv12" : "yuv422p"
        let filterComplex = FilterBuilder.buildExportFilter(
            primaryLUTPath: primaryLUTPath,
            secondaryLUTPath: secondaryLUTPath,
            opacity: opacity,
            whiteBalance: whiteBalance,
            pixelFormat: pixelFormat
        )
        
        arguments += ["-filter_complex", filterComplex]
        arguments += ["-map", "[out]", "-map", "0:a?"]
        arguments.append(outputURL.path)
        
        executeFFmpeg(with: arguments, completion: completion)
    }
} 