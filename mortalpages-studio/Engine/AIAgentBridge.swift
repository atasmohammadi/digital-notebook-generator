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
        public let suggestedTitle: String?
        public let executionTime: TimeInterval
        public let exitCode: Int32
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
                
                // Extract HTML & Title
                let extractedHTML = self.extractHTMLBlock(from: combinedOutput)
                let extractedTitle = extractedHTML != nil ? self.extractTitle(from: extractedHTML!) : nil
                
                let result = ExecutionResult(
                    output: combinedOutput,
                    extractedHTML: extractedHTML,
                    suggestedTitle: extractedTitle,
                    executionTime: duration,
                    exitCode: exitCode
                )
                
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.statusMessage = exitCode == 0 ? "Completed in \(String(format: "%.1f", duration))s" : "Process exited with code \(exitCode)"
                    self.currentProcess = nil
                    
                    if exitCode == 0 || !rawOutput.isEmpty {
                        completion(.success(result))
                    } else {
                        let err = NSError(domain: "AIAgentBridge", code: Int(exitCode), userInfo: [NSLocalizedDescriptionKey: "CLI Error: \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))"])
                        completion(.failure(err))
                    }
                }
            } catch {
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

=== MORTALPAGE STUDIO DESIGN SPECIFICATIONS ===
1. DIMENSIONS: 1152px width × 1485px height (exact 4:3 digital journal canvas @ 72 DPI).
2. SIDEBAR NAVIGATION:
   - There is a 60px left sidebar (containing 14 interactive tabs: Home, Templates, Chapters 1-12).
   - In your page HTML, always include the master layout container or ensure margin-left: 60px:
     <div class="page-container" style="display: flex; width: 1152px; height: 1485px; position: relative;">
     ... left sidebar or placeholder ...
     <main class="page-content" style="margin-left: 60px; width: calc(1152px - 60px); height: 100%; box-sizing: border-box; padding: 60px 60px 70px 30px;">
3. CSS DESIGN TOKENS:
   The page automatically links `../Base/theme_variables.css` or applies root tokens:
   - Backgrounds: var(--page-bg), var(--sidebar-bg), var(--card-bg)
   - Text: var(--text-main), var(--text-secondary), var(--text-muted)
   - Colors: var(--accent-color), var(--border-subtle), var(--border-medium)
   - Grid/Lines: var(--grid-color), var(--grid-size), var(--line-color), var(--line-spacing), var(--dot-color), var(--dot-pitch)
   - Fonts: var(--font-heading) (e.g. Playfair Display, Cinzel, Montserrat), var(--font-body) (Inter, system-ui)
4. OUTPUT FORMAT REQUIREMENTS:
   - You MUST output the complete, valid HTML file wrapped in ```html ... ``` code fences.
   - Include a descriptive title in `<title>...</title>` (e.g. `<title>Daily Time Tracker</title>`).
   - Use clean, semantic HTML5 and vector CSS (flexbox, CSS grid, SVG, linear gradients). Do NOT use low-res raster images.
   - Include CSS `<style>` blocks directly inside the HTML for self-containment.
"""
        
        if let imgPath = attachedImagePath, !imgPath.isEmpty {
            context += """
\n\n=== ATTACHED VISUAL REFERENCE IMAGE ===
The user has attached an image file located on disk at:
\(imgPath)

CRITICAL INSTRUCTIONS FOR IMAGE INSPIRATION & REPLICATION:
1. Examine the visual reference image at: \(imgPath). Inspect its layout, calendar grids, schedule blocks, header bars, lists, columns, typography, and styling.
2. Translate and recreate that layout into a complete, clean, pixel-perfect HTML5 & CSS3 vector template.
3. Fit the design seamlessly into the 1152px × 1485px page canvas with 60px left sidebar allowance.
4. Output the full HTML inside ```html ... ``` code fences.
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
1. A brief explanation of the design and features.
2. The complete, ready-to-run HTML inside a ```html ... ``` code block.
"""
        return context
    }
    
    // MARK: - HTML Extraction Helpers
    public func extractHTMLBlock(from text: String) -> String? {
        // Look for ```html ... ```
        if let startRange = text.range(of: "```html", options: .caseInsensitive),
           let endRange = text.range(of: "```", range: startRange.upperBound..<text.endIndex) {
            let html = String(text[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !html.isEmpty { return html }
        }
        
        // Alternative: Look for <!DOCTYPE html> ... </html>
        if let startRange = text.range(of: "<!DOCTYPE html>", options: .caseInsensitive),
           let endRange = text.range(of: "</html>", options: [.caseInsensitive, .backwards]) {
            let html = String(text[startRange.lowerBound...endRange.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !html.isEmpty { return html }
        }
        
        // Alternative: Look for <html ... </html>
        if let startRange = text.range(of: "<html", options: .caseInsensitive),
           let endRange = text.range(of: "</html>", options: [.caseInsensitive, .backwards]) {
            let html = String(text[startRange.lowerBound...endRange.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !html.isEmpty { return html }
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
}
