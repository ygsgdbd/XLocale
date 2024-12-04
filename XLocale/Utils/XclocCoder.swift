import Foundation

/// xcloc 文件解码器
final class XclocDecoder {
    
    /// 解码错误类型
    enum DecodingError: LocalizedError {
        case missingContentsFile
        case missingXLIFFFile
        case invalidXMLFormat(String)
        
        var errorDescription: String? {
            switch self {
            case .missingContentsFile:
                return "缺少 contents.json 文件"
            case .missingXLIFFFile:
                return "缺少 XLIFF 文件"
            case .invalidXMLFormat(let detail):
                return "无效的 XML 格式：\(detail)"
            }
        }
    }
    
    /// 从 URL 解码 xcloc 文件
    func decode(from url: URL) throws -> XclocFile {
        // 1. 读取 contents.json
        let contentsURL = url.appendingPathComponent("contents.json")
        let contentsData = try Data(contentsOf: contentsURL)
        let contents = try JSONDecoder().decode(XclocContents.self, from: contentsData)
        
        // 2. 读取 XLIFF 文件
        let xliffURL = url.appendingPathComponent("Localized Contents")
                         .appendingPathComponent("\(contents.targetLocale).xliff")
        let translations = try parseXLIFF(from: xliffURL)
        
        return XclocFile(
            url: url,
            contents: contents,
            translationUnits: translations
        )
    }
    
    /// 解析 XLIFF 文件
    private func parseXLIFF(from url: URL) throws -> [TranslationUnit] {
        let xmlData = try Data(contentsOf: url)
        let parser = XLIFFParser()
        let xmlParser = XMLParser(data: xmlData)
        xmlParser.delegate = parser
        
        guard xmlParser.parse() else {
            throw DecodingError.invalidXMLFormat(xmlParser.parserError?.localizedDescription ?? "Unknown error")
        }
        
        return parser.translationUnits
    }
}

/// xcloc 文件编码器
final class XclocEncoder {
    
    /// 编码配置
    struct Configuration {
        /// 是否格式化 XML
        var formatXML: Bool
        /// 是否包含注释
        var includeNotes: Bool
        
        init(formatXML: Bool = true, includeNotes: Bool = true) {
            self.formatXML = formatXML
            self.includeNotes = includeNotes
        }
    }
    
    private let configuration: Configuration
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    /// 编码并保存到指定位置
    func encode(_ file: XclocFile, to url: URL) throws {
        // 1. 创建必要的目录
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        
        // 2. 保存 contents.json
        let contentsURL = url.appendingPathComponent("contents.json")
        let contentsData = try JSONEncoder().encode(file.contents)
        try contentsData.write(to: contentsURL)
        
        // 3. 保存 XLIFF 文件
        let xliffURL = url.appendingPathComponent("Localized Contents")
                         .appendingPathComponent("\(file.contents.targetLocale).xliff")
        try FileManager.default.createDirectory(at: xliffURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try generateXLIFF(from: file.translationUnits, to: xliffURL)
    }
    
    /// 生成 XLIFF 文件
    private func generateXLIFF(from units: [TranslationUnit], to url: URL) throws {
        let doc = XMLDocument(rootElement: nil)
        let root = XMLElement(name: "xliff")
        
        // 添加属性
        let versionAttr = XMLNode.attribute(withName: "version", stringValue: "1.2") as! XMLNode
        let xmlnsAttr = XMLNode.attribute(withName: "xmlns", stringValue: "urn:oasis:names:tc:xliff:document:1.2") as! XMLNode
        root.addAttribute(versionAttr)
        root.addAttribute(xmlnsAttr)
        
        let file = XMLElement(name: "file")
        // 添加 file 属性
        let sourceLanguageAttr = XMLNode.attribute(withName: "source-language", stringValue: "en") as! XMLNode
        let targetLanguageAttr = XMLNode.attribute(withName: "target-language", stringValue: "zh-Hans") as! XMLNode
        let datatypeAttr = XMLNode.attribute(withName: "datatype", stringValue: "plaintext") as! XMLNode
        file.addAttribute(sourceLanguageAttr)
        file.addAttribute(targetLanguageAttr)
        file.addAttribute(datatypeAttr)
        
        let body = XMLElement(name: "body")
        
        for unit in units {
            let transUnit = XMLElement(name: "trans-unit")
            // 添加 id 属性
            let idAttr = XMLNode.attribute(withName: "id", stringValue: unit.id) as! XMLNode
            transUnit.addAttribute(idAttr)
            
            let source = XMLElement(name: "source", stringValue: unit.source)
            let target = XMLElement(name: "target", stringValue: unit.target)
            
            transUnit.addChild(source)
            transUnit.addChild(target)
            
            // 根据配置决定是否添加注释
            if configuration.includeNotes, let note = unit.note {
                let noteElement = XMLElement(name: "note", stringValue: note)
                transUnit.addChild(noteElement)
            }
            
            body.addChild(transUnit)
        }
        
        file.addChild(body)
        root.addChild(file)
        doc.setRootElement(root)
        
        let options: XMLNode.Options = configuration.formatXML ? [.nodePrettyPrint] : []
        try doc.xmlData(options: options).write(to: url)
    }
}

// 在文件顶部添加 XLIFFParser 类
private class XLIFFParser: NSObject, XMLParserDelegate {
    private var currentUnit: (id: String, source: String, target: String, note: String?)?
    private var currentElement: String?
    private var currentValue: String?
    
    var translationUnits: [TranslationUnit] = []
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "trans-unit" {
            currentUnit = (
                id: attributeDict["id"] ?? "",
                source: "",
                target: "",
                note: nil
            )
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue = (currentValue ?? "") + string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard var unit = currentUnit else { return }
        
        switch elementName {
        case "source":
            unit.source = currentValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case "target":
            unit.target = currentValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case "note":
            unit.note = currentValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        case "trans-unit":
            translationUnits.append(
                TranslationUnit(
                    id: unit.id,
                    source: unit.source,
                    target: unit.target,
                    note: unit.note
                )
            )
            currentUnit = nil
        default:
            break
        }
        
        currentElement = nil
        currentValue = nil
    }
} 