import SwiftUI
import AppKit

public struct GeneratorView: View {
    @Binding public var config: NotebookConfig
    
    @State private var isRunning = false
    @State private var progressValue: Double = 0.0
    @State private var statusMessage: String = "Ready"
    @State private var resultMessage: String? = nil
    @State private var generatedFilePath: String? = nil
    @State private var generatedFileSize: Double = 0.0
    @State private var linksGenerated: Int = 0
    @State private var executionDuration: Double = 0.0
    @State private var errorMessage: String? = nil
    
    public init(config: Binding<NotebookConfig>) {
        self._config = config
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Banner
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Digital Notebook Generator")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Create hyperlinked, interactive digital planners in seconds.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: autoDetectFiles) {
                            Label("Auto-Detect Open Files", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    GuideCallout(
                        title: "Autonomous Zero-Canva & Hybrid Compilation Engine",
                        whatItDoes: "Transforms your notebook configurations, HTML/CSS templates, and design files into a fully interactive digital planner with over 2,800 clickable hyperlinks in less than a second.",
                        howItWorks: "• Interactive PDF Engine: Direct native CoreGraphics and PDFKit rendering. Injects template paper backgrounds, generates persistent right-side tab navigation, crops master layouts, draws watermark plaques, and compiles high-resolution customer-ready PDFs.\n• Keynote Presentation Sync: Uses AppleScript to drive Apple Keynote. Automatically sets generated pages as slide backgrounds and arranges interactive objects behind presentation layers.",
                        proTip: "You can compile notebooks either from a Canva PDF export or directly from pure HTML/CSS templates in Template Studio without needing Canva at all.",
                        icon: "wand.and.stars",
                        tintColor: .indigo,
                        isExpanded: false
                    )
                }
                
                Divider()
                
                // File Inputs Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("Source Files & Design Assets")
                        .font(.headline)
                    
                    GuideCallout(
                        title: "Input Asset Roles & Auto-Detection",
                        whatItDoes: "Specifies the visual pages and hyperlink geometry to compile into the final digital notebook.",
                        howItWorks: "• 1. Target PDF: The flattened PDF exported from Canva containing your notebook artwork (Cover, dividers, headers, backgrounds).\n• 2. Hyperlink Source PDF: (Optional) A reference PDF containing existing link coordinate frames and metadata to clone.",
                        proTip: "Click 'Auto-Detect Open Files' to instantly capture the frontmost exported PDF from Keynote or Downloads.",
                        icon: "doc.badge.plus",
                        tintColor: .blue,
                        isExpanded: false
                    )
                    
                    VStack(spacing: 14) {
                        FileDropZone(
                            title: "1. Canva Export PDF (Target)",
                            subtitle: "Drop your exported Canva multi-page PDF here (covers, dividers, backgrounds)",
                            systemImage: "arrow.down.doc.fill",
                            filePath: $config.targetPDFPath,
                            fileType: "pdf"
                        )
                        
                        FileDropZone(
                            title: "2. Master Template PDF (Hyperlink Source)",
                            subtitle: "Drop your master template with active links here (optional link reference)",
                            systemImage: "link.badge.plus",
                            filePath: $config.templatePDFPath,
                            fileType: "pdf"
                        )
                    }
                }
                
                // Actions & Engines
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Output Engines")
                        .font(.headline)
                    
                    GuideCallout(
                        title: "Dual Output Pipelines",
                        whatItDoes: "Choose whether to build a customer-ready PDF file, update an active Apple Keynote presentation, or both simultaneously.",
                        howItWorks: "• Interactive PDF: Generates 2,800+ vector link annotations, stamps navigation tabs, embeds watermark plaques, and produces a finished PDF in under 1 second.\n• Keynote Sync: Replaces slide master backdrops in Keynote via AppleScript automation.",
                        icon: "cpu.fill",
                        tintColor: .teal,
                        isExpanded: false
                    )
                    
                    HStack(spacing: 20) {
                        Toggle(isOn: $config.generateInteractivePDF) {
                            VStack(alignment: .leading) {
                                Text("⚡ Generate Interactive PDF")
                                    .fontWeight(.semibold)
                                Text("Customer-ready clickable PDF with 2,800+ links in < 1 second")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        
                        Toggle(isOn: $config.syncKeynotePresentation) {
                            VStack(alignment: .leading) {
                                Text("🖥 Sync Keynote Presentation")
                                    .fontWeight(.semibold)
                                Text("Swaps slide backgrounds & sends behind Keynote layers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
                
                // Target Size & Compression Optimizer
                PDFCompressionConfigCard(config: $config)
                
                // Generate Button & Progress
                VStack(spacing: 12) {
                    Button(action: startGeneration) {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text(isRunning ? "Generating Notebook..." : "Generate Digital Journal")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isRunning || config.targetPDFPath.isEmpty)
                    
                    if isRunning {
                        VStack(spacing: 6) {
                            ProgressView(value: progressValue, total: 1.0)
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Results Card
                if let path = generatedFilePath {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            Text("Notebook Generated Successfully!")
                                .font(.headline)
                                .foregroundColor(.green)
                            Spacer()
                            Text(String(format: "%.2f sec", executionDuration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 24) {
                            VStack(alignment: .leading) {
                                Text("Active Links")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(linksGenerated)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            VStack(alignment: .leading) {
                                Text("File Size")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Text(String(format: "%.2f MB", generatedFileSize))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    if config.autoCompressPDF && config.targetMaxFileSizeMB < 50.0 {
                                        if generatedFileSize <= config.targetMaxFileSizeMB {
                                            Text("✓ ≤ \(String(format: "%.1f", config.targetMaxFileSizeMB)) MB")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.green.opacity(0.15)))
                                        } else {
                                            Text("Optimized")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.orange.opacity(0.15)))
                                        }
                                    }
                                }
                            }
                            VStack(alignment: .leading) {
                                Text("Location")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button("Open in Preview") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.green.opacity(0.3), lineWidth: 1))
                }
                
                // Error Alert
                if let err = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(err)
                            .font(.callout)
                            .foregroundColor(.red)
                        Spacer()
                        Button(action: { errorMessage = nil }) {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
                }
            }
            .padding(24)
        }
        .onAppear {
            if config.targetPDFPath.isEmpty {
                autoDetectFiles()
            }
        }
    }
    
    private func autoDetectFiles() {
        if let previewPDF = KeynoteBridge.getFrontPreviewPDFPath() {
            config.targetPDFPath = previewPDF
        }
    }
    
    private func startGeneration() {
        isRunning = true
        errorMessage = nil
        generatedFilePath = nil
        progressValue = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if config.generateInteractivePDF {
                    let result = try PDFLinkEngine.process(config: config) { p, msg in
                        DispatchQueue.main.async {
                            self.progressValue = p
                            self.statusMessage = msg
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.generatedFilePath = result.outputPath
                        self.linksGenerated = result.linksCount
                        self.executionDuration = result.duration
                        self.generatedFileSize = result.fileSizeMB
                    }
                }
                
                if config.syncKeynotePresentation {
                    _ = try KeynoteBridge.syncKeynote(config: config) { p, msg in
                        DispatchQueue.main.async {
                            self.progressValue = p
                            self.statusMessage = msg
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.statusMessage = "Finished successfully!"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct PDFCompressionConfigCard: View {
    @Binding var config: NotebookConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.accentColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PDF Target Size & Quality Optimizer")
                        .font(.headline)
                    Text("Auto-compresses to ≤ 5MB while 100% preserving all 2,800+ vector links")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("Auto Compress", isOn: $config.autoCompressPDF)
                    .toggleStyle(.switch)
            }
            
            GuideCallout(
                title: "Smart Size Enforcement & Vector Link Preservation",
                whatItDoes: "Ensures the generated digital notebook never exceeds your desired file size limit (default 5.0 MB) so it opens instantly and runs lag-free in GoodNotes, Notability, and Noteshelf.",
                howItWorks: "• Downsamples embedded background images using hardware-accelerated Apple Quartz graphics.\n• Strictly retains 100% of all 2,800+ vector hyperlinks, sidebar navigation buttons, and table of contents bookmarks without flattening pages.\n• Adaptive multi-pass engine checks final output and tightens compression if Canva export was unusually large.",
                proTip: "5.0 MB or less is the gold standard for digital planners on Etsy. It prevents customer complaints about slow iPad syncing or app crashing.",
                icon: "arrow.down.right.and.arrow.up.left",
                tintColor: .green,
                isExpanded: false
            )
            
            if config.autoCompressPDF {
                VStack(alignment: .leading, spacing: 12) {
                    // Target Size Header & Badge
                    HStack {
                        Text("Target Maximum File Size:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        if config.targetMaxFileSizeMB >= 50.0 {
                            Text("Uncompressed Master (No Limit)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.secondary.opacity(0.12)))
                        } else {
                            HStack(spacing: 4) {
                                Text(String(format: "≤ %.1f MB", config.targetMaxFileSizeMB))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                if abs(config.targetMaxFileSizeMB - 5.0) < 0.1 {
                                    Text("(Default Recommended)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(config.targetMaxFileSizeMB <= 5.0 ? .green : .blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(config.targetMaxFileSizeMB <= 5.0 ? Color.green.opacity(0.15) : Color.blue.opacity(0.12)))
                        }
                    }
                    
                    // Slider
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { min(25.0, config.targetMaxFileSizeMB) },
                                set: { config.targetMaxFileSizeMB = $0 }
                            ),
                            in: 1.5...25.0,
                            step: 0.5
                        )
                        HStack {
                            Text("1.5 MB (Ultra Compact)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("5.0 MB (GoodNotes)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            Spacer()
                            Text("25.0 MB (Print Quality)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Quick Presets
                    HStack(spacing: 8) {
                        presetButton(title: "2 MB Compact", target: 2.0)
                        presetButton(title: "5 MB (GoodNotes Default)", target: 5.0, isDefault: true)
                        presetButton(title: "10 MB Retina", target: 10.0)
                        presetButton(title: "20 MB Print HQ", target: 20.0)
                        presetButton(title: "Uncompressed", target: 99.0)
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    // Predictive Metrics Box
                    metricsView
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
    }
    
    private var metricsView: some View {
        let metrics = PDFCompressor.estimateSizeMetrics(targetMB: config.targetMaxFileSizeMB)
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ESTIMATED SIZE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text(metrics.estimatedRange)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Divider().frame(height: 28)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("RESOLUTION TIER")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text(metrics.qualityTier)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Divider().frame(height: 28)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("RECOMMENDED USE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text(metrics.performanceBadge)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor).opacity(0.8)))
    }
    
    private func presetButton(title: String, target: Double, isDefault: Bool = false) -> some View {
        let isSelected = abs(config.targetMaxFileSizeMB - target) < 0.2 || (target >= 50.0 && config.targetMaxFileSizeMB >= 50.0)
        return Button(action: {
            config.targetMaxFileSizeMB = target
        }) {
            Text(title)
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? (isDefault ? Color.green.opacity(0.2) : Color.accentColor.opacity(0.2)) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isSelected ? (isDefault ? Color.green : Color.accentColor) : Color.secondary.opacity(0.25), lineWidth: isSelected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
