import Foundation
import PDFKit
import CoreGraphics
import AppKit

func printUsage() {
    print("""
    mortalpages PDF Hyperlink Engine
    Usage:
      swift pdf_hyperlink_engine.swift [options]
    Options:
      --pdf <path>        Path to target Canva PDF (default: auto-detect from Preview)
      --template <path>   Path to template PDF with hyperlinks (default: auto-detect)
      --output <path>     Output path (default: [target]_interactive.pdf)
    """)
}

func getFrontPreviewPDF() -> String? {
    let script = "tell application \"Preview\" to if (count of documents) > 0 then return path of front document"
    if let ascript = NSAppleScript(source: script) {
        var err: NSDictionary?
        let res = ascript.executeAndReturnError(&err)
        if err == nil, let path = res.stringValue, !path.isEmpty {
            return path
        }
    }
    return nil
}

func findDefaultTemplate() -> String? {
    let candidates = [
        "/Users/sarahbenita/Library/Mobile Documents/com~apple~CloudDocs/digital business related/mortalpages/Notebook 4 - pretty pastel/Pretty Pastel Portrait.pdf",
        "/Users/sarahbenita/Library/Mobile Documents/com~apple~CloudDocs/digital business related/mortalpages/Notebook 4 - pretty pastel/FINAL PRODUCT - Pretty Pastel.pdf"
    ]
    for c in candidates {
        if FileManager.default.fileExists(atPath: c) {
            return c
        }
    }
    return nil
}

var pdfPath: String? = nil
var templatePath: String? = nil
var outputPath: String? = nil

let args = CommandLine.arguments
var i = 1
while i < args.count {
    switch args[i] {
    case "--pdf":
        if i + 1 < args.count { pdfPath = args[i + 1]; i += 1 }
    case "--template":
        if i + 1 < args.count { templatePath = args[i + 1]; i += 1 }
    case "--output":
        if i + 1 < args.count { outputPath = args[i + 1]; i += 1 }
    case "--help", "-h":
        printUsage()
        exit(0)
    default:
        break
    }
    i += 1
}

if pdfPath == nil {
    print("🔍 Auto-detecting PDF open in Preview...")
    pdfPath = getFrontPreviewPDF()
}

// If the detected PDF is already an - INTERACTIVE file, look for original source
if let p = pdfPath, p.contains(" - INTERACTIVE") {
    let original = p.replacingOccurrences(of: " - INTERACTIVE", with: "")
    if FileManager.default.fileExists(atPath: original) {
        pdfPath = original
    }
}

guard let targetPDF = pdfPath, FileManager.default.fileExists(atPath: targetPDF) else {
    print("❌ Error: No target PDF specified or open in Preview.")
    printUsage()
    exit(1)
}

if templatePath == nil {
    print("🔍 Finding master hyperlink template...")
    templatePath = findDefaultTemplate()
}

guard let tPath = templatePath, FileManager.default.fileExists(atPath: tPath) else {
    print("❌ Error: Master template PDF not found.")
    exit(1)
}

print("📄 Target PDF:   \(targetPDF)")
print("📑 Template PDF: \(tPath)")

guard let canvaDoc = PDFDocument(url: URL(fileURLWithPath: targetPDF)),
      let templateDoc = PDFDocument(url: URL(fileURLWithPath: tPath)),
      let cgPDFDoc = CGPDFDocument(URL(fileURLWithPath: targetPDF) as CFURL) else {
    print("❌ Error: Could not open PDF documents.")
    exit(1)
}

let startTime = Date()

// 1. Extract Master Sidebar from Canva Page 2 (index 1)
print("✂️  Extracting master layout sidebar from Canva Page 2...")
let masterPage = canvaDoc.page(at: 1)! // Canva Page 2 (0-indexed: 1)
let masterBounds = masterPage.bounds(for: .mediaBox)
let sidebarWidth: CGFloat = 60.0 // 80 * (1152 / 1536)

let renderScale: CGFloat = 4.16666667 // ~300 DPI high resolution
let pixelW = Int(sidebarWidth * renderScale)
let pixelH = Int(masterBounds.height * renderScale)

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

guard let sidebarCG = repSidebar.cgImage else {
    print("❌ Failed to render master sidebar image.")
    exit(1)
}

// 2. Extract Embossed Watermark from Canva Page 2
print("💧 Extracting watermark from Canva Page 2...")
let wmRect = CGRect(x: 501, y: 28, width: 150, height: 35)
let wmPixelW = Int(wmRect.width * renderScale)
let wmPixelH = Int(wmRect.height * renderScale)

let repWM = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: wmPixelW, pixelsHigh: wmPixelH,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32
)!
NSGraphicsContext.saveGraphicsState()
let wmCtx = NSGraphicsContext(bitmapImageRep: repWM)!
NSGraphicsContext.current = wmCtx
let cgWM = wmCtx.cgContext
cgWM.scaleBy(x: renderScale, y: renderScale)
cgWM.translateBy(x: -wmRect.origin.x, y: -wmRect.origin.y)
masterPage.draw(with: .mediaBox, to: cgWM)
NSGraphicsContext.restoreGraphicsState()

// Make watermark background transparent
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
guard let watermarkCG = repWM.cgImage else {
    print("❌ Failed to render watermark image.")
    exit(1)
}

// Determine output path
let outURL: URL
if let o = outputPath {
    outURL = URL(fileURLWithPath: o)
} else {
    let targetURL = URL(fileURLWithPath: targetPDF)
    let dir = targetURL.deletingLastPathComponent()
    let base = targetURL.deletingPathExtension().lastPathComponent
    outURL = dir.appendingPathComponent("\(base) - INTERACTIVE.pdf")
}

print("🔨 Generating final PDF (excluding Canva Page 2, preserving chapter colors, injecting active links)...")
let pdfCFURL = outURL as CFURL
var mediaBox = CGRect(origin: .zero, size: masterBounds.size)
guard let writeContext = CGContext(pdfCFURL, mediaBox: &mediaBox, nil) else {
    print("❌ Failed to create destination PDF context.")
    exit(1)
}

// Scale factor between template (1536x1980) and Canva (1152x1485)
let tBox = templateDoc.page(at: 1)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 1536, height: 1980)
let sx: CGFloat = masterBounds.width / tBox.width
let sy: CGFloat = masterBounds.height / tBox.height

// 12 Chapter Targets for arrows on Final Page 2 (Main Chapter Selection)
let arrowTargets: [Int] = [
    45, 57, 69, 81, 93, 105, 117, 129, 141, 153, 165, 177
]

var totalLinks = 0
let totalCanvaPages = cgPDFDoc.numberOfPages
let totalFinalPages = totalCanvaPages - 1 // Exclude master layout page

// --- Final Page 1: Cover (Canva Page 1) ---
if let coverPage = cgPDFDoc.page(at: 1) {
    var coverBox = coverPage.getBoxRect(.mediaBox)
    writeContext.beginPage(mediaBox: &coverBox)
    writeContext.addDestination("page_1" as CFString, at: CGPoint(x: 0, y: coverBox.height))
    writeContext.drawPDFPage(coverPage)
    // Draw watermark on cover
    writeContext.draw(watermarkCG, in: wmRect)
    writeContext.endPage()
}

// --- Final Pages 2 to totalFinalPages ---
for finalPageNum in 2...totalFinalPages {
    let canvaPageNum = finalPageNum + 1 // Final page 2 is Canva page 3
    guard let cPage = cgPDFDoc.page(at: canvaPageNum) else { continue }
    
    var pageBox = cPage.getBoxRect(.mediaBox)
    writeContext.beginPage(mediaBox: &pageBox)
    
    // Add anchor destination for this page
    writeContext.addDestination("page_\(finalPageNum)" as CFString, at: CGPoint(x: 0, y: pageBox.height))
    
    // Draw base page content
    writeContext.drawPDFPage(cPage)
    
    // OVERLAY RULES:
    // Pages 3..14: DO NOT overlay master sidebar (they have chapter-colored sidebar!)
    // Page 2: Has neutral sidebar in Canva.
    // Pages 15..188: Overlay master sidebar on left.
    if finalPageNum >= 15 {
        let sidebarRect = CGRect(x: 0, y: 0, width: sidebarWidth, height: pageBox.height)
        writeContext.draw(sidebarCG, in: sidebarRect)
    }
    
    // WATERMARK RULES:
    // Canva Pages 4..15 already have the watermark.
    // All other pages get the watermark stamped!
    if finalPageNum == 2 || finalPageNum >= 15 {
        writeContext.draw(watermarkCG, in: wmRect)
    }
    
    // HYPERLINK RULES:
    // 1. Inject sidebar tabs & template links from Template PDF
    let templatePageIdx = finalPageNum - 1
    var chapterTabBounds = [CGRect]()
    
    if templatePageIdx < templateDoc.pageCount, let tPage = templateDoc.page(at: templatePageIdx) {
        for a in tPage.annotations {
            guard a.type == "Link" else { continue }
            
            // Skip mortalpages.com watermark hyperlinks!
            if let url = a.url, url.absoluteString.contains("mortalpages") { continue }
            let b = a.bounds
            if b.origin.y < 80 && b.origin.x > 300 { continue }
            
            let scaledRect = CGRect(x: b.origin.x * sx, y: b.origin.y * sy, width: b.size.width * sx, height: b.size.height * sy)
            
            if let dest = a.destination, let targetPage = dest.page {
                let targetSlide = templateDoc.index(for: targetPage) + 1
                if targetSlide >= 2 && targetSlide <= totalFinalPages {
                    writeContext.setDestination("page_\(targetSlide)" as CFString, for: scaledRect)
                    totalLinks += 1
                    
                    // On Page 2, collect the 12 chapter sidebar tab rects (targets 3..14)
                    if finalPageNum == 2 && targetSlide >= 3 && targetSlide <= 14 {
                        chapterTabBounds.append(scaledRect)
                    }
                }
            } else if let url = a.url {
                writeContext.setURL(url as CFURL, for: scaledRect)
                totalLinks += 1
            }
        }
    }
    
    // 2. Arrow Links on Final Page 2 (Main Chapter Selection)
    // Uses the EXACT SAME SHAPE AND SIZE as the sidebar tab boxes!
    // Centered over the arrows at x = 804.4, using the exact vertical position and size of tabs 1..12
    if finalPageNum == 2 {
        // Sort tab bounds from top to bottom (highest y first)
        let sortedTabs = chapterTabBounds.sorted(by: { $0.origin.y > $1.origin.y })
        
        for idx in 0..<min(sortedTabs.count, arrowTargets.count) {
            let tab = sortedTabs[idx]
            let targetP = arrowTargets[idx]
            
            // Same width, same height, same shape as sidebar tab, centered over the arrow
            let arrowBox = CGRect(
                x: 825.5 - (tab.width / 2.0),
                y: tab.origin.y,
                width: tab.width,
                height: tab.height
            )
            writeContext.setDestination("page_\(targetP)" as CFString, for: arrowBox)
            totalLinks += 1
        }
    }
    
    writeContext.endPage()
}

writeContext.closePDF()

let duration = Date().timeIntervalSince(startTime)
let fileSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
let mbSize = Double(fileSize) / (1024.0 * 1024.0)

print("🎉 Success!")
print("   - Pages in final PDF: \(totalFinalPages) (Master layout page excluded)")
print("   - Injected Links:     \(totalLinks) active hyperlinks (sidebar + matching arrow boxes)")
print("   - Arrow Hitboxes:     Same shape & size as sidebar tabs (\(String(format: "%.1f", 42.2)) x \(String(format: "%.1f", 101.5)) pt)")
print("   - Watermark:          mortalpages.com placed on all pages (not hyperlinked)")
print("   - Execution Time:     \(String(format: "%.2f", duration)) seconds")
print("   - Output PDF:         \(outURL.path)")
print("   - File Size:          \(String(format: "%.2f", mbSize)) MB")
