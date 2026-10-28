import SwiftUI
import AppKit

public struct WatermarkConfigView: View {
    @Binding public var config: NotebookConfig
    
    // Preview controls
    @State private var previewBackground: PreviewBackground = .journalPaper
    @State private var previewMode: PreviewMode = .closeup
    
    public enum PreviewMode: String, CaseIterable, Identifiable {
        case closeup = "Container Zoom"
        case fullPage = "Page Simulation"
        public var id: String { self.rawValue }
    }
    
    public enum PreviewBackground: String, CaseIterable, Identifiable {
        case journalPaper = "Paper Cream"
        case glassLight = "Glass Light"
        case glassDark = "Dark Mode"
        case beige = "Warm Beige"
        case checkerboard = "Transparency Grid"
        
        public var id: String { self.rawValue }
        
        public var color: Color {
            switch self {
            case .journalPaper: return Color(hex: "#F9F7F3")
            case .glassLight: return Color(hex: "#EAEFF2")
            case .glassDark: return Color(hex: "#1E2024")
            case .beige: return Color(hex: "#E6DFD5")
            case .checkerboard: return Color.clear
            }
        }
    }
    
    public init(config: Binding<NotebookConfig>) {
        self._config = config
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // LEFT PANEL: Controls (Scrollable)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Watermark & Branding Studio")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Design a custom Canva-style watermark or extract from your master layout.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        GuideCallout(
                            title: "Branding Plaque & Watermark Engine",
                            whatItDoes: "Stamps an authentic brand watermark, copyright signature, or frosted acrylic plaque onto designated notebook pages.",
                            howItWorks: "• Pure Code Plaque (SVG / CoreGraphics): Renders vector typography with customizable font, size, 3D embossing, drop shadows, glow, and optional frosted container pill with rounded corners.\n• Extracted from Master Layout: Crops the watermark directly from Canva Page 2, strips the background color, and stamps the artwork.\n• Page Scope: Choose which pages receive the watermark (All Pages, General & Notes, Notes Only, or Cover & Notes).",
                            proTip: "Enable 'Suppress Preview App URL link detector' to prevent Apple Preview from auto-converting '@mortalpages' text into blue browser links.",
                            icon: "signature",
                            tintColor: .indigo,
                            isExpanded: false
                        )
                    }
                    
                    Divider()
                    
                    // 1. Watermark Source Mode & Scope
                    GroupBox(label: Label("Watermark Mode & Page Scope", systemImage: "sparkles")) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Choose between sharp vector-rendered plaques or cropping existing artwork from your Canva master layout.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Picker("Source:", selection: $config.watermarkSettings.mode) {
                                ForEach(WatermarkSourceMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            HStack {
                                Text("Apply To:")
                                Spacer()
                                Picker("", selection: $config.watermarkSettings.scope) {
                                    ForEach(WatermarkPageScope.allCases) { scope in
                                        Text(scope.rawValue).tag(scope)
                                    }
                                }
                                .frame(width: 260)
                            }
                            
                            Text("Page Scope controls which sections receive the mark. 'General & Notes' keeps Cover and Structural Dividers clean.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            Toggle("Suppress Preview App URL link detector", isOn: $config.watermarkSettings.neutralizeDataDetectors)
                                .font(.subheadline)
                                .help("Neutralizes raw text stream in Canva PDF so Preview never turns watermark text into an active browser link.")
                        }
                        .padding(6)
                    }
                    
                    // IF EXTRACT FROM MASTER LAYOUT
                    if config.watermarkSettings.mode == .extractedFromLayout {
                        GroupBox(label: Label("Master Layout Crop Coordinates", systemImage: "crop")) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Crops the embossed watermark from Canva layout page (Page \(config.masterLayoutPageIndex)) and makes the background transparent.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                                    GridRow {
                                        Text("X Position:")
                                        TextField("X", value: $config.watermarkSettings.layoutCropX, formatter: NumberFormatter())
                                            .frame(width: 70)
                                        Text("Y Position:")
                                        TextField("Y", value: $config.watermarkSettings.layoutCropY, formatter: NumberFormatter())
                                            .frame(width: 70)
                                    }
                                    GridRow {
                                        Text("Crop Width:")
                                        TextField("W", value: $config.watermarkSettings.layoutCropW, formatter: NumberFormatter())
                                            .frame(width: 70)
                                        Text("Crop Height:")
                                        TextField("H", value: $config.watermarkSettings.layoutCropH, formatter: NumberFormatter())
                                            .frame(width: 70)
                                    }
                                }
                                
                                Button("Reset to Default Layout Coordinates (501, 28)") {
                                    config.watermarkSettings.layoutCropX = 501.0
                                    config.watermarkSettings.layoutCropY = 28.0
                                    config.watermarkSettings.layoutCropW = 150.0
                                    config.watermarkSettings.layoutCropH = 35.0
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            }
                            .padding(6)
                        }
                    }
                    
                    // IF CUSTOM TEXT WATERMARK
                    if config.watermarkSettings.mode == .customText {
                        // 2. Typography & Text Content
                        GroupBox(label: Label("Typography & Content", systemImage: "character.textbox")) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Text Content:")
                                        .frame(width: 100, alignment: .leading)
                                    TextField("Watermark Text", text: $config.watermarkSettings.text)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                HStack {
                                    Text("Font Family:")
                                        .frame(width: 100, alignment: .leading)
                                    Picker("", selection: $config.watermarkSettings.fontFamily) {
                                        ForEach(WatermarkRenderer.availableFonts, id: \.self) { font in
                                            Text(font).tag(font)
                                        }
                                    }
                                }
                                
                                HStack {
                                    Text("Weight & Style:")
                                        .frame(width: 100, alignment: .leading)
                                    Picker("", selection: $config.watermarkSettings.fontWeight) {
                                        ForEach(WatermarkRenderer.availableWeights, id: \.self) { weight in
                                            Text(weight).tag(weight)
                                        }
                                    }
                                    .frame(width: 120)
                                    
                                    Toggle("Italic", isOn: $config.watermarkSettings.isItalic)
                                        .padding(.leading, 8)
                                    
                                    Toggle("3D Emboss", isOn: $config.watermarkSettings.embossEnabled)
                                        .padding(.leading, 8)
                                }
                                
                                HStack {
                                    Text("Font Size: \(Int(config.watermarkSettings.fontSize)) pt")
                                        .frame(width: 120, alignment: .leading)
                                    Slider(value: $config.watermarkSettings.fontSize, in: 8...48, step: 1)
                                }
                                
                                HStack {
                                    Text("Letter Spacing: \(String(format: "%.1f", config.watermarkSettings.letterSpacing)) pt")
                                        .frame(width: 140, alignment: .leading)
                                    Slider(value: $config.watermarkSettings.letterSpacing, in: 0...10, step: 0.5)
                                }
                                
                                HStack {
                                    Text("Resolution / DPI:")
                                        .frame(width: 140, alignment: .leading)
                                    Picker("", selection: $config.watermarkSettings.renderDPI) {
                                        Text("300 DPI (High)").tag(300)
                                        Text("450 DPI (Sharp)").tag(450)
                                        Text("600 DPI (Ultra)").tag(600)
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                // Text Color & Opacity
                                HStack(spacing: 16) {
                                    Text("Text Color:")
                                        .frame(width: 100, alignment: .leading)
                                    
                                    ColorPicker("", selection: Binding(
                                        get: { Color(hex: config.watermarkSettings.textColorHex) },
                                        set: { if let hex = $0.toHex() { config.watermarkSettings.textColorHex = hex } }
                                    ))
                                    .labelsHidden()
                                    
                                    Text(config.watermarkSettings.textColorHex)
                                        .font(.system(.caption, design: .monospaced))
                                    
                                    Spacer()
                                    
                                    Text("Opacity: \(Int(config.watermarkSettings.textColorAlpha * 100))%")
                                        .frame(width: 90, alignment: .trailing)
                                    Slider(value: $config.watermarkSettings.textColorAlpha, in: 0.05...1.0, step: 0.05)
                                        .frame(width: 100)
                                }
                            }
                            .padding(6)
                        }
                        
                        // 3. Shadow, Double Shadow & Glow (Canva style)
                        GroupBox(label: Label("Effects: Glow & Shadows", systemImage: "sparkle")) {
                            VStack(alignment: .leading, spacing: 14) {
                                // Glow
                                Toggle(isOn: $config.watermarkSettings.glowEnabled) {
                                    Text("✨ Glow Effect")
                                        .fontWeight(.semibold)
                                }
                                if config.watermarkSettings.glowEnabled {
                                    HStack {
                                        ColorPicker("Glow Color", selection: Binding(
                                            get: { Color(hex: config.watermarkSettings.glowColorHex) },
                                            set: { if let hex = $0.toHex() { config.watermarkSettings.glowColorHex = hex } }
                                        ))
                                        Spacer()
                                        Text("Radius: \(Int(config.watermarkSettings.glowRadius))")
                                        Slider(value: $config.watermarkSettings.glowRadius, in: 1...25, step: 1)
                                            .frame(width: 110)
                                        Text("Opacity: \(Int(config.watermarkSettings.glowColorAlpha * 100))%")
                                        Slider(value: $config.watermarkSettings.glowColorAlpha, in: 0.05...1.0, step: 0.05)
                                            .frame(width: 90)
                                    }
                                    .padding(.leading, 18)
                                }
                                
                                Divider()
                                
                                // Primary Shadow
                                Toggle(isOn: $config.watermarkSettings.shadowEnabled) {
                                    Text("🌑 Primary Drop Shadow")
                                        .fontWeight(.semibold)
                                }
                                if config.watermarkSettings.shadowEnabled {
                                    VStack(spacing: 8) {
                                        HStack {
                                            ColorPicker("Color", selection: Binding(
                                                get: { Color(hex: config.watermarkSettings.shadowColorHex) },
                                                set: { if let hex = $0.toHex() { config.watermarkSettings.shadowColorHex = hex } }
                                            ))
                                            Spacer()
                                            Text("Blur: \(Int(config.watermarkSettings.shadowBlur))")
                                            Slider(value: $config.watermarkSettings.shadowBlur, in: 0...20, step: 1)
                                                .frame(width: 100)
                                            Text("Opacity: \(Int(config.watermarkSettings.shadowColorAlpha * 100))%")
                                            Slider(value: $config.watermarkSettings.shadowColorAlpha, in: 0.05...1.0, step: 0.05)
                                                .frame(width: 90)
                                        }
                                        HStack {
                                            Text("Offset X: \(Int(config.watermarkSettings.shadowOffsetX))")
                                            Slider(value: $config.watermarkSettings.shadowOffsetX, in: -20...20, step: 1)
                                            Text("Offset Y: \(Int(config.watermarkSettings.shadowOffsetY))")
                                            Slider(value: $config.watermarkSettings.shadowOffsetY, in: -20...20, step: 1)
                                        }
                                    }
                                    .padding(.leading, 18)
                                }
                                
                                Divider()
                                
                                // Double Shadow (Secondary Ambient Shadow)
                                Toggle(isOn: $config.watermarkSettings.doubleShadowEnabled) {
                                    Text("🌓 Double Shadow (Secondary Depth)")
                                        .fontWeight(.semibold)
                                }
                                if config.watermarkSettings.doubleShadowEnabled {
                                    VStack(spacing: 8) {
                                        HStack {
                                            ColorPicker("Color", selection: Binding(
                                                get: { Color(hex: config.watermarkSettings.doubleShadowColorHex) },
                                                set: { if let hex = $0.toHex() { config.watermarkSettings.doubleShadowColorHex = hex } }
                                            ))
                                            Spacer()
                                            Text("Blur: \(Int(config.watermarkSettings.doubleShadowBlur))")
                                            Slider(value: $config.watermarkSettings.doubleShadowBlur, in: 0...25, step: 1)
                                                .frame(width: 100)
                                            Text("Opacity: \(Int(config.watermarkSettings.doubleShadowColorAlpha * 100))%")
                                            Slider(value: $config.watermarkSettings.doubleShadowColorAlpha, in: 0.05...1.0, step: 0.05)
                                                .frame(width: 90)
                                        }
                                        HStack {
                                            Text("Offset X: \(Int(config.watermarkSettings.doubleShadowOffsetX))")
                                            Slider(value: $config.watermarkSettings.doubleShadowOffsetX, in: -20...20, step: 1)
                                            Text("Offset Y: \(Int(config.watermarkSettings.doubleShadowOffsetY))")
                                            Slider(value: $config.watermarkSettings.doubleShadowOffsetY, in: -20...20, step: 1)
                                        }
                                    }
                                    .padding(.leading, 18)
                                }
                            }
                            .padding(6)
                        }
                        
                        // 4. Container & Background Box
                        GroupBox(label: Label("Container & Background Box", systemImage: "macwindow")) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Button(action: {
                                        config.watermarkSettings.containerBgEnabled = true
                                        config.watermarkSettings.containerBgColorHex = "#FAF8F5"
                                        config.watermarkSettings.containerBgAlpha = 1.0
                                        config.watermarkSettings.containerPaddingH = 18.0
                                        config.watermarkSettings.containerPaddingV = 6.0
                                        config.watermarkSettings.containerCornerRadius = 8.0
                                    }) {
                                        Label("Mask Underlying Canva Watermark (Opaque Plaque)", systemImage: "shield.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    Spacer()
                                }
                                HStack {
                                    Toggle("Auto-Fit Content Size", isOn: $config.watermarkSettings.containerAutoFit)
                                    Spacer()
                                    if !config.watermarkSettings.containerAutoFit {
                                        Text("Width:")
                                        TextField("W", value: $config.watermarkSettings.containerWidth, formatter: NumberFormatter())
                                            .frame(width: 60)
                                        Text("Height:")
                                        TextField("H", value: $config.watermarkSettings.containerHeight, formatter: NumberFormatter())
                                            .frame(width: 60)
                                    }
                                }
                                
                                HStack {
                                    Text("Padding H: \(Int(config.watermarkSettings.containerPaddingH)) pt")
                                        .frame(width: 120, alignment: .leading)
                                    Slider(value: $config.watermarkSettings.containerPaddingH, in: 0...40, step: 1)
                                    
                                    Text("Padding V: \(Int(config.watermarkSettings.containerPaddingV)) pt")
                                        .frame(width: 120, alignment: .leading)
                                    Slider(value: $config.watermarkSettings.containerPaddingV, in: 0...30, step: 1)
                                }
                                
                                HStack {
                                    Text("Corner Radius: \(Int(config.watermarkSettings.containerCornerRadius)) pt")
                                        .frame(width: 150, alignment: .leading)
                                    Slider(value: $config.watermarkSettings.containerCornerRadius, in: 0...30, step: 1)
                                }
                                
                                Divider()
                                
                                // Container Background Fill
                                Toggle(isOn: $config.watermarkSettings.containerBgEnabled) {
                                    Text("Container Background Color")
                                        .fontWeight(.semibold)
                                }
                                if config.watermarkSettings.containerBgEnabled {
                                    HStack {
                                        ColorPicker("Background Color", selection: Binding(
                                            get: { Color(hex: config.watermarkSettings.containerBgColorHex) },
                                            set: { if let hex = $0.toHex() { config.watermarkSettings.containerBgColorHex = hex } }
                                        ))
                                        Spacer()
                                        Text("Opacity: \(Int(config.watermarkSettings.containerBgAlpha * 100))%")
                                        Slider(value: $config.watermarkSettings.containerBgAlpha, in: 0.05...1.0, step: 0.05)
                                            .frame(width: 140)
                                    }
                                    .padding(.leading, 18)
                                }
                                
                                Divider()
                                
                                // Container Border
                                Toggle(isOn: $config.watermarkSettings.containerBorderEnabled) {
                                    Text("Container Border")
                                        .fontWeight(.semibold)
                                }
                                if config.watermarkSettings.containerBorderEnabled {
                                    HStack {
                                        ColorPicker("Border Color", selection: Binding(
                                            get: { Color(hex: config.watermarkSettings.containerBorderColorHex) },
                                            set: { if let hex = $0.toHex() { config.watermarkSettings.containerBorderColorHex = hex } }
                                        ))
                                        Spacer()
                                        Text("Width: \(String(format: "%.1f", config.watermarkSettings.containerBorderWidth))")
                                        Slider(value: $config.watermarkSettings.containerBorderWidth, in: 0.5...5.0, step: 0.5)
                                            .frame(width: 80)
                                        Text("Opacity: \(Int(config.watermarkSettings.containerBorderAlpha * 100))%")
                                        Slider(value: $config.watermarkSettings.containerBorderAlpha, in: 0.05...1.0, step: 0.05)
                                            .frame(width: 80)
                                    }
                                    .padding(.leading, 18)
                                }
                            }
                            .padding(6)
                        }
                        
                        // 5. Positioning & Orientation
                        GroupBox(label: Label("Positioning & Page Placement", systemImage: "location.viewfinder")) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Page Position Preset:")
                                    Spacer()
                                    Picker("", selection: $config.watermarkSettings.position) {
                                        ForEach(WatermarkPagePosition.allCases) { pos in
                                            Text(pos.rawValue).tag(pos)
                                        }
                                    }
                                    .frame(width: 220)
                                }
                                
                                if config.watermarkSettings.position == .custom {
                                    HStack {
                                        Text("Custom Coordinates:")
                                        Spacer()
                                        Text("X:")
                                        TextField("X", value: $config.watermarkSettings.customX, formatter: NumberFormatter())
                                            .frame(width: 70)
                                        Text("Y:")
                                        TextField("Y", value: $config.watermarkSettings.customY, formatter: NumberFormatter())
                                            .frame(width: 70)
                                    }
                                }
                                
                                HStack {
                                    Text("Rotation: \(Int(config.watermarkSettings.rotationDegrees))°")
                                        .frame(width: 100, alignment: .leading)
                                    Slider(value: $config.watermarkSettings.rotationDegrees, in: -180...180, step: 5)
                                    
                                    Button("0°") { config.watermarkSettings.rotationDegrees = 0 }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    Button("-35°") { config.watermarkSettings.rotationDegrees = -35 }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    Button("-45°") { config.watermarkSettings.rotationDegrees = -45 }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                            .padding(6)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(minWidth: 460)
            
            // RIGHT PANEL: Live Interactive Preview
            VStack(alignment: .leading, spacing: 14) {
                // Preview Header & Toggles
                HStack {
                    Label("Live Preview", systemImage: "eye.fill")
                        .font(.headline)
                    Spacer()
                    Picker("", selection: $previewMode) {
                        ForEach(PreviewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                // Background Switcher
                HStack {
                    Text("Canvas Background:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $previewBackground) {
                        ForEach(PreviewBackground.allCases) { bg in
                            Text(bg.rawValue).tag(bg)
                        }
                    }
                    .controlSize(.small)
                    .frame(width: 150)
                }
                
                // PREVIEW DISPLAY CANVAS
                ZStack {
                    // Background
                    if previewBackground == .checkerboard {
                        CheckerboardView()
                    } else {
                        previewBackground.color
                    }
                    
                    if config.watermarkSettings.mode == .none {
                        VStack(spacing: 8) {
                            Image(systemName: "slash.circle")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("Watermark Disabled")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else if config.watermarkSettings.mode == .extractedFromLayout {
                        VStack(spacing: 8) {
                            Image(systemName: "crop")
                                .font(.system(size: 36))
                                .foregroundColor(.accentColor)
                            Text("Extracting from Canva Page \(config.masterLayoutPageIndex)")
                                .font(.headline)
                            Text("Bounds: (\(Int(config.watermarkSettings.layoutCropX)), \(Int(config.watermarkSettings.layoutCropY)), \(Int(config.watermarkSettings.layoutCropW)), \(Int(config.watermarkSettings.layoutCropH)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Embossed graphic stamped across all pages with zero hyperlinks.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    } else {
                        // Custom Watermark Render
                        if let rendered = WatermarkRenderer.renderImage(settings: config.watermarkSettings) {
                            if previewMode == .closeup {
                                // Zoomed in container close-up
                                VStack {
                                    Image(nsImage: rendered.image)
                                        .interpolation(.high)
                                        .rotationEffect(.degrees(config.watermarkSettings.rotationDegrees))
                                        .padding(20)
                                }
                            } else {
                                // Full Page Simulation (1152 x 1485 Aspect Ratio)
                                SimulatedPageView(
                                    renderedImage: rendered.image,
                                    targetRect: rendered.drawnRect,
                                    rotation: config.watermarkSettings.rotationDegrees,
                                    bgName: previewBackground.rawValue
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                
                // Live Metrics Badge
                if config.watermarkSettings.mode == .customText,
                   let rendered = WatermarkRenderer.renderImage(settings: config.watermarkSettings) {
                    HStack(spacing: 14) {
                        Label("Box: \(Int(rendered.containerSize.width)) × \(Int(rendered.containerSize.height)) pt", systemImage: "square.dashed")
                        Label("\(config.watermarkSettings.renderDPI) DPI", systemImage: "sparkles")
                        Label("Pos: (\(Int(rendered.drawnRect.origin.x)), \(Int(rendered.drawnRect.origin.y)))", systemImage: "mappin.and.ellipse")
                        Spacer()
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                }
            }
            .frame(width: 380)
        }
        .padding(20)
    }
}

// MARK: - Subviews for Live Preview

struct CheckerboardView: View {
    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = 16
            let cols = Int(geo.size.width / size) + 1
            let rows = Int(geo.size.height / size) + 1
            
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<cols, id: \.self) { c in
                            Rectangle()
                                .fill((r + c) % 2 == 0 ? Color.white : Color(white: 0.90))
                                .frame(width: size, height: size)
                        }
                    }
                }
            }
        }
        .clipped()
    }
}

struct SimulatedPageView: View {
    let renderedImage: NSImage
    let targetRect: CGRect
    let rotation: Double
    let bgName: String
    
    // Page Dimensions in PDF points
    let pdfW: CGFloat = 1152.0
    let pdfH: CGFloat = 1485.0
    
    var body: some View {
        GeometryReader { geo in
            // Fit 1152 x 1485 into available view frame
            let aspect = pdfW / pdfH
            let maxH = geo.size.height - 40
            let maxW = geo.size.width - 40
            let simH = min(maxH, maxW / aspect)
            let simW = simH * aspect
            let scale = simW / pdfW
            
            ZStack(alignment: .bottomLeading) {
                // Page Canvas Shadow & Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                
                // Sidebar representation on left
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60.0 * scale)
                    .padding(.vertical, 8)
                    .padding(.leading, 4)
                
                // Tab dots
                VStack(spacing: 6) {
                    ForEach(0..<8, id: \.self) { _ in
                        Circle()
                            .fill(Color.accentColor.opacity(0.4))
                            .frame(width: 4, height: 4)
                    }
                }
                .padding(.leading, 8)
                .frame(maxHeight: .infinity, alignment: .center)
                
                // Simulated Page Lines
                VStack(spacing: 10) {
                    ForEach(0..<10, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.12))
                            .frame(height: 1)
                    }
                }
                .padding(.leading, 40)
                .padding(.trailing, 20)
                .padding(.vertical, 40)
                
                // Watermark Placement
                // PDF origin is bottom-left (y = 0 at bottom)
                let wmX = targetRect.origin.x * scale
                let wmY = targetRect.origin.y * scale
                let wmW = CGFloat(renderedImage.size.width) * scale
                let wmH = CGFloat(renderedImage.size.height) * scale
                
                Image(nsImage: renderedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .rotationEffect(.degrees(rotation))
                    .frame(width: wmW, height: wmH)
                    .offset(x: wmX, y: -wmY) // SwiftUI offset from bottom-left
            }
            .frame(width: simW, height: simH)
            .position(x: geo.size.width / 2.0, y: geo.size.height / 2.0)
        }
    }
}
