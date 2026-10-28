import SwiftUI
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
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if !filePath.isEmpty {
                    Button(action: {
                        selectFile()
                    }) {
                        Text("Change...")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
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
                    HStack(spacing: 12) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(URL(fileURLWithPath: filePath).lastPathComponent)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(filePath)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button(action: { filePath = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
            .frame(height: 100)
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
