import Foundation
import PDFKit
import CoreGraphics
import AppKit
import SwiftUI

public class PDFLinkEngine {
    public static func process(config: NotebookConfig, progress: @escaping (Double, String) -> Void) throws -> (outputPath: String, linksCount: Int, duration: Double, fileSizeMB: Double) {
        let startTime = Date()
        
        progress(0.05, "Opening PDF documents...")
        guard FileManager.default.fileExists(atPath: config.targetPDFPath) else {
            throw NSError(domain: "StudioEngine", code: 404, userInfo: [NSLocalizedDescriptionKey: "Target Canva PDF not found at \(config.targetPDFPath)"])
        }
        guard FileManager.default.fileExists(atPath: config.templatePDFPath) else {
            throw NSError(domain: "StudioEngine", code: 404, userInfo: [NSLocalizedDescriptionKey: "Template PDF not found at \(config.templatePDFPath)"])
        }
        
        guard let canvaDoc = PDFDocument(url: URL(fileURLWithPath: config.targetPDFPath)),
              let templateDoc = PDFDocument(url: URL(fileURLWithPath: config.templatePDFPath)),
              let cgPDFDoc = CGPDFDocument(URL(fileURLWithPath: config.targetPDFPath) as CFURL) else {
            throw NSError(domain: "StudioEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not initialize CoreGraphics PDF readers."])
        }
        
        // 1. Extract Master Sidebar from layout page
        progress(0.15, "Extracting master layout sidebar...")
        guard let masterPage = canvaDoc.page(at: config.masterLayoutPageIndex - 1) else {
            throw NSError(domain: "StudioEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not access Canva master layout page (page \(config.masterLayoutPageIndex))."])
        }
        
        let masterBounds = masterPage.bounds(for: .mediaBox)
        let sidebarWidth: CGFloat = config.sidebarWidth
        let sidebarCropRect = CGRect(x: 0, y: 0, width: sidebarWidth, height: masterBounds.height)
        
        // Adaptive render scale based on compression profile
        let compressionProfile = PDFCompressor.profileFor(targetMB: config.targetMaxFileSizeMB)
        let renderScale: CGFloat = config.autoCompressPDF ? compressionProfile.sidebarScale : 3.0
        let pixelW = Int(sidebarCropRect.width * renderScale)
        let pixelH = Int(sidebarCropRect.height * renderScale)
        
        let repSidebar = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelW, pixelsHigh: pixelH,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32
        )!
        NSGraphicsContext.saveGraphicsState()
        let nctx = NSGraphicsContext(bitmapImageRep: repSidebar)!
        NSGraphicsContext.current = nctx
        let cg = nctx.cgContext
        cg.scaleBy(x: renderScale, y: renderScale)
        masterPage.draw(with: .mediaBox, to: cg)
        NSGraphicsContext.restoreGraphicsState()
        
        let sidebarCG: CGImage
        if config.autoCompressPDF,
           let jpegData = repSidebar.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: Float(compressionProfile.quality))]),
           let src = CGImageSourceCreateWithData(jpegData as CFData, nil),
           let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            sidebarCG = img
        } else if let img = repSidebar.cgImage {
            sidebarCG = img
        } else {
            throw NSError(domain: "StudioEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to render master sidebar image."])
        }
        
        // 2. Prepare Watermark (Layout Crop, Custom Styled Text, or None)
        progress(0.25, "Preparing watermark graphics...")
        var activeWatermarkCG: CGImage? = nil
        var activeWatermarkDrawnRect: CGRect = .zero
        var activeWatermarkRotation: Double = 0.0
        
        switch config.watermarkSettings.mode {
        case .none:
            activeWatermarkCG = nil
            
        case .extractedFromLayout:
            let wmRect = CGRect(
                x: config.watermarkSettings.layoutCropX,
                y: config.watermarkSettings.layoutCropY,
                width: config.watermarkSettings.layoutCropW,
                height: config.watermarkSettings.layoutCropH
            )
            let wmPixelW = Int(wmRect.width * renderScale)
            let wmPixelH = Int(wmRect.height * renderScale)
            
            if let repWM = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: wmPixelW, pixelsHigh: wmPixelH,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32
            ) {
                NSGraphicsContext.saveGraphicsState()
                if let wmCtx = NSGraphicsContext(bitmapImageRep: repWM) {
                    NSGraphicsContext.current = wmCtx
                    let cgWM = wmCtx.cgContext
                    cgWM.scaleBy(x: renderScale, y: renderScale)
                    cgWM.translateBy(x: -wmRect.origin.x, y: -wmRect.origin.y)
                    masterPage.draw(with: .mediaBox, to: cgWM)
                }
                NSGraphicsContext.restoreGraphicsState()
                
                for y in 0..<wmPixelH {
                    for x in 0..<wmPixelW {
                        if let col = repWM.colorAt(x: x, y: y) {
                            let r = col.redComponent * 255.0
                            let g = col.greenComponent * 255.0
                            let b = col.blueComponent * 255.0
                            let diff = max(abs(r - 249), abs(g - 249), abs(b - 249))
                            if diff <= 3 {
                                repWM.setColor(NSColor(calibratedRed: r/255.0, green: g/255.0, blue: b/255.0, alpha: 0.0), atX: x, y: y)
                            } else {
                                let a = min(1.0, diff / 25.0)
                                repWM.setColor(NSColor(calibratedRed: r/255.0, green: g/255.0, blue: b/255.0, alpha: a), atX: x, y: y)
                            }
                        }
                    }
                }
                activeWatermarkCG = repWM.cgImage
                activeWatermarkDrawnRect = wmRect
                activeWatermarkRotation = 0.0
            }
            
        case .customText:
            if let rendered = WatermarkRenderer.renderImage(settings: config.watermarkSettings),
               let cg = rendered.cgImage {
                activeWatermarkCG = cg
                activeWatermarkDrawnRect = rendered.drawnRect
                activeWatermarkRotation = config.watermarkSettings.rotationDegrees
            }
        }
        
        let shouldStampPage: (Int) -> Bool = { finalPageNum in
            guard activeWatermarkCG != nil else { return false }
            switch config.watermarkSettings.scope {
            case .allPages:
                return true
            case .allExceptCover:
                return finalPageNum > 1
            case .contentOnly:
                return finalPageNum >= 15
            }
        }
        
        let drawWatermarkOnContext: (CGContext) -> Void = { ctx in
            guard let cg = activeWatermarkCG else { return }
            ctx.saveGState()
            if activeWatermarkRotation != 0.0 {
                let midX = activeWatermarkDrawnRect.midX
                let midY = activeWatermarkDrawnRect.midY
                ctx.translateBy(x: midX, y: midY)
                ctx.rotate(by: CGFloat(activeWatermarkRotation * .pi / 180.0))
                let centeredRect = CGRect(
                    x: -activeWatermarkDrawnRect.width / 2.0,
                    y: -activeWatermarkDrawnRect.height / 2.0,
                    width: activeWatermarkDrawnRect.width,
                    height: activeWatermarkDrawnRect.height
                )
                ctx.draw(cg, in: centeredRect)
            } else {
                ctx.draw(cg, in: activeWatermarkDrawnRect)
            }
            ctx.restoreGState()
        }
        
        // 3. Determine Output File Path
        let outPath: String
        if !config.outputPath.isEmpty {
            outPath = config.outputPath
        } else {
            let targetURL = URL(fileURLWithPath: config.targetPDFPath)
            let dir = targetURL.deletingLastPathComponent()
            let base = targetURL.deletingPathExtension().lastPathComponent
            outPath = dir.appendingPathComponent("\(base) - INTERACTIVE.pdf").path
        }
        
        let totalCanvaPages = cgPDFDoc.numberOfPages
        let totalFinalPages = config.excludeMasterLayoutFromOutput ? (totalCanvaPages - 1) : totalCanvaPages
        
        progress(0.40, "Assembling vector pages & applying overlays...")
        let pdfURL = URL(fileURLWithPath: outPath) as CFURL
        var mediaBox = CGRect(origin: .zero, size: masterBounds.size)
        guard let writeContext = CGContext(pdfURL, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "StudioEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create destination PDF."])
        }
        
        // Attach QuartzFilter to initial write context if compression is enabled
        if config.autoCompressPDF && config.targetMaxFileSizeMB < 50.0 {
            if let qf = PDFCompressor.createQuartzFilter(targetMB: config.targetMaxFileSizeMB, pageCount: totalFinalPages) {
                qf.apply(to: writeContext)
            }
        }
        
        let tBox = templateDoc.page(at: 1)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 1536, height: 1980)
        let sx: CGFloat = masterBounds.width / tBox.width
        let sy: CGFloat = masterBounds.height / tBox.height
        
        var totalLinks = 0
        
        // Page 1: Cover
        if config.hasCover, let coverPage = cgPDFDoc.page(at: config.coverPageIndex) {
            var coverBox = coverPage.getBoxRect(.mediaBox)
            writeContext.beginPage(mediaBox: &coverBox)
            writeContext.addDestination("page_1" as CFString, at: CGPoint(x: 0, y: coverBox.height))
            writeContext.drawPDFPage(coverPage)
            if shouldStampPage(1) {
                drawWatermarkOnContext(writeContext)
            }
            writeContext.endPage()
        }
        
        // Content Pages 2..totalFinalPages
        for finalPageNum in 2...totalFinalPages {
            let canvaPageNum = config.excludeMasterLayoutFromOutput ? (finalPageNum + 1) : finalPageNum
            guard let cPage = cgPDFDoc.page(at: canvaPageNum) else { continue }
            
            var pageBox = cPage.getBoxRect(.mediaBox)
            writeContext.beginPage(mediaBox: &pageBox)
            writeContext.addDestination("page_\(finalPageNum)" as CFString, at: CGPoint(x: 0, y: pageBox.height))
            writeContext.drawPDFPage(cPage)
            
            // Sidebar Overlay Logic
            let inSkipRange = (finalPageNum >= config.skipSidebarStartPage && finalPageNum <= config.skipSidebarEndPage)
            if !inSkipRange && finalPageNum >= 15 {
                let sidebarRect = CGRect(x: 0, y: 0, width: sidebarWidth, height: pageBox.height)
                writeContext.draw(sidebarCG, in: sidebarRect)
            }
            
            // Watermark Stamp Logic
            if shouldStampPage(finalPageNum) {
                drawWatermarkOnContext(writeContext)
            }
            
            // Hyperlink Injection Logic
            let templatePageIdx = finalPageNum - 1
            var chapterTabBounds = [CGRect]()
            
            if templatePageIdx < templateDoc.pageCount, let tPage = templateDoc.page(at: templatePageIdx) {
                for a in tPage.annotations {
                    guard a.type == "Link" else { continue }
                    if let url = a.url, url.absoluteString.contains("mortalpages") { continue }
                    let b = a.bounds
                    if b.origin.y < 80 && b.origin.x > 300 { continue }
                    
                    if let dest = a.destination, let dPage = dest.page {
                        let targetPage = templateDoc.index(for: dPage) + 1
                        let scaledRect = CGRect(x: b.origin.x * sx, y: b.origin.y * sy, width: b.size.width * sx, height: b.size.height * sy)
                        writeContext.setDestination("page_\(targetPage)" as CFString, for: scaledRect)
                        totalLinks += 1
                        
                        if scaledRect.origin.x < (sidebarWidth + 20) {
                            chapterTabBounds.append(scaledRect)
                        }
                    }
                }
            }
            
            // Page 2: Chapter Selection Links & Arrow Indicators
            if finalPageNum == 2 && config.hasChapterArrows {
                let sortedTabs = chapterTabBounds.sorted { $0.origin.y > $1.origin.y }
                let arrowX: CGFloat = config.chapterNavSettings.positionX
                let arrowW: CGFloat = config.useSidebarSizeForArrows ? 42.22 : config.customArrowWidth
                let arrowH: CGFloat = config.useSidebarSizeForArrows ? 101.51 : config.customArrowHeight
                
                for (idx, target) in config.arrowTargets.enumerated() {
                    let rowY: CGFloat
                    if idx < sortedTabs.count {
                        rowY = sortedTabs[idx].origin.y
                    } else {
                        rowY = 1276.0 - CGFloat(idx) * 101.8
                    }
                    
                    // 1. End-of-line Arrow Link & Visual Rendering
                    if config.chapterNavSettings.isEnabled {
                        let arrowRect = CGRect(x: arrowX - arrowW / 2.0, y: rowY, width: arrowW, height: arrowH)
                        
                        if config.chapterNavSettings.renderVisualIndicator {
                            drawChapterIndicator(on: writeContext, in: arrowRect, settings: config.chapterNavSettings)
                        }
                        
                        writeContext.setDestination("page_\(target)" as CFString, for: arrowRect)
                        totalLinks += 1
                    }
                    
                    // 2. Left-side Chapter Number Link (Numbers 1..12)
                    if config.chapterNavSettings.linkLeftNumberPill {
                        let leftX = config.chapterNavSettings.leftNumberX
                        let leftW = config.chapterNavSettings.leftNumberWidth
                        let leftH = config.chapterNavSettings.leftNumberHeight
                        let leftRect = CGRect(x: leftX - leftW / 2.0, y: rowY, width: leftW, height: leftH)
                        
                        writeContext.setDestination("page_\(target)" as CFString, for: leftRect)
                        totalLinks += 1
                    }
                }
            }
            
            writeContext.endPage()
            
            if finalPageNum % 25 == 0 || finalPageNum == totalFinalPages {
                let pct = 0.40 + (Double(finalPageNum) / Double(totalFinalPages)) * 0.50
                progress(pct, "Processing page \(finalPageNum) of \(totalFinalPages)...")
            }
        }
        
        writeContext.closePDF()
        
        // 4. Neutralize Preview Data Detectors (if enabled)
        if config.watermarkSettings.neutralizeDataDetectors {
            progress(0.90, "Suppressing Preview URL data detectors...")
            suppressDataDetectorsInFile(at: outPath)
        }
        
        // 5. Automatic Target Size Compression Check & Enforcement
        let rawBytes = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Double) ?? 0.0
        var finalFileSizeMB = rawBytes / (1024.0 * 1024.0)
        
        if config.autoCompressPDF && config.targetMaxFileSizeMB < 50.0 && finalFileSizeMB > config.targetMaxFileSizeMB {
            progress(0.92, "Optimizing file size (\(String(format: "%.1f", finalFileSizeMB)) MB -> target ≤ \(String(format: "%.1f", config.targetMaxFileSizeMB)) MB)...")
            let compressedMB = PDFCompressor.compressPDFFile(
                inputPath: outPath,
                outputPath: outPath,
                targetMB: config.targetMaxFileSizeMB,
                progress: progress
            )
            finalFileSizeMB = compressedMB
        }
        
        let duration = Date().timeIntervalSince(startTime)
        progress(1.0, "Ready! Processed \(totalFinalPages) pages with \(totalLinks) links (\(String(format: "%.2f", finalFileSizeMB)) MB) in \(String(format: "%.2f", duration))s.")
        return (outputPath: outPath, linksCount: totalLinks, duration: duration, fileSizeMB: finalFileSizeMB)
    }
    
    private static func suppressDataDetectorsInFile(at path: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              var pdfStr = String(data: data, encoding: .isoLatin1) else { return }
        
        let searchPatterns = ["(mortalpages.com)", "(mortalpages)", "(mortal)", "(pages.com)"]
        var modified = false
        for pattern in searchPatterns {
            let replacement = "(" + String(repeating: " ", count: max(1, pattern.count - 2)) + ")"
            if pdfStr.contains(pattern) {
                pdfStr = pdfStr.replacingOccurrences(of: pattern, with: replacement)
                modified = true
            }
        }
        if modified, let outData = pdfStr.data(using: .isoLatin1) {
            try? outData.write(to: URL(fileURLWithPath: path))
        }
    }
    
    public static func drawChapterIndicator(on ctx: CGContext, in rect: CGRect, settings: ChapterNavIndicatorSettings) {
        ctx.saveGState()
        
        let corner = min(rect.width, rect.height) / 2.0
        let pillPath = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
        
        // 1. Draw Capsule / Pill
        switch settings.capsuleStyle {
        case .glass:
            let bgCol = NSColor(Color(hex: settings.capsuleBgColorHex, alpha: settings.capsuleBgAlpha))
            ctx.addPath(pillPath)
            ctx.setFillColor(bgCol.cgColor)
            ctx.fillPath()
            
            let borderCol = NSColor(Color(hex: settings.capsuleBorderColorHex, alpha: settings.capsuleBorderAlpha))
            ctx.addPath(pillPath)
            ctx.setStrokeColor(borderCol.cgColor)
            ctx.setLineWidth(1.0)
            ctx.strokePath()
            
        case .solid:
            let bgCol = NSColor(Color(hex: settings.capsuleBgColorHex, alpha: settings.capsuleBgAlpha))
            ctx.addPath(pillPath)
            ctx.setFillColor(bgCol.cgColor)
            ctx.fillPath()
            
        case .outline:
            let borderCol = NSColor(Color(hex: settings.capsuleBorderColorHex, alpha: settings.capsuleBorderAlpha))
            ctx.addPath(pillPath)
            ctx.setStrokeColor(borderCol.cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokePath()
            
        case .none:
            break
        }
        
        // 2. Draw Symbol Text (e.g. ">", "→", etc.)
        let symbolString = settings.resolvedSymbolString
        let fontWeight: NSFont.Weight
        switch settings.fontWeight {
        case "Bold": fontWeight = .bold
        case "Semibold": fontWeight = .semibold
        case "Medium": fontWeight = .medium
        default: fontWeight = .regular
        }
        let font = NSFont.systemFont(ofSize: settings.fontSize, weight: fontWeight)
        let textColor = NSColor(Color(hex: settings.symbolColorHex, alpha: settings.symbolColorAlpha))
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let attrStr = NSAttributedString(string: symbolString, attributes: attrs)
        let textSize = attrStr.size()
        
        let textOrigin = CGPoint(
            x: rect.midX - textSize.width / 2.0,
            y: rect.midY - textSize.height / 2.0
        )
        
        NSGraphicsContext.saveGraphicsState()
        let nctx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nctx
        attrStr.draw(at: textOrigin)
        NSGraphicsContext.restoreGraphicsState()
        
        ctx.restoreGState()
    }
}
