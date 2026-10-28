import SwiftUI

public struct ThemePresetsView: View {
    @Binding public var config: NotebookConfig
    @ObservedObject public var presetManager: PresetManager
    
    @State private var showingAddSheet = false
    @State private var newPresetName = ""
    @State private var newPresetDescription = ""
    @State private var selectedPresetId: UUID?
    
    public init(config: Binding<NotebookConfig>, presetManager: PresetManager) {
        self._config = config
        self.presetManager = presetManager
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Theme Presets Manager")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Save and switch between different notebook themes in 1 click.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Label("Save Current as Preset...", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                GuideCallout(
                    title: "Unified Aesthetic Design Systems",
                    whatItDoes: "Saves and instantly swaps the entire design language of your digital notebook in a single click.",
                    howItWorks: "• Preset Bundling: Each preset packages all CSS variables and design tokens together: page paper background (#FAF8F5 cream), text contrast, grid colors and cell sizes (5mm), college-ruled lines, dotted matrix pitch and radius, and active/inactive sidebar navigation tabs.\n• Hot-Reload & PDF Sync: Applying a theme immediately updates live WebKit rendering in Template Studio and configures styling parameters for PDF export.",
                    proTip: "Design a unique palette in Template Studio, then click 'Save Current as Preset' to keep it in your permanent design library.",
                    icon: "paintpalette.fill",
                    tintColor: .indigo,
                    isExpanded: false
                )
            }
            
            Divider()
            
            // Preset List
            List(selection: $selectedPresetId) {
                ForEach(presetManager.presets) { preset in
                    HStack(spacing: 16) {
                        Image(systemName: "book.closed.fill")
                            .font(.title2)
                            .foregroundColor(config.themeName == preset.name ? .accentColor : .secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(preset.name)
                                    .font(.headline)
                                if config.themeName == preset.name {
                                    Text("ACTIVE")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            Text(preset.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Apply Theme") {
                            applyPreset(preset)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(config.themeName == preset.name)
                    }
                    .padding(.vertical, 6)
                    .tag(preset.id)
                }
                .onDelete(perform: presetManager.deletePreset)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .padding(24)
        .sheet(isPresented: $showingAddSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Save Current Configuration as Preset")
                    .font(.headline)
                
                TextField("Theme Name (e.g. Autumn Vintage, Glass Mocha)", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Short Description", text: $newPresetDescription)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Button("Cancel") {
                        showingAddSheet = false
                        newPresetName = ""
                        newPresetDescription = ""
                    }
                    Spacer()
                    Button("Save Preset") {
                        if !newPresetName.isEmpty {
                            presetManager.addPreset(name: newPresetName, description: newPresetDescription, config: config)
                            showingAddSheet = false
                            newPresetName = ""
                            newPresetDescription = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPresetName.isEmpty)
                }
            }
            .padding()
            .frame(width: 420)
        }
    }
    
    private func applyPreset(_ preset: ThemePreset) {
        var newConfig = preset.config
        // Preserve target paths if already set by user
        if !config.targetPDFPath.isEmpty {
            newConfig.targetPDFPath = config.targetPDFPath
        }
        self.config = newConfig
    }
}
