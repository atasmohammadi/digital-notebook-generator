import Foundation
import SwiftUI

public struct DynamicTemplate: Identifiable, Equatable, Hashable {
    public var id: String { relativePath }
    public var name: String
    public var category: String
    public var relativePath: String
    public var icon: String
    public var isCustom: Bool
    
    public init(name: String, category: String, relativePath: String, icon: String = "doc.text", isCustom: Bool = false) {
        self.name = name
        self.category = category
        self.relativePath = relativePath
        self.icon = icon
        self.isCustom = isCustom
    }
}

public class TemplateRegistry: ObservableObject {
    public static let shared = TemplateRegistry()
    
    @Published public var templates: [DynamicTemplate] = []
    
    public var baseDirectory: URL {
        if let bundleDir = Bundle.main.resourceURL?.appendingPathComponent("Templates"),
           FileManager.default.fileExists(atPath: bundleDir.path) {
            return bundleDir
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Dev/scripts/mortalpages-studio/Templates")
    }
    
    public init() {
        refreshTemplates()
    }
    
    public func refreshTemplates() {
        var discovered: [DynamicTemplate] = []
        let fm = FileManager.default
        let base = baseDirectory
        
        let categories = [
            ("Navigation", "Navigation", "list.bullet.rectangle.portrait"),
            ("Base", "Structure", "sidebar.left"),
            ("Covers", "Covers", "book.closed"),
            ("Grids", "Grids", "grid"),
            ("Lined", "Lined", "text.alignleft"),
            ("Dotted", "Dotted", "circle.grid.3x3"),
            ("Planners", "Planners", "calendar"),
            ("Trackers", "Trackers", "target"),
            ("Custom", "AI & Custom", "sparkles")
        ]
        
        for (subDir, catName, defaultIcon) in categories {
            let dirURL = base.appendingPathComponent(subDir)
            guard let files = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil) else { continue }
            
            for file in files where file.pathExtension.lowercased() == "html" {
                let relPath = "\(subDir)/\(file.lastPathComponent)"
                let title = extractTitle(from: file) ?? file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ").capitalized
                
                var icon = defaultIcon
                if relPath.contains("template_list") { icon = "list.bullet.rectangle.portrait" }
                else if relPath.contains("chapter_selection") { icon = "square.grid.2x2" }
                else if relPath.contains("master_layout") { icon = "sidebar.left" }
                
                let t = DynamicTemplate(
                    name: title,
                    category: catName,
                    relativePath: relPath,
                    icon: icon,
                    isCustom: (subDir == "Custom")
                )
                discovered.append(t)
            }
        }
        
        DispatchQueue.main.async {
            self.templates = discovered.sorted { $0.category < $1.category || ($0.category == $1.category && $0.name < $1.name) }
        }
    }
    
    public func loadContent(for template: DynamicTemplate) -> String {
        let fileURL = baseDirectory.appendingPathComponent(template.relativePath)
        return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "<!-- Template not found -->"
    }
    
    public func saveCustomTemplate(name: String, htmlContent: String) -> DynamicTemplate? {
        let safeName = name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let fileName = "\(safeName).html"
        let customDir = baseDirectory.appendingPathComponent("Custom")
        try? FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
        
        let fileURL = customDir.appendingPathComponent(fileName)
        do {
            try htmlContent.write(to: fileURL, atomically: true, encoding: .utf8)
            refreshTemplates()
            let relPath = "Custom/\(fileName)"
            return DynamicTemplate(name: name, category: "AI & Custom", relativePath: relPath, icon: "sparkles", isCustom: true)
        } catch {
            return nil
        }
    }
    
    private func extractTitle(from fileURL: URL) -> String? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        if let start = content.range(of: "<title>"),
           let end = content.range(of: "</title>", range: start.upperBound..<content.endIndex) {
            let t = String(content[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return nil
    }
}
