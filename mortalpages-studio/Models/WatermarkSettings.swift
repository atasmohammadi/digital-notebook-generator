import Foundation
import CoreGraphics
import SwiftUI
import AppKit

public enum WatermarkSourceMode: String, Codable, CaseIterable, Identifiable {
    case extractedFromLayout = "Extract from Master Layout"
    case customText = "Custom Styled Text"
    case none = "None (Disable Watermark)"
    
    public var id: String { self.rawValue }
}

public enum WatermarkPagePosition: String, Codable, CaseIterable, Identifiable {
    case bottomCenter = "Bottom Center"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    case topCenter = "Top Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case centerDiagonal = "Center Diagonal (-35°)"
    case custom = "Custom Coordinates (X, Y)"
    
    public var id: String { self.rawValue }
}

public enum WatermarkPageScope: String, Codable, CaseIterable, Identifiable {
    case allPages = "All Pages (Including Cover)"
    case allExceptCover = "All Content Pages (Exclude Cover)"
    case contentOnly = "Notes & Content Only (Pages 15+)"
    
    public var id: String { self.rawValue }
}

public struct WatermarkSettings: Codable, Equatable {
    public var mode: WatermarkSourceMode
    public var scope: WatermarkPageScope
    
    // Extracted from layout coordinates (Canva Page 2)
    public var layoutCropX: CGFloat
    public var layoutCropY: CGFloat
    public var layoutCropW: CGFloat
    public var layoutCropH: CGFloat
    
    // Custom Text Watermark Content
    public var text: String
    public var fontFamily: String
    public var fontSize: CGFloat
    public var fontWeight: String // "Light", "Regular", "Medium", "Semibold", "Bold", "Heavy"
    public var isItalic: Bool
    public var letterSpacing: CGFloat
    
    // Resolution / Quality
    public var renderDPI: Int // 300, 450, 600
    
    // Text Color & Alpha
    public var textColorHex: String
    public var textColorAlpha: Double
    
    // Primary Shadow
    public var shadowEnabled: Bool
    public var shadowColorHex: String
    public var shadowColorAlpha: Double
    public var shadowOffsetX: CGFloat
    public var shadowOffsetY: CGFloat
    public var shadowBlur: CGFloat
    
    // Double Shadow (Canva style secondary shadow)
    public var doubleShadowEnabled: Bool
    public var doubleShadowColorHex: String
    public var doubleShadowColorAlpha: Double
    public var doubleShadowOffsetX: CGFloat
    public var doubleShadowOffsetY: CGFloat
    public var doubleShadowBlur: CGFloat
    
    // Glow Effect
    public var glowEnabled: Bool
    public var glowColorHex: String
    public var glowColorAlpha: Double
    public var glowRadius: CGFloat
    
    // Emboss Effect
    public var embossEnabled: Bool
    
    // Container Settings
    public var containerAutoFit: Bool
    public var containerWidth: CGFloat
    public var containerHeight: CGFloat
    public var containerPaddingH: CGFloat
    public var containerPaddingV: CGFloat
    public var containerCornerRadius: CGFloat
    
    // Container Background
    public var containerBgEnabled: Bool
    public var containerBgColorHex: String
    public var containerBgAlpha: Double
    
    // Container Border
    public var containerBorderEnabled: Bool
    public var containerBorderColorHex: String
    public var containerBorderAlpha: Double
    public var containerBorderWidth: CGFloat
    
    // Position & Orientation
    public var position: WatermarkPagePosition
    public var customX: CGFloat
    public var customY: CGFloat
    public var rotationDegrees: Double
    
    // Data Detector Suppression
    public var neutralizeDataDetectors: Bool
    
    public init(
        mode: WatermarkSourceMode = .extractedFromLayout,
        scope: WatermarkPageScope = .allPages,
        layoutCropX: CGFloat = 501.0,
        layoutCropY: CGFloat = 28.0,
        layoutCropW: CGFloat = 150.0,
        layoutCropH: CGFloat = 35.0,
        text: String = "mortalpages.com",
        fontFamily: String = "Avenir Next",
        fontSize: CGFloat = 13.0,
        fontWeight: String = "Regular",
        isItalic: Bool = false,
        letterSpacing: CGFloat = 2.0,
        renderDPI: Int = 300,
        textColorHex: String = "#6E6864",
        textColorAlpha: Double = 0.65,
        shadowEnabled: Bool = true,
        shadowColorHex: String = "#FFFFFF",
        shadowColorAlpha: Double = 0.8,
        shadowOffsetX: CGFloat = 0.0,
        shadowOffsetY: CGFloat = -1.0,
        shadowBlur: CGFloat = 1.0,
        doubleShadowEnabled: Bool = false,
        doubleShadowColorHex: String = "#000000",
        doubleShadowColorAlpha: Double = 0.15,
        doubleShadowOffsetX: CGFloat = 0.0,
        doubleShadowOffsetY: CGFloat = 1.0,
        doubleShadowBlur: CGFloat = 2.0,
        glowEnabled: Bool = false,
        glowColorHex: String = "#FFFFFF",
        glowColorAlpha: Double = 0.5,
        glowRadius: CGFloat = 4.0,
        embossEnabled: Bool = true,
        containerAutoFit: Bool = true,
        containerWidth: CGFloat = 160.0,
        containerHeight: CGFloat = 36.0,
        containerPaddingH: CGFloat = 16.0,
        containerPaddingV: CGFloat = 6.0,
        containerCornerRadius: CGFloat = 8.0,
        containerBgEnabled: Bool = false,
        containerBgColorHex: String = "#FFFFFF",
        containerBgAlpha: Double = 0.0,
        containerBorderEnabled: Bool = false,
        containerBorderColorHex: String = "#E0DCD6",
        containerBorderAlpha: Double = 0.5,
        containerBorderWidth: CGFloat = 1.0,
        position: WatermarkPagePosition = .bottomCenter,
        customX: CGFloat = 501.0,
        customY: CGFloat = 28.0,
        rotationDegrees: Double = 0.0,
        neutralizeDataDetectors: Bool = true
    ) {
        self.mode = mode
        self.scope = scope
        self.layoutCropX = layoutCropX
        self.layoutCropY = layoutCropY
        self.layoutCropW = layoutCropW
        self.layoutCropH = layoutCropH
        self.text = text
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.isItalic = isItalic
        self.letterSpacing = letterSpacing
        self.renderDPI = renderDPI
        self.textColorHex = textColorHex
        self.textColorAlpha = textColorAlpha
        self.shadowEnabled = shadowEnabled
        self.shadowColorHex = shadowColorHex
        self.shadowColorAlpha = shadowColorAlpha
        self.shadowOffsetX = shadowOffsetX
        self.shadowOffsetY = shadowOffsetY
        self.shadowBlur = shadowBlur
        self.doubleShadowEnabled = doubleShadowEnabled
        self.doubleShadowColorHex = doubleShadowColorHex
        self.doubleShadowColorAlpha = doubleShadowColorAlpha
        self.doubleShadowOffsetX = doubleShadowOffsetX
        self.doubleShadowOffsetY = doubleShadowOffsetY
        self.doubleShadowBlur = doubleShadowBlur
        self.glowEnabled = glowEnabled
        self.glowColorHex = glowColorHex
        self.glowColorAlpha = glowColorAlpha
        self.glowRadius = glowRadius
        self.embossEnabled = embossEnabled
        self.containerAutoFit = containerAutoFit
        self.containerWidth = containerWidth
        self.containerHeight = containerHeight
        self.containerPaddingH = containerPaddingH
        self.containerPaddingV = containerPaddingV
        self.containerCornerRadius = containerCornerRadius
        self.containerBgEnabled = containerBgEnabled
        self.containerBgColorHex = containerBgColorHex
        self.containerBgAlpha = containerBgAlpha
        self.containerBorderEnabled = containerBorderEnabled
        self.containerBorderColorHex = containerBorderColorHex
        self.containerBorderAlpha = containerBorderAlpha
        self.containerBorderWidth = containerBorderWidth
        self.position = position
        self.customX = customX
        self.customY = customY
        self.rotationDegrees = rotationDegrees
        self.neutralizeDataDetectors = neutralizeDataDetectors
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = (try? c.decode(WatermarkSourceMode.self, forKey: .mode)) ?? .extractedFromLayout
        self.scope = (try? c.decode(WatermarkPageScope.self, forKey: .scope)) ?? .allPages
        self.layoutCropX = (try? c.decode(CGFloat.self, forKey: .layoutCropX)) ?? 501.0
        self.layoutCropY = (try? c.decode(CGFloat.self, forKey: .layoutCropY)) ?? 28.0
        self.layoutCropW = (try? c.decode(CGFloat.self, forKey: .layoutCropW)) ?? 150.0
        self.layoutCropH = (try? c.decode(CGFloat.self, forKey: .layoutCropH)) ?? 35.0
        self.text = (try? c.decode(String.self, forKey: .text)) ?? "mortalpages.com"
        self.fontFamily = (try? c.decode(String.self, forKey: .fontFamily)) ?? "Avenir Next"
        self.fontSize = (try? c.decode(CGFloat.self, forKey: .fontSize)) ?? 13.0
        self.fontWeight = (try? c.decode(String.self, forKey: .fontWeight)) ?? "Regular"
        self.isItalic = (try? c.decode(Bool.self, forKey: .isItalic)) ?? false
        self.letterSpacing = (try? c.decode(CGFloat.self, forKey: .letterSpacing)) ?? 2.0
        self.renderDPI = (try? c.decode(Int.self, forKey: .renderDPI)) ?? 300
        self.textColorHex = (try? c.decode(String.self, forKey: .textColorHex)) ?? "#6E6864"
        self.textColorAlpha = (try? c.decode(Double.self, forKey: .textColorAlpha)) ?? 0.65
        self.shadowEnabled = (try? c.decode(Bool.self, forKey: .shadowEnabled)) ?? true
        self.shadowColorHex = (try? c.decode(String.self, forKey: .shadowColorHex)) ?? "#FFFFFF"
        self.shadowColorAlpha = (try? c.decode(Double.self, forKey: .shadowColorAlpha)) ?? 0.8
        self.shadowOffsetX = (try? c.decode(CGFloat.self, forKey: .shadowOffsetX)) ?? 0.0
        self.shadowOffsetY = (try? c.decode(CGFloat.self, forKey: .shadowOffsetY)) ?? -1.0
        self.shadowBlur = (try? c.decode(CGFloat.self, forKey: .shadowBlur)) ?? 1.0
        self.doubleShadowEnabled = (try? c.decode(Bool.self, forKey: .doubleShadowEnabled)) ?? false
        self.doubleShadowColorHex = (try? c.decode(String.self, forKey: .doubleShadowColorHex)) ?? "#000000"
        self.doubleShadowColorAlpha = (try? c.decode(Double.self, forKey: .doubleShadowColorAlpha)) ?? 0.15
        self.doubleShadowOffsetX = (try? c.decode(CGFloat.self, forKey: .doubleShadowOffsetX)) ?? 0.0
        self.doubleShadowOffsetY = (try? c.decode(CGFloat.self, forKey: .doubleShadowOffsetY)) ?? 1.0
        self.doubleShadowBlur = (try? c.decode(CGFloat.self, forKey: .doubleShadowBlur)) ?? 2.0
        self.glowEnabled = (try? c.decode(Bool.self, forKey: .glowEnabled)) ?? false
        self.glowColorHex = (try? c.decode(String.self, forKey: .glowColorHex)) ?? "#FFFFFF"
        self.glowColorAlpha = (try? c.decode(Double.self, forKey: .glowColorAlpha)) ?? 0.5
        self.glowRadius = (try? c.decode(CGFloat.self, forKey: .glowRadius)) ?? 4.0
        self.embossEnabled = (try? c.decode(Bool.self, forKey: .embossEnabled)) ?? true
        self.containerAutoFit = (try? c.decode(Bool.self, forKey: .containerAutoFit)) ?? true
        self.containerWidth = (try? c.decode(CGFloat.self, forKey: .containerWidth)) ?? 160.0
        self.containerHeight = (try? c.decode(CGFloat.self, forKey: .containerHeight)) ?? 36.0
        self.containerPaddingH = (try? c.decode(CGFloat.self, forKey: .containerPaddingH)) ?? 16.0
        self.containerPaddingV = (try? c.decode(CGFloat.self, forKey: .containerPaddingV)) ?? 6.0
        self.containerCornerRadius = (try? c.decode(CGFloat.self, forKey: .containerCornerRadius)) ?? 8.0
        self.containerBgEnabled = (try? c.decode(Bool.self, forKey: .containerBgEnabled)) ?? false
        self.containerBgColorHex = (try? c.decode(String.self, forKey: .containerBgColorHex)) ?? "#FFFFFF"
        self.containerBgAlpha = (try? c.decode(Double.self, forKey: .containerBgAlpha)) ?? 0.0
        self.containerBorderEnabled = (try? c.decode(Bool.self, forKey: .containerBorderEnabled)) ?? false
        self.containerBorderColorHex = (try? c.decode(String.self, forKey: .containerBorderColorHex)) ?? "#E0DCD6"
        self.containerBorderAlpha = (try? c.decode(Double.self, forKey: .containerBorderAlpha)) ?? 0.5
        self.containerBorderWidth = (try? c.decode(CGFloat.self, forKey: .containerBorderWidth)) ?? 1.0
        self.position = (try? c.decode(WatermarkPagePosition.self, forKey: .position)) ?? .bottomCenter
        self.customX = (try? c.decode(CGFloat.self, forKey: .customX)) ?? 501.0
        self.customY = (try? c.decode(CGFloat.self, forKey: .customY)) ?? 28.0
        self.rotationDegrees = (try? c.decode(Double.self, forKey: .rotationDegrees)) ?? 0.0
        self.neutralizeDataDetectors = (try? c.decode(Bool.self, forKey: .neutralizeDataDetectors)) ?? true
    }
    
    public static var defaultSettings: WatermarkSettings {
        return WatermarkSettings()
    }
    
    /// Calculate exact bounding rectangle for 1152 x 1485 page
    public func calculateTargetRect(containerW: CGFloat, containerH: CGFloat, pageWidth: CGFloat = 1152, pageHeight: CGFloat = 1485) -> CGRect {
        switch position {
        case .bottomCenter:
            let x = (pageWidth - containerW) / 2.0
            return CGRect(x: x, y: 28.0, width: containerW, height: containerH)
        case .bottomLeft:
            return CGRect(x: 80.0, y: 28.0, width: containerW, height: containerH)
        case .bottomRight:
            return CGRect(x: pageWidth - containerW - 60.0, y: 28.0, width: containerW, height: containerH)
        case .topCenter:
            let x = (pageWidth - containerW) / 2.0
            return CGRect(x: x, y: pageHeight - containerH - 35.0, width: containerW, height: containerH)
        case .topLeft:
            return CGRect(x: 80.0, y: pageHeight - containerH - 35.0, width: containerW, height: containerH)
        case .topRight:
            return CGRect(x: pageWidth - containerW - 60.0, y: pageHeight - containerH - 35.0, width: containerW, height: containerH)
        case .centerDiagonal:
            let x = (pageWidth - containerW) / 2.0
            let y = (pageHeight - containerH) / 2.0
            return CGRect(x: x, y: y, width: containerW, height: containerH)
        case .custom:
            return CGRect(x: customX, y: customY, width: containerW, height: containerH)
        }
    }
}

// MARK: - Color Conversion Helpers
public extension Color {
    init(hex: String, alpha: Double = 1.0) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: alpha
        )
    }
    
    public func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB) else { return nil }
        let r = Float(components.redComponent)
        let g = Float(components.greenComponent)
        let b = Float(components.blueComponent)
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
