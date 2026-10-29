import Foundation
import SwiftUI

/// Granular visual styling for an individual page element (padding, margin, typography, colors, borders)
public struct PageElementStyle: Codable, Equatable {
    // Spacing & Layout
    public var paddingTop: Double
    public var paddingBottom: Double
    public var paddingLeft: Double
    public var paddingRight: Double
    public var marginTop: Double
    public var marginBottom: Double
    public var spacing: Double
    
    // Typography & Content
    public var text: String
    public var subtitle: String
    public var fontSize: Double
    public var subtitleFontSize: Double
    public var fontWeight: String // "400", "500", "600", "700", "800"
    public var fontFamily: String // "Playfair Display", "Inter", "Georgia", "Monospace"
    public var textColorHex: String
    public var subtitleColorHex: String
    public var alignment: String // "left", "center", "right"
    public var letterSpacing: Double
    public var textTransform: String // "none", "uppercase", "capitalize"
    public var isVisible: Bool
    
    // Visual Canvas / Box Styling
    public var bgColorHex: String
    public var bgOpacity: Double
    public var borderColorHex: String
    public var borderWidth: Double
    public var cornerRadius: Double
    public var shadowBlur: Double
    public var shadowOpacity: Double
    
    public init(
        paddingTop: Double = 0,
        paddingBottom: Double = 0,
        paddingLeft: Double = 0,
        paddingRight: Double = 0,
        marginTop: Double = 0,
        marginBottom: Double = 0,
        spacing: Double = 16,
        text: String = "",
        subtitle: String = "",
        fontSize: Double = 16,
        subtitleFontSize: Double = 13,
        fontWeight: String = "600",
        fontFamily: String = "Playfair Display",
        textColorHex: String = "#2D2926",
        subtitleColorHex: String = "#8C827A",
        alignment: String = "left",
        letterSpacing: Double = 0.5,
        textTransform: String = "none",
        isVisible: Bool = true,
        bgColorHex: String = "#FFFFFF",
        bgOpacity: Double = 1.0,
        borderColorHex: String = "#E8E2D9",
        borderWidth: Double = 1.0,
        cornerRadius: Double = 8.0,
        shadowBlur: Double = 6.0,
        shadowOpacity: Double = 0.05
    ) {
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.paddingLeft = paddingLeft
        self.paddingRight = paddingRight
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.spacing = spacing
        self.text = text
        self.subtitle = subtitle
        self.fontSize = fontSize
        self.subtitleFontSize = subtitleFontSize
        self.fontWeight = fontWeight
        self.fontFamily = fontFamily
        self.textColorHex = textColorHex
        self.subtitleColorHex = subtitleColorHex
        self.alignment = alignment
        self.letterSpacing = letterSpacing
        self.textTransform = textTransform
        self.isVisible = isVisible
        self.bgColorHex = bgColorHex
        self.bgOpacity = bgOpacity
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.shadowBlur = shadowBlur
        self.shadowOpacity = shadowOpacity
    }
}

/// Represents a configurable link on a specific page
public struct PageLinkOverride: Identifiable, Codable, Equatable {
    public var id: String // e.g. "ch1", "card_1", "home", "templates"
    public var name: String // Display label e.g. "Chapter One Card"
    public var targetPage: Int // Destination page (1..188)
    public var customLabel: String // Optional text override
    public var isEnabled: Bool
    public var linkKind: String // "sidebar_tab", "chapter_card", "subchapter_card", "template_card"
    
    public init(
        id: String,
        name: String,
        targetPage: Int,
        customLabel: String = "",
        isEnabled: Bool = true,
        linkKind: String = "chapter_card"
    ) {
        self.id = id
        self.name = name
        self.targetPage = targetPage
        self.customLabel = customLabel
        self.isEnabled = isEnabled
        self.linkKind = linkKind
    }
}

/// Complete customization bundle for a single page
public struct PageConfigOverride: Identifiable, Codable, Equatable {
    public var id: Int { pageNumber }
    public var pageNumber: Int // 1..188
    
    // Component Styles
    public var headerStyle: PageElementStyle
    public var sidebarStyle: PageElementStyle
    public var contentStyle: PageElementStyle
    public var cardStyle: PageElementStyle
    public var footerStyle: PageElementStyle
    
    // Configurable Link Destination Overrides: [linkId: PageLinkOverride]
    public var linkOverrides: [String: PageLinkOverride]
    
    // Optional Custom CSS string
    public var customCSS: String
    
    public init(
        pageNumber: Int,
        headerStyle: PageElementStyle = PageElementStyle(fontSize: 28, fontWeight: "700", letterSpacing: 1.5, textTransform: "uppercase"),
        sidebarStyle: PageElementStyle = PageElementStyle(spacing: 8, cornerRadius: 8),
        contentStyle: PageElementStyle = PageElementStyle(paddingTop: 36, paddingBottom: 36, paddingLeft: 36, paddingRight: 36),
        cardStyle: PageElementStyle = PageElementStyle(paddingTop: 16, paddingBottom: 16, paddingLeft: 20, paddingRight: 20, cornerRadius: 10),
        footerStyle: PageElementStyle = PageElementStyle(text: "mortalpages.com", fontSize: 11, textColorHex: "#A09890", isVisible: true),
        linkOverrides: [String: PageLinkOverride] = [:],
        customCSS: String = ""
    ) {
        self.pageNumber = pageNumber
        self.headerStyle = headerStyle
        self.sidebarStyle = sidebarStyle
        self.contentStyle = contentStyle
        self.cardStyle = cardStyle
        self.footerStyle = footerStyle
        self.linkOverrides = linkOverrides
        self.customCSS = customCSS
    }
    
    /// Default configuration for a given page number based on book architecture
    public static func defaultForPage(_ pageNum: Int) -> PageConfigOverride {
        var override = PageConfigOverride(pageNumber: pageNum)
        
        if pageNum == 1 {
            override.headerStyle.text = "Digital Journal"
            override.headerStyle.subtitle = "Interactive Planner & Notebook"
            override.headerStyle.alignment = "center"
            override.sidebarStyle.isVisible = false
        } else if pageNum == 2 {
            override.headerStyle.text = "Chapter Selection"
            override.headerStyle.subtitle = "Select a Chapter to open its Subchapter Section"
            override.headerStyle.alignment = "left"
            
            // Default 12 chapter boxes routing to Pages 3..14
            for ch in 1...12 {
                let id = "ch\(ch)"
                let words = ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"]
                let name = "Chapter \(words[ch - 1]) Box"
                override.linkOverrides[id] = PageLinkOverride(
                    id: id,
                    name: name,
                    targetPage: ch + 2,
                    customLabel: "Chapter \(words[ch - 1])",
                    isEnabled: true,
                    linkKind: "chapter_card"
                )
            }
        } else if pageNum >= 3 && pageNum <= 14 {
            let currentCh = pageNum - 2
            let words = ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"]
            let word = words[currentCh - 1]
            override.headerStyle.text = "Chapter \(word)"
            override.headerStyle.subtitle = "Subchapter Directory • 12 Sections"
            
            let noteStarts = [45, 57, 69, 81, 93, 105, 117, 129, 141, 153, 165, 177]
            let base = noteStarts[currentCh - 1]
            for sec in 1...12 {
                let id = "sec\(sec)"
                override.linkOverrides[id] = PageLinkOverride(
                    id: id,
                    name: "Section \(currentCh).\(sec)",
                    targetPage: base + (sec - 1),
                    customLabel: "Section \(sec)",
                    isEnabled: true,
                    linkKind: "subchapter_card"
                )
            }
        } else if pageNum == 15 {
            override.headerStyle.text = "Template Directory"
            override.headerStyle.subtitle = "Select any layout to jump to template"
            
            // 29 template cards
            let cardNames = [
                "Full Grid", "Blank + Grid", "Grid + Blank", "Blank + ⅓ Grid", "⅔ Grid + Blank",
                "Spacious Line", "Medium Rule", "Narrow Rule", "Lined + Grid", "Grid + Lined",
                "Full Dotted", "Blank + Dotted", "Dotted + Blank", "Pure Blank",
                "Cal + Notes", "Full Calendar", "Monthly Focus", "Overview", "Daily Details", "Quarterly",
                "Day Blocks", "7 Columns", "Weekly Rows", "Grid + Cols", "Cols + Grid", "Rows + Grid", "Rows + Cal",
                "Yearly Matrix", "Progress Log"
            ]
            for (idx, name) in cardNames.enumerated() {
                let id = "template_\(idx)"
                override.linkOverrides[id] = PageLinkOverride(
                    id: id,
                    name: "\(name) Card",
                    targetPage: 16 + idx,
                    customLabel: name,
                    isEnabled: true,
                    linkKind: "template_card"
                )
            }
        } else if pageNum >= 16 && pageNum <= 44 {
            override.headerStyle.text = "Template Style"
            override.headerStyle.subtitle = "Reusable Master Page"
        } else {
            let chIdx = min(12, max(1, ((pageNum - 45) / 12) + 1))
            let words = ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"]
            let isCover = (pageNum - 45) % 12 == 0
            override.headerStyle.text = isCover ? "Chapter \(words[chIdx - 1]) Overview" : "Notes & Journal"
            override.headerStyle.subtitle = "Chapter \(chIdx) • Page \(pageNum)"
        }
        
        // Add sidebar tabs 1..14 default links for pages >= 2
        if pageNum >= 2 {
            override.linkOverrides["home"] = PageLinkOverride(id: "home", name: "Sidebar: Home Index", targetPage: 2, isEnabled: true, linkKind: "sidebar_tab")
            for ch in 1...12 {
                override.linkOverrides["ch\(ch)"] = PageLinkOverride(id: "ch\(ch)", name: "Sidebar: Chapter \(ch)", targetPage: ch + 2, isEnabled: true, linkKind: "sidebar_tab")
            }
            override.linkOverrides["templates"] = PageLinkOverride(id: "templates", name: "Sidebar: Template List", targetPage: 15, isEnabled: true, linkKind: "sidebar_tab")
        }
        
        return override
    }
}
