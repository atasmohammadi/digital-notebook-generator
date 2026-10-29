import Foundation

public struct PageTemplateOverride: Identifiable, Codable, Equatable {
    public var id: UUID
    public var pageRangeString: String // e.g. "16-20" or "45"
    public var templateRelativePath: String
    public var note: String
    
    public init(id: UUID = UUID(), pageRangeString: String, templateRelativePath: String, note: String = "") {
        self.id = id
        self.pageRangeString = pageRangeString
        self.templateRelativePath = templateRelativePath
        self.note = note
    }
    
    public func matches(page: Int) -> Bool {
        let clean = pageRangeString.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains("-") {
            let parts = clean.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 2 {
                return page >= parts[0] && page <= parts[1]
            }
        } else if let single = Int(clean) {
            return page == single
        }
        return false
    }
}

public struct NotebookTemplateMapping: Codable, Equatable {
    // Section Default Templates
    public var coverTemplate: String // Default: "Covers/cover_minimalist.html"
    public var chapterSelectionTemplate: String // Default: "Navigation/chapter_selection.html"
    public var chapterDividerTemplate: String // Default: "Navigation/chapter_selection.html"
    public var templateListTemplate: String // Default: "Navigation/template_list.html"
    
    // General Templates Section (Pages 16-44)
    public var generalTemplates: [String] // Rotated or cycled across pages 16..44
    
    // Chapter Notes Section (Pages 45-188)
    public var subchapterCoverTemplate: String // Pages 45, 57, 69... Default: "Trackers/habit_yearly_grid.html"
    public var defaultNotesTemplate: String // Default: "Lined/medium_line.html"
    public var chapterOverrides: [Int: String] // Chapter 1..12 -> template path override
    
    // Custom Arbitrary Page Overrides
    public var customOverrides: [PageTemplateOverride]
    
    public init(
        coverTemplate: String = "Covers/cover_minimalist.html",
        chapterSelectionTemplate: String = "Navigation/chapter_selection.html",
        chapterDividerTemplate: String = "Navigation/subchapter_selection.html",
        templateListTemplate: String = "Navigation/template_list.html",
        generalTemplates: [String] = [
            // Grids (Pages 16..20)
            "Grids/full_grid.html",
            "Grids/blank_grid.html",
            "Grids/blank_grid.html",
            "Grids/blank_grid.html",
            "Grids/blank_grid.html",
            // Lined (Pages 21..25)
            "Lined/medium_line.html",
            "Lined/medium_line.html",
            "Lined/medium_line.html",
            "Lined/medium_line.html",
            "Grids/full_grid.html",
            // Dotted & Blank (Pages 26..29)
            "Dotted/full_dotted.html",
            "Dotted/full_dotted.html",
            "Dotted/full_dotted.html",
            "Grids/blank_grid.html",
            // Monthly Planners (Pages 30..35)
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            // Weekly Planners (Pages 36..42)
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            "Planners/monthly_calendar_notes.html",
            // Trackers (Pages 43..44)
            "Trackers/habit_yearly_grid.html",
            "Trackers/habit_yearly_grid.html"
        ],
        subchapterCoverTemplate: String = "Trackers/habit_yearly_grid.html",
        defaultNotesTemplate: String = "Lined/medium_line.html",
        chapterOverrides: [Int: String] = [:],
        customOverrides: [PageTemplateOverride] = []
    ) {
        self.coverTemplate = coverTemplate
        self.chapterSelectionTemplate = chapterSelectionTemplate
        self.chapterDividerTemplate = chapterDividerTemplate
        self.templateListTemplate = templateListTemplate
        self.generalTemplates = generalTemplates
        self.subchapterCoverTemplate = subchapterCoverTemplate
        self.defaultNotesTemplate = defaultNotesTemplate
        self.chapterOverrides = chapterOverrides
        self.customOverrides = customOverrides
    }
    
    public static var defaultMapping: NotebookTemplateMapping {
        return NotebookTemplateMapping()
    }
    
    /// Resolves which template relative path should be drawn on page `p` (1-based index)
    public func resolveTemplate(forPage p: Int, arrowTargets: [Int]) -> String {
        // 1. Check custom page overrides first
        for override in customOverrides {
            if override.matches(page: p) {
                return override.templateRelativePath
            }
        }
        
        // 2. Page 1: Cover
        if p == 1 {
            return coverTemplate
        }
        
        // 3. Page 2: Chapter Selection
        if p == 2 {
            return chapterSelectionTemplate
        }
        
        // 4. Pages 3..14: Subchapter Selection / Dividers
        if p >= 3 && p <= 14 {
            let currentCh = p - 2
            if chapterDividerTemplate == "Navigation/subchapter_selection.html" {
                return "Navigation/subchapter_selection_\(currentCh).html"
            }
            return chapterDividerTemplate
        }
        
        // 5. Page 15: Template List Index
        if p == 15 {
            return templateListTemplate
        }
        
        // 6. Pages 16..44: General Templates Section
        if p >= 16 && p <= 44 {
            if generalTemplates.isEmpty {
                return defaultNotesTemplate
            }
            let index = (p - 16) % generalTemplates.count
            return generalTemplates[index]
        }
        
        // 7. Subchapter Cover Headers (Pages 45, 57, 69...)
        let noteSectionStarts = [45, 57, 69, 81, 93, 105, 117, 129, 141, 153, 165, 177]
        if noteSectionStarts.contains(p) {
            return subchapterCoverTemplate
        }
        
        // 8. Chapter Notes Pages (Pages 45..188)
        // Chapter 1: 45..56, Chapter 2: 57..68, etc.
        if p >= 45 {
            let chapterIndex = min(12, max(1, ((p - 45) / 12) + 1))
            if let chapterCustom = chapterOverrides[chapterIndex] {
                return chapterCustom
            }
        }
        
        // Default notes template (alternate with grid if default is lined)
        if defaultNotesTemplate == "Lined/medium_line.html" {
            return (p % 2 == 0) ? "Lined/medium_line.html" : "Grids/full_grid.html"
        }
        
        return defaultNotesTemplate
    }
}
