import SwiftUI
import AppKit

public struct AIChatView: View {
    @ObservedObject public var chatManager: AIChatManager
    public var presetManager: PresetManager?
    public var themeManager: HTMLThemeManager?
    @Binding public var config: NotebookConfig
    public var onNavigateToStudio: ((String?) -> Void)? = nil
    public var onNavigateToPresets: (() -> Void)? = nil
    
    @ObservedObject private var bridge = AIAgentBridge.shared
    @ObservedObject private var registry = TemplateRegistry.shared
    
    @State private var inputText: String = ""
    @State private var showingConfigSheet: Bool = false
    @State private var activeTemplateName: String = "Lined Paper"
    @State private var activeTemplateHTML: String = ""
    @State private var activeCSSTokens: String = ""
    @State private var previewHTMLModal: String? = nil
    @State private var copiedMessageId: UUID? = nil
    @State private var savedTemplateSuccess: String? = nil
    
    // Image Attachment States
    @State private var attachedImage: NSImage? = nil
    @State private var attachedImageURL: URL? = nil
    @State private var attachedImageName: String = ""
    @State private var isTargetedForDrop: Bool = false
    
    public init(
        chatManager: AIChatManager,
        presetManager: PresetManager? = nil,
        themeManager: HTMLThemeManager? = nil,
        config: Binding<NotebookConfig>,
        onNavigateToStudio: ((String?) -> Void)? = nil,
        onNavigateToPresets: (() -> Void)? = nil
    ) {
        self.chatManager = chatManager
        self.presetManager = presetManager
        self.themeManager = themeManager
        self._config = config
        self.onNavigateToStudio = onNavigateToStudio
        self.onNavigateToPresets = onNavigateToPresets
    }
    
    public var body: some View {
        HSplitView {
            // LEFT COLUMN: Sessions List
            VStack(spacing: 0) {
                // Header
                HStack {
                    Label("Conversations", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        _ = chatManager.startNewSession()
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .help("New Conversation")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Sessions List
                List(selection: $chatManager.activeSessionId) {
                    ForEach(chatManager.sessions) { session in
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundColor(session.id == chatManager.activeSessionId ? .accentColor : .secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.subheadline)
                                    .fontWeight(session.id == chatManager.activeSessionId ? .semibold : .regular)
                                    .lineLimit(1)
                                
                                Text(formatDate(session.updatedAt))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if chatManager.sessions.count > 1 {
                                Button(action: {
                                    chatManager.deleteSession(id: session.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption2)
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .buttonStyle(.borderless)
                                .help("Delete Conversation")
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(session.id)
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 220, idealWidth: 250, maxWidth: 300)
            
            // RIGHT COLUMN: Active Chat Thread
            VStack(spacing: 0) {
                // Chat Header
                chatHeader
                
                Divider()
                
                // Messages ScrollView
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(chatManager.activeSession.messages) { message in
                                messageRow(for: message)
                                    .id(message.id)
                            }
                            
                            // Streaming / In-flight Indicator
                            if bridge.isRunning {
                                inFlightIndicator
                                    .id("inFlight")
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: chatManager.activeSession.messages.count) { _ in
                        withAnimation {
                            if let lastId = chatManager.activeSession.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: bridge.isRunning) { running in
                        if running {
                            withAnimation {
                                proxy.scrollTo("inFlight", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Success Toast Banner
                if let success = savedTemplateSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(success)
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Button("Dismiss") {
                            savedTemplateSuccess = nil
                        }
                        .buttonStyle(.borderless)
                        .font(.caption2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.12))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Divider()
                
                // Quick Suggestion Chips
                quickPromptChipsBar
                
                // Input Composer with Image Attachment & Drag-and-Drop
                inputBar
            }
        }
        .sheet(isPresented: $showingConfigSheet) {
            AIConfigSheet(chatManager: chatManager)
        }
        .onAppear {
            loadActiveTemplateContext()
        }
    }
    
    // MARK: - Header
    private var chatHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(chatManager.activeSession.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Config Pill
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.caption2)
                        Text("\(chatManager.config.model) (\(chatManager.config.effort))")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)
                }
                
                Text("Powered by \(chatManager.config.provider.rawValue) • Full Mortalpages Studio Design Context Attached")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { showingConfigSheet = true }) {
                Label("AI Settings", systemImage: "gearshape.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button(action: {
                let id = chatManager.startNewSession()
                chatManager.activeSessionId = id
            }) {
                Label("New Chat", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Message Row
    @ViewBuilder
    private func messageRow(for message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(LinearGradient(colors: [.accentColor, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Header (Role & Time)
                HStack {
                    Text(message.role == .user ? "You" : "mortalpages AI")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                // Attached Image Thumbnail inside Message Bubble if present
                if let imgPath = message.attachedImagePath,
                   let nsImg = NSImage(contentsOfFile: imgPath) {
                    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 260, maxHeight: 180)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.caption2)
                            Text("Attached Reference Image")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                // Text Bubble
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundColor(message.role == .user ? .white : Color(NSColor.labelColor))
                    .padding(12)
                    .background(message.role == .user ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .textSelection(.enabled)
                
                // Extracted HTML Code Card if available
                if let html = message.extractedHTML, !html.isEmpty {
                    templateCodeCard(html: html, suggestedName: message.suggestedTemplateName)
                }
                
                // Extracted Theme Preset Card if available
                if let preset = message.extractedPreset {
                    presetCard(preset: preset)
                }
            }
            
            if message.role == .user {
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.8))
                    .clipShape(Circle())
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
    
    // MARK: - Template Code Card
    @ViewBuilder
    private func templateCodeCard(html: String, suggestedName: String?) -> some View {
        let title = suggestedName ?? bridge.extractTitle(from: html) ?? "Custom Generated Template"
        
        VStack(alignment: .leading, spacing: 10) {
            // Card Header
            HStack(spacing: 8) {
                Image(systemName: "doc.richtext.fill")
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Ready-to-use 1152×1485 Vector HTML/CSS Template")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    saveAsCustomTemplate(title: title, html: html)
                }) {
                    Label("Save to Library", systemImage: "arrow.down.doc.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            Divider()
            
            // Code snippet preview
            ScrollView(.horizontal, showsIndicators: false) {
                Text(html.prefix(800) + (html.count > 800 ? "\n... (truncated for display, \(html.count) characters total)" : ""))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(8)
            }
            .frame(maxHeight: 120)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(6)
            
            // Actions Row
            HStack(spacing: 8) {
                Button(action: {
                    copyToClipboard(html)
                    savedTemplateSuccess = "HTML copied to clipboard!"
                }) {
                    Label("Copy HTML", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: {
                    if let saved = saveAsCustomTemplate(title: title, html: html) {
                        onNavigateToStudio?(saved.relativePath)
                    }
                }) {
                    Label("Open in Studio Preview", systemImage: "paintbrush.pointed")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Text("\(html.count) bytes • HTML5 + CSS3")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(10)
    }
    
    // MARK: - Generated Theme Preset Card
    @ViewBuilder
    private func presetCard(preset: GeneratedPresetData) -> some View {
        AIGeneratedPresetCard(
            preset: preset,
            isCurrentActive: config.themeName == preset.name,
            onApply: {
                applyGeneratedPreset(preset)
            },
            onOpenStudio: {
                applyGeneratedPreset(preset)
                onNavigateToStudio?(nil)
            },
            onCopyCSS: {
                let css = generateCSSTokens(from: preset.variables)
                copyToClipboard(css)
                savedTemplateSuccess = "Theme CSS variables copied to clipboard!"
            }
        )
    }
    
    // MARK: - In-flight Loading Indicator
    private var inFlightIndicator: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    
                    Text(bridge.statusMessage.isEmpty ? "Reasoning with \(chatManager.config.model)..." : bridge.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        bridge.cancelCurrentTask()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    .foregroundColor(.red)
                }
                
                if !bridge.currentOutput.isEmpty {
                    Text(bridge.currentOutput.suffix(200))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Suggestion Chips
    private var quickPromptChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(icon: "sparkles", label: "🎃 Halloween Spooky Theme") {
                    sendQuickPrompt("Create a preset with Halloween theme: dark obsidian canvas, pumpkin orange accents, midnight purple tabs, and ghostly green lines.")
                }
                
                chipButton(icon: "leaf.fill", label: "🍂 Autumn Harvest Preset") {
                    sendQuickPrompt("Create an Autumn Harvest theme preset with warm honey canvas, burnt orange accents, and rustic walnut tabs.")
                }
                
                chipButton(icon: "bolt.fill", label: "🌌 Cyberpunk Neon Theme") {
                    sendQuickPrompt("Create a Cyberpunk Neon theme preset with ultra dark canvas, electric cyan accents, and hot magenta tabs.")
                }
                
                chipButton(icon: "calendar", label: "Half Calendar + Daily Notes") {
                    sendQuickPrompt("Create a daily template where the top half is an interactive mini-calendar & schedule, and the bottom half has 3 columns: Top Priorities, Notes, and Gratitude.")
                }
                
                chipButton(icon: "dollarsign.circle", label: "Monthly Budget & Expense") {
                    sendQuickPrompt("Create a clean monthly budget & expense tracker template with income vs expenses cards, category breakdowns, and a savings goal meter.")
                }
                
                chipButton(icon: "text.book.closed", label: "Cornell Notes Layout") {
                    sendQuickPrompt("Design a professional Cornell note-taking template with a 2.5-inch cue/keyword column on the left, lined notes area on the right, and a summary block at the bottom.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func chipButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(bridge.isRunning)
    }
    
    // MARK: - Input Bar (With Multimodal Image Attachment)
    private var inputBar: some View {
        VStack(spacing: 8) {
            // Attached Image Preview Chip
            if let img = attachedImage {
                HStack(spacing: 10) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                        .clipped()
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(attachedImageName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button(action: removeAttachedImage) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Remove attached image")
                        }
                        
                        Text("Visual reference will be inspected and replicated by \(chatManager.config.model)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
            }
            
            HStack(alignment: .bottom, spacing: 10) {
                // Multiline text input
                TextEditor(text: $inputText)
                    .font(.system(size: 13))
                    .frame(minHeight: 38, maxHeight: 100)
                    .padding(6)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isTargetedForDrop ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isTargetedForDrop ? 2 : 1)
                    )
                
                // Send button
                Button(action: executePrompt) {
                    if bridge.isRunning {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImage == nil) ? .secondary : .accentColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImage == nil) || bridge.isRunning)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            
            // Toolbar Actions: Attach Image, Paste Clipboard Image & Drag-and-drop info
            HStack(spacing: 8) {
                Button(action: attachImageFromFile) {
                    Label("Attach Image...", systemImage: "photo")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: pasteImageFromClipboard) {
                    Label("Paste Clipboard Image", systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Text("Press ⌘ + Return to send • Paste image (⌘V) or drag & drop directly")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .onDrop(of: ["public.file-url", "public.image"], isTargeted: $isTargetedForDrop) { providers in
            for provider in providers {
                if provider.canLoadObject(ofClass: URL.self) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url, let img = NSImage(contentsOf: url) {
                            DispatchQueue.main.async {
                                self.saveAndAttachImage(img, name: url.lastPathComponent)
                            }
                        }
                    }
                    return true
                }
            }
            return false
        }
    }
    
    // MARK: - Actions
    private func executePrompt() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty || attachedImageURL != nil else { return }
        
        let sentPrompt = prompt.isEmpty ? "Please recreate this attached image layout into a complete vector HTML/CSS digital journal template." : prompt
        let currentAttachedPath = attachedImageURL?.path
        
        inputText = ""
        removeAttachedImage()
        
        chatManager.addMessage(role: .user, content: sentPrompt, attachedImagePath: currentAttachedPath)
        
        bridge.sendPrompt(
            userPrompt: sentPrompt,
            config: chatManager.config,
            attachedImagePath: currentAttachedPath,
            activeTemplateHTML: activeTemplateHTML,
            activeTemplateName: activeTemplateName,
            cssVariables: activeCSSTokens
        ) { result in
            switch result {
            case .success(let execResult):
                let formattedHTML = execResult.extractedHTML != nil ? CodeBeautifier.formatHTML(execResult.extractedHTML!) : nil
                self.chatManager.addMessage(
                    role: .assistant,
                    content: execResult.output,
                    extractedHTML: formattedHTML,
                    suggestedName: execResult.suggestedTitle,
                    extractedPreset: execResult.extractedPreset
                )
                
                // Auto-apply preset if returned (activates completely by itself!)
                if let preset = execResult.extractedPreset {
                    self.applyGeneratedPreset(preset)
                }
                
                // Auto-apply template if configured
                if self.chatManager.config.autoApplyChanges, let html = formattedHTML {
                    let title = execResult.suggestedTitle ?? "AI Custom Template"
                    _ = self.saveAsCustomTemplate(title: title, html: html)
                }
                
            case .failure(let error):
                self.chatManager.addMessage(
                    role: .assistant,
                    content: "⚠️ **CLI Execution Error:** \(error.localizedDescription)\n\nPlease verify that `\(self.chatManager.config.provider.rawValue)` is working properly in AI Settings."
                )
            }
        }
    }
    
    private func sendQuickPrompt(_ prompt: String) {
        inputText = prompt
        executePrompt()
    }
    
    // MARK: - Image Handling Helpers
    private func attachImageFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Template Image Reference"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .webP, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            saveAndAttachImage(img, name: url.lastPathComponent)
        }
    }
    
    private func pasteImageFromClipboard() {
        let pb = NSPasteboard.general
        if let image = NSImage(pasteboard: pb) {
            saveAndAttachImage(image, name: "Clipboard Image (\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)))")
        } else if let fileURLs = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
                  let firstURL = fileURLs.first,
                  let image = NSImage(contentsOf: firstURL) {
            saveAndAttachImage(image, name: firstURL.lastPathComponent)
        } else {
            savedTemplateSuccess = "No image found on clipboard. Copy an image or screenshot first!"
        }
    }
    
    private func saveAndAttachImage(_ image: NSImage, name: String) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let attachDir = appSupport.appendingPathComponent("mortalpages Studio/Attachments")
        try? FileManager.default.createDirectory(at: attachDir, withIntermediateDirectories: true)
        
        let fileURL = attachDir.appendingPathComponent("\(UUID().uuidString).png")
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: fileURL)
                self.attachedImage = image
                self.attachedImageURL = fileURL
                self.attachedImageName = name
            } catch {
                print("Failed to write attached image: \(error)")
            }
        }
    }
    
    private func removeAttachedImage() {
        self.attachedImage = nil
        self.attachedImageURL = nil
        self.attachedImageName = ""
    }
    
    @discardableResult
    private func saveAsCustomTemplate(title: String, html: String) -> DynamicTemplate? {
        if let created = registry.saveCustomTemplate(name: title, htmlContent: html) {
            withAnimation {
                self.savedTemplateSuccess = "Saved \"\(title)\" to Custom Templates! Available immediately in Template Studio."
            }
            return created
        }
        return nil
    }
    
    private func loadActiveTemplateContext() {
        let baseDir = registry.baseDirectory
        let linedURL = baseDir.appendingPathComponent("Lined/medium_line.html")
        let cssURL = baseDir.appendingPathComponent("Base/theme_variables.css")
        
        activeTemplateHTML = (try? String(contentsOf: linedURL, encoding: .utf8)) ?? ""
        activeCSSTokens = (try? String(contentsOf: cssURL, encoding: .utf8)) ?? ""
    }
    
    private func applyGeneratedPreset(_ preset: GeneratedPresetData) {
        // 1. Add/Update in PresetManager
        if let pm = presetManager {
            var newConfig = config
            newConfig.themeName = preset.name
            _ = pm.addOrUpdatePreset(name: preset.name, description: preset.description, config: newConfig)
        }
        
        // 2. Add/Update in HTMLThemeManager
        if let tm = themeManager {
            let theme = tm.addOrUpdateTheme(name: preset.name, description: preset.description, variables: preset.variables)
            tm.activeTheme = theme
        }
        
        // 3. Update active notebook config theme
        config.themeName = preset.name
        
        withAnimation {
            self.savedTemplateSuccess = "✓ Activated \"\(preset.name)\" preset! Live preview & PDF compiler updated."
        }
    }
    
    private func generateCSSTokens(from vars: [String: String]) -> String {
        var str = ":root {\n"
        for key in vars.keys.sorted() {
            str += "  \(key): \(vars[key] ?? "");\n"
        }
        str += "}\n"
        return str
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Standalone Preset Card View
public struct AIGeneratedPresetCard: View {
    public let preset: GeneratedPresetData
    public let isCurrentActive: Bool
    public let onApply: () -> Void
    public let onOpenStudio: () -> Void
    public let onCopyCSS: () -> Void
    
    public init(
        preset: GeneratedPresetData,
        isCurrentActive: Bool,
        onApply: @escaping () -> Void,
        onOpenStudio: @escaping () -> Void,
        onCopyCSS: @escaping () -> Void
    ) {
        self.preset = preset
        self.isCurrentActive = isCurrentActive
        self.onApply = onApply
        self.onOpenStudio = onOpenStudio
        self.onCopyCSS = onCopyCSS
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            Divider()
            paletteSection
            Divider()
            actionsRow
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrentActive ? Color.green.opacity(0.4) : Color.accentColor.opacity(0.3), lineWidth: 1.5)
        )
        .cornerRadius(10)
    }
    
    private var headerRow: some View {
        HStack(spacing: 10) {
            ZStack {
                let accentHex = preset.variables["--accent-color"] ?? "#FF7518"
                LinearGradient(
                    colors: [Color(hex: accentHex), Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "paintpalette.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(width: 36, height: 36)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(preset.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if isCurrentActive {
                        Text("ACTIVE THEME")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.2)))
                            .foregroundColor(.green)
                    } else {
                        Text("SAVED TO PRESETS")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                            .foregroundColor(.accentColor)
                    }
                }
                
                Text(preset.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isCurrentActive {
                Button(action: onApply) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Active")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button(action: onApply) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Apply Theme")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
    
    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Theme Palette Swatches:")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                swatchItem(name: "Canvas", hex: preset.variables["--page-bg"] ?? "#FAF8F5")
                swatchItem(name: "Accent", hex: preset.variables["--accent-color"] ?? "#FF7518")
                swatchItem(name: "Text", hex: preset.variables["--text-main"] ?? "#3C3835")
                swatchItem(name: "Active Tab", hex: preset.variables["--tab-active-bg"] ?? "#FF7518")
                swatchItem(name: "Tabs", hex: preset.variables["--tab-bg"] ?? "rgba(60, 56, 53, 0.1)")
                swatchItem(name: "Rules", hex: preset.variables["--grid-color"] ?? "rgba(60, 56, 53, 0.08)")
            }
        }
    }
    
    private func swatchItem(name: String, hex: String) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: hex))
                .frame(width: 44, height: 26)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.35), lineWidth: 1))
            
            Text(name)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
    
    private var actionsRow: some View {
        HStack(spacing: 8) {
            Button(action: onOpenStudio) {
                Label("View in Template Studio", systemImage: "paintbrush.pointed")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button(action: onCopyCSS) {
                Label("Copy CSS Tokens", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Spacer()
            
            Text("\(preset.variables.count) CSS tokens • 1-Click Design System")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
