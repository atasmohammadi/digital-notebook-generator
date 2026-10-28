import Foundation
import SwiftUI

public enum CLIProvider: String, Codable, CaseIterable, Identifiable {
    case agy = "agy (Antigravity CLI)"
    case claude = "claude (Claude Code CLI)"
    case codex = "codex (Codex CLI)"
    case custom = "Custom CLI Executable"
    
    public var id: String { self.rawValue }
    
    public var defaultPath: String {
        switch self {
        case .agy:
            return FileManager.default.fileExists(atPath: "/Users/sarahbenita/.local/bin/agy")
                ? "/Users/sarahbenita/.local/bin/agy"
                : "agy"
        case .claude:
            return FileManager.default.fileExists(atPath: "/opt/homebrew/bin/claude")
                ? "/opt/homebrew/bin/claude"
                : "claude"
        case .codex:
            return "codex"
        case .custom:
            return ""
        }
    }
}

public struct AIConfig: Codable, Equatable {
    public var provider: CLIProvider
    public var model: String
    public var effort: String // low, medium, high, xhigh, max
    public var customCLIPath: String
    public var autoApplyChanges: Bool
    public var customSystemPrompt: String
    
    public static var defaultConfig: AIConfig {
        return AIConfig(
            provider: .agy,
            model: "gemini-3.8-flash",
            effort: "medium",
            customCLIPath: "",
            autoApplyChanges: true,
            customSystemPrompt: """
You are an expert digital planner designer for mortalpages Studio.
You design and edit clean, aesthetic, interactive HTML5 and CSS3 notebook templates.

Technical Architecture Constraints:
1. Canvas Geometry: 1152px width by 1485px height (4:3 portrait aspect ratio @ 72 DPI standard).
2. Navigation Spine: Left sidebar has a 60px width containing 14 tabs.
3. Content Area: Has margin-left: 60px, width: calc(1152px - 60px), padding: 60px 60px 70px 30px.
4. CSS Design Tokens: Always use CSS variables:
   - --page-bg, --text-main, --text-secondary, --text-muted, --accent-color
   - --grid-color, --grid-size, --line-color, --line-spacing, --dot-color, --dot-pitch
   - --border-subtle, --border-medium, --tab-bg, --tab-active-bg, --font-heading, --font-body
5. Vector Quality: Use pure CSS grids, flexbox, linear/radial gradients, and inline SVGs.
6. When generating or editing a template, provide complete, self-contained HTML wrapped in ```html ... ``` code fences, specifying the title in <title>Template Name</title>.
"""
        )
    }
}

public struct GeneratedPresetData: Codable, Equatable {
    public var name: String
    public var description: String
    public var variables: [String: String]
    
    public init(name: String, description: String, variables: [String: String]) {
        self.name = name
        self.description = description
        self.variables = variables
    }
}

public struct ChatMessage: Identifiable, Codable, Equatable {
    public var id: UUID
    public var role: MessageRole
    public var content: String
    public var timestamp: Date
    public var extractedHTML: String?
    public var suggestedTemplateName: String?
    public var attachedImagePath: String?
    public var extractedPreset: GeneratedPresetData?
    
    public enum MessageRole: String, Codable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
    }
    
    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        extractedHTML: String? = nil,
        suggestedTemplateName: String? = nil,
        attachedImagePath: String? = nil,
        extractedPreset: GeneratedPresetData? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.extractedHTML = extractedHTML
        self.suggestedTemplateName = suggestedTemplateName
        self.attachedImagePath = attachedImagePath
        self.extractedPreset = extractedPreset
    }
}

public struct AIChatSession: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var messages: [ChatMessage]
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(id: UUID = UUID(), title: String, messages: [ChatMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public class AIChatManager: ObservableObject {
    @Published public var config: AIConfig
    @Published public var sessions: [AIChatSession] = []
    @Published public var activeSessionId: UUID
    
    private let sessionsFileURL: URL
    private let configFileURL: URL
    
    public var activeSession: AIChatSession {
        get {
            if let found = sessions.first(where: { $0.id == activeSessionId }) {
                return found
            }
            if let first = sessions.first {
                return first
            }
            let newSession = AIChatSession(title: "New Template Conversation")
            return newSession
        }
        set {
            if let idx = sessions.firstIndex(where: { $0.id == newValue.id }) {
                sessions[idx] = newValue
            } else {
                sessions.append(newValue)
            }
            saveSessions()
        }
    }
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("mortalpages Studio")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        self.sessionsFileURL = dir.appendingPathComponent("chat_sessions.json")
        self.configFileURL = dir.appendingPathComponent("ai_config.json")
        
        // Load Config
        if let data = try? Data(contentsOf: configFileURL),
           let decoded = try? JSONDecoder().decode(AIConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = .defaultConfig
        }
        
        // Load Sessions
        let defaultId = UUID()
        self.activeSessionId = defaultId
        loadSessions()
        
        if sessions.isEmpty {
            let welcomeMsg = ChatMessage(
                role: .assistant,
                content: """
Hello! I am your **mortalpages Studio AI Assistant**.

I am configured with **\(config.model)** (effort: **\(config.effort)**) using **\(config.provider.rawValue)**.

I have full context of all your digital journal templates, layout geometry (1152×1485), and CSS design tokens. You can ask me to:
- **Create new custom templates** (e.g. *"Create a daily time-blocking template with mini calendar and priority list"*).
- **Edit existing templates** (e.g. *"Make the lined template lines darker and add a margin rule on the left"*).
- **Design whole new sections** (e.g. *"Create a fitness & workout tracker"*).

What would you like to build today?
"""
            )
            let initialSession = AIChatSession(id: defaultId, title: "Welcome to Template Designer", messages: [welcomeMsg])
            self.sessions = [initialSession]
            self.activeSessionId = defaultId
            saveSessions()
        }
    }
    
    public func loadSessions() {
        if let data = try? Data(contentsOf: sessionsFileURL),
           let decoded = try? JSONDecoder().decode([AIChatSession].self, from: data), !decoded.isEmpty {
            self.sessions = decoded
            self.activeSessionId = decoded.first!.id
        }
    }
    
    public func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            try? encoded.write(to: sessionsFileURL)
        }
    }
    
    public func saveConfig() {
        if let encoded = try? JSONEncoder().encode(config) {
            try? encoded.write(to: configFileURL)
        }
    }
    
    public func startNewSession(title: String = "New Template Conversation") -> UUID {
        let newSession = AIChatSession(title: title)
        sessions.insert(newSession, at: 0)
        activeSessionId = newSession.id
        saveSessions()
        return newSession.id
    }
    
    public func deleteSession(id: UUID) {
        sessions.removeAll(where: { $0.id == id })
        if sessions.isEmpty {
            _ = startNewSession()
        } else if activeSessionId == id {
            activeSessionId = sessions.first!.id
        }
        saveSessions()
    }
    
    public func addMessage(
        role: ChatMessage.MessageRole,
        content: String,
        extractedHTML: String? = nil,
        suggestedName: String? = nil,
        attachedImagePath: String? = nil,
        extractedPreset: GeneratedPresetData? = nil
    ) {
        var session = activeSession
        let msg = ChatMessage(
            role: role,
            content: content,
            extractedHTML: extractedHTML,
            suggestedTemplateName: suggestedName,
            attachedImagePath: attachedImagePath,
            extractedPreset: extractedPreset
        )
        session.messages.append(msg)
        session.updatedAt = Date()
        
        // Auto-title from first user message if default
        if session.title.hasPrefix("New Template Conversation") && role == .user {
            let words = content.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines)
            session.title = words.isEmpty ? "Template Chat" : "\(words)..."
        }
        
        self.activeSession = session
    }
}
