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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Layout & Section Rules")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure how pages 1 to 188 are partitioned, mapped to HTML/CSS templates, cropped, and hyperlinked across your digital notebook.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    GuideCallout(
                        title: "188-Page Notebook Architecture & Priority Cascade",
                        whatItDoes: "Defines the exact page structure and template mapping for all 188 pages of your digital journal.",
                        howItWorks: "When compiling pages, the engine resolves template assignments using a strict 4-tier priority cascade:\n1. Custom Page Rules (Highest priority: overrides any page or page range)\n2. Individual Chapter Overrides (Applies to specific chapters 1–12)\n3. General Templates Slot Rotation (Cycles round-robin through slots on Pages 16–44)\n4. Structural & Default Templates (Cover, Dividers, Index, and Default Note paper)",
                        proTip: "Changes saved here apply immediately to both real-time PDF generation and Keynote presentation sync.",
                        icon: "square.stack.3d.up.fill",
                        tintColor: .indigo,
                        isExpanded: false
                    )
                }
                
                Divider()
                
                // SECTION 1: MASTER PAGE & SECTION TEMPLATE MAPPING
                GroupBox(label: Label("Page & Section Template Mapping", systemImage: "rectangle.3.group.fill")) {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        // 1. Structural Pages Mapping
                        VStack(alignment: .leading, spacing: 10) {
                            GuideCallout(
                                title: "Structural Architecture (Pages 1–15)",
                                whatItDoes: "Establishes the fixed navigational skeleton of the notebook: Front Cover, Chapter Index, Chapter Divider pages, and the Template Library Directory.",
                                howItWorks: "• Cover Page (Page 1): Front presentation cover; master sidebar navigation is hidden.\n• Chapter Selection / Index (Page 2): 12 interactive chapter buttons linking directly to chapter start pages (45, 57, 69...).\n• Chapter Cover Dividers (Pages 3–14): Full-page tabbed dividers separating each chapter with native colored tabs.\n• Template Library Index (Page 15): Interactive visual catalog of note paper templates with clickable miniature preview cards.",
                                icon: "building.columns.fill",
                                tintColor: .blue,
                                isExpanded: false
                            )
                            
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
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        // 2. General Templates Section (Pages 16-44)
                        VStack(alignment: .leading, spacing: 10) {
                            GuideCallout(
                                title: "General Templates Collection (Pages 16–44)",
                                whatItDoes: "Pages 16 to 44 (29 consecutive pages) form the general templates showcase section. This section provides users with quick access to everyday note pages (Grid, Dotted paper, Lined paper, Habit trackers, etc.) right after the template directory without entering a specific chapter.",
                                howItWorks: "Round-Robin Slot Rotation: The compiler cycles continuously through each defined slot in order (Slot 1 → Slot 2 → Slot 3 → Slot 4 → Slot 1...). For example:\n• Page 16 = Slot 1\n• Page 17 = Slot 2\n• Page 18 = Slot 3\n• Page 19 = Slot 4\n• Page 20 = Slot 1 ... repeating all the way through Page 44.\nClick 'Add Template' to insert a new slot, or the trash icon to remove a slot. Slots cycle seamlessly across all 29 pages.",
                                proTip: "If you only define 1 slot, all 29 pages use that single template. If you define 2 slots (e.g. Blank + Grid), pages will alternate back and forth throughout the section.",
                                icon: "arrow.triangle.2.circlepath",
                                tintColor: .teal,
                                isExpanded: true
                            )
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Active Slots in Rotation")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("These 29 pages rotate through the defined slots below:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                Button(action: addGeneralTemplate) {
                                    Label("Add Template Slot", systemImage: "plus.circle.fill")
                                }
                                .controlSize(.small)
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(Array(config.templateMapping.generalTemplates.enumerated()), id: \.offset) { index, templatePath in
                                    HStack {
                                        Text("Slot \(index + 1):")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.accentColor)
                                            .frame(width: 55, alignment: .leading)
                                        
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
                            GuideCallout(
                                title: "Chapter Notes Section (Pages 45–188)",
                                whatItDoes: "The primary writing body containing 12 distinct chapters, with exactly 12 pages allocated per chapter (144 pages total: 12 chapters × 12 pages = 144 pages).",
                                howItWorks: "• Subchapter Header Covers: The entry page of each chapter (Pages 45, 57, 69, 81, 93, 105, 117, 129, 141, 153, 165, 177) renders the Subchapter Header template with the chapter title, index jump buttons, and overview metadata.\n• Default Chapter Notes Template: Stamped on the remaining 11 pages of every chapter (e.g. Pages 46–56 for Chapter 1, 58–68 for Chapter 2).\n• Individual Chapter Overrides (Chapters 1–12): Allows customizing specific chapters (e.g. Chapter 1 = Fitness Log, Chapter 2 = Expense Tracker, Chapter 3 = Cornell Notes) while keeping other chapters on the default note paper.",
                                proTip: "Subchapter header covers are preserved even when you set an individual chapter override.",
                                icon: "books.vertical.fill",
                                tintColor: .purple,
                                isExpanded: false
                            )
                            
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
                            GuideCallout(
                                title: "Custom Page Rules & Overrides",
                                whatItDoes: "Allows you to target any individual page or page range (e.g., '16-24', '50', '100-110') with a specific template.",
                                howItWorks: "Highest Compilation Priority: Custom page rules take absolute precedence over all other section mappings (General rotation, Chapter defaults, and Chapter overrides). If a page matches a custom rule, that template is rendered unconditionally.",
                                proTip: "Use custom page rules for special insert sections such as Quarterly Reviews, Goal Planners, or Year-at-a-Glance sheets.",
                                icon: "star.fill",
                                tintColor: .orange,
                                isExpanded: false
                            )
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Active Custom Page Rules")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Rules with highest priority override:")
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
                        GuideCallout(
                            title: "Sidebar Crop & Layout Extraction",
                            whatItDoes: "Controls how the persistent navigation strip is extracted from your Canva source file and stamped onto pages.",
                            howItWorks: "• Exclude Master Layout Page: When enabled, Canva Page 2 (the layout source) is excluded from the customer PDF so the document opens smoothly from Cover to Chapter Selection.\n• Master Layout Page Index: Specifies which page in your Canva PDF holds the master sidebar design (default: Page 2).\n• Sidebar Strip Crop Width: The width in points (default: 60pt) cropped from the right edge of the master layout to create the persistent navigation strip across all pages.",
                            icon: "crop",
                            tintColor: .teal,
                            isExpanded: false
                        )
                        
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
                
                // SECTION 3: Chapter Navigation & Arrow Indicators (Page 2)
                GroupBox(label: Label("Chapter Navigation & Arrow Indicators (Page 2)", systemImage: "arrow.right.circle.fill")) {
                    VStack(alignment: .leading, spacing: 16) {
                        GuideCallout(
                            title: "Page 2 Chapter Navigation & End-of-Line Arrow Customizer",
                            whatItDoes: "Customizes interactive navigation on Page 2, linking both the left-side chapter numbers (1–12) and the customizable end-of-line navigation chevrons/arrows to the same chapter start pages.",
                            howItWorks: "• Dual Synchronized Linking: Hyperlinks both the number pill on the left and the arrow on the right to Pages 45, 57, 69... in 12-page intervals.\n• Visual Rendering Toggle: Turn ON to render custom glass capsules and symbols directly onto the PDF. Turn OFF if your Canva artwork already has arrows drawn.\n• Full Customization: Customize symbol character (chevron, arrow, triangle, custom text), symbol color with hex inputs, capsule style (glass embossed, solid, outline, none), background colors, and sizing.",
                            icon: "arrow.right.circle.fill",
                            tintColor: .purple,
                            isExpanded: false
                        )
                        
                        // Main Toggles
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Enable Page 2 Chapter Navigation", isOn: $config.hasChapterArrows)
                                .fontWeight(.semibold)
                            
                            if config.hasChapterArrows {
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle("Link End-of-Line Navigation Indicators (to Pages 45, 57, 69...)", isOn: $config.chapterNavSettings.isEnabled)
                                    
                                    Toggle("Link Left-Side Chapter Numbers 1–12 (to Pages 45, 57, 69...)", isOn: $config.chapterNavSettings.linkLeftNumberPill)
                                    
                                    Toggle("Render Visual Arrow / Capsule onto PDF Page", isOn: $config.chapterNavSettings.renderVisualIndicator)
                                    Text("Turn ON if your Canva design does NOT already have arrows drawn. Leave OFF if your artwork already has arrows drawn (like Canva pre-rendered art).")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 20)
                                }
                                .padding(.leading, 12)
                            }
                        }
                        
                        if config.hasChapterArrows && config.chapterNavSettings.isEnabled {
                            Divider()
                            
                            // Visual Live Preview Box
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LIVE PREVIEW (PAGE 2 ROW)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 16) {
                                    // Number Pill on Left
                                    HStack {
                                        Text("1")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color(hex: config.chapterNavSettings.symbolColorHex))
                                    }
                                    .frame(width: 32, height: 48)
                                    .background(
                                        Capsule().fill(Color(hex: config.chapterNavSettings.capsuleBgColorHex, alpha: config.chapterNavSettings.capsuleBgAlpha))
                                    )
                                    .overlay(
                                        Capsule().strokeBorder(Color(hex: config.chapterNavSettings.capsuleBorderColorHex, alpha: config.chapterNavSettings.capsuleBorderAlpha), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
                                    
                                    // Horizontal Line
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 1)
                                    
                                    // Arrow Indicator on Right
                                    HStack {
                                        Text(config.chapterNavSettings.resolvedSymbolString)
                                            .font(.system(size: config.chapterNavSettings.fontSize * 0.8, weight: config.chapterNavSettings.fontWeight == "Bold" ? .bold : .medium))
                                            .foregroundColor(Color(hex: config.chapterNavSettings.symbolColorHex, alpha: config.chapterNavSettings.symbolColorAlpha))
                                    }
                                    .frame(width: 32, height: 48)
                                    .background(
                                        Group {
                                            if config.chapterNavSettings.capsuleStyle != .none {
                                                Capsule().fill(Color(hex: config.chapterNavSettings.capsuleBgColorHex, alpha: config.chapterNavSettings.capsuleBgAlpha))
                                            }
                                        }
                                    )
                                    .overlay(
                                        Group {
                                            if config.chapterNavSettings.capsuleStyle == .glass || config.chapterNavSettings.capsuleStyle == .outline {
                                                Capsule().strokeBorder(Color(hex: config.chapterNavSettings.capsuleBorderColorHex, alpha: config.chapterNavSettings.capsuleBorderAlpha), lineWidth: 1)
                                            }
                                        }
                                    )
                                    .shadow(color: config.chapterNavSettings.capsuleStyle == .glass ? Color.black.opacity(0.04) : Color.clear, radius: 2, y: 1)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
                                
                                HStack {
                                    Text("Both left number \"1\" and right arrow link to:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Page 45 (Chapter 1)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            
                            Divider()
                            
                            // Symbol & Icon Customization
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Arrow Symbol & Icon")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                HStack {
                                    Text("Symbol Style:")
                                        .frame(width: 120, alignment: .leading)
                                    Picker("", selection: $config.chapterNavSettings.symbolType) {
                                        ForEach(ChapterNavIndicatorSettings.IndicatorSymbol.allCases, id: \.self) { sym in
                                            Text(sym.rawValue).tag(sym)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                if config.chapterNavSettings.symbolType == .custom {
                                    HStack {
                                        Text("Custom Text/Icon:")
                                            .frame(width: 120, alignment: .leading)
                                        TextField("e.g. > or → or GO", text: $config.chapterNavSettings.customSymbolText)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 140)
                                    }
                                }
                                
                                // Symbol Color & Hex
                                HStack(spacing: 12) {
                                    Text("Symbol Color:")
                                        .frame(width: 120, alignment: .leading)
                                    
                                    ColorPicker("", selection: Binding(
                                        get: { Color(hex: config.chapterNavSettings.symbolColorHex) },
                                        set: { config.chapterNavSettings.symbolColorHex = $0.toHex() ?? config.chapterNavSettings.symbolColorHex }
                                    ))
                                    .labelsHidden()
                                    
                                    TextField("Hex", text: $config.chapterNavSettings.symbolColorHex)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 90)
                                    
                                    Text("Opacity:")
                                        .font(.caption)
                                    Slider(value: $config.chapterNavSettings.symbolColorAlpha, in: 0.1...1.0, step: 0.05)
                                        .frame(width: 80)
                                    Text("\(Int(config.chapterNavSettings.symbolColorAlpha * 100))%")
                                        .font(.caption)
                                        .frame(width: 36)
                                }
                                
                                HStack(spacing: 16) {
                                    HStack {
                                        Text("Font Size:")
                                            .frame(width: 120, alignment: .leading)
                                        Slider(value: $config.chapterNavSettings.fontSize, in: 10...30, step: 1)
                                            .frame(width: 100)
                                        Text("\(Int(config.chapterNavSettings.fontSize)) pt")
                                            .font(.caption)
                                    }
                                    
                                    HStack {
                                        Text("Weight:")
                                        Picker("", selection: $config.chapterNavSettings.fontWeight) {
                                            Text("Regular").tag("Regular")
                                            Text("Medium").tag("Medium")
                                            Text("Semibold").tag("Semibold")
                                            Text("Bold").tag("Bold")
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 110)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Capsule / Pill Styling
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Capsule / Pill Badge Container")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                HStack {
                                    Text("Capsule Style:")
                                        .frame(width: 120, alignment: .leading)
                                    Picker("", selection: $config.chapterNavSettings.capsuleStyle) {
                                        ForEach(ChapterNavIndicatorSettings.CapsuleStyle.allCases, id: \.self) { style in
                                            Text(style.rawValue).tag(style)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                if config.chapterNavSettings.capsuleStyle != .none {
                                    HStack(spacing: 12) {
                                        Text("Pill Fill Color:")
                                            .frame(width: 120, alignment: .leading)
                                        
                                        ColorPicker("", selection: Binding(
                                            get: { Color(hex: config.chapterNavSettings.capsuleBgColorHex) },
                                            set: { config.chapterNavSettings.capsuleBgColorHex = $0.toHex() ?? config.chapterNavSettings.capsuleBgColorHex }
                                        ))
                                        .labelsHidden()
                                        
                                        TextField("Hex", text: $config.chapterNavSettings.capsuleBgColorHex)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 90)
                                        
                                        Text("Opacity:")
                                            .font(.caption)
                                        Slider(value: $config.chapterNavSettings.capsuleBgAlpha, in: 0.0...1.0, step: 0.05)
                                            .frame(width: 80)
                                        Text("\(Int(config.chapterNavSettings.capsuleBgAlpha * 100))%")
                                            .font(.caption)
                                            .frame(width: 36)
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Text("Border Color:")
                                            .frame(width: 120, alignment: .leading)
                                        
                                        ColorPicker("", selection: Binding(
                                            get: { Color(hex: config.chapterNavSettings.capsuleBorderColorHex) },
                                            set: { config.chapterNavSettings.capsuleBorderColorHex = $0.toHex() ?? config.chapterNavSettings.capsuleBorderColorHex }
                                        ))
                                        .labelsHidden()
                                        
                                        TextField("Hex", text: $config.chapterNavSettings.capsuleBorderColorHex)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 90)
                                        
                                        Text("Opacity:")
                                            .font(.caption)
                                        Slider(value: $config.chapterNavSettings.capsuleBorderAlpha, in: 0.0...1.0, step: 0.05)
                                            .frame(width: 80)
                                        Text("\(Int(config.chapterNavSettings.capsuleBorderAlpha * 100))%")
                                            .font(.caption)
                                            .frame(width: 36)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Dimensions & Geometry
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Dimensions & Coordinate Placement")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Toggle("Match Standard Sidebar Tab Dimensions (42.2 x 101.5 pt)", isOn: $config.useSidebarSizeForArrows)
                                
                                if !config.useSidebarSizeForArrows {
                                    HStack(spacing: 16) {
                                        HStack {
                                            Text("Arrow Width:")
                                            TextField("Width", value: $config.customArrowWidth, formatter: NumberFormatter())
                                                .frame(width: 60)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                        HStack {
                                            Text("Arrow Height:")
                                            TextField("Height", value: $config.customArrowHeight, formatter: NumberFormatter())
                                                .frame(width: 60)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                    }
                                    .padding(.leading, 12)
                                }
                                
                                HStack {
                                    Text("Right Arrow X Position:")
                                        .frame(width: 150, alignment: .leading)
                                    TextField("X", value: $config.chapterNavSettings.positionX, formatter: NumberFormatter())
                                        .frame(width: 80)
                                        .textFieldStyle(.roundedBorder)
                                    Text("pt (default 804.4)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Left Number X Position:")
                                        .frame(width: 150, alignment: .leading)
                                    TextField("X", value: $config.chapterNavSettings.leftNumberX, formatter: NumberFormatter())
                                        .frame(width: 80)
                                        .textFieldStyle(.roundedBorder)
                                    Text("pt (default 33.5)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            // Target pages
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Chapter Destination Pages (Chapters 1 to 12):")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(config.arrowTargets.map { String($0) }.joined(separator: ", "))
                                    .font(.system(.body, design: .monospaced))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
                            }
                        }
                    }
                    .padding(8)
                }
                
                // SECTION 4: Colored Chapter Tabs Range
                GroupBox(label: Label("Colored Chapter Tabs (Native Design)", systemImage: "paintpalette.fill")) {
                    VStack(alignment: .leading, spacing: 14) {
                        GuideCallout(
                            title: "Colored Chapter Tabs Range (Native Design)",
                            whatItDoes: "Preserves custom colored tab artwork on Chapter Divider pages by skipping the generic master sidebar overlay.",
                            howItWorks: "• Skip master sidebar on Final Pages (default: 3 to 14): Pages 3–14 are Chapter Divider pages with pre-designed colored tabs. On these pages, the compiler does not stamp the gray master sidebar graphic over the page, preventing visual clashes while keeping all 12 tab hyperlinks fully clickable.",
                            icon: "paintpalette.fill",
                            tintColor: .purple,
                            isExpanded: false
                        )
                        
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
