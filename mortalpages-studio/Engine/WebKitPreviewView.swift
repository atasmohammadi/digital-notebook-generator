import SwiftUI
import WebKit
import AppKit

public struct WebKitPreviewView: NSViewRepresentable {
    public let htmlContent: String
    public let baseURL: URL?
    public let customVariables: [String: String]
    public let zoomFactor: Double
    public let pageKey: String
    
    public init(
        htmlContent: String,
        baseURL: URL? = nil,
        customVariables: [String: String] = [:],
        zoomFactor: Double = 0.5,
        pageKey: String = ""
    ) {
        self.htmlContent = htmlContent
        self.baseURL = baseURL
        self.customVariables = customVariables
        self.zoomFactor = zoomFactor
        self.pageKey = pageKey
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        webView.pageZoom = zoomFactor
        
        context.coordinator.lastPageKey = pageKey
        context.coordinator.lastHTML = htmlContent
        context.coordinator.lastVariables = customVariables
        context.coordinator.isLoaded = true
        loadContent(in: webView)
        return webView
    }
    
    public func updateNSView(_ webView: WKWebView, context: Context) {
        webView.pageZoom = zoomFactor
        
        let pageKeyChanged = !pageKey.isEmpty && context.coordinator.lastPageKey != pageKey
        let htmlChanged = context.coordinator.lastHTML != htmlContent
        let varsChanged = context.coordinator.lastVariables != customVariables
        
        if pageKeyChanged || !context.coordinator.isLoaded {
            context.coordinator.lastPageKey = pageKey
            context.coordinator.lastHTML = htmlContent
            context.coordinator.lastVariables = customVariables
            context.coordinator.isLoaded = true
            loadContent(in: webView)
        } else if htmlChanged {
            context.coordinator.lastHTML = htmlContent
            context.coordinator.lastVariables = customVariables
            applyFastDOMUpdate(in: webView)
        } else if varsChanged {
            context.coordinator.lastVariables = customVariables
            applyCSSVariablesLive(in: webView)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator: NSObject {
        var lastPageKey: String = ""
        var lastHTML: String = ""
        var lastVariables: [String: String] = [:]
        var isLoaded: Bool = false
    }
    
    private func applyFastDOMUpdate(in webView: WKWebView) {
        // Extract <style id="page-customizer-overrides">...</style> if present
        var styleCSS = ""
        if let startRange = htmlContent.range(of: "<style id=\"page-customizer-overrides\">"),
           let endRange = htmlContent.range(of: "</style>", range: startRange.upperBound..<htmlContent.endIndex) {
            styleCSS = String(htmlContent[startRange.upperBound..<endRange.lowerBound])
        }
        
        let title = extractTagText(from: htmlContent, tagClass: "page-title")
        let subtitle = extractTagText(from: htmlContent, tagClass: "page-subtitle")
        let plaque = extractTagText(from: htmlContent, tagClass: "watermark-plaque")
        
        let escapedCSS = styleCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        var js = "(function() {\n"
        if !styleCSS.isEmpty {
            js += """
            var st = document.getElementById('page-customizer-overrides');
            if (st) {
                st.textContent = '\(escapedCSS)';
            } else {
                st = document.createElement('style');
                st.id = 'page-customizer-overrides';
                st.textContent = '\(escapedCSS)';
                document.head.appendChild(st);
            }
            """
        }
        
        if let t = title {
            let escT = t.replacingOccurrences(of: "'", with: "\\'")
            js += "\nvar pt = document.querySelector('.page-title'); if (pt) pt.textContent = '\(escT)';"
        }
        if let s = subtitle {
            let escS = s.replacingOccurrences(of: "'", with: "\\'")
            js += "\nvar ps = document.querySelector('.page-subtitle'); if (ps) ps.textContent = '\(escS)';"
        }
        if let p = plaque {
            let escP = p.replacingOccurrences(of: "'", with: "\\'")
            js += "\nvar wp = document.querySelector('.watermark-plaque'); if (wp) wp.textContent = '\(escP)';"
        }
        
        js += "\n})();"
        
        webView.evaluateJavaScript(js) { _, error in
            if error != nil {
                self.loadContent(in: webView)
            }
        }
    }
    
    private func extractTagText(from html: String, tagClass: String) -> String? {
        let pattern = "<[^>]*class=\"[^\"]*\(tagClass)[^\"]*\"[^>]*>([^<]*)</[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: html.utf16.count)
        if let match = regex.firstMatch(in: html, options: [], range: range), match.numberOfRanges > 1 {
            let captureRange = match.range(at: 1)
            if let swiftRange = Range(captureRange, in: html) {
                return String(html[swiftRange])
            }
        }
        return nil
    }
    
    private func loadContent(in webView: WKWebView) {
        var finalHTML = htmlContent
        
        // Auto-inline base stylesheets if present to avoid WebKit sandbox / cross-directory blocks
        var baseCSS = ""
        if let base = baseURL {
            let candidates = [
                base.appendingPathComponent("../Base"),
                base.appendingPathComponent("Base"),
                base
            ]
            for candidate in candidates {
                let tURL = candidate.appendingPathComponent("theme_variables.css")
                let sURL = candidate.appendingPathComponent("styles.css")
                if FileManager.default.fileExists(atPath: tURL.path) && FileManager.default.fileExists(atPath: sURL.path) {
                    let tc = (try? String(contentsOf: tURL, encoding: .utf8)) ?? ""
                    let sc = (try? String(contentsOf: sURL, encoding: .utf8)) ?? ""
                    baseCSS = "\(tc)\n\(sc)\n"
                    break
                }
            }
        }
        if !baseCSS.isEmpty {
            finalHTML = finalHTML.replacingOccurrences(of: "<link rel=\"stylesheet\" href=\"../Base/theme_variables.css\">", with: "")
            finalHTML = finalHTML.replacingOccurrences(of: "<link rel=\"stylesheet\" href=\"../Base/styles.css\">", with: "")
            finalHTML = finalHTML.replacingOccurrences(of: "<link rel=\"stylesheet\" href=\"theme_variables.css\">", with: "")
            finalHTML = finalHTML.replacingOccurrences(of: "<link rel=\"stylesheet\" href=\"styles.css\">", with: "")
            let inlinedTag = "<style id='inlined-preview-base-css'>\n\(baseCSS)</style>"
            if finalHTML.contains("</head>") {
                finalHTML = finalHTML.replacingOccurrences(of: "</head>", with: "\(inlinedTag)\n</head>")
            } else {
                finalHTML = inlinedTag + finalHTML
            }
        }
        
        // Inject custom CSS variable overrides inside <head>
        if !customVariables.isEmpty {
            var cssRules = ":root {\n"
            for (key, val) in customVariables {
                cssRules += "  \(key): \(val) !important;\n"
            }
            cssRules += "}\n"
            
            let styleTag = "<style id='dynamic-theme-overrides'>\n\(cssRules)</style>"
            if finalHTML.contains("</head>") {
                finalHTML = finalHTML.replacingOccurrences(of: "</head>", with: "\(styleTag)\n</head>")
            } else {
                finalHTML = styleTag + finalHTML
            }
        }
        
        webView.loadHTMLString(finalHTML, baseURL: baseURL)
    }
    
    private func applyCSSVariablesLive(in webView: WKWebView) {
        guard !customVariables.isEmpty else { return }
        
        var cssRules = ":root {\n"
        for (key, val) in customVariables {
            cssRules += "  \(key): \(val) !important;\n"
        }
        cssRules += "}"
        
        let escapedCSS = cssRules
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        let inlineSetters = customVariables.map {
            "root.style.setProperty('\($0.key)', '\($0.value)', 'important');"
        }.joined(separator: "\n")
        
        let js = """
        (function() {
            var el = document.getElementById('dynamic-theme-overrides');
            if (el) {
                el.textContent = '\(escapedCSS)';
            } else {
                el = document.createElement('style');
                el.id = 'dynamic-theme-overrides';
                el.textContent = '\(escapedCSS)';
                document.head.appendChild(el);
            }
            var root = document.documentElement;
            \(inlineSetters)
            // Force WebKit to re-render background patterns and gradients immediately
            if (document.body) {
                var prev = document.body.style.display;
                document.body.style.display = 'none';
                document.body.offsetHeight; // trigger reflow
                document.body.style.display = prev;
            }
        })();
        """
        
        webView.evaluateJavaScript(js) { _, error in
            if error != nil {
                self.loadContent(in: webView)
            }
        }
    }
}
