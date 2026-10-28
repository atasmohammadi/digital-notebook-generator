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
                
                Divider()
                
                // File Inputs Section
                VStack(spacing: 16) {
                    FileDropZone(
                        title: "1. Canva Export PDF (Target)",
                        subtitle: "Drop your exported Canva multi-page PDF here",
                        systemImage: "arrow.down.doc.fill",
                        filePath: $config.targetPDFPath,
                        fileType: "pdf"
                    )
                    
                    FileDropZone(
                        title: "2. Master Template PDF (Hyperlink Source)",
                        subtitle: "Drop your master template with active links here",
                        systemImage: "link.badge.plus",
                        filePath: $config.templatePDFPath,
                        fileType: "pdf"
                    )
                }
                
                // Actions & Engines
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Output Engines")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        Toggle(isOn: $config.generateInteractivePDF) {
                            VStack(alignment: .leading) {
                                Text("⚡ Generate Interactive PDF")
                                    .fontWeight(.semibold)
                                Text("Customer-ready clickable PDF in < 1 second")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        
                        Toggle(isOn: $config.syncKeynotePresentation) {
                            VStack(alignment: .leading) {
                                Text("🖥 Sync Keynote Presentation")
                                    .fontWeight(.semibold)
                                Text("Swaps slide backgrounds & sends to back")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
                
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
                                Text(String(format: "%.2f MB", generatedFileSize))
                                    .font(.title3)
                                    .fontWeight(.semibold)
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
