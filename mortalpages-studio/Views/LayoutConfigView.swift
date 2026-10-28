import SwiftUI

public struct LayoutConfigView: View {
    @Binding public var config: NotebookConfig
    @ObservedObject private var registry = TemplateRegistry.shared
    
    @State private var showingAddOverrideSheet: Bool = false
    @State private var newOverrideRange: String = "16-20"
    @State private var newOverrideTemplate: String = "Lined/medium_line.html"
    @State private var newOverrideNote: String = ""
    @State private var expandedChapterOverrides: Bool = false
    
    public init(config: Binding<NotebookConfig>) {
        self._config = config
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Layout & Section Rules")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure how pages are structured, cropped, hyperlinked, and which templates are mapped to which pages.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // SECTION 1: MASTER PAGE & SECTION TEMPLATE MAPPING
                GroupBox(label: Label("Page & Section Template Mapping", systemImage: "rectangle.3.group.fill")) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Choose which HTML/CSS template (built-in or AI-generated) is drawn for each section of your 188-page digital notebook.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // 1. Structural Pages Mapping
                        VStack(spacing: 12) {
                            TemplatePicker("Cover Page (Page 1):", selection: $config.templateMapping.coverTemplate)
                            Divider()
                            TemplatePicker("Chapter Selection / Index (Page 2):", selection: $config.templateMapping.chapterSelectionTemplate)
                            Divider()
                            TemplatePicker("Chapter Cover Dividers (Pages 3–14):", selection: $config.templateMapping.chapterDividerTemplate)
                            Divider()
                            TemplatePicker("Template Library Index (Page 15):", selection: $config.templateMapping.templateListTemplate)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        Divider().padding(.vertical, 4)
                        
                        // 2. General Templates Section (Pages 16-44)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("General Templates Collection (Pages 16–44)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("These 29 pages rotate through the selected templates below:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                Button(action: addGeneralTemplate) {
                                    Label("Add Template", systemImage: "plus.circle.fill")
                                }
                                .controlSize(.small)
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(Array(config.templateMapping.generalTemplates.enumerated()), id: \.offset) { index, templatePath in
                                    HStack {
                                        Text("Slot \(index + 1):")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 50, alignment: .leading)
                                        
                                        let binding = Binding<String>(
                                            get: { config.templateMapping.generalTemplates[index] },
                                            set: { config.templateMapping.generalTemplates[index] = $0 }
                                        )
                                        TemplatePicker("", selection: binding)
                                        
                                        if config.templateMapping.generalTemplates.count > 1 {
                                            Button(action: {
                                                config.templateMapping.generalTemplates.remove(at: index)
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        // 3. Chapter Notes Pages (Pages 45-188)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Chapter Notes Section (Pages 45–188)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 12) {
                                TemplatePicker("Subchapter Header Covers (Pages 45, 57, 69...):", selection: $config.templateMapping.subchapterCoverTemplate)
                                Divider()
                                TemplatePicker("Default Chapter Notes Template:", selection: $config.templateMapping.defaultNotesTemplate)
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            // Disclosure Group for Individual Chapter Overrides (1-12)
                            DisclosureGroup(isExpanded: $expandedChapterOverrides) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Assign a specific template for individual chapters (e.g. Chapter 1 = Fitness, Chapter 2 = Financial Tracker, Chapter 3 = Cornell Notes):")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(1...12, id: \.self) { ch in
                                        let startP = 45 + (ch - 1) * 12
                                        let endP = startP + 11
                                        
                                        HStack {
                                            Text("Chapter \(ch) (Pages \(startP)–\(endP)):")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .frame(width: 170, alignment: .leading)
                                            
                                            Spacer()
                                            
                                            Picker("", selection: Binding<String>(
                                                get: { config.templateMapping.chapterOverrides[ch] ?? "" },
                                                set: { val in
                                                    if val.isEmpty {
                                                        config.templateMapping.chapterOverrides.removeValue(forKey: ch)
                                                    } else {
                                                        config.templateMapping.chapterOverrides[ch] = val
                                                    }
                                                }
                                            )) {
                                                Text("Default (\(templateName(for: config.templateMapping.defaultNotesTemplate)))").tag("")
                                                Divider()
                                                ForEach(registry.templates) { t in
                                                    Text(t.name).tag(t.relativePath)
                                                }
                                            }
                                            .labelsHidden()
                                            .frame(width: 220)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding(.top, 6)
                            } label: {
                                HStack {
                                    Text("Individual Chapter Overrides (Chapters 1–12)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    let count = config.templateMapping.chapterOverrides.count
                                    Text(count > 0 ? "\(count) chapters customized" : "All chapters use default")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        // 4. Custom Page Overrides (Arbitrary Page Ranges)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Custom Page Rules & Overrides")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Assign any custom or AI template to specific individual pages or page ranges (e.g. \"20-25\", \"50\"):")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                Button(action: { showingAddOverrideSheet = true }) {
                                    Label("Add Page Rule", systemImage: "plus")
                                }
                                .controlSize(.small)
                            }
                            
                            if config.templateMapping.customOverrides.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No custom page rules added yet.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                                .cornerRadius(6)
                            } else {
                                VStack(spacing: 6) {
                                    ForEach(config.templateMapping.customOverrides) { rule in
                                        HStack(spacing: 12) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "number.square.fill")
                                                    .foregroundColor(.accentColor)
                                                Text("Pages \(rule.pageRangeString):")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                            }
                                            .frame(width: 120, alignment: .leading)
                                            
                                            Text(templateName(for: rule.templateRelativePath))
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            if !rule.note.isEmpty {
                                                Text(rule.note)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Button(action: {
                                                config.templateMapping.customOverrides.removeAll(where: { $0.id == rule.id })
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                        .padding(8)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                
                // SECTION 2: Master Layout Page & Sidebar (Canva / Legacy)
                GroupBox(label: Label("Master Layout Page & Sidebar Navigation", systemImage: "sidebar.left")) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Exclude Master Layout Page from final customer PDF", isOn: $config.excludeMasterLayoutFromOutput)
                            .help("Omits Canva Page 2 from the customer PDF so Cover goes straight to Chapter Selection.")
                        
                        HStack {
                            Text("Master Layout Page Index in Canva:")
                            Spacer()
                            TextField("Page", value: $config.masterLayoutPageIndex, formatter: NumberFormatter())
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Sidebar Strip Crop Width:")
                            Spacer()
                            TextField("Width (pt)", value: $config.sidebarWidth, formatter: NumberFormatter())
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                            Text("pt (default 60)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }
                
                // SECTION 3: Chapter Selection Arrows (Page 2)
                GroupBox(label: Label("Chapter Selection Arrows (Page 2)", systemImage: "arrow.right.circle.fill")) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Enable 12 Chapter Arrow Hyperlinks", isOn: $config.hasChapterArrows)
                        
                        Toggle("Match Sidebar Tab Dimensions (42.2 x 101.5 pt)", isOn: $config.useSidebarSizeForArrows)
                            .disabled(!config.hasChapterArrows)
                        
                        if !config.useSidebarSizeForArrows {
                            HStack(spacing: 16) {
                                HStack {
                                    Text("Custom Width:")
                                    TextField("Width", value: $config.customArrowWidth, formatter: NumberFormatter())
                                        .frame(width: 60)
                                        .textFieldStyle(.roundedBorder)
                                }
                                HStack {
                                    Text("Custom Height:")
                                    TextField("Height", value: $config.customArrowHeight, formatter: NumberFormatter())
                                        .frame(width: 60)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding(.leading, 20)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Arrow Chapter Target Pages (Chapters 1 to 12):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(config.arrowTargets.map { String($0) }.joined(separator: ", "))
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
                        }
                    }
                    .padding(8)
                }
                
                // SECTION 4: Colored Chapter Tabs Range
                GroupBox(label: Label("Colored Chapter Tabs (Native Design)", systemImage: "paintpalette.fill")) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("These pages already have their own colored tabs drawn in Canva/HTML. The master sidebar overlay is automatically skipped on these pages, while keeping all sidebar tab hyperlinks active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Skip master sidebar on Final Pages:")
                            TextField("Start", value: $config.skipSidebarStartPage, formatter: NumberFormatter())
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                            Text("to")
                            TextField("End", value: $config.skipSidebarEndPage, formatter: NumberFormatter())
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                            Spacer()
                            Text("(default 3 to 14)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }
                
                // Reset Button
                HStack {
                    Spacer()
                    Button("Restore Mortalpages Defaults") {
                        let def = NotebookConfig.standardMortalpages
                        config.sidebarWidth = def.sidebarWidth
                        config.excludeMasterLayoutFromOutput = def.excludeMasterLayoutFromOutput
                        config.hasChapterArrows = def.hasChapterArrows
                        config.useSidebarSizeForArrows = def.useSidebarSizeForArrows
                        config.skipSidebarStartPage = def.skipSidebarStartPage
                        config.skipSidebarEndPage = def.skipSidebarEndPage
                        config.arrowTargets = def.arrowTargets
                        config.templateMapping = .defaultMapping
                    }
                    .buttonStyle(.link)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingAddOverrideSheet) {
            addOverrideModal
        }
    }
    
    // MARK: - Add Override Sheet
    private var addOverrideModal: some View {
        VStack(spacing: 16) {
            Text("Add Custom Page Template Rule")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Page Number or Range (e.g. \"20\" or \"16-24\"):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Page Range", text: $newOverrideRange)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Template:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TemplatePicker("", selection: $newOverrideTemplate)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Optional Note (e.g. \"Q1 Budgeting\"):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Note", text: $newOverrideNote)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Spacer()
                Button("Cancel") { showingAddOverrideSheet = false }
                Button("Add Rule") {
                    let rule = PageTemplateOverride(
                        pageRangeString: newOverrideRange,
                        templateRelativePath: newOverrideTemplate,
                        note: newOverrideNote
                    )
                    config.templateMapping.customOverrides.append(rule)
                    showingAddOverrideSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
    
    // MARK: - Helpers
    private func addGeneralTemplate() {
        if let first = registry.templates.first {
            config.templateMapping.generalTemplates.append(first.relativePath)
        }
    }
    
    private func templateName(for path: String) -> String {
        if let found = registry.templates.first(where: { $0.relativePath == path }) {
            return found.name
        }
        return path.components(separatedBy: "/").last?.replacingOccurrences(of: ".html", with: "").capitalized ?? path
    }
}
