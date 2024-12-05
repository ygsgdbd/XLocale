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
        
        // 添加调试信息
        print("解析到的翻译单元：")
        for unit in parser.translationUnits {
            print("ID: \(unit.id)")
            print("Source: \(unit.source)")
            print("Target: \(unit.target)")
            print("Note: \(unit.note ?? "无")")
            print("---")
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
        let fileManager = FileManager.default
        
        // 1. 确保目标目录存在
        let parentDirectory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDirectory.path) {
            try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        }
        
        // 2. 如果是首次保存，复制整个目录结构
        if !fileManager.fileExists(atPath: url.path) {
            // 如果有原始文件，复制它
            if fileManager.fileExists(atPath: file.url.path) {
                try fileManager.copyItem(at: file.url, to: url)
            } else {
                // 如果是新文件，创建必要的目录结构
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                
                // 创建并保存 contents.json
                let contentsURL = url.appendingPathComponent("contents.json")
                let contentsData = try JSONEncoder().encode(file.contents)
                try contentsData.write(to: contentsURL)
                
                // 创建本地化内容目录
                let localizedContentsURL = url.appendingPathComponent("Localized Contents")
                try fileManager.createDirectory(at: localizedContentsURL, withIntermediateDirectories: true)
            }
        }
        
        // 3. 更新或创建 XLIFF 文件
        let xliffURL = url.appendingPathComponent("Localized Contents")
                         .appendingPathComponent("\(file.contents.targetLocale).xliff")
        
        // 确保 XLIFF 文件的父目录存在
        let xliffDirectory = xliffURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: xliffDirectory.path) {
            try fileManager.createDirectory(at: xliffDirectory, withIntermediateDirectories: true)
        }
        
        // 4. 更新 XLIFF 文件内容
        if fileManager.fileExists(atPath: xliffURL.path) {
            // 如果文件存在，更新翻译内容
            let xmlData = try Data(contentsOf: xliffURL)
            let originalDoc = try XMLDocument(data: xmlData)
            guard let root = originalDoc.rootElement(),
                  let fileElement = root.elements(forName: "file").first,
                  let body = fileElement.elements(forName: "body").first else {
                throw NSError(domain: "XclocEncoder", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 XLIFF 文件结构"])
            }
            
            // 更新翻译单元
            let transUnits = body.elements(forName: "trans-unit")
            print("找到 \(transUnits.count) 个翻译单元")
            print("当前文件有 \(file.translationUnits.count) 个翻译")

            for transUnit in transUnits {
                guard let id = transUnit.attribute(forName: "id")?.stringValue else {
                    print("跳过无效的翻译单元：缺少 ID")
                    continue
                }
                
                // 查找对应的更新后的翻译
                if let updatedUnit = file.translationUnits.first(where: { $0.id == id }) {
                    print("找到需要更新的翻译：")
                    print("- ID: \(id)")
                    print("- 原内容: \(transUnit.elements(forName: "target").first?.stringValue ?? "无")")
                    print("- 新内容: \(updatedUnit.target)")
                    
                    // 检查是否存在 target 元素
                    if let targetElement = transUnit.elements(forName: "target").first {
                        // 更新现有的 target 元素
                        targetElement.setStringValue(updatedUnit.target, resolvingEntities: false)
                    } else {
                        // 如果不存在 target 元素，创建一个新的
                        let targetElement = XMLElement(name: "target")
                        targetElement.setStringValue(updatedUnit.target, resolvingEntities: false)
                        
                        // 确保 target 元素插入在 source 和 note 之间
                        if let sourceElement = transUnit.elements(forName: "source").first,
                           let sourceIndex = transUnit.children?.firstIndex(of: sourceElement) {
                            transUnit.insertChild(targetElement, at: sourceIndex + 1)
                        } else {
                            transUnit.addChild(targetElement)
                        }
                    }
                    
                    // 验证更新是否成功
                    print("- 更新后的内容: \(transUnit.elements(forName: "target").first?.stringValue ?? "更新失败")")
                } else {
                    print("未找到 ID 为 \(id) 的更新翻译")
                }
            }

            // 保存前打印整个文档内容
            print("\n准备保存的 XLIFF 内容：")
            print(originalDoc.xmlString)

            // 保存更新后的 XLIFF 文件
            let options: XMLNode.Options = [.nodePrettyPrint]
            let updatedData = try originalDoc.xmlData(options: options)
            try updatedData.write(to: xliffURL, options: .atomic)

            // 验证保存后的内容
            if let savedContent = try? String(contentsOf: xliffURL, encoding: .utf8) {
                print("\n保存后的文件内容：")
                print(savedContent)
            }
        } else {
            // 如果文件不存在，创建新的 XLIFF 文件
            let doc = XMLDocument(rootElement: nil)
            let root = XMLElement(name: "xliff")
            root.addAttribute(XMLNode.attribute(withName: "version", stringValue: "1.2") as! XMLNode)
            root.addAttribute(XMLNode.attribute(withName: "xmlns", stringValue: "urn:oasis:names:tc:xliff:document:1.2") as! XMLNode)
            
            let fileElement = XMLElement(name: "file")
            fileElement.addAttribute(XMLNode.attribute(withName: "original", stringValue: "XLocale/Resources/Localizations/\(file.contents.developmentRegion).lproj/Localizable.strings") as! XMLNode)
            fileElement.addAttribute(XMLNode.attribute(withName: "source-language", stringValue: file.contents.developmentRegion) as! XMLNode)
            fileElement.addAttribute(XMLNode.attribute(withName: "target-language", stringValue: file.contents.targetLocale) as! XMLNode)
            fileElement.addAttribute(XMLNode.attribute(withName: "datatype", stringValue: "plaintext") as! XMLNode)
            
            let header = XMLElement(name: "header")
            fileElement.addChild(header)
            
            let body = XMLElement(name: "body")
            for unit in file.translationUnits {
                let transUnit = XMLElement(name: "trans-unit")
                transUnit.addAttribute(XMLNode.attribute(withName: "id", stringValue: unit.id) as! XMLNode)
                
                let source = XMLElement(name: "source", stringValue: unit.source)
                let target = XMLElement(name: "target", stringValue: unit.target)
                
                transUnit.addChild(source)
                transUnit.addChild(target)
                
                if let note = unit.note {
                    let noteElement = XMLElement(name: "note", stringValue: note)
                    transUnit.addChild(noteElement)
                }
                
                body.addChild(transUnit)
            }
            
            fileElement.addChild(body)
            root.addChild(fileElement)
            doc.setRootElement(root)
            
            let options: XMLNode.Options = [.nodePrettyPrint]
            try doc.xmlData(options: options).write(to: xliffURL)
        }
    }
}

// 在文件顶添加 XLIFFParser 
private class XLIFFParser: NSObject, XMLParserDelegate {
    private var currentUnit: (id: String, source: String, target: String, note: String?)?
    private var currentElement: String?
    private var currentValue: String?
    private var isCollectingCharacters = false
    
    var translationUnits: [TranslationUnit] = []
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        isCollectingCharacters = ["source", "target", "note"].contains(elementName)
        currentValue = ""
        
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
        if isCollectingCharacters {
            currentValue = (currentValue ?? "") + string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard var unit = currentUnit else { return }
        
        switch elementName {
        case "source":
            unit.source = currentValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            currentUnit = unit
        case "target":
            unit.target = currentValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            currentUnit = unit
        case "note":
            unit.note = currentValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            currentUnit = unit
        case "trans-unit":
            // 打印调试信息
            print("添加翻译单元：")
            print("ID: \(unit.id)")
            print("Source: \(unit.source)")
            print("Target: \(unit.target)")
            print("Note: \(unit.note ?? "无")")
            print("---")
            
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
        
        if isCollectingCharacters {
            currentValue = nil
            isCollectingCharacters = false
        }
        currentElement = nil
    }
} 
