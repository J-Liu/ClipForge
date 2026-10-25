// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import AVFoundation
import Accelerate

/// Loads and renders audio waveform data.
class WaveformLoader {
    struct WaveformData {
        let minSamples: [Float]
        let maxSamples: [Float]
        let sampleCount: Int
    }

    /// Load waveform data from audio file with specified resolution.
    static func load(from url: URL, samplesPerPixel: Int = 256) async throws -> WaveformData {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw NSError(domain: "WaveformLoader", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot create buffer"])
        }

        try file.read(into: buffer)

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(format.channelCount)

        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "WaveformLoader", code: -3, userInfo: [NSLocalizedDescriptionKey: "No channel data"])
        }

        let outputSampleCount = max(1, frameCount / samplesPerPixel)

        var minSamples = [Float](repeating: 0, count: outputSampleCount)
        var maxSamples = [Float](repeating: 0, count: outputSampleCount)

        // Downsample to get min/max for each pixel
        for i in 0..<outputSampleCount {
            let start = i * samplesPerPixel
            let end = min(start + samplesPerPixel, frameCount)
            var minVal: Float = 1.0
            var maxVal: Float = -1.0

            for j in start..<end {
                // Average across channels
                var sample: Float = 0
                for c in 0..<channelCount {
                    sample += channelData[c][j]
                }
                sample /= Float(channelCount)

                minVal = min(minVal, sample)
                maxVal = max(maxVal, sample)
            }

            minSamples[i] = minVal
            maxSamples[i] = maxVal
        }

        return WaveformData(minSamples: minSamples, maxSamples: maxSamples, sampleCount: outputSampleCount)
    }
}

/// Renders waveform visualization.
class WaveformView: NSView {
    private(set) var waveformData: WaveformLoader.WaveformData?
    private var progress: Double = 0.0  // 0.0 to 1.0
    private var cutPoints: [CMTime] = []
    private var segments: [Segment] = []
    private var totalDuration: CMTime = .zero

    private let backgroundColor: NSColor = .black
    private let waveformColor: NSColor = NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)  // Blue
    private let playedColor: NSColor = NSColor(red: 0.35, green: 0.4, blue: 0.45, alpha: 1.0)  // Dark gray-blue
    private let cutPointColor: NSColor = .red

    var onCutPointAdded: ((CMTime) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = backgroundColor.cgColor
        isHidden = true  // Hidden until we have data
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setWaveformData(_ data: WaveformLoader.WaveformData?) {
        waveformData = data
        isHidden = (data == nil)
        needsDisplay = true
    }

    func setProgress(_ progress: Double) {
        self.progress = progress
        needsDisplay = true
    }

    func setCutPoints(_ points: [CMTime], segments: [Segment], duration: CMTime) {
        self.cutPoints = points
        self.segments = segments
        self.totalDuration = duration
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        guard let data = waveformData, data.sampleCount > 0 else { return }

        // Draw segment backgrounds first
        drawSegmentBackgrounds(ctx: ctx)

        // Draw waveform (static, showing loudness)
        drawWaveform(ctx: ctx, data: data)

        // Draw cut points
        drawCutPoints(ctx: ctx)

        // Draw playhead
        drawPlayhead(ctx: ctx)
    }

    private func drawSegmentBackgrounds(ctx: CGContext) {
        guard totalDuration.isValid, CMTimeGetSeconds(totalDuration) > 0 else { return }

        for segment in segments {
            let startX = CGFloat(CMTimeGetSeconds(segment.start) / CMTimeGetSeconds(totalDuration)) * bounds.width
            let endX = CGFloat(CMTimeGetSeconds(segment.end) / CMTimeGetSeconds(totalDuration)) * bounds.width

            let color = segment.isKept ? NSColor.cyan.withAlphaComponent(0.1) : NSColor.red.withAlphaComponent(0.1)
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(x: startX, y: 0, width: endX - startX, height: bounds.height))
        }
    }

    private func drawWaveform(ctx: CGContext, data: WaveformLoader.WaveformData) {
        let midY = bounds.height / 2
        let amplitude = bounds.height / 2 * 0.9

        let playedSampleCount = Int(Double(data.sampleCount) * progress)

        // Draw unplayed portion (bright blue)
        ctx.setStrokeColor(waveformColor.cgColor)
        ctx.setLineWidth(1.0)

        for i in playedSampleCount..<data.sampleCount {
            let x = CGFloat(i) / CGFloat(data.sampleCount) * bounds.width
            let minVal = data.minSamples[i]
            let maxVal = data.maxSamples[i]

            let absMin = abs(minVal)
            let absMax = abs(maxVal)
            let maxAmp = max(absMin, absMax)

            let minY = midY - CGFloat(maxAmp) * amplitude
            let maxY = midY + CGFloat(maxAmp) * amplitude

            ctx.move(to: CGPoint(x: x, y: minY))
            ctx.addLine(to: CGPoint(x: x, y: maxY))
        }
        ctx.strokePath()

        // Draw played portion (darker gray-blue)
        ctx.setStrokeColor(playedColor.cgColor)
        for i in 0..<playedSampleCount {
            let x = CGFloat(i) / CGFloat(data.sampleCount) * bounds.width
            let minVal = data.minSamples[i]
            let maxVal = data.maxSamples[i]

            let absMin = abs(minVal)
            let absMax = abs(maxVal)
            let maxAmp = max(absMin, absMax)

            let minY = midY - CGFloat(maxAmp) * amplitude
            let maxY = midY + CGFloat(maxAmp) * amplitude

            ctx.move(to: CGPoint(x: x, y: minY))
            ctx.addLine(to: CGPoint(x: x, y: maxY))
        }
        ctx.strokePath()

        // Draw center line
        ctx.setStrokeColor(NSColor.gray.withAlphaComponent(0.2).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: 0, y: midY))
        ctx.addLine(to: CGPoint(x: bounds.width, y: midY))
        ctx.strokePath()
    }

    private func drawCutPoints(ctx: CGContext) {
        guard totalDuration.isValid, CMTimeGetSeconds(totalDuration) > 0 else { return }

        ctx.setStrokeColor(cutPointColor.cgColor)
        ctx.setLineWidth(2.0)

        for cutPoint in cutPoints {
            let x = CGFloat(CMTimeGetSeconds(cutPoint) / CMTimeGetSeconds(totalDuration)) * bounds.width
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: bounds.height))
        }
        ctx.strokePath()
    }

    private func drawPlayhead(ctx: CGContext) {
        guard progress >= 0, progress <= 1.0 else { return }

        let x = CGFloat(progress) * bounds.width

        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.0)
        ctx.move(to: CGPoint(x: x, y: 0))
        ctx.addLine(to: CGPoint(x: x, y: bounds.height))
        ctx.strokePath()
    }

    override func mouseDown(with event: NSEvent) {
        addCutPoint(at: event)
    }

    private func addCutPoint(at event: NSEvent) {
        guard totalDuration.isValid, CMTimeGetSeconds(totalDuration) > 0 else { return }

        let point = convert(event.locationInWindow, from: nil)
        let progress = Double(point.x / bounds.width)
        let time = CMTime(seconds: progress * CMTimeGetSeconds(totalDuration), preferredTimescale: 600)

        onCutPointAdded?(time)
    }
}
