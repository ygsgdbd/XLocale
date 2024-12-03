import Foundation

// MARK: - 核心数据模型
struct XclocFile: Hashable, Equatable {
    let url: URL
    let contents: XclocContents
    var translationUnits: [TranslationUnit]
    
    mutating func updateTranslation(_ translation: TranslationUnit) {
        if let index = translationUnits.firstIndex(where: { $0.id == translation.id }) {
            translationUnits[index] = translation
        }
    }
}

// MARK: - 翻译单元
struct TranslationUnit: Identifiable, Hashable, Equatable {
    let id: String
    let source: String
    var target: String
    let note: String?
}

// MARK: - Xcode 本地化文件结构
struct XclocContents: Codable, Hashable, Equatable {
    let developmentRegion: String
    let targetLocale: String
    let toolInfo: ToolInfo
    let version: String
    
    struct ToolInfo: Codable, Hashable, Equatable {
        let toolBuildNumber: String
        let toolID: String
        let toolName: String
        let toolVersion: String
    }
}

// MARK: - 翻译条目
struct TranslationItem: Codable, Hashable, Equatable {
    let comment: String?
    let extractionState: String
    let localizations: [String: Localization]
    
    struct Localization: Codable, Hashable, Equatable {
        let stringUnit: StringUnit
        
        struct StringUnit: Codable, Hashable, Equatable {
            let state: String
            let value: String
        }
    }
}

// MARK: - 类型扩展
extension TranslationUnit {
    init(id: String, item: TranslationItem, sourceLocale: String, targetLocale: String) {
        self.id = id
        self.source = item.localizations[sourceLocale]?.stringUnit.value ?? ""
        self.target = item.localizations[targetLocale]?.stringUnit.value ?? ""
        self.note = item.comment
    }
} 
