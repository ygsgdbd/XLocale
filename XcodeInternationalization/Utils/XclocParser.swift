import Foundation

class XclocParser {
    static func parse(xclocURL: URL) throws -> XclocFile {
        // 读取 contents.json
        let contentsURL = xclocURL.appendingPathComponent("contents.json")
        let contentsData = try Data(contentsOf: contentsURL)
        let contents = try JSONDecoder().decode(XclocContents.self, from: contentsData)
        
        // 读取翻译文件
        let sourceLocale = contents.developmentRegion
        let targetLocale = contents.targetLocale
        let translations = try parseTranslations(xclocURL: xclocURL, sourceLocale: sourceLocale, targetLocale: targetLocale)
        
        return XclocFile(
            url: xclocURL,
            contents: contents,
            translationUnits: translations
        )
    }
    
    private static func parseTranslations(xclocURL: URL, sourceLocale: String, targetLocale: String) throws -> [TranslationUnit] {
        let stringsURL = xclocURL.appendingPathComponent("Localized Contents")
                                .appendingPathComponent("\(targetLocale).xliff")
        
        let stringsData = try Data(contentsOf: stringsURL)
        let items = try parseXLIFF(data: stringsData)
        
        return items.map { (id, item) in
            TranslationUnit(
                id: id,
                source: item.localizations[sourceLocale]?.stringUnit.value ?? "",
                target: item.localizations[targetLocale]?.stringUnit.value ?? "",
                note: item.comment
            )
        }
    }
    
    private static func parseXLIFF(data: Data) throws -> [(String, TranslationItem)] {
        // XLIFF 解析逻辑
        var items: [(String, TranslationItem)] = []
        let xmlDoc = try XMLDocument(data: data)
        
        // 遍历 XML 节点，构建 TranslationItem
        if let nodes = try? xmlDoc.nodes(forXPath: "//trans-unit") {
            for node in nodes {
                guard let element = node as? XMLElement,
                      let id = element.attribute(forName: "id")?.stringValue else {
                    continue
                }
                
                let sourceNode = element.elements(forName: "source").first
                let targetNode = element.elements(forName: "target").first
                let noteNode = element.elements(forName: "note").first
                
                let item = TranslationItem(
                    comment: noteNode?.stringValue,
                    extractionState: "manual",
                    localizations: [
                        "en": .init(stringUnit: .init(
                            state: "translated",
                            value: sourceNode?.stringValue ?? ""
                        )),
                        "zh-Hans": .init(stringUnit: .init(
                            state: "translated",
                            value: targetNode?.stringValue ?? ""
                        ))
                    ]
                )
                
                items.append((id, item))
            }
        }
        
        return items
    }
    
    static func save(file: XclocFile, translation: TranslationUnit) throws {
        let xliffURL = file.url.appendingPathComponent("Localized Contents")
                              .appendingPathComponent("\(file.contents.targetLocale).xliff")
        print("保存路径: \(xliffURL.path)")
        
        let xmlDoc = try XMLDocument(contentsOf: xliffURL)
        let nodes = try xmlDoc.nodes(forXPath: "//trans-unit")
        for node in nodes {
            guard let element = node as? XMLElement,
                  let id = element.attribute(forName: "id")?.stringValue,
                  id == translation.id else {
                continue
            }
            
            if let targetNode = element.elements(forName: "target").first {
                targetNode.stringValue = translation.target
            }
            break
        }
        
        let xmlData = xmlDoc.xmlData(options: [.nodePrettyPrint])
        try xmlData.write(to: xliffURL)
    }
}
