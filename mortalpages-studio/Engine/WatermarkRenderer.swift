import Foundation
import CoreGraphics
import AppKit
import SwiftUI

public class WatermarkRenderer {
    
    /// Available Popular Canva & Editorial Fonts
    public static let availableFonts: [String] = [
        "Avenir Next",
        "Helvetica Neue",
        "SF Pro Display",
        "Georgia",
        "Didot",
        "Baskerville",
        "Futura",
        "Playfair Display",
        "Palatino",
        "Optima",
        "Times New Roman",
        "Courier New",
        "Snell Roundhand",
        "Zapfino"
    ]
    
    public static let availableWeights: [String] = [
        "Light",
        "Regular",
        "Medium",
        "Semibold",
        "Bold",
        "Heavy"
    ]
    
    /// Renders the styled watermark into a crystal-sharp high-DPI image and CGImage for print-quality PDF output
    public static func renderImage(settings: WatermarkSettings, customDPI: Int? = nil) -> (image: NSImage, cgImage: CGImage?, containerSize: CGSize, drawnRect: CGRect)? {
        guard settings.mode == .customText, !settings.text.isEmpty else {
            return nil
        }
        
        let dpi = customDPI ?? max(150, settings.renderDPI)
        let scale: CGFloat = CGFloat(dpi) / 72.0
        
        // 1. Resolve Font with requested traits
        let baseFont: NSFont = NSFont(name: settings.fontFamily, size: settings.fontSize) ?? NSFont.systemFont(ofSize: settings.fontSize)
        
        var traits: NSFontDescriptor.SymbolicTraits = []
        if settings.isItalic { traits.insert(.italic) }
        
        let weight: NSFont.Weight
        switch settings.fontWeight {
        case "Light": weight = .light
        case "Medium": weight = .medium
        case "Semibold": weight = .semibold
        case "Bold": weight = .bold
        case "Heavy": weight = .heavy
        default: weight = .regular
        }
        
        let descriptor = baseFont.fontDescriptor.addingAttributes([
            .traits: [
                NSFontDescriptor.TraitKey.weight: weight
            ]
        ]).withSymbolicTraits(traits)
        
        let font = NSFont(descriptor: descriptor, size: settings.fontSize) ?? baseFont
        
        // 2. Resolve Text Attributes
        let textColor = NSColor(Color(hex: settings.textColorHex, alpha: settings.textColorAlpha))
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .kern: settings.letterSpacing as NSNumber
        ]
        
        let attrString = NSAttributedString(string: settings.text, attributes: attributes)
        let naturalTextSize = attrString.size()
        
        // 3. Container Dimensions
        let containerW: CGFloat = settings.containerAutoFit
            ? ceil(naturalTextSize.width + (settings.containerPaddingH * 2.0))
            : max(settings.containerWidth, naturalTextSize.width)
        let containerH: CGFloat = settings.containerAutoFit
            ? ceil(naturalTextSize.height + (settings.containerPaddingV * 2.0))
            : max(settings.containerHeight, naturalTextSize.height)
            
        // Extra margin for shadow, glow, and rotation bleed
        let shadowBleed: CGFloat = max(
            settings.glowEnabled ? (settings.glowRadius * 2.5) : 0.0,
            settings.shadowEnabled ? (abs(settings.shadowOffsetX) + settings.shadowBlur * 2.5) : 0.0,
            settings.doubleShadowEnabled ? (abs(settings.doubleShadowOffsetX) + settings.doubleShadowBlur * 2.5) : 0.0,
            16.0
        )
        
        let totalW = ceil(containerW + shadowBleed * 2.0)
        let totalH = ceil(containerH + shadowBleed * 2.0)
        
        // 4. Create Ultra High-DPI Bitmap Representation
        let pixelW = Int(ceil(totalW * scale))
        let pixelH = Int(ceil(totalH * scale))
        
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelW,
            pixelsHigh: pixelH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else { return nil }
        
        rep.size = NSSize(width: totalW, height: totalH)
        
        NSGraphicsContext.saveGraphicsState()
        guard let nctx = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = nctx
        let ctx = nctx.cgContext
        
        // Scale context by high-res scale factor
        ctx.scaleBy(x: scale, y: scale)
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setAllowsFontSmoothing(true)
        ctx.setShouldSmoothFonts(true)
        ctx.interpolationQuality = .high
        
        // 5. Container Geometry in point coordinates
        let containerRect = CGRect(x: shadowBleed, y: shadowBleed, width: containerW, height: containerH)
        let containerPath = CGPath(
            roundedRect: containerRect,
            cornerWidth: settings.containerCornerRadius,
            cornerHeight: settings.containerCornerRadius,
            transform: nil
        )
        
        // 6. Draw Container Background
        if settings.containerBgEnabled && settings.containerBgAlpha > 0 {
            let bgNSColor = NSColor(Color(hex: settings.containerBgColorHex, alpha: settings.containerBgAlpha))
            ctx.saveGState()
            ctx.addPath(containerPath)
            ctx.setFillColor(bgNSColor.cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }
        
        // 7. Draw Container Border
        if settings.containerBorderEnabled && settings.containerBorderWidth > 0 && settings.containerBorderAlpha > 0 {
            let borderNSColor = NSColor(Color(hex: settings.containerBorderColorHex, alpha: settings.containerBorderAlpha))
            ctx.saveGState()
            ctx.addPath(containerPath)
            ctx.setStrokeColor(borderNSColor.cgColor)
            ctx.setLineWidth(settings.containerBorderWidth)
            ctx.strokePath()
            ctx.restoreGState()
        }
        
        // Text drawing origin centered in container
        let textX = containerRect.minX + (containerW - naturalTextSize.width) / 2.0
        let textY = containerRect.minY + (containerH - naturalTextSize.height) / 2.0
        let textPoint = CGPoint(x: textX, y: textY)
        
        // 8. Glow Effect
        if settings.glowEnabled && settings.glowRadius > 0 && settings.glowColorAlpha > 0 {
            ctx.saveGState()
            let glowColor = NSColor(Color(hex: settings.glowColorHex, alpha: settings.glowColorAlpha)).cgColor
            ctx.setShadow(offset: .zero, blur: settings.glowRadius, color: glowColor)
            attrString.draw(at: textPoint)
            ctx.restoreGState()
        }
        
        // 9. Double Shadow (Secondary Ambient Shadow)
        if settings.doubleShadowEnabled && settings.doubleShadowColorAlpha > 0 {
            ctx.saveGState()
            let s2Color = NSColor(Color(hex: settings.doubleShadowColorHex, alpha: settings.doubleShadowColorAlpha)).cgColor
            ctx.setShadow(
                offset: CGSize(width: settings.doubleShadowOffsetX, height: -settings.doubleShadowOffsetY),
                blur: settings.doubleShadowBlur,
                color: s2Color
            )
            attrString.draw(at: textPoint)
            ctx.restoreGState()
        }
        
        // 10. Primary Drop Shadow
        if settings.shadowEnabled && settings.shadowColorAlpha > 0 {
            ctx.saveGState()
            let s1Color = NSColor(Color(hex: settings.shadowColorHex, alpha: settings.shadowColorAlpha)).cgColor
            ctx.setShadow(
                offset: CGSize(width: settings.shadowOffsetX, height: -settings.shadowOffsetY),
                blur: settings.shadowBlur,
                color: s1Color
            )
            attrString.draw(at: textPoint)
            ctx.restoreGState()
        }
        
        // 11. Emboss 3D Highlight & Depth
        if settings.embossEnabled {
            // Top highlight
            ctx.saveGState()
            let highlightAttr = NSMutableAttributedString(attributedString: attrString)
            let hlColor = NSColor(white: 1.0, alpha: min(1.0, 0.45 * settings.textColorAlpha))
            highlightAttr.addAttribute(.foregroundColor, value: hlColor, range: NSRange(location: 0, length: attrString.length))
            highlightAttr.draw(at: CGPoint(x: textPoint.x, y: textPoint.y + 0.8))
            ctx.restoreGState()
            
            // Bottom shadow
            ctx.saveGState()
            let shadowAttr = NSMutableAttributedString(attributedString: attrString)
            let shColor = NSColor(white: 0.0, alpha: min(1.0, 0.3 * settings.textColorAlpha))
            shadowAttr.addAttribute(.foregroundColor, value: shColor, range: NSRange(location: 0, length: attrString.length))
            shadowAttr.draw(at: CGPoint(x: textPoint.x, y: textPoint.y - 0.8))
            ctx.restoreGState()
        }
        
        // 12. Draw Base Typography
        ctx.saveGState()
        attrString.draw(at: textPoint)
        ctx.restoreGState()
        
        NSGraphicsContext.restoreGraphicsState()
        
        let highResImage = NSImage(size: NSSize(width: totalW, height: totalH))
        highResImage.addRepresentation(rep)
        
        // Calculate target location on page (1152 x 1485)
        let targetRect = settings.calculateTargetRect(containerW: containerW, containerH: containerH)
        let drawnRect = CGRect(
            x: targetRect.minX - shadowBleed,
            y: targetRect.minY - shadowBleed,
            width: totalW,
            height: totalH
        )
        
        return (
            image: highResImage,
            cgImage: rep.cgImage,
            containerSize: CGSize(width: containerW, height: containerH),
            drawnRect: drawnRect
        )
    }
}
