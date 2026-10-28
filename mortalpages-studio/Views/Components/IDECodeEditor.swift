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
            .background(Color(NSColor.textBackgroundColor))
        }
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
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        // Setup Line Gutter View
        let textView = IDEAppKitTextView(frame: .zero)
        textView.language = language
        textView.textDelegate = context.coordinator
        textView.string = text
        textView.applyHighlighting()
        
        let ruler = IDELineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? IDEAppKitTextView else { return }
        if textView.string != text {
            textView.string = text
            textView.applyHighlighting()
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
        
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? IDEAppKitTextView else { return }
            parent.text = tv.string
            tv.enclosingScrollView?.verticalRulerView?.needsDisplay = true
            parent.onMetricsChanged?(tv.string.components(separatedBy: .newlines).count, tv.string.count)
        }
    }
}

// MARK: - Custom NSTextView with Soft Tabs & Syntax Highlighting
class IDEAppKitTextView: NSTextView {
    var language: CodeLanguage = .html
    weak var textDelegate: NSTextViewDelegate?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDefaults()
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
        self.isHorizontallyResizable = true
        self.textContainer?.widthTracksTextView = false
        self.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    }
    
    override func didChangeText() {
        super.didChangeText()
        applyHighlighting()
        textDelegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
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
    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 42.0
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = self.clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }
        
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
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
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
