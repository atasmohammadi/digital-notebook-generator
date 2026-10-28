import Foundation
import PDFKit
import AppKit

func printUsage() {
    print("""
    mortalpages Keynote Background Swapper
    Usage:
      swift keynote_bg_swapper.swift [options]
    Options:
      --pdf <path>          Path to target Canva PDF (default: auto-detect from Preview)
      --offset <int>        PDF cover page offset (default: 1, slide 1 gets PDF page 2)
      --start <int>         Starting Keynote slide (default: 1)
      --end <int>           Ending Keynote slide (default: all slides)
      --scale <float>       Render scale DPI multiplier (default: 3.5, ~250-300 DPI)
      --save / --no-save    Auto-save presentation when finished (default: true)
    """)
}

func executeAppleScript(_ script: String) -> (success: Bool, output: String, error: String?) {
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

func getFrontPreviewPDF() -> String? {
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

func getKeynoteDocInfo() -> (name: String, width: Int, height: Int, slideCount: Int)? {
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

var pdfPath: String? = nil
var offset: Int = 1
var startSlideArg: Int? = nil
var endSlideArg: Int? = nil
var renderScale: CGFloat = 3.5
var autoSave: Bool = true

let args = CommandLine.arguments
var argIdx = 1
while argIdx < args.count {
    switch args[argIdx] {
    case "--pdf":
        if argIdx + 1 < args.count { pdfPath = args[argIdx + 1]; argIdx += 1 }
    case "--offset":
        if argIdx + 1 < args.count, let val = Int(args[argIdx + 1]) { offset = val; argIdx += 1 }
    case "--start":
        if argIdx + 1 < args.count, let val = Int(args[argIdx + 1]) { startSlideArg = val; argIdx += 1 }
    case "--end":
        if argIdx + 1 < args.count, let val = Int(args[argIdx + 1]) { endSlideArg = val; argIdx += 1 }
    case "--scale":
        if argIdx + 1 < args.count, let val = Double(args[argIdx + 1]) { renderScale = CGFloat(val); argIdx += 1 }
    case "--no-save":
        autoSave = false
    case "--save":
        autoSave = true
    case "--help", "-h":
        printUsage()
        exit(0)
    default:
        break
    }
    argIdx += 1
}

print("==================================================")
print("   mortalpages Keynote Background Swapper")
print("==================================================")

// 1. Identify Keynote Document
guard let docInfo = getKeynoteDocInfo() else {
    print("❌ Error: No Keynote presentation is open.")
    print("   Please open your master Keynote presentation and try again.")
    exit(1)
}
print("🖥  Keynote Document: \(docInfo.name)")
print("📐 Dimensions:       \(docInfo.width) x \(docInfo.height)")
print("📊 Total Slides:     \(docInfo.slideCount)")

// 2. Identify Target PDF
if pdfPath == nil {
    print("🔍 Auto-detecting PDF open in Preview...")
    pdfPath = getFrontPreviewPDF()
}

guard let targetPDF = pdfPath, FileManager.default.fileExists(atPath: targetPDF) else {
    print("❌ Error: No target PDF specified or open in Preview.")
    printUsage()
    exit(1)
}
print("📄 Target PDF:       \(targetPDF)")

guard let pdfDoc = PDFDocument(url: URL(fileURLWithPath: targetPDF)) else {
    print("❌ Error: Could not read target PDF with PDFKit.")
    exit(1)
}
let totalPDFPages = pdfDoc.pageCount
print("📑 PDF Page Count:   \(totalPDFPages)")

let startSlide = max(1, startSlideArg ?? 1)
let endSlide = min(docInfo.slideCount, endSlideArg ?? docInfo.slideCount)
print("🎯 Slide Range:      \(startSlide) to \(endSlide)")
print("⚡ Page Offset:      +\(offset) (Keynote slide \(startSlide) gets PDF page \(startSlide + offset))")

// 3. Render required PDF pages concurrently
let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("keynote_bg_swap_\(Int(Date().timeIntervalSince1970))")
try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

print("\n🚀 Rendering PDF pages (scale: \(renderScale)x)...")
let renderStart = Date()

let slidesToProcess = Array(startSlide...endSlide)
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

let renderTime = Date().timeIntervalSince(renderStart)
print("✅ Rendered \(renderedFiles.count) pages in \(String(format: "%.2f", renderTime))s\n")

// 4. Update Keynote slides
print("🎬 Updating Keynote slides and layering to back...")
let keynoteStart = Date()

let activateScript = "tell application \"Keynote\" to activate"
_ = executeAppleScript(activateScript)
usleep(200000)

for sIdx in startSlide...endSlide {
    guard let imgPath = renderedFiles[sIdx] else {
        print("⚠️ Skipping slide \(sIdx): no rendered image.")
        continue
    }
    
    let isSubchapterSlide = (sIdx >= 3 && sIdx <= 14)
    
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
            -- 1. Safely remove previous background images in reverse order
            repeat with idx from (count of images) to 1 by -1
                set anImg to item idx of images
                set iW to width of anImg
                set iH to height of anImg
                
                -- Remove previous large page backgrounds & 1x1 artifacts
                if (iW > (docW * 0.4) and iH > (docH * 0.4)) or (iW <= 2 and iH <= 2) then
                    try
                        delete anImg
                    end try
                -- On subchapter slides 3..14, remove master sidebar strip so Canva colored tab shows!
                else if \(isSubchapterSlide) and (iW > 50 and iW < 120 and iH > (docH * 0.8)) then
                    try
                        delete anImg
                    end try
                end if
            end repeat
            
            -- 2. Place new page image
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
        
        -- 3. Select placed image
        set selection of targetDoc to {placedImg}
    end tell
    
    delay 0.08
    
    -- 4. Send to back via System Events
    tell application "System Events"
        tell process "Keynote"
            try
                click menu item "Send to Back" of menu "Arrange" of menu bar 1
            end try
        end tell
    end tell
    delay 0.04
    """
    
    let res = executeAppleScript(updateScript)
    if !res.success {
        print("❌ Error on slide \(sIdx): \(res.error ?? "unknown")")
    } else {
        let pdfPage = sIdx + offset
        let pct = Int((Double(sIdx - startSlide + 1) / Double(endSlide - startSlide + 1)) * 100)
        let note = isSubchapterSlide ? " (colored chapter tab preserved)" : ""
        print("[\(sIdx)/\(endSlide)] (\(pct)%) Slide \(sIdx) updated with PDF Page \(pdfPage)\(note)")
    }
    
    // Auto-save periodically every 25 slides
    if autoSave && sIdx % 25 == 0 {
        _ = executeAppleScript("tell application \"Keynote\" to save front document")
        print("💾 Auto-saved checkpoint at slide \(sIdx)")
    }
}

if autoSave {
    _ = executeAppleScript("tell application \"Keynote\" to save front document")
    print("💾 Final presentation saved.")
}

// 5. Cleanup temporary files
try? FileManager.default.removeItem(at: tempDir)
print("🧹 Cleaned up temporary rendered files.")

let totalDuration = Date().timeIntervalSince(keynoteStart)
print("\n🎉 Completed all \(slidesToProcess.count) slides in \(String(format: "%.1f", totalDuration))s!")
print("==================================================")
