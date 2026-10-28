import SwiftUI

public enum NavigationTab: String, CaseIterable, Identifiable {
    case generator = "Generator"
    case templateStudio = "Template Studio (Zero Canva)"
    case aiChat = "AI Template Designer"
    case layout = "Layout & Sections"
    case watermark = "Watermark & Branding"
    case presets = "Theme Presets"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .generator: return "wand.and.stars"
        case .templateStudio: return "paintbrush.pointed.fill"
        case .aiChat: return "sparkles.bubble.fill"
        case .layout: return "rectangle.split.2x1"
        case .watermark: return "signature"
        case .presets: return "paintpalette.fill"
        }
    }
}

public struct MainAppView: View {
    @StateObject private var presetManager = PresetManager()
    @StateObject private var chatManager = AIChatManager()
    @State private var config = NotebookConfig.defaultLight
    @State private var selectedTab: NavigationTab = .generator
    @State private var showingResetAlert = false
    @State private var studioInitialTemplate: String? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                List(NavigationTab.allCases, selection: $selectedTab) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.iconName)
                            .padding(.vertical, 4)
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                // Sidebar Footer: Active Theme Badge & Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                        Text("Active Preset:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    Menu {
                        ForEach(presetManager.presets) { preset in
                            Button(action: { applyPreset(preset) }) {
                                HStack {
                                    Text(preset.name)
                                    if config.themeName == preset.name {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(config.themeName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    
                    HStack {
                        Text("mortalpages Studio v1.0")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(12)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            }
            .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
        } detail: {
            // Main Content Area
            Group {
                switch selectedTab {
                case .generator:
                    GeneratorView(config: $config)
                case .templateStudio:
                    TemplateStudioView(
                        notebookConfig: $config,
                        initialTemplatePath: studioInitialTemplate,
                        onOpenAIChat: { templatePath in
                            selectedTab = .aiChat
                        }
                    )
                case .aiChat:
                    AIChatView(chatManager: chatManager) { newTemplatePath in
                        studioInitialTemplate = newTemplatePath
                        selectedTab = .templateStudio
                    }
                case .layout:
                    LayoutConfigView(config: $config)
                case .watermark:
                    WatermarkConfigView(config: $config)
                case .presets:
                    ThemePresetsView(config: $config, presetManager: presetManager)
                }
            }
            .frame(minWidth: 700, minHeight: 560)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    // Quick Preset Selector in Toolbar
                    Picker("Theme", selection: Binding(
                        get: { config.themeName },
                        set: { newName in
                            if let found = presetManager.presets.first(where: { $0.name == newName }) {
                                applyPreset(found)
                            }
                        }
                    )) {
                        ForEach(presetManager.presets) { p in
                            Text(p.name).tag(p.name)
                        }
                    }
                    .frame(width: 140)
                    
                    Button(action: autoDetect) {
                        Label("Detect Files", systemImage: "sparkles")
                    }
                    .help("Auto-detect frontmost Keynote and Preview documents")
                    
                    Button(action: { showingResetAlert = true }) {
                        Label("Reset Defaults", systemImage: "arrow.counterclockwise")
                    }
                    .help("Reset configuration to Light Theme defaults")
                }
            }
        }
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("Reset to Default Settings?"),
                message: Text("This will reset all layout coordinates, watermark parameters, and section rules to factory Light Theme defaults."),
                primaryButton: .destructive(Text("Reset")) {
                    config = NotebookConfig.defaultLight
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func applyPreset(_ preset: ThemePreset) {
        let currentTarget = config.targetPDFPath
        let currentTemplate = config.templatePDFPath
        let currentOutput = config.outputPath
        
        var newConfig = preset.config
        // Preserve current file paths if already set
        if !currentTarget.isEmpty { newConfig.targetPDFPath = currentTarget }
        if !currentTemplate.isEmpty { newConfig.templatePDFPath = currentTemplate }
        if !currentOutput.isEmpty { newConfig.outputPath = currentOutput }
        
        config = newConfig
    }
    
    private func autoDetect() {
        if let previewPath = KeynoteBridge.getFrontPreviewPDFPath() {
            config.targetPDFPath = previewPath
        }
    }
}
