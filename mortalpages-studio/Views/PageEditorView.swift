import SwiftUI
import WebKit
import AppKit

public enum InspectorTab: String, CaseIterable, Identifiable {
    case links = "Hyperlinks & Routing"
    case header = "Header & Typography"
    case sidebar = "Sidebar Navigation"
    case content = "Canvas & Spacing"
    case cards = "Cards & Elements"
    case footer = "Footer & Branding"
    case customCSS = "Custom CSS"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .links: return "link.badge.plus"
        case .header: return "character.textbox"
        case .sidebar: return "sidebar.left"
        case .content: return "aspectratio"
        case .cards: return "square.grid.2x2"
        case .footer: return "signature"
        case .customCSS: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

public struct PageEditorView: View {
    @Binding public var config: NotebookConfig
    @ObservedObject public var presetManager: PresetManager
    @ObservedObject public var themeManager: HTMLThemeManager
    
    @State private var currentPage: Int = 2
    @State private var pageInputString: String = "2"
    @State private var selectedTab: InspectorTab = .links
    @State private var previewZoom: Double = 0.45
    @State private var renderedHTML: String = ""
    @State private var toastMessage: String? = nil
    @State private var showingSavePresetSheet = false
    @State private var newPresetName = ""
    @State private var newPresetDesc = ""
    @State private var filterLinkKind: String = "all"
    
    private var templateBaseDir: URL {
        TemplateRegistry.shared.baseDirectory
    }
    
    public init(
        config: Binding<NotebookConfig>,
        presetManager: PresetManager,
        themeManager: HTMLThemeManager,
        initialPage: Int = 2
    ) {
        self._config = config
        self.presetManager = presetManager
        self.themeManager = themeManager
        self._currentPage = State(initialValue: initialPage)
        self._pageInputString = State(initialValue: "\(initialPage)")
    }
    
    // Binding to active page configuration override
    private var activeOverrideBinding: Binding<PageConfigOverride> {
        Binding(
            get: {
                if let existing = config.pageOverrides[currentPage] {
                    return existing
                }
                return PageConfigOverride.defaultForPage(currentPage)
            },
            set: { updated in
                config.pageOverrides[currentPage] = updated
                refreshRenderedHTML()
            }
        )
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // TOP BAR: Navigation, Page Stepper, Fast Jump Pills & Preset Actions
            topNavigationBar
            
            Divider()
            
            // MAIN SPLIT CONTENT: Live WebKit Preview (Left) & Inspector Controls (Right)
            HSplitView {
                // LEFT PANE: WYSIWYG Page Preview
                leftPreviewPane
                    .frame(minWidth: 420, idealWidth: 540)
                
                // RIGHT PANE: Granular Visual Inspector
                rightInspectorPane
                    .frame(minWidth: 380, idealWidth: 460)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = toastMessage {
                Text(toast)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.85)))
                    .shadow(radius: 8)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingSavePresetSheet) {
            saveAsPresetSheet
        }
        .onAppear {
            refreshRenderedHTML()
        }
        .onChange(of: currentPage) { newP in
            pageInputString = "\(newP)"
            refreshRenderedHTML()
        }
        .onChange(of: themeManager.activeTheme.id) { _ in
            refreshRenderedHTML()
        }
    }
    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Page Navigation Steppers
                HStack(spacing: 6) {
                    Button(action: { changePage(to: max(1, currentPage - 1)) }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentPage <= 1)
                    .help("Previous Page (Left Arrow)")
                    
                    HStack(spacing: 4) {
                        Text("Page")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("2", text: $pageInputString)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 48)
                            .multilineTextAlignment(.center)
                            .onSubmit {
                                if let p = Int(pageInputString), p >= 1, p <= 188 {
                                    changePage(to: p)
                                } else {
                                    pageInputString = "\(currentPage)"
                                }
                            }
                        
                        Text("of 188")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: { changePage(to: min(188, currentPage + 1)) }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentPage >= 188)
                    .help("Next Page (Right Arrow)")
                }
                
                // Page Range Slider
                Slider(
                    value: Binding(
                        get: { Double(currentPage) },
                        set: { changePage(to: Int($0)) }
                    ),
                    in: 1...188,
                    step: 1
                )
                .frame(width: 140)
                
                // Page Type Badge
                pageTypeBadge
                
                Spacer()
                
                // Preset Saving & Reset Buttons
                HStack(spacing: 8) {
                    Button(action: saveToActivePreset) {
                        Label("Save Preset", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Save all per-page styles and link destinations into '\(config.themeName)' preset")
                    
                    Button(action: {
                        newPresetName = "\(config.themeName) (Custom)"
                        newPresetDesc = "Customized layout and links for \(config.themeName)"
                        showingSavePresetSheet = true
                    }) {
                        Label("Save As...", systemImage: "plus.square")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Menu {
                        Button("Reset Current Page to Default", action: resetCurrentPage)
                        Button("Reset All Pages in Notebook", action: resetAllPages)
                        Divider()
                        Button("Copy Header to All Pages", action: copyHeaderToAll)
                        Button("Copy Sidebar to All Pages", action: copySidebarToAll)
                        Button("Copy Footer to All Pages", action: copyFooterToAll)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                }
            }
            
            // Fast Jump Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    quickJumpPill("Cover (1)", page: 1)
                    quickJumpPill("Ch Selection (2)", page: 2)
                    
                    Divider().frame(height: 16)
                    
                    ForEach(1...12, id: \.self) { ch in
                        quickJumpPill("Ch \(ch)", page: ch + 2)
                    }
                    
                    Divider().frame(height: 16)
                    
                    quickJumpPill("Templates (15)", page: 15)
                    quickJumpPill("Masters (16)", page: 16)
                    quickJumpPill("Notes (45)", page: 45)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func quickJumpPill(_ title: String, page: Int) -> some View {
        let isSelected = currentPage == page
        return Button(action: { changePage(to: page) }) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color(NSColor.windowBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private var pageTypeBadge: some View {
        let title: String
        let color: Color
        if currentPage == 1 {
            title = "Cover Page"
            color = .purple
        } else if currentPage == 2 {
            title = "Chapter Selection (Index)"
            color = .blue
        } else if currentPage >= 3 && currentPage <= 14 {
            title = "Chapter \(currentPage - 2) Divider"
            color = .indigo
        } else if currentPage == 15 {
            title = "Template Directory"
            color = .orange
        } else if currentPage >= 16 && currentPage <= 44 {
            title = "Template Master #\(currentPage - 15)"
            color = .teal
        } else {
            let chNum = min(12, max(1, ((currentPage - 45) / 12) + 1))
            title = "Ch \(chNum) Notes & Journal"
            color = .green
        }
        
        return Text(title)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundColor(color)
    }
    
    // MARK: - Left Pane: WYSIWYG Page Preview
    private var leftPreviewPane: some View {
        VStack(spacing: 0) {
            // Preview Controls Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.secondary)
                    Text("Live Render • Page \(currentPage)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Zoom Steppers & Slider
                HStack(spacing: 6) {
                    Button(action: { previewZoom = max(0.2, previewZoom - 0.05) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    
                    Slider(value: $previewZoom, in: 0.25...1.0, step: 0.05)
                        .frame(width: 80)
                    
                    Button(action: { previewZoom = min(1.0, previewZoom + 0.05) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(Int(previewZoom * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 34)
                    
                    Button("Fit") {
                        previewZoom = 0.45
                    }
                    .controlSize(.mini)
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // WebKit Preview
            ZStack {
                Color(NSColor.underPageBackgroundColor)
                
                if renderedHTML.isEmpty {
                    ProgressView("Loading page preview...")
                } else {
                    WebKitPreviewView(
                        htmlContent: renderedHTML,
                        baseURL: templateBaseDir,
                        customVariables: themeManager.activeTheme.variables,
                        zoomFactor: previewZoom
                    )
                }
            }
        }
    }
    
    // MARK: - Right Pane: Inspector Controls
    private var rightInspectorPane: some View {
        VStack(spacing: 0) {
            // Inspector Tab Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(InspectorTab.allCases) { tab in
                        Button(action: { selectedTab = tab }) {
                            HStack(spacing: 5) {
                                Image(systemName: tab.iconName)
                                Text(tab.rawValue)
                            }
                            .font(.system(size: 11, weight: selectedTab == tab ? .bold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(selectedTab == tab ? Color(NSColor.controlAccentColor).opacity(0.12) : Color.clear)
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Tab Inspector Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .links:
                        hyperlinksInspector(override: activeOverrideBinding)
                    case .header:
                        headerInspector(override: activeOverrideBinding)
                    case .sidebar:
                        sidebarInspector(override: activeOverrideBinding)
                    case .content:
                        contentCanvasInspector(override: activeOverrideBinding)
                    case .cards:
                        cardsInspector(override: activeOverrideBinding)
                    case .footer:
                        footerInspector(override: activeOverrideBinding)
                    case .customCSS:
                        customCSSInspector(override: activeOverrideBinding)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Tab 1: Hyperlinks & Destinations Inspector
    private func hyperlinksInspector(override: Binding<PageConfigOverride>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            GuideCallout(
                title: "PER-PAGE HYPERLINK MANAGER",
                whatItDoes: "Configures clickable hotspot destinations across all 188 pages of the digital journal.",
                howItWorks: "Select any interactive card or tab to modify where it routes users. The PDF compiler writes genuine PDF destination annotations, linking pages instantly with zero lag.",
                proTip: "Use the 'Jump to Page' button (arrow icon) to test the destination immediately in the live preview.",
                icon: "link.badge.plus",
                tintColor: .blue
            )
            
            // Filter Pills (All, Sidebar Tabs, Content Cards)
            HStack {
                Text("Filter:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $filterLinkKind) {
                    Text("All Links").tag("all")
                    Text("Content Cards").tag("cards")
                    Text("Sidebar Tabs").tag("sidebar")
                }
                .pickerStyle(.segmented)
                
                Spacer()
                
                Button("Auto-Detect Page Links") {
                    ensureLinksForCurrentPage()
                }
                .controlSize(.small)
            }
            
            let linksDict = override.wrappedValue.linkOverrides
            let sortedKeys = linksDict.keys.sorted { k1, k2 in
                let l1 = linksDict[k1]!
                let l2 = linksDict[k2]!
                if l1.linkKind != l2.linkKind {
                    return l1.linkKind > l2.linkKind
                }
                return l1.targetPage < l2.targetPage
            }
            
            let filteredKeys = sortedKeys.filter { k in
                guard let l = linksDict[k] else { return false }
                if filterLinkKind == "cards" { return l.linkKind != "sidebar_tab" }
                if filterLinkKind == "sidebar" { return l.linkKind == "sidebar_tab" }
                return true
            }
            
            if filteredKeys.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "link.slash")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No interactive links configured on Page \(currentPage)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Generate Standard Architecture Links") {
                        ensureLinksForCurrentPage()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
            } else {
                ForEach(filteredKeys, id: \.self) { linkId in
                    linkRowCard(linkId: linkId, override: override)
                }
            }
        }
    }
    
    private func linkRowCard(linkId: String, override: Binding<PageConfigOverride>) -> some View {
        let link = override.wrappedValue.linkOverrides[linkId] ?? PageLinkOverride(id: linkId, name: linkId, targetPage: 2)
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(isOn: Binding(
                    get: { override.wrappedValue.linkOverrides[linkId]?.isEnabled ?? true },
                    set: {
                        override.wrappedValue.linkOverrides[linkId]?.isEnabled = $0
                        refreshRenderedHTML()
                    }
                )) {
                    Text(link.name)
                        .fontWeight(.semibold)
                        .font(.subheadline)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Text(link.linkKind.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                // Target Destination Page Stepper & Slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Destination Page:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Stepper(
                            value: Binding(
                                get: { override.wrappedValue.linkOverrides[linkId]?.targetPage ?? 2 },
                                set: {
                                    override.wrappedValue.linkOverrides[linkId]?.targetPage = max(1, min(188, $0))
                                    refreshRenderedHTML()
                                }
                            ),
                            in: 1...188
                        ) {
                            Text("Page \(override.wrappedValue.linkOverrides[linkId]?.targetPage ?? 2)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .frame(width: 70, alignment: .leading)
                        }
                        
                        // Destination Page Dropdown Quick Jumper
                        Picker("", selection: Binding(
                            get: { override.wrappedValue.linkOverrides[linkId]?.targetPage ?? 2 },
                            set: {
                                override.wrappedValue.linkOverrides[linkId]?.targetPage = $0
                                refreshRenderedHTML()
                            }
                        )) {
                            Text("P1: Cover").tag(1)
                            Text("P2: Chapter Selection").tag(2)
                            Divider()
                            ForEach(1...12, id: \.self) { ch in
                                Text("P\(ch + 2): Chapter \(ch) Divider").tag(ch + 2)
                            }
                            Divider()
                            Text("P15: Template Directory").tag(15)
                            ForEach(1...12, id: \.self) { ch in
                                let noteStarts = [45, 57, 69, 81, 93, 105, 117, 129, 141, 153, 165, 177]
                                Text("P\(noteStarts[ch - 1]): Ch \(ch) Notes").tag(noteStarts[ch - 1])
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        
                        // Jump & Test Button
                        Button(action: {
                            if let target = override.wrappedValue.linkOverrides[linkId]?.targetPage {
                                changePage(to: target)
                            }
                        }) {
                            Image(systemName: "arrow.up.right.square")
                        }
                        .buttonStyle(.plain)
                        .help("Jump preview to destination page")
                    }
                }
            }
            
            // Custom Label Override
            if link.linkKind != "sidebar_tab" {
                HStack(spacing: 8) {
                    Text("Label:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 44, alignment: .leading)
                    
                    TextField("Card display name (e.g. Chapter One)", text: Binding(
                        get: { override.wrappedValue.linkOverrides[linkId]?.customLabel ?? "" },
                        set: {
                            override.wrappedValue.linkOverrides[linkId]?.customLabel = $0
                            refreshRenderedHTML()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor).opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
    }
    
    // MARK: - Tab 2: Header & Typography Inspector
    private func headerInspector(override: Binding<PageConfigOverride>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GuideCallout(
                title: "HEADER & TYPOGRAPHY CONTROLS",
                whatItDoes: "Customizes the page title, subtitle, font family, typography size, weight, alignment, and spacing for Page \(currentPage).",
                howItWorks: "Replaces the HTML header tags dynamically and applies inline CSS variables. Changes update the live preview instantly and compile directly into the output PDF.",
                proTip: "Use 'Apply Header Style to All Pages' to enforce brand consistency across the entire 188-page journal in one click.",
                icon: "character.textbox",
                tintColor: .purple
            )
            
            Toggle("Show Header Section", isOn: override.headerStyle.isVisible)
                .font(.headline)
            
            if override.wrappedValue.headerStyle.isVisible {
                Group {
                    Text("TEXT & CONTENT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Page Title Text")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("Title text", text: override.headerStyle.text)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Page Subtitle Text")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("Subtitle text", text: override.headerStyle.subtitle)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Divider()
                
                Group {
                    Text("TYPOGRAPHY & APPEARANCE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Font Family")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Picker("", selection: override.headerStyle.fontFamily) {
                                Text("Playfair Display (Serif)").tag("Playfair Display")
                                Text("Inter (Modern Sans)").tag("Inter")
                                Text("Georgia (Classic)").tag("Georgia")
                                Text("Cinzel (Luxury Serif)").tag("Cinzel")
                                Text("Montserrat (Geometric)").tag("Montserrat")
                                Text("Courier New (Mono)").tag("Courier New")
                            }
                            .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Picker("", selection: override.headerStyle.fontWeight) {
                                Text("400 Regular").tag("400")
                                Text("500 Medium").tag("500")
                                Text("600 SemiBold").tag("600")
                                Text("700 Bold").tag("700")
                                Text("800 ExtraBold").tag("800")
                            }
                            .labelsHidden()
                        }
                    }
                    
                    // Title Font Size
                    sliderControl(
                        title: "Title Font Size",
                        value: override.headerStyle.fontSize,
                        range: 12...72,
                        unit: "px"
                    )
                    
                    // Subtitle Font Size
                    sliderControl(
                        title: "Subtitle Font Size",
                        value: override.headerStyle.subtitleFontSize,
                        range: 8...36,
                        unit: "px"
                    )
                    
                    // Letter Spacing
                    sliderControl(
                        title: "Letter Spacing",
                        value: override.headerStyle.letterSpacing,
                        range: -1...10,
                        unit: "px"
                    )
                    
                    // Alignment & Text Transform
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Alignment")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Picker("", selection: override.headerStyle.alignment) {
                                Text("Left").tag("left")
                                Text("Center").tag("center")
                                Text("Right").tag("right")
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transform")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Picker("", selection: override.headerStyle.textTransform) {
                                Text("None").tag("none")
                                Text("UPPERCASE").tag("uppercase")
                                Text("Capitalize").tag("capitalize")
                            }
                            .labelsHidden()
                        }
                    }
                    
                    // Colors: Title & Subtitle
                    HStack(spacing: 16) {
                        colorPickerWithHex(
                            title: "Title Color",
                            hex: override.headerStyle.textColorHex
                        )
                        
                        colorPickerWithHex(
                            title: "Subtitle Color",
                            hex: override.headerStyle.subtitleColorHex
                        )
                    }
                }
                
                Divider()
                
                Group {
                    Text("SPACING & MARGINS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    sliderControl(title: "Padding Top", value: override.headerStyle.paddingTop, range: 0...100, unit: "px")
                    sliderControl(title: "Padding Bottom", value: override.headerStyle.paddingBottom, range: 0...100, unit: "px")
                    sliderControl(title: "Margin Bottom", value: override.headerStyle.marginBottom, range: 0...100, unit: "px")
                    sliderControl(title: "Title-Subtitle Gap", value: override.headerStyle.spacing, range: 0...50, unit: "px")
                }
                
                Divider()
                
                Button(action: copyHeaderToAll) {
                    Label("Apply Header Style to All Pages in Notebook", systemImage: "square.on.square")
                }
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Tab 3: Sidebar Navigation Inspector
    private func sidebarInspector(override: Binding<PageConfigOverride>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GuideCallout(
                title: "SIDEBAR NAVIGATION TABS",
                whatItDoes: "Configures the vertical navigation tabs on the left edge of the page: width, tab height, corner radius, background, active accent color, and text styling.",
                howItWorks: "Overrides the CSS variables for --sidebar-width, --tab-height, and tab surface colors. Can be toggled on or off for cover and master pages.",
                proTip: "A tab height between 60px and 75px offers optimal finger-tap surface area on iPad GoodNotes and Notability.",
                icon: "sidebar.left",
                tintColor: .blue
            )
            
            Toggle("Show Sidebar Navigation on Page \(currentPage)", isOn: override.sidebarStyle.isVisible)
                .font(.headline)
            
            if override.wrappedValue.sidebarStyle.isVisible {
                Group {
                    Text("DIMENSIONS & GEOMETRY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    sliderControl(title: "Sidebar Width", value: override.sidebarStyle.paddingRight, range: 30...120, unit: "px")
                    sliderControl(title: "Tab Height", value: override.sidebarStyle.paddingBottom, range: 30...120, unit: "px")
                    sliderControl(title: "Tab Gap / Spacing", value: override.sidebarStyle.spacing, range: 0...30, unit: "px")
                    sliderControl(title: "Tab Corner Radius", value: override.sidebarStyle.cornerRadius, range: 0...24, unit: "px")
                    sliderControl(title: "Tab Font Size", value: override.sidebarStyle.fontSize, range: 8...22, unit: "px")
                }
                
                Divider()
                
                Group {
                    Text("COLORS & SURFACES")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        colorPickerWithHex(title: "Tab Background", hex: override.sidebarStyle.bgColorHex)
                        colorPickerWithHex(title: "Active Tab Accent", hex: override.sidebarStyle.subtitleColorHex)
                    }
                    
                    HStack(spacing: 16) {
                        colorPickerWithHex(title: "Tab Text Color", hex: override.sidebarStyle.textColorHex)
                        colorPickerWithHex(title: "Border Color", hex: override.sidebarStyle.borderColorHex)
                    }
                    
                    sliderControl(title: "Tab Shadow Opacity", value: override.sidebarStyle.shadowOpacity, range: 0...0.5, unit: "")
                }
                
                Divider()
                
                Button(action: copySidebarToAll) {
                    Label("Apply Sidebar Style to All Pages in Notebook", systemImage: "square.on.square")
                }
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Tab 4: Content Canvas & Spacing Inspector
    private func contentCanvasInspector(override: Binding<PageConfigOverride>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GuideCallout(
                title: "CANVAS & PAGE MARGINS",
                whatItDoes: "Adjusts outer page margins, padding, background colors, and container borders for the active page.",
                howItWorks: "Controls the spacing around the main grid or writing area to allow ample breathing room for handwriting and stickers.",
                proTip: "Setting padding-left to 36px leaves enough room for comfortable navigation tab tapping without clipping notebook content.",
                icon: "aspectratio",
                tintColor: .green
            )
            
            Group {
                Text("PAGE PADDING (MARGINS)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                sliderControl(title: "Padding Top", value: override.contentStyle.paddingTop, range: 0...120, unit: "px")
                sliderControl(title: "Padding Bottom", value: override.contentStyle.paddingBottom, range: 0...120, unit: "px")
                sliderControl(title: "Padding Left", value: override.contentStyle.paddingLeft, range: 0...120, unit: "px")
                sliderControl(title: "Padding Right", value: override.contentStyle.paddingRight, range: 0...120, unit: "px")
            }
            
            Divider()
            
            Group {
                Text("CANVAS BACKGROUND & BORDER")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    colorPickerWithHex(title: "Page Background", hex: override.contentStyle.bgColorHex)
                    colorPickerWithHex(title: "Border Color", hex: override.contentStyle.borderColorHex)
                }
                
                sliderControl(title: "Border Width", value: override.contentStyle.borderWidth, range: 0...10, unit: "px")
                sliderControl(title: "Corner Radius", value: override.contentStyle.cornerRadius, range: 0...30, unit: "px")
                sliderControl(title: "Shadow Blur", value: override.contentStyle.shadowBlur, range: 0...40, unit: "px")
                sliderControl(title: "Shadow Opacity", value: override.contentStyle.shadowOpacity, range: 0...0.5, unit: "")
            }
        }
    }
    
    // MARK: - Tab 5: Cards & Elements Inspector
    private func cardsInspector(override: Binding<PageConfigOverride>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GuideCallout(
                title: "GRID CARDS & DIRECTORY ITEMS",
                whatItDoes: "Customizes interactive cards (such as the 12 chapter boxes on Page 2, 12 subchapter sections on Pages 3-14, and template directory cards on Page 15).",
                howItWorks: "Adjusts padding, gap spacing, corner radius, border color, and drop shadow on each interactive card box.",
                proTip: "Increasing corner radius to 12px and adding a subtle 6px shadow gives cards a modern glass aesthetic.",
                icon: "square.grid.2x2",
                tintColor: .orange
            )
            
            Group {
                Text("CARD SPACING & SIZING")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                sliderControl(title: "Card Padding (Top / Bottom)", value: override.cardStyle.paddingTop, range: 4...60, unit: "px")
                sliderControl(title: "Card Padding (Left / Right)", value: override.cardStyle.paddingLeft, range: 4...60, unit: "px")
                sliderControl(title: "Column Gap (Spacing X)", value: override.cardStyle.spacing, range: 4...60, unit: "px")
                sliderControl(title: "Row Gap (Spacing Y)", value: override.cardStyle.marginBottom, range: 4...60, unit: "px")
                sliderControl(title: "Corner Radius", value: override.cardStyle.cornerRadius, range: 0...30, unit: "px")
            }
            
            Divider()
            
            Group {
                Text("CARD COLORS & SHADOWS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    colorPickerWithHex(title: "Card Background", hex: override.cardStyle.bgColorHex)
                    colorPickerWithHex(title: "Border Color", hex: override.cardStyle.borderColorHex)
                }
                
                sliderControl(title: "Border Width", value: override.cardStyle.borderWidth, range: 0...8, unit: "px")
                sliderControl(title: "Background Opacity", value: override.cardStyle.bgOpacity, range: 0.1...1.0, unit: "")
                sliderControl(title: "Shadow Blur", value: override.cardStyle.shadowBlur, range: 0...30, unit: "px")
                sliderControl(title: "Shadow Opacity", value: override.cardStyle.shadowOpacity, range: 0...0.5, unit: "")
            }
            
            Divider()
            
            Group {
                Text("CARD TYPOGRAPHY")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                sliderControl(title: "Font Size", value: override.cardStyle.fontSize, range: 10...36, unit: "px")
                
                HStack(spacing: 16) {
                    colorPickerWithHex(title: "Text Color", hex: override.cardStyle.textColorHex)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weight")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Picker("", selection: override.cardStyle.fontWeight) {
                            Text("500 Medium").tag("500")
                            Text("600 SemiBold").tag("600")
                            Text("700 Bold").tag("700")
                        }
                        .labelsHidden()
                    }
                }
            }
        }
    }
    
    // MARK: - Tab 6: Footer & Branding Inspector
    private func footerInspector(override: Binding<PageConfigOverride>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GuideCallout(
                title: "FOOTER & WATERMARK PLAQUE",
                whatItDoes: "Configures the bottom brand badge, typography, plaque background, borders, and alignment for Page \(currentPage).",
                howItWorks: "Updates the watermark plaque element and ensures the text is neutralized against Apple Preview data detector false-positives.",
                proTip: "Use 'Apply Footer Style to All Pages' to standardize your brand plaque or URL across all pages.",
                icon: "signature",
                tintColor: .indigo
            )
            
            Toggle("Show Footer on Page \(currentPage)", isOn: override.footerStyle.isVisible)
                .font(.headline)
            
            if override.wrappedValue.footerStyle.isVisible {
                Group {
                    Text("PLAQUE TEXT & TYPOGRAPHY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Watermark Plaque Text")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("e.g. mortalpages.com", text: override.footerStyle.text)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    sliderControl(title: "Font Size", value: override.footerStyle.fontSize, range: 8...24, unit: "px")
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Alignment")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Picker("", selection: override.footerStyle.alignment) {
                                Text("Left").tag("left")
                                Text("Center").tag("center")
                                Text("Right").tag("right")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                
                Divider()
                
                Group {
                    Text("PLAQUE VISUAL STYLING")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        colorPickerWithHex(title: "Text Color", hex: override.footerStyle.textColorHex)
                        colorPickerWithHex(title: "Plaque Background", hex: override.footerStyle.bgColorHex)
                    }
                    
                    HStack(spacing: 16) {
                        colorPickerWithHex(title: "Border Color", hex: override.footerStyle.borderColorHex)
                    }
                    
                    sliderControl(title: "Border Width", value: override.footerStyle.borderWidth, range: 0...5, unit: "px")
                    sliderControl(title: "Corner Radius", value: override.footerStyle.cornerRadius, range: 0...20, unit: "px")
                    sliderControl(title: "Background Opacity", value: override.footerStyle.bgOpacity, range: 0...1.0, unit: "")
                }
                
                Divider()
                
                Button(action: copyFooterToAll) {
                    Label("Apply Footer Style to All Pages in Notebook", systemImage: "square.on.square")
                }
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Tab 7: Custom CSS Inspector
    private func customCSSInspector(override: Binding<PageConfigOverride>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            GuideCallout(
                title: "CUSTOM CSS INJECTION",
                whatItDoes: "Injects raw CSS rules specifically for Page \(currentPage) without modifying global template files.",
                howItWorks: "Appends your custom CSS into the inlined override stylesheet inside the page's HTML head element.",
                proTip: "Use CSS backdrop-filter: blur(12px) for high-end glassmorphism effects.",
                icon: "chevron.left.forwardslash.chevron.right",
                tintColor: .teal
            )
            
            HStack {
                Text("Quick Snippets:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Glass Frosted Plaque") {
                    override.wrappedValue.customCSS += "\n.watermark-plaque { backdrop-filter: blur(10px); background: rgba(255,255,255,0.7) !important; }"
                    refreshRenderedHTML()
                }
                .controlSize(.mini)
                
                Button("Card Subtle Glow") {
                    override.wrappedValue.customCSS += "\n.chapter-card:hover { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(194,142,117,0.25) !important; }"
                    refreshRenderedHTML()
                }
                .controlSize(.mini)
            }
            
            TextEditor(text: Binding(
                get: { override.wrappedValue.customCSS },
                set: {
                    override.wrappedValue.customCSS = $0
                    refreshRenderedHTML()
                }
            ))
            .font(.system(size: 12, design: .monospaced))
            .frame(minHeight: 220)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
    
    // MARK: - Reusable UI Controls
    private func sliderControl(title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue))\(unit)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: {
                    value.wrappedValue = $0
                    refreshRenderedHTML()
                }
            ), in: range)
        }
    }
    
    private func colorPickerWithHex(title: String, hex: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                ColorPicker("", selection: Binding(
                    get: { Color(hex: hex.wrappedValue) },
                    set: { newColor in
                        if let h = newColor.toHex() {
                            hex.wrappedValue = h
                            refreshRenderedHTML()
                        }
                    }
                ))
                .labelsHidden()
                
                TextField("#HEX", text: Binding(
                    get: { hex.wrappedValue },
                    set: {
                        hex.wrappedValue = $0
                        refreshRenderedHTML()
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 80)
            }
        }
    }
    
    // MARK: - Save Preset Sheet
    private var saveAsPresetSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Customized Preset")
                .font(.headline)
            
            Text("This will save all your per-page link routing, visual element customizer settings, and styles into a new theme preset.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Preset Name")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("My Custom Preset", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Description")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("Preset description...", text: $newPresetDesc)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") {
                    showingSavePresetSheet = false
                }
                
                Spacer()
                
                Button("Save Preset") {
                    let saved = presetManager.addOrUpdatePreset(
                        name: newPresetName.isEmpty ? "Custom Notebook" : newPresetName,
                        description: newPresetDesc,
                        config: config
                    )
                    config.themeName = saved.name
                    showingSavePresetSheet = false
                    showToast("Preset '\(saved.name)' created successfully!")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 400)
    }
    
    // MARK: - Actions & Logic
    private func changePage(to newPage: Int) {
        guard newPage >= 1 && newPage <= 188 else { return }
        currentPage = newPage
        pageInputString = "\(newPage)"
        ensureLinksForCurrentPage()
        refreshRenderedHTML()
    }
    
    private func ensureLinksForCurrentPage() {
        if config.pageOverrides[currentPage] == nil {
            config.pageOverrides[currentPage] = PageConfigOverride.defaultForPage(currentPage)
        } else if config.pageOverrides[currentPage]!.linkOverrides.isEmpty {
            let defaults = PageConfigOverride.defaultForPage(currentPage)
            config.pageOverrides[currentPage]!.linkOverrides = defaults.linkOverrides
        }
    }
    
    private func refreshRenderedHTML() {
        let noteSectionStarts = [45, 57, 69, 81, 93, 105, 117, 129, 141, 153, 165, 177]
        let relPath = config.templateMapping.resolveTemplate(forPage: currentPage, arrowTargets: noteSectionStarts)
        let fileURL = templateBaseDir.appendingPathComponent(relPath)
        
        guard let baseHTML = try? String(contentsOf: fileURL, encoding: .utf8) else {
            renderedHTML = "<div style='padding:40px;color:red;'>Template not found: \(relPath)</div>"
            return
        }
        
        let override = config.pageOverrides[currentPage] ?? PageConfigOverride.defaultForPage(currentPage)
        let customized = PageHTMLCustomizer.customize(html: baseHTML, with: override)
        renderedHTML = customized
    }
    
    private func saveToActivePreset() {
        presetManager.addPreset(name: config.themeName, description: "Updated with per-page element styles and link routing", config: config)
        showToast("Preset '\(config.themeName)' saved with all page configurations!")
    }
    
    private func resetCurrentPage() {
        config.pageOverrides[currentPage] = PageConfigOverride.defaultForPage(currentPage)
        refreshRenderedHTML()
        showToast("Page \(currentPage) reset to defaults")
    }
    
    private func resetAllPages() {
        config.pageOverrides.removeAll()
        refreshRenderedHTML()
        showToast("All page overrides reset to defaults")
    }
    
    private func copyHeaderToAll() {
        let currentHeader = (config.pageOverrides[currentPage] ?? PageConfigOverride.defaultForPage(currentPage)).headerStyle
        for p in 1...188 {
            if config.pageOverrides[p] == nil {
                config.pageOverrides[p] = PageConfigOverride.defaultForPage(p)
            }
            config.pageOverrides[p]?.headerStyle = currentHeader
        }
        refreshRenderedHTML()
        showToast("Header style copied to all 188 pages!")
    }
    
    private func copySidebarToAll() {
        let currentSidebar = (config.pageOverrides[currentPage] ?? PageConfigOverride.defaultForPage(currentPage)).sidebarStyle
        for p in 1...188 {
            if config.pageOverrides[p] == nil {
                config.pageOverrides[p] = PageConfigOverride.defaultForPage(p)
            }
            config.pageOverrides[p]?.sidebarStyle = currentSidebar
        }
        refreshRenderedHTML()
        showToast("Sidebar style copied to all 188 pages!")
    }
    
    private func copyFooterToAll() {
        let currentFooter = (config.pageOverrides[currentPage] ?? PageConfigOverride.defaultForPage(currentPage)).footerStyle
        for p in 1...188 {
            if config.pageOverrides[p] == nil {
                config.pageOverrides[p] = PageConfigOverride.defaultForPage(p)
            }
            config.pageOverrides[p]?.footerStyle = currentFooter
        }
        refreshRenderedHTML()
        showToast("Footer style copied to all 188 pages!")
    }
    
    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}
