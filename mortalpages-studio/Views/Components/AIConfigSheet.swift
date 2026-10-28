import SwiftUI
import AppKit

public struct AIConfigSheet: View {
    @ObservedObject public var chatManager: AIChatManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var workingConfig: AIConfig
    @State private var testResult: String? = nil
    @State private var isTestingCLI: Bool = false
    @State private var showingCustomPrompt: Bool = false
    
    public init(chatManager: AIChatManager) {
        self.chatManager = chatManager
        self._workingConfig = State(initialValue: chatManager.config)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Agent & CLI Settings")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Configure your underlying AI model, CLI tool, and reasoning effort.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Done") {
                    chatManager.config = workingConfig
                    chatManager.saveConfig()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Settings Form Scroll Area
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    
                    // SECTION 1: CLI PROVIDER & EXECUTABLE
                    VStack(alignment: .leading, spacing: 12) {
                        Label("CLI ENGINE & PROVIDER", systemImage: "terminal.fill")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Text("Provider:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            
                            Picker("", selection: $workingConfig.provider) {
                                ForEach(CLIProvider.allCases) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Status & Path verification card
                        HStack(spacing: 10) {
                            let path = workingConfig.provider == .custom ? workingConfig.customCLIPath : workingConfig.provider.defaultPath
                            let exists = FileManager.default.fileExists(atPath: path)
                            
                            Image(systemName: exists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(exists ? .green : .orange)
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(exists ? "Binary Available" : "Binary Not Found")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(exists ? .primary : .orange)
                                
                                Text(path.isEmpty ? "No custom binary path configured" : path)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            Spacer()
                            
                            Button(action: testCLIConnection) {
                                if isTestingCLI {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Label("Test CLI", systemImage: "bolt.fill")
                                }
                            }
                            .controlSize(.small)
                            .disabled(isTestingCLI)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        // Custom executable path field if custom provider selected
                        if workingConfig.provider == .custom {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Custom Executable Path:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("/path/to/cli", text: $workingConfig.customCLIPath)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        // Test Result Badge
                        if let res = testResult {
                            HStack(spacing: 6) {
                                Image(systemName: res.contains("✓") ? "checkmark.seal.fill" : "xmark.octagon.fill")
                                Text(res)
                                    .font(.caption)
                            }
                            .foregroundColor(res.contains("✓") ? .green : .red)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(res.contains("✓") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                    
                    // SECTION 2: MODEL & REASONING EFFORT
                    VStack(alignment: .leading, spacing: 14) {
                        Label("MODEL & REASONING EFFORT", systemImage: "cpu.fill")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        // Model string input
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Model String:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(width: 100, alignment: .leading)
                                
                                TextField("e.g. gemini-3.8-flash", text: $workingConfig.model)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            // Quick model preset chips
                            HStack(spacing: 8) {
                                Text("Quick Pick:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                
                                Button("gemini-3.8-flash (Default)") {
                                    workingConfig.model = "gemini-3.8-flash"
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button("gemini-3.8-pro") {
                                    workingConfig.model = "gemini-3.8-pro"
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button("claude-3-7-sonnet") {
                                    workingConfig.model = "claude-3-7-sonnet"
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        Divider()
                        
                        // Reasoning Effort Selector (Clean, compact, no overflow!)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Reasoning Effort:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(width: 110, alignment: .leading)
                                
                                Picker("", selection: $workingConfig.effort) {
                                    Text("Low").tag("low")
                                    Text("Medium").tag("medium")
                                    Text("High").tag("high")
                                    Text("XHigh").tag("xhigh")
                                    Text("Max").tag("max")
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 320)
                                
                                Spacer()
                            }
                            
                            // Effort Explanation Badge
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                                
                                Text(effortDescription(workingConfig.effort))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 114)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                    
                    // SECTION 3: AUTOMATION & INTEGRATION
                    VStack(alignment: .leading, spacing: 10) {
                        Label("WORKFLOW AUTOMATION", systemImage: "sparkles")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Toggle("Automatically save generated templates to Custom library", isOn: $workingConfig.autoApplyChanges)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("When enabled, valid HTML templates generated in the AI chat are immediately compiled and made available in the Template Studio dropdown.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                    
                    // SECTION 4: SYSTEM PROMPT
                    DisclosureGroup(isExpanded: $showingCustomPrompt) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $workingConfig.customSystemPrompt)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(height: 120)
                                .padding(4)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                            
                            HStack {
                                Text("Appended automatically with 1152×1485 canvas rules, 60px sidebar constraints, and CSS tokens.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Reset Prompt") {
                                    workingConfig.customSystemPrompt = AIConfig.defaultConfig.customSystemPrompt
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Label("Advanced System Instructions", systemImage: "text.quote")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 620, idealWidth: 660, maxWidth: 700, minHeight: 560, idealHeight: 620, maxHeight: 700)
    }
    
    private func effortDescription(_ effort: String) -> String {
        switch effort.lowercased() {
        case "low":
            return "Low effort: fastest response time, minimal chain-of-thought."
        case "medium":
            return "Medium effort (Default): balanced latency and deep design reasoning."
        case "high":
            return "High effort: thorough layout planning and validation."
        case "xhigh":
            return "Extra-high effort: comprehensive reasoning on complex structures."
        case "max":
            return "Maximum effort: exhaustive model exploration budget."
        default:
            return "Reasoning effort passed to CLI via --effort."
        }
    }
    
    private func testCLIConnection() {
        isTestingCLI = true
        testResult = nil
        
        let path = workingConfig.provider == .custom ? workingConfig.customCLIPath : workingConfig.provider.defaultPath
        guard FileManager.default.fileExists(atPath: path) else {
            isTestingCLI = false
            testResult = "Error: Executable not found at \(path)"
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: path)
            
            if self.workingConfig.provider == .agy {
                proc.arguments = ["--version"]
            } else if self.workingConfig.provider == .claude {
                proc.arguments = ["--version"]
            } else {
                proc.arguments = ["--help"]
            }
            
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/Users/sarahbenita/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            proc.environment = env
            
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            
            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                DispatchQueue.main.async {
                    self.isTestingCLI = false
                    if proc.terminationStatus == 0 || !out.isEmpty {
                        self.testResult = "✓ CLI reachable: \(out.prefix(60))"
                    } else {
                        self.testResult = "CLI returned status \(proc.terminationStatus)"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isTestingCLI = false
                    self.testResult = "Execution failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
