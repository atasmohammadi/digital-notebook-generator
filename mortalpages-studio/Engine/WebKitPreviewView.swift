import SwiftUI
import WebKit
import AppKit

public struct WebKitPreviewView: NSViewRepresentable {
    public let htmlContent: String
    public let baseURL: URL?
    public let customVariables: [String: String]
    public let zoomFactor: Double
    
    public init(htmlContent: String, baseURL: URL? = nil, customVariables: [String: String] = [:], zoomFactor: Double = 0.5) {
        self.htmlContent = htmlContent
        self.baseURL = baseURL
        self.customVariables = customVariables
        self.zoomFactor = zoomFactor
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        webView.pageZoom = zoomFactor
        
        context.coordinator.lastHTML = htmlContent
        context.coordinator.lastVariables = customVariables
        loadContent(in: webView)
        return webView
    }
    
    public func updateNSView(_ webView: WKWebView, context: Context) {
        webView.pageZoom = zoomFactor
        
        let htmlChanged = context.coordinator.lastHTML != htmlContent
        let varsChanged = context.coordinator.lastVariables != customVariables
        
        if htmlChanged {
            context.coordinator.lastHTML = htmlContent
            context.coordinator.lastVariables = customVariables
            loadContent(in: webView)
        } else if varsChanged {
            context.coordinator.lastVariables = customVariables
            applyCSSVariablesLive(in: webView)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator: NSObject {
        var lastHTML: String = ""
        var lastVariables: [String: String] = [:]
    }
    
    private func loadContent(in webView: WKWebView) {
        var finalHTML = htmlContent
        
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
