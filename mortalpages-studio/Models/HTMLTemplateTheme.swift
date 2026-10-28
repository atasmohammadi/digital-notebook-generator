import Foundation
import SwiftUI

public struct HTMLTemplateTheme: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var description: String
    public var variables: [String: String]
    
    public init(id: UUID = UUID(), name: String, description: String, variables: [String: String]) {
        self.id = id
        self.name = name
        self.description = description
        self.variables = variables
    }
    
    public static var glassLight: HTMLTemplateTheme {
        return HTMLTemplateTheme(
            name: "Glass Minimalist (Light)",
            description: "Clean warm cream canvas with subtle glass tabs and warm accents",
            variables: [
                "--page-bg": "#FAF8F5",
                "--text-main": "#3C3835",
                "--text-secondary": "#7A736E",
                "--text-muted": "#A39B95",
                "--accent-color": "#C28E75",
                "--border-subtle": "#E8E3DC",
                "--border-medium": "#D5CEC5",
                "--tab-bg": "rgba(225, 220, 212, 0.35)",
                "--tab-border": "rgba(200, 195, 185, 0.45)",
                "--tab-text": "#6A635E",
                "--tab-active-bg": "#E4C1B4",
                "--tab-active-text": "#FFFFFF",
                "--grid-color": "rgba(60, 56, 53, 0.07)",
                "--grid-size": "24px",
                "--line-color": "rgba(60, 56, 53, 0.12)",
                "--line-spacing": "28px",
                "--dot-color": "rgba(60, 56, 53, 0.20)",
                "--dot-pitch": "20px",
                "--font-heading": "'Avenir Next', -apple-system, sans-serif"
            ]
        )
    }
    
    public static var obsidianDark: HTMLTemplateTheme {
        return HTMLTemplateTheme(
            name: "Obsidian Dark Mode",
            description: "Deep charcoal palette with glowing accents and high contrast",
            variables: [
                "--page-bg": "#1C1D21",
                "--text-main": "#E8E6E3",
                "--text-secondary": "#9E9A95",
                "--text-muted": "#686460",
                "--accent-color": "#7FA3C9",
                "--border-subtle": "#2B2D33",
                "--border-medium": "#3E414A",
                "--tab-bg": "rgba(45, 48, 56, 0.7)",
                "--tab-border": "rgba(70, 74, 85, 0.5)",
                "--tab-text": "#B0ACB6",
                "--tab-active-bg": "#7FA3C9",
                "--tab-active-text": "#1C1D21",
                "--grid-color": "rgba(255, 255, 255, 0.06)",
                "--grid-size": "24px",
                "--line-color": "rgba(255, 255, 255, 0.10)",
                "--line-spacing": "28px",
                "--dot-color": "rgba(255, 255, 255, 0.18)",
                "--dot-pitch": "20px",
                "--font-heading": "'Avenir Next', -apple-system, sans-serif"
            ]
        )
    }
    
    public static var warmBeige: HTMLTemplateTheme {
        return HTMLTemplateTheme(
            name: "Warm Earthy Beige",
            description: "Earth tone journal with warm terracotta and sage undertones",
            variables: [
                "--page-bg": "#EFE9DF",
                "--text-main": "#38312B",
                "--text-secondary": "#6E6359",
                "--text-muted": "#968A7D",
                "--accent-color": "#A66D57",
                "--border-subtle": "#DDD4C7",
                "--border-medium": "#C8BCAD",
                "--tab-bg": "rgba(215, 205, 192, 0.4)",
                "--tab-border": "rgba(185, 175, 160, 0.5)",
                "--tab-text": "#544A40",
                "--tab-active-bg": "#A66D57",
                "--tab-active-text": "#FFFFFF",
                "--grid-color": "rgba(56, 49, 43, 0.08)",
                "--grid-size": "24px",
                "--line-color": "rgba(56, 49, 43, 0.13)",
                "--line-spacing": "28px",
                "--dot-color": "rgba(56, 49, 43, 0.22)",
                "--dot-pitch": "20px",
                "--font-heading": "'Avenir Next', -apple-system, sans-serif"
            ]
        )
    }
    
    public static var prettyPastel: HTMLTemplateTheme {
        return HTMLTemplateTheme(
            name: "Pretty Pastel",
            description: "Soft rose and lilac tones with delicate accents",
            variables: [
                "--page-bg": "#FAF5F7",
                "--text-main": "#3D3539",
                "--text-secondary": "#7D6F76",
                "--text-muted": "#A89BA1",
                "--accent-color": "#D48BA8",
                "--border-subtle": "#EBDFE5",
                "--border-medium": "#D6C4CD",
                "--tab-bg": "rgba(235, 218, 226, 0.4)",
                "--tab-border": "rgba(210, 190, 200, 0.5)",
                "--tab-text": "#6E5B64",
                "--tab-active-bg": "#D48BA8",
                "--tab-active-text": "#FFFFFF",
                "--grid-color": "rgba(61, 53, 57, 0.07)",
                "--grid-size": "24px",
                "--line-color": "rgba(61, 53, 57, 0.11)",
                "--line-spacing": "28px",
                "--dot-color": "rgba(61, 53, 57, 0.19)",
                "--dot-pitch": "20px",
                "--font-heading": "'Avenir Next', -apple-system, sans-serif"
            ]
        )
    }
}

public class HTMLThemeManager: ObservableObject {
    @Published public var themes: [HTMLTemplateTheme] = []
    @Published public var activeTheme: HTMLTemplateTheme
    
    private let fileURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("mortalpages Studio")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("html_themes.json")
        
        let initialLight = HTMLTemplateTheme.glassLight
        self.activeTheme = initialLight
        loadThemes()
    }
    
    public func loadThemes() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([HTMLTemplateTheme].self, from: data), !decoded.isEmpty {
            self.themes = decoded
            if let first = decoded.first {
                self.activeTheme = first
            }
        } else {
            self.themes = [
                .glassLight,
                .obsidianDark,
                .warmBeige,
                .prettyPastel
            ]
            saveThemes()
        }
    }
    
    public func saveThemes() {
        if let encoded = try? JSONEncoder().encode(themes) {
            try? encoded.write(to: fileURL)
        }
    }
    
    public func addTheme(name: String, description: String, baseTheme: HTMLTemplateTheme) {
        var newTheme = baseTheme
        newTheme.id = UUID()
        newTheme.name = name
        newTheme.description = description
        themes.append(newTheme)
        activeTheme = newTheme
        saveThemes()
    }
    
    @discardableResult
    public func addOrUpdateTheme(name: String, description: String, variables: [String: String]) -> HTMLTemplateTheme {
        let newTheme = HTMLTemplateTheme(name: name, description: description, variables: variables)
        if let idx = themes.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
            themes[idx] = newTheme
        } else {
            themes.append(newTheme)
        }
        activeTheme = newTheme
        saveThemes()
        return newTheme
    }
    
    public func updateActiveThemeVariables(_ vars: [String: String]) {
        activeTheme.variables = vars
        if let idx = themes.firstIndex(where: { $0.id == activeTheme.id }) {
            themes[idx] = activeTheme
            saveThemes()
        }
    }
    
    public func updateVariable(_ key: String, value: String) {
        activeTheme.variables[key] = value
        if let idx = themes.firstIndex(where: { $0.id == activeTheme.id }) {
            themes[idx] = activeTheme
            saveThemes()
        }
    }
}
