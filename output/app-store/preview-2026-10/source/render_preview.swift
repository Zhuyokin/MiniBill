#!/usr/bin/env swift
import Foundation
import AVFoundation
import AppKit
import CoreImage
import AudioToolbox

let frameRate: Int32 = 30
let totalFrames = 450
let totalTime = CMTime(value: 15, timescale: 1)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

struct PreviewError: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) { description = text }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw PreviewError(message) }
}

struct Clip: Decodable {
    let path: String
    let start: Double
    let duration: Double
    let title: String
    let subtitleY: Double?
}

struct Manifest: Decodable {
    let width: Int
    let height: Int
    let audio: String
    let output: String
    let clips: [Clip]
}

func resolve(_ path: String, relativeTo directory: URL) -> URL {
    if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
    return directory.appendingPathComponent(path).standardizedFileURL
}

func fourCC(_ value: FourCharCode) -> String {
    String(bytes: [UInt8((value >> 24) & 255), UInt8((value >> 16) & 255),
                   UInt8((value >> 8) & 255), UInt8(value & 255)], encoding: .ascii) ?? "unknown"
}

func drawBitmap(width: Int, height: Int, _ draw: () -> Void) -> CGImage {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: width * 4, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.cgImage!
}

func caption(_ text: String, width: Int, height: Int, normalizedY: Double) -> CIImage {
    let image = drawBitmap(width: width, height: height) {
        let font = NSFont.systemFont(ofSize: CGFloat(width) * 0.041, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(srgbRed: 0.035, green: 0.22, blue: 0.13, alpha: 1)
        ]
        let label = text as NSString
        let textSize = label.size(withAttributes: attributes)
        let horizontalInset = CGFloat(width) * 0.05
        let badgeHeight = CGFloat(width) * 0.09
        let badgeWidth = textSize.width + horizontalInset * 2 + CGFloat(width) * 0.025
        let badge = NSRect(x: (CGFloat(width) - badgeWidth) / 2,
                           y: CGFloat(height) * CGFloat(1 - normalizedY) - badgeHeight / 2,
                           width: badgeWidth, height: badgeHeight)
        let path = NSBezierPath(roundedRect: badge, xRadius: badgeHeight * 0.31, yRadius: badgeHeight * 0.31)
        NSColor(srgbRed: 0.96, green: 1, blue: 0.975, alpha: 0.94).setFill()
        path.fill()
        NSColor(srgbRed: 7.0 / 255, green: 193.0 / 255, blue: 96.0 / 255, alpha: 0.28).setStroke()
        path.lineWidth = max(1, CGFloat(width) / 650)
        path.stroke()
        NSColor(srgbRed: 7.0 / 255, green: 193.0 / 255, blue: 96.0 / 255, alpha: 1).setFill()
        let dotSize = CGFloat(width) * 0.010
        NSBezierPath(ovalIn: NSRect(x: badge.minX + horizontalInset * 0.64,
                                   y: badge.midY - dotSize / 2, width: dotSize, height: dotSize)).fill()
        label.draw(at: NSPoint(x: badge.minX + horizontalInset + CGFloat(width) * 0.018,
                               y: badge.midY - textSize.height / 2), withAttributes: attributes)
    }
    return CIImage(cgImage: image)
}

final class ClipReader {
    let reader: AVAssetReader
    let output: AVAssetReaderTrackOutput
    let transform: CGAffineTransform
    private var current: CMSampleBuffer?
    private var next: CMSampleBuffer?

    init(url: URL, clip: Clip) throws {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw PreviewError("No video track: \(url.path)")
        }
        try require(clip.start >= 0 && clip.duration > 0, "Clip start/duration is invalid")
        try require(clip.start + clip.duration <= asset.duration.seconds + 0.034,
                    "Clip exceeds source duration: \(url.lastPathComponent), \(asset.duration.seconds)s")
        transform = track.preferredTransform
        reader = try AVAssetReader(asset: asset)
        output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        let start = max(0, clip.start - 0.1)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 60000),
                                      duration: CMTime(seconds: clip.start + clip.duration - start,
                                                       preferredTimescale: 60000))
        try require(reader.startReading(), "Cannot decode \(url.path): \(String(describing: reader.error))")
        next = output.copyNextSampleBuffer()
    }

    func frame(at seconds: Double) throws -> CIImage {
        while let upcoming = next,
              current == nil || CMSampleBufferGetPresentationTimeStamp(upcoming).seconds <= seconds + 0.00001 {
            current = upcoming
            next = output.copyNextSampleBuffer()
        }
        try require(reader.status != .failed, "Source decoding failed: \(String(describing: reader.error))")
        guard let sample = current, let buffer = CMSampleBufferGetImageBuffer(sample) else {
            throw PreviewError("Source contains no decoded frame at \(seconds)s")
        }
        let image = CIImage(cvPixelBuffer: buffer).transformed(by: transform)
        return image.transformed(by: CGAffineTransform(translationX: -image.extent.minX,
                                                       y: -image.extent.minY))
    }
}

func render(manifestURL: URL) throws -> URL {
    let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
    let directory = manifestURL.deletingLastPathComponent()
    let width = manifest.width, height = manifest.height
    try require([(886, 1920), (1200, 1600)].contains { $0.0 == width && $0.1 == height },
                "Supported dimensions: 886x1920 or 1200x1600")
    try require(!manifest.clips.isEmpty, "At least one clip is required")
    try require(abs(manifest.clips.reduce(0) { $0 + $1.duration } - 15) < 0.000001,
                "Clip durations must total exactly 15 seconds")
    let lengths = try manifest.clips.map { clip -> Int in
        let frames = clip.duration * Double(frameRate)
        try require(abs(frames - frames.rounded()) < 0.000001,
                    "Every clip duration must be a multiple of 1/30 second")
        if let y = clip.subtitleY { try require(y >= 0.1 && y <= 0.9, "subtitleY must be 0.1…0.9") }
        return Int(frames.rounded())
    }
    let videoReaders = try manifest.clips.map {
        try ClipReader(url: resolve($0.path, relativeTo: directory), clip: $0)
    }
    let captions = manifest.clips.map { clip in
        clip.title.isEmpty ? nil : caption(clip.title, width: width, height: height,
                                          normalizedY: clip.subtitleY ?? 0.79)
    }
    let audioURL = resolve(manifest.audio, relativeTo: directory)
    let audioAsset = AVURLAsset(url: audioURL)
    guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first else {
        throw PreviewError("No audio track: \(audioURL.path)")
    }
    try require(abs(audioAsset.duration.seconds - 15) < 0.0001, "Music must be exactly 15 seconds")
    let audioReader = try AVAssetReader(asset: audioAsset)
    let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 48000,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
    ])
    audioReader.add(audioOutput)
    audioReader.timeRange = CMTimeRange(start: .zero, duration: totalTime)
    try require(audioReader.startReading(), "Cannot decode music: \(String(describing: audioReader.error))")

    let outputURL = resolve(manifest.output, relativeTo: directory)
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: outputURL.path) { try FileManager.default.removeItem(at: outputURL) }
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true
    writer.movieTimeScale = 60000
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ],
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 11_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264High40,
            AVVideoExpectedSourceFrameRateKey: 30,
            AVVideoMaxKeyFrameIntervalKey: 30,
            AVVideoAllowFrameReorderingKey: false
        ]
    ])
    videoInput.mediaTimeScale = 60000
    videoInput.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput,
                                                       sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ])
    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 48000,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 256000
    ])
    audioInput.expectsMediaDataInRealTime = false
    try require(writer.canAdd(videoInput) && writer.canAdd(audioInput), "Cannot add encoding tracks")
    writer.add(videoInput)
    writer.add(audioInput)
    try require(writer.startWriting(), "Cannot start encoding: \(String(describing: writer.error))")
    writer.startSession(atSourceTime: .zero)

    let context = CIContext(options: [.workingColorSpace: colorSpace, .outputColorSpace: colorSpace])
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    let background = CIImage(color: CIColor(red: 0.975, green: 0.98, blue: 0.975)).cropped(to: bounds)
    var frameIndex = 0
    var clipIndex = 0
    var clipFirstFrame = 0
    var nextAudio = audioOutput.copyNextSampleBuffer()
    var videoFinished = false, audioFinished = false
    var lastProgress = Date()
    while !videoFinished || !audioFinished {
        try require(writer.status == .writing, "Encoding failed: \(String(describing: writer.error))")
        var advanced = false
        if !audioFinished && audioInput.isReadyForMoreMediaData {
            if let sample = nextAudio {
                try require(audioInput.append(sample), "Audio encoding failed: \(String(describing: writer.error))")
                nextAudio = audioOutput.copyNextSampleBuffer()
            } else {
                try require(audioReader.status == .completed, "Music decoding failed: \(String(describing: audioReader.error))")
                audioInput.markAsFinished()
                audioFinished = true
            }
            advanced = true
        }
        if !videoFinished && videoInput.isReadyForMoreMediaData {
            if frameIndex == totalFrames {
                videoInput.markAsFinished()
                videoFinished = true
            } else {
                try autoreleasepool {
                    while frameIndex >= clipFirstFrame + lengths[clipIndex] {
                        clipFirstFrame += lengths[clipIndex]
                        clipIndex += 1
                    }
                    let clip = manifest.clips[clipIndex]
                    let localTime = Double(frameIndex - clipFirstFrame) / Double(frameRate)
                    var frame = try videoReaders[clipIndex].frame(at: clip.start + localTime)
                    let scale = min(CGFloat(width) / frame.extent.width, CGFloat(height) / frame.extent.height)
                    frame = frame.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    frame = frame.transformed(by: CGAffineTransform(translationX: (CGFloat(width) - frame.extent.width) / 2,
                                                                     y: (CGFloat(height) - frame.extent.height) / 2))
                    frame = frame.composited(over: background)
                    if let badge = captions[clipIndex] {
                        let fade = min(1.0, max(0, localTime / 0.25), max(0, (clip.duration - localTime - 1.0 / 30) / 0.25))
                        let overlay = badge.applyingFilter("CIColorMatrix", parameters: [
                            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: fade)
                        ])
                        frame = overlay.composited(over: frame)
                    }
                    var buffer: CVPixelBuffer?
                    guard let pool = adaptor.pixelBufferPool,
                          CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess,
                          let pixelBuffer = buffer else { throw PreviewError("Cannot allocate video frame") }
                    context.render(frame, to: pixelBuffer, bounds: bounds, colorSpace: colorSpace)
                    try require(adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frameIndex), timescale: frameRate)),
                                "Video encoding failed: \(String(describing: writer.error))")
                    frameIndex += 1
                }
            }
            advanced = true
        }
        if advanced { lastProgress = Date() }
        else {
            try require(Date().timeIntervalSince(lastProgress) < 30, "Encoder stalled for 30 seconds")
            Thread.sleep(forTimeInterval: 0.002)
        }
    }
    writer.endSession(atSourceTime: totalTime)
    let completion = DispatchSemaphore(value: 0)
    writer.finishWriting { completion.signal() }
    try require(completion.wait(timeout: .now() + 60) == .success, "Timed out finalizing MP4")
    try require(writer.status == .completed, "Cannot finalize MP4: \(String(describing: writer.error))")
    print("Rendered \(outputURL.path)")
    return outputURL
}

func atomOrder(_ url: URL) throws -> [String] {
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    let length = try file.seekToEnd()
    var offset: UInt64 = 0
    var names: [String] = []
    while offset + 8 <= length {
        try file.seek(toOffset: offset)
        let header = try file.read(upToCount: 16) ?? Data()
        try require(header.count >= 8, "Truncated MP4 atom")
        func integer(_ start: Int, _ count: Int) -> UInt64 {
            header[start..<(start + count)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        }
        var size = integer(0, 4)
        names.append(String(data: header[4..<8], encoding: .ascii) ?? "????")
        if size == 1 { size = integer(8, 8) }
        if size == 0 { size = length - offset }
        try require(size >= 8 && offset + size <= length, "Invalid MP4 atom size")
        offset += size
    }
    return names
}

func writePNG(_ image: CGImage, to url: URL) throws {
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw PreviewError("Cannot write PNG")
    }
    try data.write(to: url)
}

func makeQA(asset: AVAsset, directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let times = [1.5, 4.5, 7.5, 10.5, 13.5]
    var images: [CGImage] = []
    for (index, seconds) in times.enumerated() {
        let image = try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 30), actualTime: nil)
        images.append(image)
        try writePNG(image, to: directory.appendingPathComponent(String(format: "frame-%02d-%04.1fs.png", index + 1, seconds)))
    }
    let thumbHeight = 480
    let thumbWidth = Int(CGFloat(images[0].width) / CGFloat(images[0].height) * CGFloat(thumbHeight))
    let padding = 18, labelHeight = 28
    let sheetWidth = padding + (thumbWidth + padding) * images.count
    let sheetHeight = thumbHeight + padding * 2 + labelHeight
    let sheet = drawBitmap(width: sheetWidth, height: sheetHeight) {
        NSColor(srgbRed: 0.92, green: 0.94, blue: 0.93, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight).fill()
        for (index, image) in images.enumerated() {
            let x = padding + index * (thumbWidth + padding)
            NSImage(cgImage: image, size: .zero).draw(in: NSRect(x: x, y: padding + labelHeight,
                                                              width: thumbWidth, height: thumbHeight))
            (String(format: "%.1f s", times[index]) as NSString).draw(
                at: NSPoint(x: x + 4, y: padding),
                withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium),
                                 .foregroundColor: NSColor.darkGray])
        }
    }
    try writePNG(sheet, to: directory.appendingPathComponent("contact-sheet.png"))
}

func verify(url: URL, qaDirectory: URL?) throws {
    let asset = AVURLAsset(url: url)
    guard let video = asset.tracks(withMediaType: .video).first,
          let audio = asset.tracks(withMediaType: .audio).first,
          let videoFormat = video.formatDescriptions.first,
          let audioFormat = audio.formatDescriptions.first else {
        throw PreviewError("MP4 must contain video and audio tracks")
    }
    let vf = videoFormat as! CMFormatDescription
    let af = audioFormat as! CMFormatDescription
    let codec = fourCC(CMFormatDescriptionGetMediaSubType(vf))
    let audioCodec = fourCC(CMFormatDescriptionGetMediaSubType(af))
    let dimensions = CMVideoFormatDescriptionGetDimensions(vf)
    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(af)!.pointee
    let extensions = CMFormatDescriptionGetExtensions(vf)! as NSDictionary
    let atoms = extensions[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms] as? NSDictionary
    let avcC = atoms?["avcC"] as? Data
    let profile = avcC.flatMap { $0.count > 3 ? Int($0[1]) : nil } ?? -1
    let level = avcC.flatMap { $0.count > 3 ? Int($0[3]) : nil } ?? -1
    let fieldCount = extensions[kCMFormatDescriptionExtension_FieldCount] as? Int ?? 1
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: video, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    output.alwaysCopiesSampleData = false
    reader.add(output)
    try require(reader.startReading(), "Cannot start complete video decoding")
    var decodedFrames = 0
    var firstPTS = Double.nan, lastPTS = Double.nan
    var uniformFrameTimes = true
    while true {
        let hasFrame: Bool = try autoreleasepool {
            guard let sample = output.copyNextSampleBuffer() else { return false }
            try require(CMSampleBufferGetImageBuffer(sample) != nil, "Undecodable video frame")
            let pts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            if decodedFrames == 0 { firstPTS = pts }
            if abs(pts - Double(decodedFrames) / 30) > 0.00001 { uniformFrameTimes = false }
            lastPTS = pts
            decodedFrames += 1
            return true
        }
        if !hasFrame { break }
    }
    try require(reader.status == .completed, "Video decoding failed: \(String(describing: reader.error))")
    let musicReader = try AVAssetReader(asset: asset)
    let musicOutput = AVAssetReaderTrackOutput(track: audio, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
    musicReader.add(musicOutput)
    try require(musicReader.startReading(), "Cannot start complete audio decoding")
    var decodedAudioSamples = 0
    while let sample = musicOutput.copyNextSampleBuffer() { decodedAudioSamples += CMSampleBufferGetNumSamples(sample) }
    try require(musicReader.status == .completed, "Audio decoding failed: \(String(describing: musicReader.error))")
    let order = try atomOrder(url)
    let fastStart = (order.firstIndex(of: "moov") ?? Int.max) < (order.firstIndex(of: "mdat") ?? -1)
    let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! Int
    let checks: [String: Bool] = [
        "duration_15_seconds": abs(asset.duration.seconds - 15) < 0.00001,
        "video_duration_15_seconds": abs(video.timeRange.duration.seconds - 15) < 0.00001,
        "audio_duration_15_seconds": abs(audio.timeRange.duration.seconds - 15) < 0.00001,
        "supported_dimensions": [(886, 1920), (1200, 1600)].contains { $0.0 == dimensions.width && $0.1 == dimensions.height },
        "h264_high_level_4_or_lower": codec == "avc1" && profile == 100 && level <= 40,
        "progressive": fieldCount == 1,
        "30_fps": abs(video.nominalFrameRate - 30) < 0.001 && uniformFrameTimes,
        "450_frames_fully_decoded": decodedFrames == 450,
        "aac_48khz_stereo": CMFormatDescriptionGetMediaSubType(af) == kAudioFormatMPEG4AAC && asbd.mSampleRate == 48000 && asbd.mChannelsPerFrame == 2,
        "audio_fully_decoded": decodedAudioSamples >= 720000,
        "fast_start": fastStart
    ]
    let report: [String: Any] = [
        "file": url.path,
        "duration_seconds": asset.duration.seconds,
        "video_duration_seconds": video.timeRange.duration.seconds,
        "audio_duration_seconds": audio.timeRange.duration.seconds,
        "width": dimensions.width, "height": dimensions.height,
        "video_codec": codec, "h264_profile_idc": profile, "h264_level_idc": level,
        "field_count": fieldCount, "nominal_fps": video.nominalFrameRate,
        "decoded_frames": decodedFrames, "first_frame_pts": firstPTS, "last_frame_pts": lastPTS,
        "video_bitrate_bps": video.estimatedDataRate,
        "configured_video_bitrate_bps": 11_000_000,
        "audio_codec": audioCodec, "sample_rate_hz": asbd.mSampleRate,
        "audio_channels": asbd.mChannelsPerFrame, "audio_bitrate_bps": audio.estimatedDataRate,
        "decoded_audio_samples": decodedAudioSamples,
        "file_bytes": fileSize, "top_level_atoms": order,
        "checks": checks, "passed": checks.values.allSatisfy { $0 }
    ]
    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    let reportURL = url.deletingPathExtension().appendingPathExtension("verification.json")
    try data.write(to: reportURL)
    print(String(data: data, encoding: .utf8)!)
    try require(checks.values.allSatisfy { $0 }, "Verification failed: \(checks.filter { !$0.value }.keys.sorted().joined(separator: ", "))")
    if let qaDirectory { try makeQA(asset: asset, directory: qaDirectory) }
}

do {
    let arguments = CommandLine.arguments
    try require(arguments.count >= 3, "Usage: render_preview render manifest.json [qa-directory]\n       render_preview verify video.mp4 [qa-directory]")
    let input = URL(fileURLWithPath: arguments[2])
    let qa = arguments.count > 3 ? URL(fileURLWithPath: arguments[3]) : nil
    switch arguments[1] {
    case "render":
        let output = try render(manifestURL: input)
        try verify(url: output, qaDirectory: qa)
    case "verify":
        try verify(url: input, qaDirectory: qa)
    default:
        throw PreviewError("Unknown command: \(arguments[1])")
    }
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
