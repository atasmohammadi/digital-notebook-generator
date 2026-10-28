import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct FileDropZone: View {
    public let title: String
    public let subtitle: String
    public let systemImage: String
    @Binding public var filePath: String
    public let fileType: String // e.g. "pdf" or "key"
    
    @State private var isTargeted = false
    
    public init(title: String, subtitle: String, systemImage: String, filePath: Binding<String>, fileType: String = "pdf") {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._filePath = filePath
        self.fileType = fileType
    }
    
    private var fileExists: Bool {
        !filePath.isEmpty && FileManager.default.fileExists(atPath: filePath)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if !filePath.isEmpty {
                    HStack(spacing: 12) {
                        Button(action: openFile) {
                            Label("Open", systemImage: "arrow.up.forward.app")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(fileExists ? .accentColor : .secondary)
                        .disabled(!fileExists)
                        .help("Open in Preview or default viewer")
                        
                        Button(action: revealInFinder) {
                            Label("Reveal", systemImage: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(fileExists ? .accentColor : .secondary)
                        .disabled(!fileExists)
                        .help("Reveal in Finder")
                        
                        Button(action: {
                            selectFile()
                        }) {
                            Text("Change...")
                                .font(.caption)
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6]))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                    )
                
                if filePath.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: systemImage)
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Browse File...") {
                            selectFile()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding()
                } else {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 34))
                            .foregroundColor(fileExists ? .accentColor : .secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(URL(fileURLWithPath: filePath).lastPathComponent)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                
                                if !fileExists {
                                    Text("(File Not Found)")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            Text(filePath)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            // Action Buttons
                            HStack(spacing: 8) {
                                Button(action: openFile) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.forward.app")
                                        Text("Open File")
                                    }
                                    .font(.caption2)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(!fileExists)
                                .help("Open in Preview or default application")
                                
                                Button(action: revealInFinder) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder")
                                        Text("Reveal in Finder")
                                    }
                                    .font(.caption2)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(!fileExists)
                                .help("Reveal file in macOS Finder")
                            }
                            .padding(.top, 2)
                        }
                        
                        Spacer()
                        
                        Button(action: { filePath = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .help("Clear selection")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button(action: openFile) {
                            Label("Open File", systemImage: "arrow.up.forward.app")
                        }
                        .disabled(!fileExists)
                        
                        Button(action: revealInFinder) {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        .disabled(!fileExists)
                        
                        Divider()
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(filePath, forType: .string)
                        }) {
                            Label("Copy File Path", systemImage: "doc.on.doc")
                        }
                        
                        Button(action: selectFile) {
                            Label("Change File...", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { filePath = "" }) {
                            Label("Clear", systemImage: "trash")
                        }
                    }
                }
            }
            .frame(minHeight: 104)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            self.filePath = url.path
                        }
                    }
                }
                return true
            }
        }
    }
    
    private func openFile() {
        guard fileExists else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
    }
    
    private func revealInFinder() {
        guard fileExists else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: filePath)])
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [fileType == "pdf" ? UTType.pdf : UTType.item]
        
        if panel.runModal() == .OK, let url = panel.url {
            self.filePath = url.path
        }
    }
}
