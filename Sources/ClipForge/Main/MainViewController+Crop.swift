import AppKit

extension MainViewController {

    func updateOverlayContentRect() {
        guard videoNaturalSize.width > 0 else { return }
        let displayRect = playerView.videoDisplayRect(for: videoNaturalSize)
        cropOverlay.contentRect = displayRect
    }

    func updateCropRect(from selectionRect: NSRect) {
        guard videoNaturalSize.width > 0 else { return }
        let displayRect = cropOverlay.contentRect
        guard displayRect.width > 0, displayRect.height > 0 else { return }

        let scaleX = videoNaturalSize.width / displayRect.width
        let scaleY = videoNaturalSize.height / displayRect.height

        let cropX = (selectionRect.minX - displayRect.minX) * scaleX
        let cropY = (selectionRect.minY - displayRect.minY) * scaleY
        let cropW = selectionRect.width * scaleX
        let cropH = selectionRect.height * scaleY

        let evenW = floor(cropW / 2) * 2
        let evenH = floor(cropH / 2) * 2

        cropRect = NSRect(x: cropX, y: cropY, width: evenW, height: evenH)
    }
}

