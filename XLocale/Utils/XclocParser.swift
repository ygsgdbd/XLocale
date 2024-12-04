import Foundation

class XclocParser {
    // 解析整个 xcloc 文件
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
    
    // 解析翻译文件
    private static func parseTranslations(xclocURL: URL, sourceLocale: String, targetLocale: String) throws -> [TranslationUnit] {
        let stringsURL = xclocURL.appendingPathComponent("Localized Contents")
                                .appendingPathComponent("\(targetLocale).xliff")
        
        let stringsData = try Data(contentsOf: stringsURL)
        
        // 使用 XMLParser 解析 XLIFF
        let parser = XLIFFParser(sourceLocale: sourceLocale, targetLocale: targetLocale)
        let xmlParser = XMLParser(data: stringsData)
        xmlParser.delegate = parser
        
        guard xmlParser.parse() else {
            throw XMLError.parseError(xmlParser.parserError?.localizedDescription ?? "Unknown error")
        }
        
        return parser.translationUnits
    }
    
    // 保存翻译更新
    static func save(file: XclocFile, translation: TranslationUnit) throws {
        let xliffURL = file.url.appendingPathComponent("Localized Contents")
                              .appendingPathComponent("\(file.contents.targetLocale).xliff")
        
        let xmlDoc = try XMLDocument(contentsOf: xliffURL, options: .documentTidyXML)
        
        // 查找并更新目标翻译节点
        if let nodes = try? xmlDoc.nodes(forXPath: "//trans-unit[@id='\(translation.id)']"),
           let element = nodes.first as? XMLElement {
            
            // 更新或创建 target 节点
            if let targetNode = element.elements(forName: "target").first {
                targetNode.stringValue = translation.target
            } else {
                let targetNode = XMLElement(name: "target")
                targetNode.stringValue = translation.target
                element.addChild(targetNode)
            }
        }
        
        // 保存文件
        let xmlData = xmlDoc.xmlData(options: [.nodePrettyPrint, .documentTidyXML])
        try xmlData.write(to: xliffURL)
    }
    
    // 一次性保存所有翻译
    static func saveAll(file: XclocFile) throws {
        // 获取 xliff 文件路径
        let xliffURL = file.url.appendingPathComponent("Localized Contents")
            .appendingPathComponent("\(file.contents.targetLocale).xliff")
        
        // 读取现有的 xliff 文件
        let data = try Data(contentsOf: xliffURL)
        var document = try XMLDocument(data: data)
        
        // 更新所有翻译
        if let files = try document.nodes(forXPath: "//file") as? [XMLElement] {
            for xmlFile in files {  // 重命名变量避免冲突
                if let units = try xmlFile.nodes(forXPath: ".//trans-unit") as? [XMLElement] {
                    for unit in units {
                        if let id = unit.attribute(forName: "id")?.stringValue,
                           let translation = file.translationUnits.first(where: { $0.id == id }) {
                            // 更新目标文本
                            if let target = try unit.nodes(forXPath: ".//target").first as? XMLElement {
                                target.stringValue = translation.target
                            } else {
                                // 如果没有 target 节点，创建一个新的
                                let target = XMLElement(name: "target")
                                target.stringValue = translation.target
                                unit.addChild(target)
                            }
                        }
                    }
                }
            }
        }
        
        // 保存更新后的文件
        try document.xmlData(options: [.nodePrettyPrint, .documentTidyXML])
            .write(to: xliffURL, options: .atomic)
    }
}

// XLIFF 解析器
class XLIFFParser: NSObject, XMLParserDelegate {
    private let sourceLocale: String
    private let targetLocale: String
    private var currentElement: String = ""
    private var currentId: String = ""
    private var currentSource: String = ""
    private var currentTarget: String = ""
    private var currentNote: String = ""
    
    var translationUnits: [TranslationUnit] = []
    
    init(sourceLocale: String, targetLocale: String) {
        self.sourceLocale = sourceLocale
        self.targetLocale = targetLocale
        super.init()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "trans-unit" {
            currentId = attributeDict["id"] ?? ""
            currentSource = ""
            currentTarget = ""
            currentNote = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let content = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch currentElement {
        case "source":
            currentSource += content
        case "target":
            currentTarget += content
        case "note":
            currentNote += content
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "trans-unit" {
            let unit = TranslationUnit(
                id: currentId,
                source: currentSource,
                target: currentTarget,
                note: currentNote
            )
            translationUnits.append(unit)
        }
    }
}

// 错误类型
enum XMLError: Error {
    case parseError(String)
}
