import Foundation
import PDFKit
import AppKit

public class KeynoteBridge {
    public static func executeAppleScript(_ script: String) -> (success: Bool, output: String, error: String?) {
        if let ascript = NSAppleScript(source: script) {
            var err: NSDictionary?
            let res = ascript.executeAndReturnError(&err)
            if let e = err {
                let msg = (e[NSAppleScript.errorMessage] as? String) ?? e.description
                return (false, "", msg)
            }
            return (true, res.stringValue ?? "", nil)
        }
        return (false, "", "Could not initialize AppleScript.")
    }
    
    public static func getFrontKeynoteDocInfo() -> (name: String, width: Int, height: Int, slideCount: Int)? {
        let script = """
        tell application "Keynote"
            if not (exists front document) then return "NO_DOC"
            set doc to front document
            return (name of doc) & "|||" & (width of doc as integer) & "|||" & (height of doc as integer) & "|||" & (count of slides of doc)
        end tell
        """
        let res = executeAppleScript(script)
        guard res.success, res.output != "NO_DOC" else { return nil }
        let parts = res.output.components(separatedBy: "|||")
        guard parts.count == 4,
              let w = Int(parts[1]),
              let h = Int(parts[2]),
              let sCount = Int(parts[3]) else { return nil }
        return (parts[0], w, h, sCount)
    }
    
    public static func getFrontPreviewPDFPath() -> String? {
        let script = "tell application \"Preview\" to if (count of documents) > 0 then return path of front document"
        let res = executeAppleScript(script)
        if res.success && !res.output.isEmpty {
            var path = res.output
            if path.contains(" - INTERACTIVE") {
                let original = path.replacingOccurrences(of: " - INTERACTIVE", with: "")
                if FileManager.default.fileExists(atPath: original) {
                    path = original
                }
            }
            return path
        }
        return nil
    }
    
    public static func syncKeynote(config: NotebookConfig, progress: @escaping (Double, String) -> Void) throws -> (slideCount: Int, duration: Double) {
        let startTime = Date()
        
        progress(0.05, "Connecting to Keynote...")
        guard let docInfo = getFrontKeynoteDocInfo() else {
            throw NSError(domain: "KeynoteBridge", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active presentation open in Keynote. Please open your Keynote master template."])
        }
        
        guard let pdfDoc = PDFDocument(url: URL(fileURLWithPath: config.targetPDFPath)) else {
            throw NSError(domain: "KeynoteBridge", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not open target PDF for rendering."])
        }
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("keynote_bg_swap_\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        progress(0.15, "Rendering PDF pages concurrently...")
        let renderScale: CGFloat = 3.5
        let totalPDFPages = pdfDoc.pageCount
        let offset = config.hasCover ? 1 : 0
        let slidesToProcess = Array(1...docInfo.slideCount)
        var renderedFiles: [Int: String] = [:]
        let lock = NSLock()
        
        DispatchQueue.concurrentPerform(iterations: slidesToProcess.count) { i in
            let sNum = slidesToProcess[i]
            let pdfPageNum = sNum + offset
            guard pdfPageNum <= totalPDFPages, let page = pdfDoc.page(at: pdfPageNum - 1) else { return }
            
            let pageRect = page.bounds(for: .mediaBox)
            let pixelW = Int(pageRect.width * renderScale)
            let pixelH = Int(pageRect.height * renderScale)
            
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixelW, pixelsHigh: pixelH,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32
            ) else { return }
            
            NSGraphicsContext.saveGraphicsState()
            guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
            NSGraphicsContext.current = context
            let cg = context.cgContext
            cg.scaleBy(x: renderScale, y: renderScale)
            page.draw(with: .mediaBox, to: cg)
            NSGraphicsContext.restoreGraphicsState()
            
            if let data = rep.representation(using: .png, properties: [:]) {
                let fileURL = tempDir.appendingPathComponent(String(format: "slide_%04d.png", sNum))
                try? data.write(to: fileURL)
                lock.lock()
                renderedFiles[sNum] = fileURL.path
                lock.unlock()
            }
        }
        
        progress(0.40, "Activating Keynote and processing slides...")
        _ = executeAppleScript("tell application \"Keynote\" to activate")
        usleep(200000)
        
        for sIdx in 1...docInfo.slideCount {
            guard let imgPath = renderedFiles[sIdx] else { continue }
            let isSubchapterSlide = (sIdx >= config.skipSidebarStartPage && sIdx <= config.skipSidebarEndPage)
            
            let updateScript = """
            tell application "Keynote"
                set targetDoc to front document
                set docW to width of targetDoc
                set docH to height of targetDoc
                set curSlide to slide \(sIdx) of targetDoc
                set current slide of targetDoc to curSlide
                
                set imgPosix to "\(imgPath)"
                set imgAlias to (POSIX file imgPosix) as alias
                
                tell curSlide
                    repeat with idx from (count of images) to 1 by -1
                        set anImg to item idx of images
                        set iW to width of anImg
                        set iH to height of anImg
                        if (iW > (docW * 0.4) and iH > (docH * 0.4)) or (iW <= 2 and iH <= 2) then
                            try
                                delete anImg
                            end try
                        else if \(isSubchapterSlide) and (iW > 50 and iW < 120 and iH > (docH * 0.8)) then
                            try
                                delete anImg
                            end try
                        end if
                    end repeat
                    
                    set placedImg to make new image with properties {file:imgAlias}
                    tell placedImg
                        set curW to width
                        set curH to height
                        set scaleW to docW / curW
                        set scaleH to docH / curH
                        if scaleW > scaleH then
                            set finalW to docW
                            set finalH to curH * scaleW
                        else
                            set finalW to curW * scaleH
                            set finalH to docH
                        end if
                        set width to finalW
                        set height to finalH
                        set position to {(docW - finalW) / 2, (docH - finalH) / 2}
                    end tell
                end tell
                set selection of targetDoc to {placedImg}
            end tell
            delay 0.08
            tell application "System Events"
                tell process "Keynote"
                    try
                        click menu item "Send to Back" of menu "Arrange" of menu bar 1
                    end try
                end tell
            end tell
            delay 0.04
            """
            
            _ = executeAppleScript(updateScript)
            
            if sIdx % 10 == 0 {
                let p = 0.40 + (0.55 * Double(sIdx) / Double(docInfo.slideCount))
                progress(p, "Updating Keynote slide \(sIdx) of \(docInfo.slideCount)...")
            }
            if sIdx % 25 == 0 {
                _ = executeAppleScript("tell application \"Keynote\" to save front document")
            }
        }
        
        _ = executeAppleScript("tell application \"Keynote\" to save front document")
        try? FileManager.default.removeItem(at: tempDir)
        
        let duration = Date().timeIntervalSince(startTime)
        progress(1.0, "Keynote presentation saved!")
        return (docInfo.slideCount, duration)
    }
}
