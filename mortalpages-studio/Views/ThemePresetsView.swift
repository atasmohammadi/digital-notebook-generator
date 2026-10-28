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
