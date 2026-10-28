import Foundation

public struct ThemePreset: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var description: String
    public var config: NotebookConfig
    
    public init(id: UUID = UUID(), name: String, description: String, config: NotebookConfig) {
        self.id = id
        self.name = name
        self.description = description
        self.config = config
    }
}

public class PresetManager: ObservableObject {
    @Published public var presets: [ThemePreset] = []
    
    private let fileURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("mortalpages Studio")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("presets.json")
        loadPresets()
    }
    
    public func loadPresets() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([ThemePreset].self, from: data), !decoded.isEmpty {
            self.presets = decoded
            
            // Ensure Benita preset is present and up to date
            if let idx = self.presets.firstIndex(where: { $0.name.lowercased() == "benita" }) {
                self.presets[idx] = ThemePreset(
                    name: "Benita",
                    description: "Glass Portrait Light with embossed watermark & synchronized dual chapter hyperlinks (Numbers 1-12 & End-of-Line Chevrons)",
                    config: .benitaPreset
                )
            } else {
                self.presets.insert(ThemePreset(
                    name: "Benita",
                    description: "Glass Portrait Light with embossed watermark & synchronized dual chapter hyperlinks (Numbers 1-12 & End-of-Line Chevrons)",
                    config: .benitaPreset
                ), at: 0)
            }
            savePresets()
        } else {
            // Default initial presets
            var lightConfig = NotebookConfig.standardMortalpages
            lightConfig.themeName = "Glass Notebook (Light)"
            
            var darkConfig = NotebookConfig.standardMortalpages
            darkConfig.themeName = "Glass Notebook (Dark)"
            
            var beigeConfig = NotebookConfig.standardMortalpages
            beigeConfig.themeName = "Glass Notebook (Beige)"
            
            var pastelConfig = NotebookConfig.standardMortalpages
            pastelConfig.themeName = "Pretty Pastel"
            
            self.presets = [
                ThemePreset(name: "Benita", description: "Glass Portrait Light with embossed watermark & synchronized dual chapter hyperlinks (Numbers 1-12 & End-of-Line Chevrons)", config: .benitaPreset),
                ThemePreset(name: "Glass Notebook (Light)", description: "Glass style with light transparent tabs", config: lightConfig),
                ThemePreset(name: "Glass Notebook (Dark)", description: "Glass style with dark mode tabs", config: darkConfig),
                ThemePreset(name: "Glass Notebook (Beige)", description: "Minimalist warm beige palette", config: beigeConfig),
                ThemePreset(name: "Pretty Pastel", description: "Pastel color palette master", config: pastelConfig)
            ]
            savePresets()
        }
    }
    
    public func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            try? encoded.write(to: fileURL)
        }
    }
    
    public func addPreset(name: String, description: String, config: NotebookConfig) {
        _ = addOrUpdatePreset(name: name, description: description, config: config)
    }
    
    @discardableResult
    public func addOrUpdatePreset(name: String, description: String, config: NotebookConfig) -> ThemePreset {
        var c = config
        c.themeName = name
        let preset = ThemePreset(name: name, description: description, config: c)
        if let idx = presets.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        savePresets()
        return preset
    }
    
    public func deletePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        savePresets()
    }
}
