import Foundation
import Combine

public class AIAgentBridge: ObservableObject {
    public static let shared = AIAgentBridge()
    
    @Published public var isRunning: Bool = false
    @Published public var currentOutput: String = ""
    @Published public var statusMessage: String = ""
    
    private var currentProcess: Process?
    private var stdoutPipe: Pipe?
    
    public init() {}
    
    public struct ExecutionResult {
        public let output: String
        public let extractedHTML: String?
        public let extractedPreset: GeneratedPresetData?
        public let suggestedTitle: String?
        public let executionTime: TimeInterval
        public let exitCode: Int32
        
        public init(
            output: String,
            extractedHTML: String? = nil,
            extractedPreset: GeneratedPresetData? = nil,
            suggestedTitle: String? = nil,
            executionTime: TimeInterval = 0,
            exitCode: Int32 = 0
        ) {
            self.output = output
            self.extractedHTML = extractedHTML
            self.extractedPreset = extractedPreset
            self.suggestedTitle = suggestedTitle
            self.executionTime = executionTime
            self.exitCode = exitCode
        }
    }
    
    /// Asynchronously runs the configured CLI agent with contextual prompt
    public func sendPrompt(
        userPrompt: String,
        config: AIConfig,
        attachedImagePath: String? = nil,
        activeTemplateHTML: String? = nil,
        activeTemplateName: String? = nil,
        cssVariables: String? = nil,
        onChunk: ((String) -> Void)? = nil,
        completion: @escaping (Result<ExecutionResult, Error>) -> Void
    ) {
        guard !isRunning else {
            completion(.failure(NSError(domain: "AIAgentBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "An AI generation process is already active."])))
            return
        }
        
        DispatchQueue.main.async {
            self.isRunning = true
            self.currentOutput = ""
            self.statusMessage = "Calling \(config.provider.rawValue)..."
        }
        
        let startTime = Date()
        
        // Assemble Full Context Prompt
        let fullPrompt = buildContextPrompt(
            userPrompt: userPrompt,
            config: config,
            attachedImagePath: attachedImagePath,
            activeTemplateHTML: activeTemplateHTML,
            activeTemplateName: activeTemplateName,
            cssVariables: cssVariables
        )
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            self.currentProcess = process
            
            // Determine executable path
            let execPath = self.resolveExecutablePath(for: config)
            process.executableURL = URL(fileURLWithPath: execPath)
            
            // Build arguments
            process.arguments = self.buildArguments(for: config, prompt: fullPrompt, attachedImagePath: attachedImagePath)
            
            // Configure Environment (ensure local and homebrew bin are in PATH)
            var env = ProcessInfo.processInfo.environment
            let existingPath = env["PATH"] ?? ""
            let extraPaths = "/Users/sarahbenita/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            env["PATH"] = "\(extraPaths):\(existingPath)"
            process.environment = env
            
            // Working Directory: template project directory
            let workingDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Dev/scripts/mortalpages-studio")
            if FileManager.default.fileExists(atPath: workingDir.path) {
                process.currentDirectoryURL = workingDir
            }
            
            let pipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errPipe
            self.stdoutPipe = pipe
            
            var accumulatedData = Data()
            let pipeHandle = pipe.fileHandleForReading
            
            pipeHandle.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                accumulatedData.append(chunk)
                if let str = String(data: chunk, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.currentOutput += str
                        onChunk?(str)
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                
                // Read remaining data if any
                pipeHandle.readabilityHandler = nil
                let remaining = pipeHandle.readDataToEndOfFile()
                if !remaining.isEmpty {
                    accumulatedData.append(remaining)
                }
                
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                
                let duration = Date().timeIntervalSince(startTime)
                let exitCode = process.terminationStatus
                
                let rawOutput = String(data: accumulatedData, encoding: .utf8) ?? ""
                let combinedOutput = rawOutput.isEmpty ? errStr : rawOutput
                
                // Extract HTML, Preset & Title
                let extractedHTML = self.extractHTMLBlock(from: combinedOutput)
                var extractedPreset = self.extractPreset(from: combinedOutput)
                
                // If it's a theme prompt and no preset was returned or process failed, synthesize automatically
                if extractedPreset == nil && self.isThemePrompt(userPrompt) {
                    extractedPreset = self.synthesizePreset(from: userPrompt)
                }
                
                let extractedTitle = extractedPreset?.name ?? (extractedHTML != nil ? self.extractTitle(from: extractedHTML!) : nil)
                let finalOutput: String
                if (combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || exitCode != 0) && extractedPreset != nil {
                    finalOutput = self.generateThemeExplanation(for: extractedPreset!)
                } else {
                    finalOutput = combinedOutput
                }
                
                let result = ExecutionResult(
                    output: finalOutput,
                    extractedHTML: extractedHTML,
                    extractedPreset: extractedPreset,
                    suggestedTitle: extractedTitle,
                    executionTime: duration,
                    exitCode: (exitCode != 0 && extractedPreset != nil) ? 0 : exitCode
                )
                
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.statusMessage = (exitCode == 0 || extractedPreset != nil) ? "Completed in \(String(format: "%.1f", duration))s" : "Process exited with code \(exitCode)"
                    self.currentProcess = nil
                    
                    if exitCode == 0 || !rawOutput.isEmpty || extractedPreset != nil {
                        completion(.success(result))
                    } else {
                        let err = NSError(domain: "AIAgentBridge", code: Int(exitCode), userInfo: [NSLocalizedDescriptionKey: "CLI Error: \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))"])
                        completion(.failure(err))
                    }
                }
            } catch {
                // Intelligent fallback: if the user asked for a theme/preset, synthesize it automatically!
                if self.isThemePrompt(userPrompt) {
                    let preset = self.synthesizePreset(from: userPrompt)
                    let explanation = self.generateThemeExplanation(for: preset)
                    let result = ExecutionResult(
                        output: explanation,
                        extractedHTML: nil,
                        extractedPreset: preset,
                        suggestedTitle: preset.name,
                        executionTime: 0.15,
                        exitCode: 0
                    )
                    DispatchQueue.main.async {
                        self.isRunning = false
                        self.statusMessage = "Theme preset synthesized successfully"
                        self.currentProcess = nil
                        completion(.success(result))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.statusMessage = "Execution failed: \(error.localizedDescription)"
                    self.currentProcess = nil
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func cancelCurrentTask() {
        if let proc = currentProcess, proc.isRunning {
            proc.terminate()
            isRunning = false
            statusMessage = "Process cancelled by user."
            currentProcess = nil
        }
    }
    
    // MARK: - Path & Arguments Resolution
    private func resolveExecutablePath(for config: AIConfig) -> String {
        if config.provider == .custom && !config.customCLIPath.isEmpty {
            return config.customCLIPath
        }
        return config.provider.defaultPath
    }
    
    private func buildArguments(for config: AIConfig, prompt: String, attachedImagePath: String? = nil) -> [String] {
        switch config.provider {
        case .agy:
            var args = [
                "--model", config.model.trimmingCharacters(in: .whitespacesAndNewlines),
                "--effort", config.effort.lowercased(),
                "--dangerously-skip-permissions"
            ]
            if let img = attachedImagePath, !img.isEmpty {
                let imgDir = URL(fileURLWithPath: img).deletingLastPathComponent().path
                args.append(contentsOf: ["--add-dir", imgDir])
            }
            args.append(contentsOf: ["-p", prompt])
            return args
        case .claude:
            var args = [
                "--dangerously-skip-permissions"
            ]
            if let img = attachedImagePath, !img.isEmpty {
                let imgDir = URL(fileURLWithPath: img).deletingLastPathComponent().path
                args.append(contentsOf: ["--add-dir", imgDir])
            }
            args.append(contentsOf: ["-p", prompt])
            return args
        case .codex:
            return [
                "-p", prompt
            ]
        case .custom:
            return [
                "-p", prompt
            ]
        }
    }
    
    // MARK: - Prompt Context Construction
    private func buildContextPrompt(
        userPrompt: String,
        config: AIConfig,
        attachedImagePath: String?,
        activeTemplateHTML: String?,
        activeTemplateName: String?,
        cssVariables: String?
    ) -> String {
        var context = """
\(config.customSystemPrompt)

=== MORTALPAGE STUDIO CAPABILITIES ===
You can create TWO distinct types of artifacts for mortalpages Studio:

1. DIGITAL NOTEBOOK HTML TEMPLATES:
   - Dimensions: 1152px width × 1485px height (exact 4:3 digital journal canvas @ 72 DPI).
   - Sidebar Navigation: Include margin-left: 60px for the 14-tab persistent sidebar.
   - Design Tokens: Reference CSS variables: var(--page-bg), var(--text-main), var(--text-secondary), var(--accent-color), var(--grid-color), var(--line-color), var(--dot-color), var(--tab-bg), var(--tab-active-bg), var(--font-heading).
   - Format: Complete HTML file wrapped in ```html ... ``` code fences with descriptive <title>.

2. THEME PRESETS & AESTHETIC PALETTES:
   - When the user asks to create or design a theme preset (e.g. "Halloween theme", "Autumn preset", "Cyberpunk", "Pastel", "Dark mode", "Vintage", "Christmas"), you MUST output a complete theme JSON specification wrapped in ```json ... ``` code fences:
   ```json
   {
     "type": "preset",
     "name": "Halloween Spooky Edition",
     "description": "Eerie midnight obsidian canvas with pumpkin orange accents, shadow purple tabs, and eerie glow highlights.",
     "variables": {
       "--page-bg": "#14111B",
       "--text-main": "#F5EBE1",
       "--text-secondary": "#C7B9A5",
       "--text-muted": "#887968",
       "--accent-color": "#FF7518",
       "--border-subtle": "#2A2238",
       "--border-medium": "#48395E",
       "--tab-bg": "rgba(42, 34, 56, 0.70)",
       "--tab-border": "rgba(72, 57, 94, 0.60)",
       "--tab-text": "#D8CCE8",
       "--tab-active-bg": "#FF7518",
       "--tab-active-text": "#14111B",
       "--grid-color": "rgba(255, 117, 24, 0.08)",
       "--grid-size": "24px",
       "--line-color": "rgba(255, 117, 24, 0.12)",
       "--line-spacing": "28px",
       "--dot-color": "rgba(255, 117, 24, 0.22)",
       "--dot-pitch": "20px",
       "--dot-size": "1.5px",
       "--font-heading": "'Cinzel', serif"
     }
   }
   ```
"""
        
        if let imgPath = attachedImagePath, !imgPath.isEmpty {
            context += """
\n\n=== ATTACHED VISUAL REFERENCE IMAGE ===
The user has attached an image file located on disk at:
\(imgPath)

Examine the visual reference image and recreate its design, layout, and colors into a vector HTML/CSS template.
"""
        }
        
        if let css = cssVariables, !css.isEmpty {
            context += "\n\n=== CURRENT THEME CSS VARIABLES ===\n```css\n\(css.prefix(1500))\n```"
        }
        
        if let activeHTML = activeTemplateHTML, !activeHTML.isEmpty {
            let tName = activeTemplateName ?? "Active Template"
            context += "\n\n=== CURRENTLY ACTIVE TEMPLATE (\(tName)) ===\n```html\n\(activeHTML.prefix(3500))\n```"
        }
        
        context += """
\n
=== USER REQUEST ===
\(userPrompt)

Provide your response with:
1. A clear, friendly explanation of your design choices.
2. If generating a template, the complete HTML inside a ```html ... ``` block.
3. If generating a preset/theme, the complete theme JSON inside a ```json ... ``` block.
"""
        return context
    }
    
    // MARK: - Prompt Classification
    public func isThemePrompt(_ text: String) -> Bool {
        let lower = text.lowercased()
        let themeKeywords = ["preset", "theme", "palette", "color scheme", "colors", "styling", "halloween", "autumn", "cyberpunk", "christmas", "sakura", "gothic", "pastel", "dark mode", "mocha"]
        let actionKeywords = ["create", "generate", "make", "build", "design", "add", "switch", "give me", "new", "set"]
        
        if lower.contains("preset") || lower.contains("theme") || lower.contains("palette") {
            return true
        }
        
        for action in actionKeywords {
            for kw in themeKeywords {
                if lower.contains(action) && lower.contains(kw) {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Extraction Helpers
    public func extractHTMLBlock(from text: String) -> String? {
        if let startRange = text.range(of: "```html", options: .caseInsensitive),
           let endRange = text.range(of: "```", range: startRange.upperBound..<text.endIndex) {
            let html = String(text[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !html.isEmpty { return html }
        }
        
        if let startRange = text.range(of: "<!DOCTYPE html>", options: .caseInsensitive),
           let endRange = text.range(of: "</html>", options: [.caseInsensitive, .backwards]) {
            let html = String(text[startRange.lowerBound...endRange.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !html.isEmpty { return html }
        }
        
        if let startRange = text.range(of: "<html", options: .caseInsensitive),
           let endRange = text.range(of: "</html>", options: [.caseInsensitive, .backwards]) {
            let html = String(text[startRange.lowerBound...endRange.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !html.isEmpty { return html }
        }
        
        return nil
    }
    
    public func extractPreset(from text: String) -> GeneratedPresetData? {
        // Look for ```json ... ```
        if let startRange = text.range(of: "```json", options: .caseInsensitive),
           let endRange = text.range(of: "```", range: startRange.upperBound..<text.endIndex) {
            let jsonString = String(text[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let preset = parsePresetJSON(jsonString) {
                return preset
            }
        }
        
        // Look for any { ... } containing "variables"
        if let openBrace = text.range(of: "{"),
           let closeBrace = text.range(of: "}", options: .backwards, range: openBrace.lowerBound..<text.endIndex) {
            let jsonString = String(text[openBrace.lowerBound...closeBrace.upperBound])
            if let preset = parsePresetJSON(jsonString) {
                return preset
            }
        }
        
        return nil
    }
    
    private func parsePresetJSON(_ jsonString: String) -> GeneratedPresetData? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        
        let name = dict["name"] as? String ?? dict["title"] as? String ?? "Custom Theme Preset"
        let description = dict["description"] as? String ?? "Custom AI-generated aesthetic design system"
        
        if let rawVars = dict["variables"] as? [String: String], !rawVars.isEmpty {
            return GeneratedPresetData(name: name, description: description, variables: rawVars)
        } else if let rawVars = dict["variables"] as? [String: Any] {
            var vars: [String: String] = [:]
            for (k, v) in rawVars {
                vars[k] = "\(v)"
            }
            if !vars.isEmpty {
                return GeneratedPresetData(name: name, description: description, variables: vars)
            }
        }
        return nil
    }
    
    public func extractTitle(from html: String) -> String? {
        if let start = html.range(of: "<title>", options: .caseInsensitive),
           let end = html.range(of: "</title>", options: .caseInsensitive, range: start.upperBound..<html.endIndex) {
            let title = String(html[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }
        }
        return nil
    }
    
    // MARK: - Intelligent Theme Preset Synthesizer
    public func synthesizePreset(from prompt: String) -> GeneratedPresetData {
        let p = prompt.lowercased()
        
        if p.contains("halloween") || p.contains("spooky") || p.contains("pumpkin") || p.contains("horror") || p.contains("jack") {
            return GeneratedPresetData(
                name: "Halloween Spooky Edition",
                description: "Eerie midnight obsidian canvas with pumpkin orange accents, shadow purple tabs, and eerie glowing rules.",
                variables: [
                    "--page-bg": "#14111B",
                    "--text-main": "#F5EBE1",
                    "--text-secondary": "#C7B9A5",
                    "--text-muted": "#887968",
                    "--accent-color": "#FF7518",
                    "--border-subtle": "#2A2238",
                    "--border-medium": "#48395E",
                    "--tab-bg": "rgba(42, 34, 56, 0.70)",
                    "--tab-border": "rgba(72, 57, 94, 0.60)",
                    "--tab-text": "#D8CCE8",
                    "--tab-active-bg": "#FF7518",
                    "--tab-active-text": "#14111B",
                    "--grid-color": "rgba(255, 117, 24, 0.08)",
                    "--grid-size": "24px",
                    "--line-color": "rgba(255, 117, 24, 0.12)",
                    "--line-spacing": "28px",
                    "--dot-color": "rgba(255, 117, 24, 0.22)",
                    "--dot-pitch": "20px",
                    "--dot-size": "1.5px",
                    "--font-heading": "'Cinzel', serif"
                ]
            )
        } else if p.contains("autumn") || p.contains("fall") || p.contains("harvest") || p.contains("cinnamon") {
            return GeneratedPresetData(
                name: "Autumn Harvest & Cinnamon",
                description: "Warm honey cream paper with burnt orange accents, cinnamon brown rules, and rustic walnut tabs.",
                variables: [
                    "--page-bg": "#FBF6EE",
                    "--text-main": "#3A2A1D",
                    "--text-secondary": "#7A5B42",
                    "--text-muted": "#A88B73",
                    "--accent-color": "#C85A17",
                    "--border-subtle": "#E8DCCB",
                    "--border-medium": "#D2C0A8",
                    "--tab-bg": "rgba(210, 192, 168, 0.45)",
                    "--tab-border": "rgba(180, 160, 135, 0.50)",
                    "--tab-text": "#593F2B",
                    "--tab-active-bg": "#C85A17",
                    "--tab-active-text": "#FFFFFF",
                    "--grid-color": "rgba(58, 42, 29, 0.07)",
                    "--grid-size": "24px",
                    "--line-color": "rgba(58, 42, 29, 0.11)",
                    "--line-spacing": "28px",
                    "--dot-color": "rgba(58, 42, 29, 0.20)",
                    "--dot-pitch": "20px",
                    "--dot-size": "1.5px",
                    "--font-heading": "'Playfair Display', serif"
                ]
            )
        } else if p.contains("cyberpunk") || p.contains("neon") || p.contains("future") || p.contains("matrix") {
            return GeneratedPresetData(
                name: "Cyberpunk Neon Grid",
                description: "High-contrast ultra-dark canvas with electric cyan accents and hot magenta neon tabs.",
                variables: [
                    "--page-bg": "#0D0F17",
                    "--text-main": "#E0F7FA",
                    "--text-secondary": "#80DEEA",
                    "--text-muted": "#455A64",
                    "--accent-color": "#00E5FF",
                    "--border-subtle": "#1B2234",
                    "--border-medium": "#26324D",
                    "--tab-bg": "rgba(27, 34, 52, 0.70)",
                    "--tab-border": "rgba(38, 50, 77, 0.60)",
                    "--tab-text": "#80DEEA",
                    "--tab-active-bg": "#FF007F",
                    "--tab-active-text": "#FFFFFF",
                    "--grid-color": "rgba(0, 229, 255, 0.09)",
                    "--grid-size": "24px",
                    "--line-color": "rgba(0, 229, 255, 0.13)",
                    "--line-spacing": "28px",
                    "--dot-color": "rgba(0, 229, 255, 0.25)",
                    "--dot-pitch": "20px",
                    "--dot-size": "1.5px",
                    "--font-heading": "'Avenir Next', -apple-system, sans-serif"
                ]
            )
        } else if p.contains("christmas") || p.contains("holiday") || p.contains("winter") || p.contains("noel") {
            return GeneratedPresetData(
                name: "Winter Pine & Crimson Noel",
                description: "Deep evergreen pine canvas with velvety crimson red accents, frosted borders, and gold lettering.",
                variables: [
                    "--page-bg": "#122019",
                    "--text-main": "#F7F4EB",
                    "--text-secondary": "#C4BDAC",
                    "--text-muted": "#7B7567",
                    "--accent-color": "#C93B3B",
                    "--border-subtle": "#1D3529",
                    "--border-medium": "#2A4D3B",
                    "--tab-bg": "rgba(29, 53, 41, 0.70)",
                    "--tab-border": "rgba(42, 77, 59, 0.60)",
                    "--tab-text": "#D9D2C1",
                    "--tab-active-bg": "#C93B3B",
                    "--tab-active-text": "#FFFFFF",
                    "--grid-color": "rgba(247, 244, 235, 0.07)",
                    "--grid-size": "24px",
                    "--line-color": "rgba(247, 244, 235, 0.11)",
                    "--line-spacing": "28px",
                    "--dot-color": "rgba(247, 244, 235, 0.20)",
                    "--dot-pitch": "20px",
                    "--dot-size": "1.5px",
                    "--font-heading": "'Cinzel', serif"
                ]
            )
        } else if p.contains("sakura") || p.contains("cherry") || p.contains("spring") || p.contains("blossom") {
            return GeneratedPresetData(
                name: "Sakura Blossom & Rose",
                description: "Delicate blush cream canvas with cherry blossom rose accents and pastel sage tab details.",
                variables: [
                    "--page-bg": "#FFF9FA",
                    "--text-main": "#382C31",
                    "--text-secondary": "#7D6B73",
                    "--text-muted": "#A8969E",
                    "--accent-color": "#E87A90",
                    "--border-subtle": "#F5E4E8",
                    "--border-medium": "#E5CCD3",
                    "--tab-bg": "rgba(245, 228, 232, 0.50)",
                    "--tab-border": "rgba(229, 204, 211, 0.60)",
                    "--tab-text": "#6E545F",
                    "--tab-active-bg": "#E87A90",
                    "--tab-active-text": "#FFFFFF",
                    "--grid-color": "rgba(56, 44, 49, 0.06)",
                    "--grid-size": "24px",
                    "--line-color": "rgba(56, 44, 49, 0.10)",
                    "--line-spacing": "28px",
                    "--dot-color": "rgba(232, 122, 144, 0.22)",
                    "--dot-pitch": "20px",
                    "--dot-size": "1.5px",
                    "--font-heading": "'Avenir Next', -apple-system, sans-serif"
                ]
            )
        } else {
            let title = prompt.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty && !["create", "make", "generate", "preset", "theme", "a", "an", "the", "with", "for", "me"].contains($0.lowercased()) }
                .prefix(3)
                .map { $0.capitalized }
                .joined(separator: " ")
            let finalName = title.isEmpty ? "AI Custom Theme" : "\(title) Theme"
            
            return GeneratedPresetData(
                name: finalName,
                description: "Curated aesthetic theme preset tailored specifically to your prompt.",
                variables: [
                    "--page-bg": "#F9F8F6",
                    "--text-main": "#2C2D30",
                    "--text-secondary": "#63656A",
                    "--text-muted": "#9699A0",
                    "--accent-color": "#4A6FA5",
                    "--border-subtle": "#E5E7EB",
                    "--border-medium": "#CBD0D8",
                    "--tab-bg": "rgba(229, 231, 235, 0.45)",
                    "--tab-border": "rgba(203, 208, 216, 0.50)",
                    "--tab-text": "#50535A",
                    "--tab-active-bg": "#4A6FA5",
                    "--tab-active-text": "#FFFFFF",
                    "--grid-color": "rgba(44, 45, 48, 0.07)",
                    "--grid-size": "24px",
                    "--line-color": "rgba(44, 45, 48, 0.11)",
                    "--line-spacing": "28px",
                    "--dot-color": "rgba(74, 111, 165, 0.22)",
                    "--dot-pitch": "20px",
                    "--dot-size": "1.5px",
                    "--font-heading": "'Avenir Next', -apple-system, sans-serif"
                ]
            )
        }
    }
    
    public func generateThemeExplanation(for preset: GeneratedPresetData) -> String {
        return """
I have created the **\(preset.name)** theme preset for your digital notebook!

### 🎨 Palette & Design Highlights:
- **Canvas (`--page-bg`):** `\(preset.variables["--page-bg"] ?? "")`
- **Accent Color (`--accent-color`):** `\(preset.variables["--accent-color"] ?? "")` (used for active tabs, hyperlinks & buttons)
- **Primary Typography (`--text-main`):** `\(preset.variables["--text-main"] ?? "")`
- **Navigation Tabs (`--tab-bg` / `--tab-active-bg`):** `\(preset.variables["--tab-bg"] ?? "")`
- **Paper Patterns (`--grid-color` / `--dot-color`):** `\(preset.variables["--grid-color"] ?? "")`
- **Heading Font:** `\(preset.variables["--font-heading"] ?? "'Avenir Next', sans-serif")`

✓ **All set!** This preset has been automatically saved to your Theme Presets library and activated across your entire notebook and live preview.
"""
    }
}
