import Foundation

public class CodeBeautifier {
    
    /// Formats an HTML string with proper 2-space nesting and formatted <style> blocks
    public static func formatHTML(_ html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        // Fast tokenization of tags and content
        var formatted = ""
        var indentLevel = 0
        let indentStr = "  "
        
        let voidTags: Set<String> = [
            "area", "base", "br", "col", "embed", "hr", "img", "input",
            "link", "meta", "param", "source", "track", "wbr", "!doctype"
        ]
        
        let inlineTags: Set<String> = [
            "b", "i", "u", "span", "strong", "em", "a", "code", "small"
        ]
        
        // Split by < and >
        let lines = trimmed.components(separatedBy: .newlines)
        var insideStyle = false
        var styleBuffer: [String] = []
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            // Handle style tag toggle
            if line.contains("<style") {
                insideStyle = true
                formatted += String(repeating: indentStr, count: max(0, indentLevel)) + line + "\n"
                continue
            }
            if line.contains("</style>") {
                insideStyle = false
                let cssText = styleBuffer.joined(separator: "\n")
                styleBuffer.removeAll()
                let formattedCSS = formatCSS(cssText, baseIndentLevel: indentLevel + 1)
                if !formattedCSS.isEmpty {
                    formatted += formattedCSS + "\n"
                }
                formatted += String(repeating: indentStr, count: max(0, indentLevel)) + line + "\n"
                continue
            }
            
            if insideStyle {
                styleBuffer.append(line)
                continue
            }
            
            // Standard HTML line processing
            let isClosing = line.hasPrefix("</")
            let isDocType = line.lowercased().hasPrefix("<!doctype")
            let isComment = line.hasPrefix("<!--")
            let isSelfClosing = line.hasSuffix("/>") || isDocType
            
            // Detect tag name
            var tagName = ""
            if let start = line.range(of: "<")?.upperBound {
                let rest = line[start...]
                let clean = rest.trimmingCharacters(in: CharacterSet(charactersIn: "/!"))
                tagName = clean.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ">"))).first?.lowercased() ?? ""
            }
            
            let isVoid = voidTags.contains(tagName)
            
            if isClosing {
                indentLevel = max(0, indentLevel - 1)
            }
            
            let currentIndent = String(repeating: indentStr, count: max(0, indentLevel))
            formatted += currentIndent + line + "\n"
            
            if !isClosing && !isSelfClosing && !isVoid && !isComment && line.contains("<") && !line.contains("</\(tagName)>") {
                // If it opened a tag on this line that was not closed on the same line
                if !inlineTags.contains(tagName) {
                    indentLevel += 1
                }
            }
        }
        
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Formats CSS rules with consistent indentation
    public static func formatCSS(_ css: String, baseIndentLevel: Int = 0) -> String {
        let trimmed = css.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let indentStr = "  "
        let baseIndent = String(repeating: indentStr, count: max(0, baseIndentLevel))
        let ruleIndent = String(repeating: indentStr, count: max(0, baseIndentLevel + 1))
        
        var result = ""
        var insideBlock = false
        
        // Normalize braces and semicolons
        let clean = trimmed
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "{\n", with: " { ")
            .replacingOccurrences(of: "}", with: " } ")
        
        let lines = clean.components(separatedBy: .newlines)
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            if line.contains("{") {
                insideBlock = true
                let parts = line.components(separatedBy: "{")
                let selector = parts[0].trimmingCharacters(in: .whitespaces)
                result += baseIndent + selector + " {\n"
                
                if parts.count > 1 {
                    let inside = parts[1].replacingOccurrences(of: "}", with: "").trimmingCharacters(in: .whitespaces)
                    if !inside.isEmpty {
                        let declarations = inside.components(separatedBy: ";")
                        for decl in declarations {
                            let d = decl.trimmingCharacters(in: .whitespaces)
                            if !d.isEmpty {
                                result += ruleIndent + formatDeclaration(d) + ";\n"
                            }
                        }
                    }
                }
                
                if line.contains("}") {
                    insideBlock = false
                    result += baseIndent + "}\n"
                }
            } else if line.contains("}") {
                insideBlock = false
                result += baseIndent + "}\n\n"
            } else if insideBlock {
                let declarations = line.components(separatedBy: ";")
                for decl in declarations {
                    let d = decl.trimmingCharacters(in: .whitespaces)
                    if !d.isEmpty {
                        result += ruleIndent + formatDeclaration(d) + ";\n"
                    }
                }
            } else {
                result += baseIndent + line + "\n"
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func formatDeclaration(_ decl: String) -> String {
        let parts = decl.components(separatedBy: ":")
        guard parts.count >= 2 else { return decl }
        let prop = parts[0].trimmingCharacters(in: .whitespaces)
        let val = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
        return "\(prop): \(val)"
    }
}
