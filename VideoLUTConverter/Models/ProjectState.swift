import Foundation

// MARK: - Project State Model
class ProjectState: ObservableObject {
    
    // MARK: - Video Files
    @Published var videoURLs: [URL] = []
    
    // MARK: - LUT Files
    @Published var primaryLUTURL: URL?
    @Published var secondaryLUTURL: URL?
    @Published var secondLUTOpacity: Float = 1.0
    
    // MARK: - Export Settings
    @Published var exportDirectoryURL: URL?
    @Published var useGPU: Bool = true
    
    // MARK: - Progress Tracking
    @Published var totalFrames: Int = 0
    @Published var currentProgress: Double = 0.0
    @Published var overallProgress: Double = 0.0
    
    // MARK: - Computed Properties
    var isReadyForPreview: Bool {
        return !videoURLs.isEmpty && primaryLUTURL != nil
    }
    
    var isReadyForExport: Bool {
        return isReadyForPreview && exportDirectoryURL != nil
    }
    
    var hasSecondaryLUT: Bool {
        return secondaryLUTURL != nil
    }
    
    var opacityPercentage: Int {
        return Int(secondLUTOpacity * 100)
    }
    
    // MARK: - File Management
    func addVideoURL(_ url: URL) {
        if !videoURLs.contains(url) {
            videoURLs.append(url)
        }
    }
    
    func removeVideoURL(_ url: URL) {
        videoURLs.removeAll { $0 == url }
    }
    
    func clearVideoURLs() {
        videoURLs.removeAll()
    }
    
    func setPrimaryLUT(_ url: URL?) {
        primaryLUTURL = url
    }
    
    func setSecondaryLUT(_ url: URL?) {
        secondaryLUTURL = url
    }
    
    func setExportDirectory(_ url: URL?) {
        exportDirectoryURL = url
    }
    
    // MARK: - Progress Management
    func updateProgress(_ progress: Double) {
        currentProgress = max(0.0, min(1.0, progress))
    }
    
    func updateOverallProgress(_ progress: Double) {
        overallProgress = max(0.0, min(1.0, progress))
    }
    
    func resetProgress() {
        currentProgress = 0.0
        overallProgress = 0.0
        totalFrames = 0
    }
    
    // MARK: - Export File Naming
    func generateOutputFileName(for videoURL: URL) -> String {
        let filename = videoURL.deletingPathExtension().lastPathComponent
        let secondaryLUTName = secondaryLUTURL?.deletingPathExtension().lastPathComponent ?? "NoSecondLUT"
        return "\(filename)_converted_\(secondaryLUTName)_\(opacityPercentage)percent.mp4"
    }
    
    func generateOutputURL(for videoURL: URL) -> URL? {
        guard let exportDirectory = exportDirectoryURL else { return nil }
        let fileName = generateOutputFileName(for: videoURL)
        return exportDirectory.appendingPathComponent(fileName)
    }
    
    // MARK: - Validation
    func validateConfiguration() -> ValidationResult {
        if videoURLs.isEmpty {
            return .failure("No video files selected")
        }
        
        if primaryLUTURL == nil {
            return .failure("No primary LUT selected")
        }
        
        if exportDirectoryURL == nil {
            return .failure("No export directory selected")
        }
        
        return .success
    }
}

// MARK: - Validation Result
enum ValidationResult {
    case success
    case failure(String)
    
    var isValid: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let message):
            return message
        }
    }
} 