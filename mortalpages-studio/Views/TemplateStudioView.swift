import SwiftUI
import WebKit
import AppKit

public enum EditorMode: String, CaseIterable, Identifiable {
    case visual = "Visual Controls"
    case htmlCode = "HTML Source"
    case cssTokens = "CSS Tokens"
    
    public var id: String { self.rawValue }
}

public struct TemplateStudioView: View {
    @ObservedObject private var themeManager = HTMLThemeManager()
    @ObservedObject private var registry = TemplateRegistry.shared
    @Binding public var notebookConfig: NotebookConfig
    
    @State private var selectedRelativePath: String = "Navigation/template_list.html"
    @State private var editorMode: EditorMode = .visual
    @State private var rawHTMLContent: String = ""
    @State private var rawCSSTokens: String = ""
    @State private var previewZoom: Double = 0.42
    @State private var isCompiling = false
    @State private var compileProgress: Double = 0.0
    @State private var compileStatus: String = "Ready to generate"
    @State private var generatedPDFPath: String? = nil
    @State private var compileStats: String? = nil
    @State private var errorMessage: String? = nil
    @State private var showingNewThemeSheet = false
    @State private var newThemeName = ""
    @State private var newThemeDesc = ""
    
    public var initialTemplatePath: String? = nil
    public var onOpenAIChat: ((String) -> Void)? = nil
    
    private var templateBaseDir: URL {
        return registry.baseDirectory
    }
    
    private var currentTemplate: DynamicTemplate? {
        registry.templates.first(where: { $0.relativePath == selectedRelativePath })
    }
    
    public init(
        notebookConfig: Binding<NotebookConfig>,
        initialTemplatePath: String? = nil,
        onOpenAIChat: ((String) -> Void)? = nil
    ) {
        self._notebookConfig = notebookConfig
        self.initialTemplatePath = initialTemplatePath
        self.onOpenAIChat = onOpenAIChat
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // TOP HEADER: Theme & 1-Click Generator
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.accentColor)
                        Text("Zero-Canva Template Studio")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    Text("Design, customize, and compile 188-page digital journals natively.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Theme Switcher Dropdown
                HStack(spacing: 8) {
                    Text("Theme:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { themeManager.activeTheme.name },
                        set: { newName in
                            if let found = themeManager.themes.first(where: { $0.name == newName }) {
                                themeManager.activeTheme = found
                                notebookConfig.themeName = newName
                                loadActiveTemplateContent()
                            }
                        }
                    )) {
                        ForEach(themeManager.themes) { theme in
                            Text(theme.name).tag(theme.name)
                        }
                    }
                    .frame(width: 180)
                    
                    Button(action: { showingNewThemeSheet = true }) {
                        Label("New Theme...", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                // Ask AI Assistant Button
                if let openAI = onOpenAIChat {
                    Button(action: { openAI(selectedRelativePath) }) {
                        Label("Ask AI Designer", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                
                // 1-Click Autonomous Notebook Generator
                Button(action: startAutonomousGeneration) {
                    Label("⚡ Generate 188-Page Notebook", systemImage: "bolt.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(isCompiling)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 2-COLUMN MAIN WORKSPACE (No clipping, stable geometry)
            HStack(spacing: 0) {
                // LEFT COLUMN: Controls & Code Editor (Fixed width, never squished)
                VStack(spacing: 0) {
                    // 1. Dynamic Template Selector Bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Active Template:", systemImage: currentTemplate?.icon ?? "doc.text")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Spacer()
                            
                            Button(action: {
                                registry.refreshTemplates()
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderless)
                            .help("Refresh Template Library")
                        }
                        
                        Picker("", selection: Binding(
                            get: { selectedRelativePath },
                            set: { newItem in
                                selectedRelativePath = newItem
                                loadActiveTemplateContent()
                            }
                        )) {
                            // Group by Category
                            let grouped = Dictionary(grouping: registry.templates, by: { $0.category })
                            let categories = grouped.keys.sorted()
                            
                            ForEach(categories, id: \.self) { cat in
                                Section(header: Text(cat)) {
                                    ForEach(grouped[cat] ?? []) { item in
                                        HStack {
                                            Image(systemName: item.icon)
                                            Text(item.name)
                                        }
                                        .tag(item.relativePath)
                                    }
                                }
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // 2. Editor Mode Switcher (Visual vs HTML vs CSS)
                    HStack {
                        Picker("", selection: $editorMode) {
                            ForEach(EditorMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if editorMode != .visual {
                            Button(action: saveCodeAndHotReload) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .help("Save & Hot-Reload (⌘R)")
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // 3. Editor / Inspector Body
                    if editorMode == .visual {
                        visualCustomizerContent
                    } else if editorMode == .htmlCode {
                        IDECodeEditor(text: $rawHTMLContent, language: .html, onSave: saveCodeAndHotReload)
                    } else {
                        IDECodeEditor(text: $rawCSSTokens, language: .css, onSave: saveCodeAndHotReload)
                    }
                }
                .frame(width: 440)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // RIGHT COLUMN: Live WebKit Vector Preview (Expands flexibly)
                VStack(spacing: 0) {
                    // Preview Bar
                    HStack {
                        Label("Live Preview (1152 × 1485)", systemImage: "eye.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button(action: { loadActiveTemplateContent() }) {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        
                        Text("Zoom:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                        
                        Picker("", selection: $previewZoom) {
                            Text("35%").tag(0.35)
                            Text("42% (Fit)").tag(0.42)
                            Text("50%").tag(0.50)
                            Text("75%").tag(0.75)
                            Text("100%").tag(1.0)
                        }
                        .frame(width: 100)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // WebKit Preview View
                    ZStack {
                        Color(NSColor.underPageBackgroundColor)
                        
                        WebKitPreviewView(
                            htmlContent: rawHTMLContent,
                            baseURL: templateBaseDir.appendingPathComponent("Base"),
                            customVariables: themeManager.activeTheme.variables,
                            zoomFactor: previewZoom
                        )
                        .id("\(selectedRelativePath)-\(themeManager.activeTheme.id)")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 5)
                        .padding(14)
                    }
                    
                    // Bottom Compilation / Progress Panel
                    if isCompiling || generatedPDFPath != nil || errorMessage != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            if isCompiling {
                                ProgressView(value: compileProgress, total: 1.0)
                                    .progressViewStyle(.linear)
                            }
                            
                            HStack {
                                Image(systemName: errorMessage != nil ? "exclamationmark.triangle.fill" : (isCompiling ? "gearshape.2.fill" : "checkmark.circle.fill"))
                                    .foregroundColor(errorMessage != nil ? .red : (isCompiling ? .accentColor : .green))
                                
                                Text(compileStatus)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                if let stats = compileStats {
                                    Text(stats)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let path = generatedPDFPath {
                                    Button("Open PDF") {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    
                                    Button("Show in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewThemeSheet) {
            newThemeSheetView
        }
        .onAppear {
            registry.refreshTemplates()
            if let initial = initialTemplatePath, !initial.isEmpty {
                selectedRelativePath = initial
            }
            syncWithNotebookConfigTheme()
            loadActiveTemplateContent()
        }
        .onChange(of: notebookConfig.themeName) { _ in
            syncWithNotebookConfigTheme()
        }
    }
    
    // MARK: - Visual Customizer Content
    private var visualCustomizerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Page Background & Canvas
                GroupBox(label: Label("Page Canvas & Colors", systemImage: "paintpalette")) {
                    VStack(alignment: .leading, spacing: 12) {
                        colorRow(title: "Page Background", varKey: "--page-bg", defaultHex: "#FAF8F5")
                        colorRow(title: "Main Typography", varKey: "--text-main", defaultHex: "#3C3835")
                        colorRow(title: "Secondary Text", varKey: "--text-secondary", defaultHex: "#7A736E")
                        colorRow(title: "Accent / Active Color", varKey: "--accent-color", defaultHex: "#C28E75")
                    }
                    .padding(6)
                }
                
                // 2. Paper Patterns: Grid, Lines & Dots
                GroupBox(label: Label("Grids, Lined Rules & Dots", systemImage: "ruler")) {
                    VStack(alignment: .leading, spacing: 12) {
                        colorRow(title: "Grid Line Color", varKey: "--grid-color", defaultHex: "rgba(60, 56, 53, 0.07)")
                        sliderRow(title: "Grid Cell Size", varKey: "--grid-size", min: 14, max: 48, unit: "px", defaultVal: 24)
                        
                        Divider()
                        
                        colorRow(title: "Notebook Line Color", varKey: "--line-color", defaultHex: "rgba(60, 56, 53, 0.12)")
                        sliderRow(title: "Line Rule Spacing", varKey: "--line-spacing", min: 16, max: 48, unit: "px", defaultVal: 28)
                        
                        Divider()
                        
                        colorRow(title: "Dotted Matrix Color", varKey: "--dot-color", defaultHex: "rgba(60, 56, 53, 0.20)")
                        sliderRow(title: "Dot Pitch (Spacing)", varKey: "--dot-pitch", min: 12, max: 36, unit: "px", defaultVal: 20)
                    }
                    .padding(6)
                }
                
                // 3. Navigation Spine & Tabs
                GroupBox(label: Label("Navigation Tabs & Sidebar", systemImage: "sidebar.left")) {
                    VStack(alignment: .leading, spacing: 12) {
                        colorRow(title: "Tab Inactive Fill", varKey: "--tab-bg", defaultHex: "rgba(225, 220, 212, 0.35)")
                        colorRow(title: "Tab Inactive Text", varKey: "--tab-text", defaultHex: "#6A635E")
                        colorRow(title: "Tab Active Fill", varKey: "--tab-active-bg", defaultHex: "#E4C1B4")
                        colorRow(title: "Tab Active Text", varKey: "--tab-active-text", defaultHex: "#FFFFFF")
                    }
                    .padding(6)
                }
            }
            .padding(14)
        }
    }
    
    // MARK: - Helper Rows
    private func colorRow(title: String, varKey: String, defaultHex: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            
            let currentColor = Color(hex: themeManager.activeTheme.variables[varKey] ?? defaultHex)
            
            ColorPicker("", selection: Binding<Color>(
                get: { currentColor },
                set: { (newColor: Color) in
                    let hex = newColor.toHex() ?? defaultHex
                    themeManager.updateVariable(varKey, value: hex)
                }
            ))
            .labelsHidden()
            
            Text(themeManager.activeTheme.variables[varKey] ?? defaultHex)
                .font(.caption)
                .monospaced()
                .frame(width: 75, alignment: .trailing)
                .foregroundColor(.secondary)
        }
    }
    
    private func sliderRow(title: String, varKey: String, min: Double, max: Double, unit: String, defaultVal: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                let currentStr = themeManager.activeTheme.variables[varKey] ?? "\(Int(defaultVal))\(unit)"
                Text(currentStr)
                    .font(.caption)
                    .monospaced()
                    .foregroundColor(.secondary)
            }
            
            let valBinding = Binding<Double>(
                get: {
                    let raw = themeManager.activeTheme.variables[varKey] ?? "\(defaultVal)"
                    let digits = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    return Double(digits) ?? defaultVal
                },
                set: { newVal in
                    themeManager.updateVariable(varKey, value: "\(Int(newVal))\(unit)")
                }
            )
            
            Slider(value: valBinding, in: min...max, step: 1)
        }
    }
    
    // MARK: - New Theme Sheet
    private var newThemeSheetView: some View {
        VStack(spacing: 16) {
            Text("Create New Theme")
                .font(.headline)
            
            TextField("Theme Name (e.g. Earthy Sage)", text: $newThemeName)
                .textFieldStyle(.roundedBorder)
            
            TextField("Description", text: $newThemeDesc)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Spacer()
                Button("Cancel") { showingNewThemeSheet = false }
                Button("Create Theme") {
                    guard !newThemeName.isEmpty else { return }
                    themeManager.addTheme(name: newThemeName, description: newThemeDesc, baseTheme: themeManager.activeTheme)
                    newThemeName = ""
                    newThemeDesc = ""
                    showingNewThemeSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
    
    // MARK: - Content Loading & Compilation
    private func syncWithNotebookConfigTheme() {
        let name = notebookConfig.themeName.lowercased()
        if let match = themeManager.themes.first(where: { t in
            let tn = t.name.lowercased()
            if tn == name { return true }
            if (name.contains("dark") || name.contains("obsidian")) && (tn.contains("dark") || tn.contains("obsidian")) { return true }
            if (name.contains("beige") || name.contains("warm")) && (tn.contains("beige") || tn.contains("warm")) { return true }
            if name.contains("pastel") && tn.contains("pastel") { return true }
            if (name.contains("light") || name.contains("minimalist")) && (tn.contains("light") || tn.contains("minimalist")) { return true }
            return false
        }) {
            if themeManager.activeTheme.id != match.id {
                themeManager.activeTheme = match
                loadActiveTemplateContent()
            }
        }
    }
    
    private func loadActiveTemplateContent() {
        let fileURL = templateBaseDir.appendingPathComponent(selectedRelativePath)
        rawHTMLContent = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "<!-- Template not found at \(fileURL.path) -->"
        
        let cssURL = templateBaseDir.appendingPathComponent("Base/theme_variables.css")
        rawCSSTokens = (try? String(contentsOf: cssURL, encoding: .utf8)) ?? ""
    }
    
    private func saveCodeAndHotReload() {
        let fileURL = templateBaseDir.appendingPathComponent(selectedRelativePath)
        try? rawHTMLContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        let cssURL = templateBaseDir.appendingPathComponent("Base/theme_variables.css")
        try? rawCSSTokens.write(to: cssURL, atomically: true, encoding: .utf8)
        
        loadActiveTemplateContent()
    }
    
    private func startAutonomousGeneration() {
        isCompiling = true
        errorMessage = nil
        generatedPDFPath = nil
        compileProgress = 0.0
        compileStatus = "Preparing autonomous compiler..."
        
        let options = AutonomousNotebookCompiler.CompilerOptions(
            theme: themeManager.activeTheme,
            watermarkSettings: notebookConfig.watermarkSettings,
            templateMapping: notebookConfig.templateMapping,
            totalPages: 188
        )
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try AutonomousNotebookCompiler.compileNotebook(
                    options: options,
                    templateDir: self.templateBaseDir
                ) { p, msg in
                    DispatchQueue.main.async {
                        self.compileProgress = p
                        self.compileStatus = msg
                    }
                }
                
                DispatchQueue.main.async {
                    self.isCompiling = false
                    self.generatedPDFPath = result.outputPath
                    self.compileStats = "\(result.linksCount) links • \(String(format: "%.1f MB", result.fileSizeMB)) • \(String(format: "%.1f s", result.duration))"
                    self.compileStatus = "Finished successfully!"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCompiling = false
                    self.errorMessage = error.localizedDescription
                    self.compileStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
