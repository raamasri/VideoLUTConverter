import Cocoa

class DropTargetView: NSView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let vc = window?.contentViewController as? ViewController {
            return vc.draggingEntered(sender)
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        // No-op; available for future highlighting
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let vc = window?.contentViewController as? ViewController {
            return vc.performDragOperation(sender)
        }
        return false
    }
}
