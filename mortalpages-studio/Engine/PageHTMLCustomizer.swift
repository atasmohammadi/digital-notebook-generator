import Foundation
import SwiftUI

public class PageHTMLCustomizer {
    
    /// Applies granular element styling and text customization from a PageConfigOverride onto an HTML template
    public static func customize(html: String, with override: PageConfigOverride) -> String {
        var result = html
        
        // 1. Text overrides: Page Title & Subtitle
        if !override.headerStyle.text.isEmpty {
            let titleRegex = try? NSRegularExpression(pattern: "<h1 class=\"page-title\">[^<]*</h1>", options: [])
            if let regex = titleRegex {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "<h1 class=\"page-title\">\(override.headerStyle.text)</h1>")
            }
        }
        
        if !override.headerStyle.subtitle.isEmpty {
            let subtitleRegex = try? NSRegularExpression(pattern: "<p class=\"page-subtitle\">[^<]*</p>", options: [])
            if let regex = subtitleRegex {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "<p class=\"page-subtitle\">\(override.headerStyle.subtitle)</p>")
            }
        }
        
        // Footer text override
        if !override.footerStyle.text.isEmpty {
            let footerRegex = try? NSRegularExpression(pattern: "<div class=\"watermark-plaque\">[^<]*</div>", options: [])
            if let regex = footerRegex {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "<div class=\"watermark-plaque\">\(override.footerStyle.text)</div>")
            }
        }
        
        // 2. Custom card labels
        for (id, link) in override.linkOverrides {
            if !link.customLabel.isEmpty && link.linkKind != "sidebar_tab" {
                // E.g. replace <span class="chapter-name">...</span> inside data-dest="id"
                let cardRegex = try? NSRegularExpression(pattern: "(<div class=\"chapter-card\"[^>]*data-dest=\"\(id)\"[^>]*>[\\s\\S]*?<span class=\"chapter-name\">)[^<]*(</span>)", options: [])
                if let regex = cardRegex {
                    let range = NSRange(location: 0, length: result.utf16.count)
                    result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1\(link.customLabel)$2")
                }
            }
        }
        
        // 3. Generate Injected CSS Override Block
        let hs = override.headerStyle
        let ss = override.sidebarStyle
        let cs = override.contentStyle
        let cards = override.cardStyle
        let fs = override.footerStyle
        
        let injectedCSS = """
        <style id="page-customizer-overrides">
        :root {
            /* Content Area Padding */
            --page-padding-top: \(cs.paddingTop)px !important;
            --page-padding-bottom: \(cs.paddingBottom)px !important;
            --page-padding-left: calc(\(ss.paddingRight > 0 ? ss.paddingRight : 60)px + \(cs.paddingLeft)px) !important;
            --page-padding-right: \(cs.paddingRight)px !important;
            --page-bg: \(cs.bgColorHex) !important;
            
            /* Sidebar Navigation */
            --sidebar-width: \(ss.paddingRight > 0 ? ss.paddingRight : 60)px !important;
            --tab-height: \(ss.paddingBottom > 0 ? ss.paddingBottom : 75)px !important;
            --tab-border-radius: \(ss.cornerRadius)px !important;
            --tab-bg: \(ss.bgColorHex) !important;
            --tab-border: \(ss.borderColorHex) !important;
            --tab-text: \(ss.textColorHex) !important;
            --tab-active-bg: \(ss.subtitleColorHex.isEmpty ? "#C28E75" : ss.subtitleColorHex) !important;
            --tab-active-text: #FFFFFF !important;
            
            /* Cards */
            --card-radius: \(cards.cornerRadius)px !important;
            --card-bg: \(cards.bgColorHex) !important;
            --card-border: \(cards.borderColorHex) !important;
            --card-border-width: \(cards.borderWidth)px !important;
            --card-pt: \(cards.paddingTop)px !important;
            --card-pb: \(cards.paddingBottom)px !important;
            --card-pl: \(cards.paddingLeft)px !important;
            --card-pr: \(cards.paddingRight)px !important;
            --card-gap-x: \(cards.spacing)px !important;
            --card-gap-y: \(cards.marginBottom > 0 ? cards.marginBottom : 24)px !important;
        }
        
        /* Header Overrides */
        .page-header {
            display: \(hs.isVisible ? "block" : "none") !important;
            padding-top: \(hs.paddingTop)px !important;
            padding-bottom: \(hs.paddingBottom)px !important;
            margin-bottom: \(hs.marginBottom > 0 ? hs.marginBottom : 24)px !important;
            text-align: \(hs.alignment) !important;
        }
        .page-title {
            font-family: "\(hs.fontFamily)", serif !important;
            font-size: \(hs.fontSize)px !important;
            font-weight: \(hs.fontWeight) !important;
            color: \(hs.textColorHex) !important;
            letter-spacing: \(hs.letterSpacing)px !important;
            text-transform: \(hs.textTransform) !important;
        }
        .page-subtitle {
            font-size: \(hs.subtitleFontSize)px !important;
            color: \(hs.subtitleColorHex) !important;
            margin-top: \(hs.spacing)px !important;
        }
        
        /* Sidebar Overrides */
        .sidebar {
            display: \(ss.isVisible ? "flex" : "none") !important;
            gap: \(ss.spacing)px !important;
            padding-top: \(ss.paddingTop > 0 ? ss.paddingTop : 20)px !important;
            padding-bottom: \(ss.paddingBottom > 0 ? ss.paddingBottom : 20)px !important;
        }
        .tab {
            font-size: \(ss.fontSize > 0 ? ss.fontSize : 13)px !important;
            box-shadow: 0 2px 6px rgba(0,0,0,\(ss.shadowOpacity)) !important;
        }
        
        /* Chapter & Subchapter Grid Cards */
        .chapter-grid {
            column-gap: \(cards.spacing)px !important;
            row-gap: \(cards.marginBottom > 0 ? cards.marginBottom : 24)px !important;
        }
        .chapter-card {
            padding: \(cards.paddingTop)px \(cards.paddingRight)px \(cards.paddingBottom)px \(cards.paddingLeft)px !important;
            border-radius: \(cards.cornerRadius)px !important;
            border-width: \(cards.borderWidth)px !important;
            border-color: \(cards.borderColorHex) !important;
            background: \(cards.bgColorHex) !important;
            opacity: \(cards.bgOpacity) !important;
            box-shadow: 0 4px \(cards.shadowBlur)px rgba(0, 0, 0, \(cards.shadowOpacity)) !important;
        }
        .chapter-name {
            font-size: \(cards.fontSize)px !important;
            font-weight: \(cards.fontWeight) !important;
            color: \(cards.textColorHex) !important;
        }
        
        /* Footer Overrides */
        .page-footer {
            display: \(fs.isVisible ? "flex" : "none") !important;
            margin-top: auto !important;
            padding-top: \(fs.paddingTop > 0 ? fs.paddingTop : 16)px !important;
            padding-bottom: \(fs.paddingBottom > 0 ? fs.paddingBottom : 8)px !important;
            justify-content: \(fs.alignment == "left" ? "flex-start" : (fs.alignment == "right" ? "flex-end" : "center")) !important;
        }
        .watermark-plaque {
            font-size: \(fs.fontSize)px !important;
            color: \(fs.textColorHex) !important;
            opacity: \(fs.bgOpacity) !important;
            background: \(fs.bgColorHex) !important;
            border-radius: \(fs.cornerRadius)px !important;
            padding: \(fs.marginTop > 0 ? fs.marginTop : 4)px \(fs.spacing > 0 ? fs.spacing : 12)px !important;
            border: \(fs.borderWidth)px solid \(fs.borderColorHex) !important;
        }
        
        \(override.customCSS)
        </style>
        """
        
        if result.contains("</head>") {
            return result.replacingOccurrences(of: "</head>", with: "\(injectedCSS)\n</head>")
        }
        return injectedCSS + result
    }
}
