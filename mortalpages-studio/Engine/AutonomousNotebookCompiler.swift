import Foundation
import WebKit
import CoreGraphics
import PDFKit
import AppKit

public class AutonomousNotebookCompiler {
    
    public struct CompilerOptions {
        public var theme: HTMLTemplateTheme
        public var watermarkSettings: WatermarkSettings
        public var templateMapping: NotebookTemplateMapping
        public var totalPages: Int // Default 188
        public var outputPath: String
        
        public init(
            theme: HTMLTemplateTheme = .glassLight,
            watermarkSettings: WatermarkSettings = .defaultSettings,
            templateMapping: NotebookTemplateMapping = .defaultMapping,
            totalPages: Int = 188,
            outputPath: String = ""
        ) {
            self.theme = theme
            self.watermarkSettings = watermarkSettings
            self.templateMapping = templateMapping
            self.totalPages = totalPages
            self.outputPath = outputPath
        }
    }
    
    public static func compileNotebook(
        options: CompilerOptions,
        templateDir: URL,
        progress: @escaping (Double, String) -> Void
    ) throws -> (outputPath: String, linksCount: Int, duration: Double, fileSizeMB: Double) {
        let startTime = Date()
        
        progress(0.05, "Initializing HTML Template Engine...")
        
        // 1. Resolve Output Path
        let outPath: String
        if !options.outputPath.isEmpty {
            outPath = options.outputPath
        } else {
            let userDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let safeThemeName = options.theme.name.replacingOccurrences(of: "/", with: "-")
            outPath = userDocs.appendingPathComponent("\(safeThemeName) - Digital Journal.pdf").path
        }
        
        // 2. Pre-render High-DPI Watermark if enabled
        var activeWatermarkCG: CGImage? = nil
        var activeWatermarkDrawnRect: CGRect = .zero
        var activeWatermarkRotation: Double = 0.0
        
        if options.watermarkSettings.mode == .customText {
            if let rendered = WatermarkRenderer.renderImage(settings: options.watermarkSettings),
               let cg = rendered.cgImage {
                activeWatermarkCG = cg
                activeWatermarkDrawnRect = rendered.drawnRect
                activeWatermarkRotation = options.watermarkSettings.rotationDegrees
            }
        }
        
        let shouldStampPage: (Int) -> Bool = { pageNum in
            guard activeWatermarkCG != nil else { return false }
            switch options.watermarkSettings.scope {
            case .allPages: return true
            case .allExceptCover: return pageNum > 1
            case .contentOnly: return pageNum >= 15
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
        
        // 3. Setup Master PDF Destination Context
        let pdfURL = URL(fileURLWithPath: outPath) as CFURL
        var mediaBox = CGRect(x: 0, y: 0, width: 1152, height: 1485)
        guard let writeContext = CGContext(pdfURL, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "Compiler", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize master PDF context."])
        }
        
        // 4. Preload HTML Template Files
        let loadHTMLFile: (String) -> String = { relPath in
            let fileURL = templateDir.appendingPathComponent(relPath)
            return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        }
        
        // Build CSS variable injection string
        var cssVars = ":root {\n"
        for (k, v) in options.theme.variables {
            cssVars += "  \(k): \(v) !important;\n"
        }
        cssVars += "}\n"
        let styleOverride = "<style id='injected-theme'>\n\(cssVars)</style>\n"
        
        let injectTheme: (String) -> String = { html in
            if html.contains("</head>") {
                return html.replacingOccurrences(of: "</head>", with: "\(styleOverride)</head>")
            }
            return styleOverride + html
        }
        
        // Thread-safe WebKit renderer
        func renderHTMLToPDFPage(html: String) throws -> CGPDFPage? {
            let preparedHTML = injectTheme(html)
            var renderedData: Data? = nil
            var renderError: Error? = nil
            var isFinished = false
            
            let loadBlock = {
                let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1152, height: 1485))
                
                class NavDelegate: NSObject, WKNavigationDelegate {
                    var onFinish: (() -> Void)?
                    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                        onFinish?()
                    }
                    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
                        onFinish?()
                    }
                }
                
                let delegate = NavDelegate()
                objc_setAssociatedObject(webView, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                delegate.onFinish = {
                    let pdfConfig = WKPDFConfiguration()
                    pdfConfig.rect = CGRect(x: 0, y: 0, width: 1152, height: 1485)
                    webView.createPDF(configuration: pdfConfig) { res in
                        switch res {
                        case .success(let data):
                            renderedData = data
                        case .failure(let err):
                            renderError = err
                        }
                        isFinished = true
                    }
                }
                webView.navigationDelegate = delegate
                webView.loadHTMLString(preparedHTML, baseURL: templateDir.appendingPathComponent("Base"))
            }
            
            if Thread.isMainThread {
                loadBlock()
                while !isFinished {
                    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
                }
            } else {
                DispatchQueue.main.async(execute: loadBlock)
                while !isFinished {
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
            
            if let err = renderError { throw err }
            guard let data = renderedData,
                  let provider = CGDataProvider(data: data as CFData),
                  let doc = CGPDFDocument(provider),
                  let page = doc.page(at: 1) else {
                return nil
            }
            return page
        }
        
        progress(0.15, "Rendering master template components...")
        
        // Cache rendered master template PDF pages on demand
        var renderedPagesCache: [String: CGPDFPage] = [:]
        
        let getRenderedPage: (String) -> CGPDFPage? = { relPath in
            if let cached = renderedPagesCache[relPath] {
                return cached
            }
            let html = loadHTMLFile(relPath)
            guard !html.isEmpty else { return nil }
            if let page = try? renderHTMLToPDFPage(html: html) {
                renderedPagesCache[relPath] = page
                return page
            }
            return nil
        }
        
        var totalLinks = 0
        let totalPages = options.totalPages
        
        // Sidebar tab geometry (Standard mortalpages 14 tabs)
        let tabW: CGFloat = 44.0
        let tabH: CGFloat = 98.0
        let tabX: CGFloat = 8.0
        let topY: CGFloat = 1420.0
        let tabSpacing: CGFloat = 104.0
        
        // Chapter arrow targets: Subchapter covers on Pages 45, 57, 69, ...
        let arrowTargets = [45, 57, 69, 81, 93, 105, 117, 129, 141, 153, 165, 177]
        
        // 5. Assemble All 188 Pages
        progress(0.30, "Assembling 188 interactive notebook pages...")
        
        for p in 1...totalPages {
            var box = mediaBox
            writeContext.beginPage(mediaBox: &box)
            writeContext.addDestination("page_\(p)" as CFString, at: CGPoint(x: 0, y: box.height))
            
            // Resolve template for page dynamically
            let templateRelPath = options.templateMapping.resolveTemplate(forPage: p, arrowTargets: arrowTargets)
            if let renderedPage = getRenderedPage(templateRelPath) {
                writeContext.drawPDFPage(renderedPage)
            }
            
            // Watermark stamping
            if shouldStampPage(p) {
                drawWatermarkOnContext(writeContext)
            }
            
            // Inject Navigation Tabs on Pages 2..188
            if p >= 2 {
                // 1. Home Tab -> Page 2
                let homeRect = CGRect(x: tabX, y: topY, width: tabW, height: tabH)
                writeContext.setDestination("page_2" as CFString, for: homeRect)
                totalLinks += 1
                
                // 2. Template List Tab -> Page 15
                let tlistRect = CGRect(x: tabX, y: topY - tabSpacing, width: tabW, height: tabH)
                writeContext.setDestination("page_15" as CFString, for: tlistRect)
                totalLinks += 1
                
                // 3. Chapters 1..12 Tabs -> Pages 3..14
                for ch in 1...12 {
                    let chY = topY - tabSpacing * CGFloat(ch + 1)
                    let chRect = CGRect(x: tabX, y: chY, width: tabW, height: tabH)
                    let targetPage = ch + 2 // Pages 3..14
                    writeContext.setDestination("page_\(targetPage)" as CFString, for: chRect)
                    totalLinks += 1
                }
            }
            
            // Inject Chapter Selection Cards on Page 2 (2-Column Grid)
            if p == 2 {
                let rows: [CGFloat] = [381.875, 477.875, 573.875, 669.875, 765.875, 861.875]
                let cardH: CGFloat = 72.0
                let cardW: CGFloat = 543.0
                let col1X: CGFloat = 8.0
                let col2X: CGFloat = 601.0
                
                for (rowIdx, htmlY) in rows.enumerated() {
                    let pdfY = 1485.0 - htmlY - cardH
                    
                    // Col 1 (Odd chapters: 1, 3, 5, 7, 9, 11)
                    let chOdd = rowIdx * 2 + 1
                    if chOdd <= arrowTargets.count {
                        let targetOdd = arrowTargets[chOdd - 1]
                        let rectOdd = CGRect(x: col1X, y: pdfY, width: cardW, height: cardH)
                        writeContext.setDestination("page_\(targetOdd)" as CFString, for: rectOdd)
                        totalLinks += 1
                    }
                    
                    // Col 2 (Even chapters: 2, 4, 6, 8, 10, 12)
                    let chEven = rowIdx * 2 + 2
                    if chEven <= arrowTargets.count {
                        let targetEven = arrowTargets[chEven - 1]
                        let rectEven = CGRect(x: col2X, y: pdfY, width: cardW, height: cardH)
                        writeContext.setDestination("page_\(targetEven)" as CFString, for: rectEven)
                        totalLinks += 1
                    }
                }
            }
            
            writeContext.endPage()
            
            if p % 25 == 0 || p == totalPages {
                let pct = 0.30 + (Double(p) / Double(totalPages)) * 0.60
                progress(pct, "Compiled page \(p) of \(totalPages)...")
            }
        }
        
        writeContext.closePDF()
        
        // 6. Neutralize Preview Data Detectors
        if options.watermarkSettings.neutralizeDataDetectors {
            progress(0.95, "Neutralizing Preview link detectors...")
            if let data = try? Data(contentsOf: URL(fileURLWithPath: outPath)),
               var pdfStr = String(data: data, encoding: .isoLatin1) {
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
                    try? outData.write(to: URL(fileURLWithPath: outPath))
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let fileSizeMB = ((try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Double) ?? 0.0) / (1024.0 * 1024.0)
        
        progress(1.0, "Ready! Autonomous notebook generated with \(totalPages) pages and \(totalLinks) links in \(String(format: "%.1f", duration))s.")
        return (outputPath: outPath, linksCount: totalLinks, duration: duration, fileSizeMB: fileSizeMB)
    }
}
