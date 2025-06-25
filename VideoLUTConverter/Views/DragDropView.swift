import Cocoa
import UniformTypeIdentifiers

protocol DragDropViewDelegate: AnyObject {
    func dragDropView(_ view: DragDropView, didReceiveVideoFiles urls: [URL])
    func dragDropView(_ view: DragDropView, didReceiveLUTFile url: URL, isPrimary: Bool)
}

class DragDropView: NSView {
    
    // MARK: - Properties
    weak var delegate: DragDropViewDelegate?
    
    enum DropType {
        case video
        case primaryLUT
        case secondaryLUT
    }
    
    var dropType: DropType = .video
    var isHighlighted: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    // Visual properties
    private let cornerRadius: CGFloat = 12.0
    private let borderWidth: CGFloat = 2.0
    private let dashLength: CGFloat = 8.0
    
    // MARK: - Initialization
    override func awakeFromNib() {
        super.awakeFromNib()
        setupDragAndDrop()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }
    
    // MARK: - Setup
    private func setupDragAndDrop() {
        // Register for drag and drop operations
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.movie"),
            NSPasteboard.PasteboardType("public.mpeg-4"),
            NSPasteboard.PasteboardType("com.apple.quicktime-movie")
        ])
        
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
    }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Set up the drawing path
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: borderWidth/2, dy: borderWidth/2), 
                               xRadius: cornerRadius, yRadius: cornerRadius)
        
        // Background color
        let backgroundColor: NSColor
        if isHighlighted {
            backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1)
        } else {
            backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.05)
        }
        
        backgroundColor.setFill()
        path.fill()
        
        // Border
        let borderColor: NSColor
        if isHighlighted {
            borderColor = NSColor.controlAccentColor
        } else {
            borderColor = NSColor.tertiaryLabelColor
        }
        
        borderColor.setStroke()
        path.lineWidth = borderWidth
        
        // Create dashed pattern
        let dashPattern: [CGFloat] = [dashLength, dashLength]
        path.setLineDash(dashPattern, count: 2, phase: 0.0)
        path.stroke()
        
        // Draw text and icon
        drawContent()
    }
    
    private func drawContent() {
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: isHighlighted ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
        ]
        
        let subtextAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        
        let (mainText, subText, icon) = getContentForDropType()
        
        // Calculate text positioning
        let textRect = bounds.insetBy(dx: 20, dy: 20)
        let iconSize: CGFloat = 32
        let spacing: CGFloat = 12
        
        // Draw icon
        if let iconImage = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let iconRect = NSRect(
                x: (bounds.width - iconSize) / 2,
                y: bounds.midY + spacing,
                width: iconSize,
                height: iconSize
            )
            
            iconImage.draw(in: iconRect)
        }
        
        // Draw main text
        let mainTextSize = mainText.size(withAttributes: textAttributes)
        let mainTextRect = NSRect(
            x: (bounds.width - mainTextSize.width) / 2,
            y: bounds.midY - spacing/2,
            width: mainTextSize.width,
            height: mainTextSize.height
        )
        
        mainText.draw(in: mainTextRect, withAttributes: textAttributes)
        
        // Draw subtext
        let subTextSize = subText.size(withAttributes: subtextAttributes)
        let subTextRect = NSRect(
            x: (bounds.width - subTextSize.width) / 2,
            y: bounds.midY - spacing - mainTextSize.height,
            width: subTextSize.width,
            height: subTextSize.height
        )
        
        subText.draw(in: subTextRect, withAttributes: subtextAttributes)
    }
    
    private func getContentForDropType() -> (String, String, String) {
        switch dropType {
        case .video:
            return ("Drop Video Files Here", "Supports .mov, .mp4, .avi, .mkv and more", "video.fill")
        case .primaryLUT:
            return ("Drop Primary LUT Here", "Supports .cube files", "camera.filters")
        case .secondaryLUT:
            return ("Drop Secondary LUT Here", "Optional - Supports .cube files", "camera.filters")
        }
    }
    
    // MARK: - Drag and Drop
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        
        // Check if we have file URLs
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return []
        }
        
        // Validate file types based on drop type
        let validFiles = fileURLs.filter { url in
            switch dropType {
            case .video:
                return isVideoFile(url)
            case .primaryLUT, .secondaryLUT:
                return isLUTFile(url)
            }
        }
        
        if validFiles.isEmpty {
            return []
        }
        
        isHighlighted = true
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false
        
        let pasteboard = sender.draggingPasteboard
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        switch dropType {
        case .video:
            let videoFiles = fileURLs.filter { isVideoFile($0) }
            if !videoFiles.isEmpty {
                delegate?.dragDropView(self, didReceiveVideoFiles: videoFiles)
                return true
            }
            
        case .primaryLUT:
            if let lutFile = fileURLs.first(where: { isLUTFile($0) }) {
                delegate?.dragDropView(self, didReceiveLUTFile: lutFile, isPrimary: true)
                return true
            }
            
        case .secondaryLUT:
            if let lutFile = fileURLs.first(where: { isLUTFile($0) }) {
                delegate?.dragDropView(self, didReceiveLUTFile: lutFile, isPrimary: false)
                return true
            }
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
    
    // MARK: - Public Methods
    func setDropType(_ type: DropType) {
        dropType = type
        needsDisplay = true
    }
    
    func setHighlighted(_ highlighted: Bool) {
        isHighlighted = highlighted
    }
} 