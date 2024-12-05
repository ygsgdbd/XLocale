import Foundation

// MARK: - 核心数据模型
struct XclocFile: Hashable, Equatable {
    let url: URL
    let contents: XclocContents
    var translationUnits: [TranslationUnit]
    
    mutating func updateTranslation(_ unit: TranslationUnit) {
        if let index = translationUnits.firstIndex(where: { $0.id == unit.id }) {
            translationUnits[index] = unit
        }
    }
    
    /// 总条目数
    var totalCount: Int {
        translationUnits.count
    }
    
    /// 已翻译条目数
    var translatedCount: Int {
        translationUnits.filter { !$0.target.isEmpty }.count
    }
    
    /// 翻译进度 (0.0-1.0)
    var translationProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(translatedCount) / Double(totalCount)
    }
}

// MARK: - 翻译单元
struct TranslationUnit: Identifiable, Hashable {
    let id: String
    let source: String
    var target: String
    let note: String?
}

// MARK: - Xcode 本地化文件结构
struct XclocContents: Codable, Hashable {
    let developmentRegion: String
    let targetLocale: String
    let toolInfo: ToolInfo
    let version: String
    
    struct ToolInfo: Codable, Hashable {
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
