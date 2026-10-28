import Foundation
import CoreGraphics
import SwiftUI

public struct ChapterNavIndicatorSettings: Codable, Equatable {
    // Master toggles
    public var isEnabled: Bool // End-of-line indicator toggle
    public var renderVisualIndicator: Bool // Draw visual pill + symbol on PDF vs invisible link hitbox
    
    // Symbol / Icon selection
    public enum IndicatorSymbol: String, Codable, CaseIterable {
        case chevron = "Chevron (>)"
        case arrow = "Arrow (→)"
        case doubleChevron = "Double Chevron (»)"
        case triangle = "Triangle (▶)"
        case dot = "Dot (•)"
        case custom = "Custom Symbol / Text"
    }
    public var symbolType: IndicatorSymbol
    public var customSymbolText: String
    
    // Symbol Appearance
    public var symbolColorHex: String
    public var symbolColorAlpha: Double
    public var fontSize: CGFloat
    public var fontWeight: String // "Regular", "Medium", "Semibold", "Bold"
    
    // Pill / Capsule Container Appearance
    public enum CapsuleStyle: String, Codable, CaseIterable {
        case glass = "Glass Pill (Embossed)"
        case solid = "Solid Fill"
        case outline = "Outline Only"
        case none = "None (Symbol Only)"
    }
    public var capsuleStyle: CapsuleStyle
    public var capsuleBgColorHex: String
    public var capsuleBgAlpha: Double
    public var capsuleBorderColorHex: String
    public var capsuleBorderAlpha: Double
    public var capsuleCornerRadius: CGFloat
    
    // Horizontal alignment and dimensions
    public var positionX: CGFloat // Default 804.4 pt
    public var width: CGFloat // Default 42.22 pt
    public var height: CGFloat // Default 101.51 pt
    
    // Left-side Number Capsule Hyperlink (Numbers 1..12)
    public var linkLeftNumberPill: Bool
    public var leftNumberX: CGFloat // Default 33.5 pt
    public var leftNumberWidth: CGFloat // Default 42.22 pt
    public var leftNumberHeight: CGFloat // Default 101.51 pt
    
    public init(
        isEnabled: Bool = true,
        renderVisualIndicator: Bool = false,
        symbolType: IndicatorSymbol = .chevron,
        customSymbolText: String = ">",
        symbolColorHex: String = "#6E6864",
        symbolColorAlpha: Double = 0.85,
        fontSize: CGFloat = 16,
        fontWeight: String = "Bold",
        capsuleStyle: CapsuleStyle = .glass,
        capsuleBgColorHex: String = "#FFFFFF",
        capsuleBgAlpha: Double = 0.65,
        capsuleBorderColorHex: String = "#E0DCD6",
        capsuleBorderAlpha: Double = 0.5,
        capsuleCornerRadius: CGFloat = 21.0,
        positionX: CGFloat = 804.4,
        width: CGFloat = 42.22,
        height: CGFloat = 101.51,
        linkLeftNumberPill: Bool = true,
        leftNumberX: CGFloat = 33.5,
        leftNumberWidth: CGFloat = 42.22,
        leftNumberHeight: CGFloat = 101.51
    ) {
        self.isEnabled = isEnabled
        self.renderVisualIndicator = renderVisualIndicator
        self.symbolType = symbolType
        self.customSymbolText = customSymbolText
        self.symbolColorHex = symbolColorHex
        self.symbolColorAlpha = symbolColorAlpha
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.capsuleStyle = capsuleStyle
        self.capsuleBgColorHex = capsuleBgColorHex
        self.capsuleBgAlpha = capsuleBgAlpha
        self.capsuleBorderColorHex = capsuleBorderColorHex
        self.capsuleBorderAlpha = capsuleBorderAlpha
        self.capsuleCornerRadius = capsuleCornerRadius
        self.positionX = positionX
        self.width = width
        self.height = height
        self.linkLeftNumberPill = linkLeftNumberPill
        self.leftNumberX = leftNumberX
        self.leftNumberWidth = leftNumberWidth
        self.leftNumberHeight = leftNumberHeight
    }
    
    public static var defaultSettings: ChapterNavIndicatorSettings {
        ChapterNavIndicatorSettings()
    }
    
    public var resolvedSymbolString: String {
        switch symbolType {
        case .chevron: return ">"
        case .arrow: return "→"
        case .doubleChevron: return "»"
        case .triangle: return "▶"
        case .dot: return "•"
        case .custom: return customSymbolText.isEmpty ? ">" : customSymbolText
        }
    }
}
