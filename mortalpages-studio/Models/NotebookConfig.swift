import Foundation
import CoreGraphics

public struct NotebookConfig: Codable, Equatable {
    public var themeName: String
    public var targetPDFPath: String
    public var templatePDFPath: String
    public var outputPath: String
    
    // Page Structure
    public var hasCover: Bool
    public var coverPageIndex: Int // 1-based (default 1)
    public var hasMasterLayout: Bool
    public var masterLayoutPageIndex: Int // 1-based (default 2)
    public var excludeMasterLayoutFromOutput: Bool
    
    // Sidebar Rules
    public var sidebarWidth: CGFloat
    public var skipSidebarStartPage: Int // 1-based in final PDF (default 3)
    public var skipSidebarEndPage: Int   // 1-based in final PDF (default 14)
    
    // Chapter Selection Arrows on Page 2
    public var hasChapterArrows: Bool
    public var arrowTargets: [Int] // Chapters 1..12 targets: 3, 4, 5, ... (or custom targets)
    public var useSidebarSizeForArrows: Bool
    public var customArrowWidth: CGFloat
    public var customArrowHeight: CGFloat
    
    // Page 2 Chapter Navigation & Arrow Indicator Settings
    public var chapterNavSettings: ChapterNavIndicatorSettings
    
    // Rich Watermark Settings
    public var watermarkSettings: WatermarkSettings
    
    // Page & Section Template Mapping
    public var templateMapping: NotebookTemplateMapping
    
    // Output Compression & Quality Optimization
    public var autoCompressPDF: Bool
    public var targetMaxFileSizeMB: Double
    public var strictSizeEnforcement: Bool
    
    // Legacy convenience properties
    public var stampWatermarkOnAllPages: Bool {
        get { watermarkSettings.mode != .none }
        set { watermarkSettings.mode = newValue ? .extractedFromLayout : .none }
    }
    public var watermarkX: CGFloat {
        get { watermarkSettings.layoutCropX }
        set { watermarkSettings.layoutCropX = newValue }
    }
    public var watermarkY: CGFloat {
        get { watermarkSettings.layoutCropY }
        set { watermarkSettings.layoutCropY = newValue }
    }
    public var watermarkWidth: CGFloat {
        get { watermarkSettings.layoutCropW }
        set { watermarkSettings.layoutCropW = newValue }
    }
    public var watermarkHeight: CGFloat {
        get { watermarkSettings.layoutCropH }
        set { watermarkSettings.layoutCropH = newValue }
    }
    public var neutralizeDataDetectors: Bool {
        get { watermarkSettings.neutralizeDataDetectors }
        set { watermarkSettings.neutralizeDataDetectors = newValue }
    }
    
    // Actions
    public var generateInteractivePDF: Bool
    public var syncKeynotePresentation: Bool
    
    public init(
        themeName: String,
        targetPDFPath: String,
        templatePDFPath: String,
        outputPath: String,
        hasCover: Bool,
        coverPageIndex: Int,
        hasMasterLayout: Bool,
        masterLayoutPageIndex: Int,
        excludeMasterLayoutFromOutput: Bool,
        sidebarWidth: CGFloat,
        skipSidebarStartPage: Int,
        skipSidebarEndPage: Int,
        hasChapterArrows: Bool,
        arrowTargets: [Int],
        useSidebarSizeForArrows: Bool,
        customArrowWidth: CGFloat,
        customArrowHeight: CGFloat,
        chapterNavSettings: ChapterNavIndicatorSettings = .defaultSettings,
        watermarkSettings: WatermarkSettings = .defaultSettings,
        templateMapping: NotebookTemplateMapping = .defaultMapping,
        autoCompressPDF: Bool = true,
        targetMaxFileSizeMB: Double = 5.0,
        strictSizeEnforcement: Bool = true,
        generateInteractivePDF: Bool,
        syncKeynotePresentation: Bool
    ) {
        self.themeName = themeName
        self.targetPDFPath = targetPDFPath
        self.templatePDFPath = templatePDFPath
        self.outputPath = outputPath
        self.hasCover = hasCover
        self.coverPageIndex = coverPageIndex
        self.hasMasterLayout = hasMasterLayout
        self.masterLayoutPageIndex = masterLayoutPageIndex
        self.excludeMasterLayoutFromOutput = excludeMasterLayoutFromOutput
        self.sidebarWidth = sidebarWidth
        self.skipSidebarStartPage = skipSidebarStartPage
        self.skipSidebarEndPage = skipSidebarEndPage
        self.hasChapterArrows = hasChapterArrows
        self.arrowTargets = arrowTargets
        self.useSidebarSizeForArrows = useSidebarSizeForArrows
        self.customArrowWidth = customArrowWidth
        self.customArrowHeight = customArrowHeight
        self.chapterNavSettings = chapterNavSettings
        self.watermarkSettings = watermarkSettings
        self.templateMapping = templateMapping
        self.autoCompressPDF = autoCompressPDF
        self.targetMaxFileSizeMB = targetMaxFileSizeMB
        self.strictSizeEnforcement = strictSizeEnforcement
        self.generateInteractivePDF = generateInteractivePDF
        self.syncKeynotePresentation = syncKeynotePresentation
    }
    
    // Codable implementation with backward-compatibility for legacy presets
    enum CodingKeys: String, CodingKey {
        case themeName, targetPDFPath, templatePDFPath, outputPath
        case hasCover, coverPageIndex, hasMasterLayout, masterLayoutPageIndex, excludeMasterLayoutFromOutput
        case sidebarWidth, skipSidebarStartPage, skipSidebarEndPage
        case hasChapterArrows, arrowTargets, useSidebarSizeForArrows, customArrowWidth, customArrowHeight
        case chapterNavSettings
        case watermarkSettings, templateMapping
        case autoCompressPDF, targetMaxFileSizeMB, strictSizeEnforcement
        case stampWatermarkOnAllPages, watermarkX, watermarkY, watermarkWidth, watermarkHeight, neutralizeDataDetectors
        case generateInteractivePDF, syncKeynotePresentation
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        themeName = try container.decode(String.self, forKey: .themeName)
        targetPDFPath = try container.decode(String.self, forKey: .targetPDFPath)
        templatePDFPath = try container.decode(String.self, forKey: .templatePDFPath)
        outputPath = try container.decode(String.self, forKey: .outputPath)
        hasCover = try container.decode(Bool.self, forKey: .hasCover)
        coverPageIndex = try container.decode(Int.self, forKey: .coverPageIndex)
        hasMasterLayout = try container.decode(Bool.self, forKey: .hasMasterLayout)
        masterLayoutPageIndex = try container.decode(Int.self, forKey: .masterLayoutPageIndex)
        excludeMasterLayoutFromOutput = try container.decode(Bool.self, forKey: .excludeMasterLayoutFromOutput)
        sidebarWidth = try container.decode(CGFloat.self, forKey: .sidebarWidth)
        skipSidebarStartPage = try container.decode(Int.self, forKey: .skipSidebarStartPage)
        skipSidebarEndPage = try container.decode(Int.self, forKey: .skipSidebarEndPage)
        hasChapterArrows = try container.decode(Bool.self, forKey: .hasChapterArrows)
        arrowTargets = try container.decode([Int].self, forKey: .arrowTargets)
        useSidebarSizeForArrows = try container.decode(Bool.self, forKey: .useSidebarSizeForArrows)
        customArrowWidth = try container.decode(CGFloat.self, forKey: .customArrowWidth)
        customArrowHeight = try container.decode(CGFloat.self, forKey: .customArrowHeight)
        generateInteractivePDF = try container.decode(Bool.self, forKey: .generateInteractivePDF)
        syncKeynotePresentation = try container.decode(Bool.self, forKey: .syncKeynotePresentation)
        
        self.templateMapping = (try? container.decode(NotebookTemplateMapping.self, forKey: .templateMapping)) ?? .defaultMapping
        self.autoCompressPDF = (try? container.decode(Bool.self, forKey: .autoCompressPDF)) ?? true
        self.targetMaxFileSizeMB = (try? container.decode(Double.self, forKey: .targetMaxFileSizeMB)) ?? 5.0
        self.strictSizeEnforcement = (try? container.decode(Bool.self, forKey: .strictSizeEnforcement)) ?? true
        
        if let nav = try? container.decode(ChapterNavIndicatorSettings.self, forKey: .chapterNavSettings) {
            self.chapterNavSettings = nav
        } else {
            var nav = ChapterNavIndicatorSettings.defaultSettings
            nav.isEnabled = (try? container.decode(Bool.self, forKey: .hasChapterArrows)) ?? true
            if let customW = try? container.decode(CGFloat.self, forKey: .customArrowWidth) {
                nav.width = customW
            }
            if let customH = try? container.decode(CGFloat.self, forKey: .customArrowHeight) {
                nav.height = customH
            }
            self.chapterNavSettings = nav
        }
        
        if let ws = try? container.decode(WatermarkSettings.self, forKey: .watermarkSettings) {
            self.watermarkSettings = ws
        } else {
            // Reconstruct from legacy fields
            let legacyStamp = (try? container.decode(Bool.self, forKey: .stampWatermarkOnAllPages)) ?? true
            let legacyX = (try? container.decode(CGFloat.self, forKey: .watermarkX)) ?? 501.0
            let legacyY = (try? container.decode(CGFloat.self, forKey: .watermarkY)) ?? 28.0
            let legacyW = (try? container.decode(CGFloat.self, forKey: .watermarkWidth)) ?? 150.0
            let legacyH = (try? container.decode(CGFloat.self, forKey: .watermarkHeight)) ?? 35.0
            let legacyNeut = (try? container.decode(Bool.self, forKey: .neutralizeDataDetectors)) ?? true
            
            var ws = WatermarkSettings.defaultSettings
            ws.mode = legacyStamp ? .extractedFromLayout : .none
            ws.layoutCropX = legacyX
            ws.layoutCropY = legacyY
            ws.layoutCropW = legacyW
            ws.layoutCropH = legacyH
            ws.neutralizeDataDetectors = legacyNeut
            self.watermarkSettings = ws
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(themeName, forKey: .themeName)
        try container.encode(targetPDFPath, forKey: .targetPDFPath)
        try container.encode(templatePDFPath, forKey: .templatePDFPath)
        try container.encode(outputPath, forKey: .outputPath)
        try container.encode(hasCover, forKey: .hasCover)
        try container.encode(coverPageIndex, forKey: .coverPageIndex)
        try container.encode(hasMasterLayout, forKey: .hasMasterLayout)
        try container.encode(masterLayoutPageIndex, forKey: .masterLayoutPageIndex)
        try container.encode(excludeMasterLayoutFromOutput, forKey: .excludeMasterLayoutFromOutput)
        try container.encode(sidebarWidth, forKey: .sidebarWidth)
        try container.encode(skipSidebarStartPage, forKey: .skipSidebarStartPage)
        try container.encode(skipSidebarEndPage, forKey: .skipSidebarEndPage)
        try container.encode(hasChapterArrows, forKey: .hasChapterArrows)
        try container.encode(arrowTargets, forKey: .arrowTargets)
        try container.encode(useSidebarSizeForArrows, forKey: .useSidebarSizeForArrows)
        try container.encode(customArrowWidth, forKey: .customArrowWidth)
        try container.encode(customArrowHeight, forKey: .customArrowHeight)
        try container.encode(chapterNavSettings, forKey: .chapterNavSettings)
        try container.encode(generateInteractivePDF, forKey: .generateInteractivePDF)
        try container.encode(syncKeynotePresentation, forKey: .syncKeynotePresentation)
        
        try container.encode(watermarkSettings, forKey: .watermarkSettings)
        try container.encode(templateMapping, forKey: .templateMapping)
        try container.encode(autoCompressPDF, forKey: .autoCompressPDF)
        try container.encode(targetMaxFileSizeMB, forKey: .targetMaxFileSizeMB)
        try container.encode(strictSizeEnforcement, forKey: .strictSizeEnforcement)
        // Also encode legacy fields for backwards compatibility
        try container.encode(stampWatermarkOnAllPages, forKey: .stampWatermarkOnAllPages)
        try container.encode(watermarkX, forKey: .watermarkX)
        try container.encode(watermarkY, forKey: .watermarkY)
        try container.encode(watermarkWidth, forKey: .watermarkWidth)
        try container.encode(watermarkHeight, forKey: .watermarkHeight)
        try container.encode(neutralizeDataDetectors, forKey: .neutralizeDataDetectors)
    }
    
    public static var defaultLight: NotebookConfig {
        return standardMortalpages
    }
    
    public static var standardMortalpages: NotebookConfig {
        return NotebookConfig(
            themeName: "Glass Notebook (Light)",
            targetPDFPath: "",
            templatePDFPath: "/Users/sarahbenita/Library/Mobile Documents/com~apple~CloudDocs/digital business related/mortalpages/Notebook 4 - pretty pastel/Pretty Pastel Portrait.pdf",
            outputPath: "",
            hasCover: true,
            coverPageIndex: 1,
            hasMasterLayout: true,
            masterLayoutPageIndex: 2,
            excludeMasterLayoutFromOutput: true,
            sidebarWidth: 60.0,
            skipSidebarStartPage: 3,
            skipSidebarEndPage: 14,
            hasChapterArrows: true,
            arrowTargets: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
            useSidebarSizeForArrows: true,
            customArrowWidth: 42.22,
            customArrowHeight: 101.51,
            chapterNavSettings: .defaultSettings,
            watermarkSettings: .defaultSettings,
            templateMapping: .defaultMapping,
            autoCompressPDF: true,
            targetMaxFileSizeMB: 5.0,
            strictSizeEnforcement: true,
            generateInteractivePDF: true,
            syncKeynotePresentation: false
        )
    }
    
    public static var benitaPreset: NotebookConfig {
        return NotebookConfig(
            themeName: "Benita",
            targetPDFPath: "/Users/sarahbenita/Library/Mobile Documents/com~apple~CloudDocs/digital business related/mortalpages/Notebook 6 - Glass  (Light)/Glass Notebook Portrait - Light (PDF from canva) embossed watermark.pdf",
            templatePDFPath: "/Users/sarahbenita/Library/Mobile Documents/com~apple~CloudDocs/digital business related/mortalpages/Notebook 4 - pretty pastel/Pretty Pastel Portrait.pdf",
            outputPath: "",
            hasCover: true,
            coverPageIndex: 1,
            hasMasterLayout: true,
            masterLayoutPageIndex: 2,
            excludeMasterLayoutFromOutput: true,
            sidebarWidth: 60.0,
            skipSidebarStartPage: 3,
            skipSidebarEndPage: 14,
            hasChapterArrows: true,
            arrowTargets: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
            useSidebarSizeForArrows: true,
            customArrowWidth: 42.22,
            customArrowHeight: 101.51,
            chapterNavSettings: ChapterNavIndicatorSettings(
                isEnabled: true,
                renderVisualIndicator: false,
                symbolType: .chevron,
                customSymbolText: ">",
                symbolColorHex: "#6E6864",
                symbolColorAlpha: 0.85,
                fontSize: 16,
                fontWeight: "Bold",
                capsuleStyle: .glass,
                capsuleBgColorHex: "#FFFFFF",
                capsuleBgAlpha: 0.65,
                capsuleBorderColorHex: "#E0DCD6",
                capsuleBorderAlpha: 0.5,
                capsuleCornerRadius: 21.0,
                positionX: 804.4,
                width: 42.22,
                height: 101.51,
                linkLeftNumberPill: true,
                leftNumberX: 33.5,
                leftNumberWidth: 42.22,
                leftNumberHeight: 101.51
            ),
            watermarkSettings: WatermarkSettings(
                mode: .extractedFromLayout,
                scope: .allPages,
                layoutCropX: 501.0,
                layoutCropY: 28.0,
                layoutCropW: 150.0,
                layoutCropH: 35.0,
                neutralizeDataDetectors: true
            ),
            templateMapping: .defaultMapping,
            autoCompressPDF: true,
            targetMaxFileSizeMB: 5.0,
            strictSizeEnforcement: true,
            generateInteractivePDF: true,
            syncKeynotePresentation: false
        )
    }
}
