import Foundation
import AppKit

public enum CodeLanguage {
    case html
    case css
}

public class SyntaxHighlighter {
    
    // Theme Colors (VS Code / Xcode Pro Palette)
    public static let tagColor = NSColor(calibratedRed: 0.34, green: 0.61, blue: 0.84, alpha: 1.0)      // #569CD6
    public static let attributeColor = NSColor(calibratedRed: 0.61, green: 0.86, blue: 0.99, alpha: 1.0)// #9CDCFE
    public static let stringColor = NSColor(calibratedRed: 0.81, green: 0.57, blue: 0.47, alpha: 1.0)   // #CE9178
    public static let commentColor = NSColor(calibratedRed: 0.42, green: 0.60, blue: 0.33, alpha: 1.0)  // #6A9955
    public static let selectorColor = NSColor(calibratedRed: 0.84, green: 0.73, blue: 0.49, alpha: 1.0) // #D7BA7D
    public static let propertyColor = NSColor(calibratedRed: 0.61, green: 0.86, blue: 0.99, alpha: 1.0) // #9CDCFE
    public static let variableColor = NSColor(calibratedRed: 0.77, green: 0.52, blue: 0.75, alpha: 1.0) // #C586C0
    public static let numberColor = NSColor(calibratedRed: 0.71, green: 0.81, blue: 0.66, alpha: 1.0)   // #B5CEA8
    public static let defaultColor = NSColor.labelColor
    
    public static let codeFont = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
    public static let boldCodeFont = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .semibold)
    
    // MARK: - HTML Highlighting Pre-compiled Regexes
    private static let htmlTagRegex = try? NSRegularExpression(pattern: "</?[a-zA-Z0-9\\-_!]+")
    private static let htmlTagEndRegex = try? NSRegularExpression(pattern: "/?>")
    private static let htmlAttrRegex = try? NSRegularExpression(pattern: "\\s+([a-zA-Z0-9\\-_:]+)(?=\\=)")
    private static let htmlStringRegex = try? NSRegularExpression(pattern: "\"[^\"]*\"|'[^']*'")
    private static let htmlCommentRegex = try? NSRegularExpression(pattern: "<!--[\\s\\S]*?-->")
    private static let htmlStyleBlockRegex = try? NSRegularExpression(pattern: "<style[\\s\\S]*?>([\\s\\S]*?)</style>", options: .caseInsensitive)

    // MARK: - CSS Highlighting Pre-compiled Regexes
    private static let cssSelectorRegex = try? NSRegularExpression(pattern: "(?m)^\\s*([.#:]?[a-zA-Z0-9\\-_*\\s,>+~:]+)(?=\\s*\\{)")
    private static let cssPropertyRegex = try? NSRegularExpression(pattern: "(?m)^\\s*([a-zA-Z0-9\\-_]+)(?=\\s*:)")
    private static let cssVariableRegex = try? NSRegularExpression(pattern: "--[a-zA-Z0-9\\-_]+")
    private static let cssNumberRegex = try? NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?(px|pt|em|rem|%|vh|vw|deg|s|ms|dpi)?\\b")
    private static let cssStringRegex = try? NSRegularExpression(pattern: "\"[^\"]*\"|'[^']*'")
    private static let cssCommentRegex = try? NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/")

    /// Highlights an attributed string in-place
    public static func highlight(attributedString: NSMutableAttributedString, language: CodeLanguage) {
        let string = attributedString.string
        let fullRange = NSRange(location: 0, length: string.utf16.count)
        
        // Reset base font and color
        attributedString.addAttributes([
            .font: codeFont,
            .foregroundColor: defaultColor
        ], range: fullRange)
        
        guard fullRange.length > 0 else { return }
        
        if language == .html {
            highlightHTML(in: attributedString, string: string, range: fullRange)
        } else {
            highlightCSS(in: attributedString, string: string, range: fullRange)
        }
    }
    
    // MARK: - HTML Highlighting
    private static func highlightHTML(in attr: NSMutableAttributedString, string: String, range: NSRange) {
        // 1. Tags: <tag ... > and </tag>
        if let regex = htmlTagRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: tagColor, range: match)
                attr.addAttribute(.font, value: boldCodeFont, range: match)
            }
        }
        if let regex = htmlTagEndRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: tagColor, range: match)
            }
        }
        
        // 2. Attributes: name=
        if let regex = htmlAttrRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: attributeColor, range: match)
            }
        }
        
        // 3. Attribute Strings: "..." or '...'
        if let regex = htmlStringRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: stringColor, range: match)
            }
        }
        
        // 4. Comments: <!-- ... -->
        if let regex = htmlCommentRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: commentColor, range: match)
            }
        }
        
        // 5. Embedded CSS in <style> ... </style>
        if let regex = htmlStyleBlockRegex {
            let matches = regex.matches(in: string, range: range)
            for m in matches where m.numberOfRanges >= 2 {
                let cssRange = m.range(at: 1)
                if cssRange.location != NSNotFound && cssRange.length > 0 {
                    highlightCSS(in: attr, string: string, range: cssRange)
                }
            }
        }
    }
    
    // MARK: - CSS Highlighting
    private static func highlightCSS(in attr: NSMutableAttributedString, string: String, range: NSRange) {
        // 1. CSS Selectors (before {)
        if let regex = cssSelectorRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: selectorColor, range: match)
                attr.addAttribute(.font, value: boldCodeFont, range: match)
            }
        }
        
        // 2. CSS Properties: prop:
        if let regex = cssPropertyRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: propertyColor, range: match)
            }
        }
        
        // 3. CSS Custom Variables: --variable-name
        if let regex = cssVariableRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: variableColor, range: match)
            }
        }
        
        // 4. CSS Numbers & Units: 12px, 1.5em, 100%, 72dpi
        if let regex = cssNumberRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: numberColor, range: match)
            }
        }
        
        // 5. CSS Strings
        if let regex = cssStringRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: stringColor, range: match)
            }
        }
        
        // 6. CSS Comments: /* ... */
        if let regex = cssCommentRegex {
            applyMatches(regex: regex, string: string, range: range) { match in
                attr.addAttribute(.foregroundColor, value: commentColor, range: match)
            }
        }
    }
    
    private static func applyMatches(regex: NSRegularExpression, string: String, range: NSRange, action: (NSRange) -> Void) {
        let matches = regex.matches(in: string, options: [], range: range)
        for match in matches {
            action(match.range)
        }
    }
}
