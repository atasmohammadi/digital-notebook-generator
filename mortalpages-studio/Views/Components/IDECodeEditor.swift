import SwiftUI
import AppKit

public struct IDECodeEditor: View {
    @Binding public var text: String
    public let language: CodeLanguage
    public var onSave: (() -> Void)? = nil
    
    @State private var lineCount: Int = 1
    @State private var characterCount: Int = 0
    @State private var formattedNotification: Bool = false
    
    public init(text: Binding<String>, language: CodeLanguage, onSave: (() -> Void)? = nil) {
        self._text = text
        self.language = language
        self.onSave = onSave
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // IDE Editor Toolbar
            HStack(spacing: 10) {
                // Language Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(language == .html ? Color.orange : Color.blue)
                        .frame(width: 8, height: 8)
                    Text(language == .html ? "HTML5" : "CSS3")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
                
                // Stats: Lines & Characters
                Text("\(lineCount) lines • \(characterCount) chars")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if formattedNotification {
                    Text("✓ Formatted")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
                
                // Format Code Button (⌥⇧F)
                Button(action: formatCurrentCode) {
                    Label("Format Code 🪄", systemImage: "wand.and.stars")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Beautify & auto-indent code (⌥⇧F)")
                .keyboardShortcut("f", modifiers: [.option, .shift])
                
                // Save & Reload Button
                if let saveAction = onSave {
                    Button(action: saveAction) {
                        Label("Save & Hot-Reload ⚡", systemImage: "bolt.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Save & Hot-Reload Preview (⌘S)")
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Editor Body with Line Numbers & Real-time Syntax Highlighting
            IDEEditorRepresentable(text: $text, language: language, onMetricsChanged: { lines, chars in
                self.lineCount = lines
                self.characterCount = chars
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updateMetrics(for: text)
        }
    }
    
    private func formatCurrentCode() {
        if language == .html {
            text = CodeBeautifier.formatHTML(text)
        } else {
            text = CodeBeautifier.formatCSS(text)
        }
        updateMetrics(for: text)
        withAnimation {
            formattedNotification = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                formattedNotification = false
            }
        }
    }
    
    private func updateMetrics(for string: String) {
        lineCount = string.components(separatedBy: .newlines).count
        characterCount = string.count
    }
}

// MARK: - AppKit Native NSTextView with Syntax Storage & Gutter
struct IDEEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    let language: CodeLanguage
    var onMetricsChanged: ((Int, Int) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        
        let textView = IDEAppKitTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 1000), textContainer: textContainer)
        textView.language = language
        textView.delegate = context.coordinator
        textView.string = text
        
        scrollView.documentView = textView
        
        // Critical: configure sizing constraints AFTER setting documentView
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        
        textView.applyHighlighting()
        layoutManager.ensureLayout(for: textContainer)
        textView.sizeToFit()
        
        let ruler = IDELineNumberRulerView(scrollView: scrollView, textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.contentView.postsFrameChangedNotifications = true
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.clipViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.clipViewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView.contentView
        )
        
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? IDEAppKitTextView else { return }
        
        if textView.language != language {
            textView.language = language
            textView.applyHighlighting()
        }
        
        if textView.string != text {
            textView.string = text
            textView.applyHighlighting()
            
            textView.minSize = NSSize(width: 0, height: 0)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            if let tc = textView.textContainer, let lm = textView.layoutManager {
                lm.ensureLayout(for: tc)
                textView.sizeToFit()
            }
            
            nsView.verticalRulerView?.needsDisplay = true
            onMetricsChanged?(text.components(separatedBy: .newlines).count, text.count)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: IDEEditorRepresentable
        weak var textView: IDEAppKitTextView?
        
        init(parent: IDEEditorRepresentable) {
            self.parent = parent
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func clipViewBoundsDidChange(_ notification: Notification) {
            textView?.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }
        
        @objc func clipViewFrameDidChange(_ notification: Notification) {
            guard let tv = textView, let tc = tv.textContainer, let lm = tv.layoutManager else { return }
            tv.minSize = NSSize(width: 0, height: 0)
            tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            lm.ensureLayout(for: tc)
            tv.sizeToFit()
            tv.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }
        
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? IDEAppKitTextView else { return }
            parent.text = tv.string
            tv.minSize = NSSize(width: 0, height: 0)
            tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            if let tc = tv.textContainer, let lm = tv.layoutManager {
                lm.ensureLayout(for: tc)
                tv.sizeToFit()
            }
            tv.enclosingScrollView?.verticalRulerView?.needsDisplay = true
            parent.onMetricsChanged?(tv.string.components(separatedBy: .newlines).count, tv.string.count)
        }
    }
}

// MARK: - Custom NSTextView with Soft Tabs & Syntax Highlighting
class IDEAppKitTextView: NSTextView {
    var language: CodeLanguage = .html
    
    override init(frame frameRect: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: textContainer)
        setupDefaults()
    }
    
    convenience override init(frame frameRect: NSRect) {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(containerSize: NSSize(width: frameRect.width > 0 ? frameRect.width : 400, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        self.init(frame: frameRect, textContainer: textContainer)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDefaults()
    }
    
    private func setupDefaults() {
        self.isRichText = true
        self.allowsUndo = true
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isAutomaticDashSubstitutionEnabled = false
        self.isAutomaticTextReplacementEnabled = false
        self.isAutomaticSpellingCorrectionEnabled = false
        self.font = SyntaxHighlighter.codeFont
        self.backgroundColor = NSColor.textBackgroundColor
        self.textColor = NSColor.textColor
        self.insertionPointColor = NSColor.controlAccentColor
        self.textContainerInset = NSSize(width: 8, height: 8)
        self.minSize = NSSize(width: 0, height: 0)
        self.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        self.isVerticallyResizable = true
        self.isHorizontallyResizable = false
        self.autoresizingMask = [.width]
        self.textContainer?.widthTracksTextView = true
        self.textContainer?.heightTracksTextView = false
    }
    
    override func didChangeText() {
        super.didChangeText()
        applyHighlighting()
        enclosingScrollView?.verticalRulerView?.needsDisplay = true
    }
    
    public func applyHighlighting() {
        guard let storage = self.textStorage else { return }
        let selectedRanges = self.selectedRanges
        storage.beginEditing()
        SyntaxHighlighter.highlight(attributedString: storage, language: language)
        storage.endEditing()
        self.selectedRanges = selectedRanges
    }
    
    // Soft Tab support (Insert 2 spaces on Tab key)
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 { // Tab key
            if event.modifierFlags.contains(.shift) {
                // Shift-Tab: Unindent
                super.keyDown(with: event)
            } else {
                // Tab: Insert 2 spaces
                self.insertText("  ", replacementRange: self.selectedRange())
            }
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Line Number Gutter Ruler View
class IDELineNumberRulerView: NSRulerView {
    init(scrollView: NSScrollView, textView: NSTextView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 40.0
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func scrollWheel(with event: NSEvent) {
        self.enclosingScrollView?.scrollWheel(with: event)
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = self.clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }
        
        let visibleRect = textView.visibleRect
        guard visibleRect.width > 0 && visibleRect.height > 0 else { return }
        
        let bgBounds = NSRect(x: 0, y: rect.origin.y, width: self.ruleThickness, height: rect.height)
        NSColor.controlBackgroundColor.setFill()
        bgBounds.fill()
        
        // Right border stroke for gutter
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: self.ruleThickness - 0.5, y: rect.origin.y))
        path.line(to: NSPoint(x: self.ruleThickness - 0.5, y: rect.origin.y + rect.height))
        path.stroke()
        
        let text = textView.string as NSString
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        if text.length == 0 {
            let numStr = "1" as NSString
            let strSize = numStr.size(withAttributes: textAttributes)
            let drawRect = NSRect(x: self.ruleThickness - strSize.width - 8, y: textView.textContainerInset.height + 1, width: strSize.width, height: strSize.height)
            numStr.draw(in: drawRect, withAttributes: textAttributes)
            return
        }
        
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        var lineNumber = 1
        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: [.byLines, .substringNotRequired]) { _, substringRange, _, stop in
            if substringRange.location >= charRange.location + charRange.length {
                stop.pointee = true
            }
            
            if substringRange.location >= charRange.location || (substringRange.location + substringRange.length) >= charRange.location {
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: substringRange.location)
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                
                let yPos = lineRect.origin.y + textView.textContainerInset.height - visibleRect.origin.y
                let numStr = "\(lineNumber)" as NSString
                let strSize = numStr.size(withAttributes: textAttributes)
                let drawRect = NSRect(x: self.ruleThickness - strSize.width - 8, y: yPos + 1, width: strSize.width, height: strSize.height)
                
                numStr.draw(in: drawRect, withAttributes: textAttributes)
            }
            
            lineNumber += 1
        }
    }
}
