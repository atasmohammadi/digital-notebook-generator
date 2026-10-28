import Foundation
import WebKit
import CoreGraphics
import PDFKit
import AppKit

public class AutonomousNotebookCompiler {
    
    public struct CompilerOptions {
        public var theme: HTMLTemplateTheme
        public var watermarkSettings: WatermarkSettings
        public var chapterNavSettings: ChapterNavIndicatorSettings
        public var templateMapping: NotebookTemplateMapping
        public var totalPages: Int // Default 188
        public var outputPath: String
        public var autoCompressPDF: Bool
        public var targetMaxFileSizeMB: Double
        
        public init(
            theme: HTMLTemplateTheme = .glassLight,
            watermarkSettings: WatermarkSettings = .defaultSettings,
            chapterNavSettings: ChapterNavIndicatorSettings = .defaultSettings,
            templateMapping: NotebookTemplateMapping = .defaultMapping,
            totalPages: Int = 188,
            outputPath: String = "",
            autoCompressPDF: Bool = true,
            targetMaxFileSizeMB: Double = 5.0
        ) {
            self.theme = theme
            self.watermarkSettings = watermarkSettings
            self.chapterNavSettings = chapterNavSettings
            self.templateMapping = templateMapping
            self.totalPages = totalPages
            self.outputPath = outputPath
            self.autoCompressPDF = autoCompressPDF
            self.targetMaxFileSizeMB = targetMaxFileSizeMB
        }
    }
    
    public struct ParsedHTMLLink {
        public enum Kind {
            case tab
            case chapterCard
            case templateCard
        }
        public var kind: Kind
        public var dest: String
        public var index: Int
        public var rect: CGRect // In CoreGraphics PDF coordinates (bottom-left origin)
        
        public init(kind: Kind, dest: String, index: Int, rect: CGRect) {
            self.kind = kind
            self.dest = dest
            self.index = index
            self.rect = rect
        }
    }
    
    public struct RenderedComponent {
        public var pdfPage: CGPDFPage
        public var links: [ParsedHTMLLink]
        
        public init(pdfPage: CGPDFPage, links: [ParsedHTMLLink]) {
            self.pdfPage = pdfPage
            self.links = links
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
        
        // Attach QuartzFilter to master context if auto-compression enabled
        if options.autoCompressPDF && options.targetMaxFileSizeMB < 50.0 {
            if let qf = PDFCompressor.createQuartzFilter(targetMB: options.targetMaxFileSizeMB, pageCount: options.totalPages) {
                qf.apply(to: writeContext)
            }
        }
        
        // 4. Preload CSS Files & Build Inlined Stylesheet to avoid WebKit file:// cross-origin blocks
        let themeCSS = (try? String(contentsOf: templateDir.appendingPathComponent("Base/theme_variables.css"), encoding: .utf8)) ?? ""
        let stylesCSS = (try? String(contentsOf: templateDir.appendingPathComponent("Base/styles.css"), encoding: .utf8)) ?? ""
        
        var cssVars = ":root {\n"
        for (k, v) in options.theme.variables {
            cssVars += "  \(k): \(v) !important;\n"
        }
        cssVars += "}\n"
        
        let inlinedStylesTag = """
        <style id='inlined-template-studio-styles'>
        \(themeCSS)
        \(stylesCSS)
        \(cssVars)
        </style>
        """
        
        let loadAndPrepareHTML: (String, String) -> String = { relPath, activeDest in
            var fileURL = templateDir.appendingPathComponent(relPath)
            var currentCh = 0
            if relPath.hasPrefix("Navigation/subchapter_selection_") {
                let stem = relPath.replacingOccurrences(of: "Navigation/subchapter_selection_", with: "").replacingOccurrences(of: ".html", with: "")
                currentCh = Int(stem) ?? 1
                fileURL = templateDir.appendingPathComponent("Navigation/subchapter_selection.html")
            }
            
            guard var html = try? String(contentsOf: fileURL, encoding: .utf8), !html.isEmpty else {
                return ""
            }
            
            // If subchapter selection, substitute placeholders
            if currentCh > 0 {
                let chWords = ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"]
                let word = (currentCh >= 1 && currentCh <= 12) ? chWords[currentCh - 1] : "\(currentCh)"
                html = html.replacingOccurrences(of: "{{CHAPTER_NUM}}", with: "\(currentCh)")
                html = html.replacingOccurrences(of: "{{CHAPTER_WORD}}", with: word)
                
                var cardsHTML = ""
                for k in 1...12 {
                    cardsHTML += """
                    <div class="chapter-card" data-dest="sec\(k)">
                      <div class="chapter-info"><div class="chapter-number">\(currentCh).\(k)</div><span class="chapter-name">Section \(k)</span></div>
                      <svg class="chapter-arrow" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg>
                    </div>\n
                    """
                }
                html = html.replacingOccurrences(of: "{{SUBCHAPTER_CARDS}}", with: cardsHTML)
            }
            
            // Highlight active sidebar tab
            html = html.replacingOccurrences(of: "tab active", with: "tab")
            if !activeDest.isEmpty {
                html = html.replacingOccurrences(of: "class=\"tab\" data-dest=\"\(activeDest)\"", with: "class=\"tab active\" data-dest=\"\(activeDest)\"")
                html = html.replacingOccurrences(of: "data-dest=\"\(activeDest)\" class=\"tab\"", with: "data-dest=\"\(activeDest)\" class=\"tab active\"")
                html = html.replacingOccurrences(of: "{{ACTIVE_\(activeDest.uppercased())}}", with: "active")
            }
            // Clear remaining {{ACTIVE_...}} tokens
            let tokenRegex = try? NSRegularExpression(pattern: "\\{\\{ACTIVE_[A-Z0-9_]+\\}\\}", options: [])
            if let regex = tokenRegex {
                html = regex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count), withTemplate: "")
            }
            
            // Strip relative link tags so WebKit doesn't trigger security blocks or unstyled layout
            html = html.replacingOccurrences(of: "<link rel=\"stylesheet\" href=\"../Base/theme_variables.css\">", with: "")
            html = html.replacingOccurrences(of: "<link rel=\"stylesheet\" href=\"../Base/styles.css\">", with: "")
            html = html.replacingOccurrences(of: "<link rel=\"stylesheet\" href=\"theme_variables.css\">", with: "")
            html = html.replacingOccurrences(of: "<link rel=\"stylesheet\" href=\"styles.css\">", with: "")
            
            if html.contains("</head>") {
                return html.replacingOccurrences(of: "</head>", with: "\(inlinedStylesTag)\n</head>")
            }
            return inlinedStylesTag + html
        }
        
        // Thread-safe WebKit renderer with live DOM coordinate extraction
        func renderHTMLComponent(html: String) throws -> RenderedComponent? {
            guard !html.isEmpty else { return nil }
            var renderedData: Data? = nil
            var extractedLinks: [ParsedHTMLLink] = []
            var renderError: Error? = nil
            var isFinished = false
            
            let loadBlock = {
                let config = WKWebViewConfiguration()
                config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
                config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
                
                let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1152, height: 1485), configuration: config)
                
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
                    let jsExtract = """
                    (function() {
                        let items = [];
                        // 1. Sidebar tabs
                        document.querySelectorAll('.tab').forEach((el, idx) => {
                            let r = el.getBoundingClientRect();
                            items.push({
                                kind: 'tab',
                                dest: el.getAttribute('data-dest') || '',
                                index: idx,
                                x: r.x, y: r.y, w: r.width, h: r.height
                            });
                        });
                        // 2. Chapter cards
                        document.querySelectorAll('.chapter-card').forEach((el, idx) => {
                            let r = el.getBoundingClientRect();
                            items.push({
                                kind: 'chapter_card',
                                dest: el.getAttribute('data-dest') || '',
                                index: idx,
                                x: r.x, y: r.y, w: r.width, h: r.height
                            });
                        });
                        // 3. Template directory cards
                        document.querySelectorAll('.template-card, a.template-card, a[href^="#"]').forEach((el, idx) => {
                            let r = el.getBoundingClientRect();
                            items.push({
                                kind: 'template_card',
                                dest: el.getAttribute('href') || el.getAttribute('data-dest') || '',
                                index: idx,
                                x: r.x, y: r.y, w: r.width, h: r.height
                            });
                        });
                        return items;
                    })();
                    """
                    
                    webView.evaluateJavaScript(jsExtract) { res, _ in
                        if let items = res as? [[String: Any]] {
                            for item in items {
                                guard let kindStr = item["kind"] as? String,
                                      let x = item["x"] as? CGFloat,
                                      let y = item["y"] as? CGFloat,
                                      let w = item["w"] as? CGFloat,
                                      let h = item["h"] as? CGFloat,
                                      w > 0, h > 0 else { continue }
                                let dest = (item["dest"] as? String) ?? ""
                                let idx = (item["index"] as? Int) ?? 0
                                
                                let kind: ParsedHTMLLink.Kind
                                switch kindStr {
                                case "tab": kind = .tab
                                case "chapter_card": kind = .chapterCard
                                case "template_card": kind = .templateCard
                                default: continue
                                }
                                
                                // HTML top-down Y -> PDF CoreGraphics bottom-up Y
                                let pdfY = 1485.0 - (y + h)
                                let rect = CGRect(x: x, y: pdfY, width: w, height: h)
                                extractedLinks.append(ParsedHTMLLink(kind: kind, dest: dest, index: idx, rect: rect))
                            }
                        }
                        
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
                }
                webView.navigationDelegate = delegate
                webView.loadHTMLString(html, baseURL: templateDir)
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
            return RenderedComponent(pdfPage: page, links: extractedLinks)
        }
        
        progress(0.15, "Rendering master template components...")
        
        // Cache rendered master template components on demand
        var renderedComponentsCache: [String: RenderedComponent] = [:]
        
        let getRenderedComponent: (String, String) -> RenderedComponent? = { relPath, activeDest in
            let cacheKey = "\(relPath):\(activeDest)"
            if let cached = renderedComponentsCache[cacheKey] {
                return cached
            }
            let html = loadAndPrepareHTML(relPath, activeDest)
            guard !html.isEmpty else { return nil }
            if let comp = try? renderHTMLComponent(html: html) {
                renderedComponentsCache[cacheKey] = comp
                return comp
            }
            return nil
        }
        
        var totalLinks = 0
        let totalPages = options.totalPages
        
        // Chapter arrow targets: Subchapter covers on Pages 45, 57, 69, ...
        let arrowTargets = [45, 57, 69, 81, 93, 105, 117, 129, 141, 153, 165, 177]
        
        // Cache master sidebar tabs extracted from chapter_selection or full_grid
        var masterTabs: [ParsedHTMLLink] = []
        
        // 5. Assemble All Pages
        progress(0.30, "Assembling \(totalPages) interactive notebook pages...")
        
        for p in 1...totalPages {
            var box = mediaBox
            writeContext.beginPage(mediaBox: &box)
            writeContext.addDestination("page_\(p)" as CFString, at: CGPoint(x: 0, y: box.height))
            
            // Determine active destination tab for page p
            let activeDest: String
            if p == 1 {
                activeDest = ""
            } else if p == 2 {
                activeDest = "home"
            } else if p >= 3 && p <= 14 {
                activeDest = "ch\(p - 2)"
            } else if p >= 15 && p <= 44 {
                activeDest = "templates"
            } else {
                let chIdx = min(12, max(1, ((p - 45) / 12) + 1))
                activeDest = "ch\(chIdx)"
            }
            
            // Resolve template for page dynamically
            let templateRelPath = options.templateMapping.resolveTemplate(forPage: p, arrowTargets: arrowTargets)
            if let comp = getRenderedComponent(templateRelPath, activeDest) {
                writeContext.drawPDFPage(comp.pdfPage)
                
                if masterTabs.isEmpty {
                    let tabs = comp.links.filter { $0.kind == .tab }
                    if tabs.count >= 14 {
                        masterTabs = tabs
                    }
                }
                
                let pageTabs = comp.links.filter { $0.kind == .tab }
                let activeTabs = pageTabs.isEmpty ? masterTabs : pageTabs
                
                // Inject Navigation Tabs on Pages 2..totalPages
                if p >= 2 {
                    for tab in activeTabs {
                        let targetPage: Int
                        if tab.dest == "home" {
                            targetPage = 2
                        } else if tab.dest == "templates" {
                            targetPage = 15
                        } else if tab.dest.hasPrefix("ch") {
                            let chNum = Int(tab.dest.dropFirst(2)) ?? 1
                            targetPage = chNum + 2 // Pages 3..14
                        } else {
                            targetPage = 2
                        }
                        
                        if targetPage <= totalPages {
                            writeContext.setDestination("page_\(targetPage)" as CFString, for: tab.rect)
                            totalLinks += 1
                        }
                    }
                }
                
                // Page 2: Chapter Selection Cards (Jump to Subchapter Sections 45, 57, 69...)
                if p == 2 {
                    let cards = comp.links.filter { $0.kind == .chapterCard }
                    for card in cards {
                        let chNum = Int(card.dest.dropFirst(2)) ?? (card.index + 1)
                        if chNum >= 1 && chNum <= arrowTargets.count {
                            let target = arrowTargets[chNum - 1]
                            if target <= totalPages {
                                writeContext.setDestination("page_\(target)" as CFString, for: card.rect)
                                totalLinks += 1
                                
                                // Render visual arrow indicator if configured
                                if options.chapterNavSettings.isEnabled && options.chapterNavSettings.renderVisualIndicator {
                                    let arrowW = options.chapterNavSettings.width
                                    let arrowH = options.chapterNavSettings.height
                                    let arrowX = card.rect.maxX - arrowW - 12.0
                                    let arrowY = card.rect.midY - arrowH / 2.0
                                    let arrowRect = CGRect(x: arrowX, y: arrowY, width: arrowW, height: arrowH)
                                    PDFLinkEngine.drawChapterIndicator(on: writeContext, in: arrowRect, settings: options.chapterNavSettings)
                                }
                            }
                        }
                    }
                }
                
                // Pages 3..14: Subchapter Selection Cards (Chapter Divider Pages)
                if p >= 3 && p <= 14 {
                    let currentCh = p - 2 // 1..12
                    let chBasePage = arrowTargets[currentCh - 1]
                    let cards = comp.links.filter { $0.kind == .chapterCard }
                    for (idx, card) in cards.enumerated() {
                        let target = chBasePage + idx // 12 subchapters within chapter
                        if target <= totalPages {
                            writeContext.setDestination("page_\(target)" as CFString, for: card.rect)
                            totalLinks += 1
                            
                            if options.chapterNavSettings.isEnabled && options.chapterNavSettings.renderVisualIndicator {
                                let arrowW = options.chapterNavSettings.width
                                let arrowH = options.chapterNavSettings.height
                                let arrowX = card.rect.maxX - arrowW - 12.0
                                let arrowY = card.rect.midY - arrowH / 2.0
                                let arrowRect = CGRect(x: arrowX, y: arrowY, width: arrowW, height: arrowH)
                                PDFLinkEngine.drawChapterIndicator(on: writeContext, in: arrowRect, settings: options.chapterNavSettings)
                            }
                        }
                    }
                }
                
                // Page 15: Template Directory Cards (Jump to Pages 16..44)
                if p == 15 {
                    let tCards = comp.links.filter { $0.kind == .templateCard }
                    for (idx, card) in tCards.enumerated() {
                        let target = 16 + idx
                        if target <= totalPages {
                            writeContext.setDestination("page_\(target)" as CFString, for: card.rect)
                            totalLinks += 1
                        }
                    }
                }
            }
            
            // Watermark stamping
            if shouldStampPage(p) {
                drawWatermarkOnContext(writeContext)
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
        
        // 7. Enforce Target File Size Compression
        let rawBytes = ((try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Double) ?? 0.0)
        var finalFileSizeMB = rawBytes / (1024.0 * 1024.0)
        
        if options.autoCompressPDF && options.targetMaxFileSizeMB < 50.0 && finalFileSizeMB > options.targetMaxFileSizeMB {
            progress(0.96, "Optimizing file size (\(String(format: "%.1f", finalFileSizeMB)) MB -> target ≤ \(String(format: "%.1f", options.targetMaxFileSizeMB)) MB)...")
            let compressedMB = PDFCompressor.compressPDFFile(
                inputPath: outPath,
                outputPath: outPath,
                targetMB: options.targetMaxFileSizeMB,
                progress: progress
            )
            finalFileSizeMB = compressedMB
        }
        
        let duration = Date().timeIntervalSince(startTime)
        progress(1.0, "Ready! Autonomous notebook generated with \(totalPages) pages and \(totalLinks) links (\(String(format: "%.2f", finalFileSizeMB)) MB) in \(String(format: "%.1f", duration))s.")
        return (outputPath: outPath, linksCount: totalLinks, duration: duration, fileSizeMB: finalFileSizeMB)
    }
}
