import XCTest
@testable import XLocale

final class XclocCoderTests: XCTestCase {
    
    var tempDirectoryURL: URL!
    var testResourcesURL: URL!
    var decoder: XclocDecoder!
    var encoder: XclocEncoder!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        
        testResourcesURL = Bundle(for: type(of: self))
            .url(forResource: "TestResources", withExtension: nil)!
        
        decoder = XclocDecoder()
        encoder = XclocEncoder()
    }
    
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDirectoryURL)
        decoder = nil
        encoder = nil
        tempDirectoryURL = nil
        testResourcesURL = nil
        try super.tearDownWithError()
    }
    
    /// 测试编解码能力，验证 contents.json 保持不变
    func testContentsJsonConsistency() throws {
        // 1. 读取原始文件
        let sourceURL = testResourcesURL.appendingPathComponent("zh-Hant.xcloc")
        let xclocFile = try decoder.decode(from: sourceURL)
        
        // 2. 保存到新位置
        let outputURL = tempDirectoryURL.appendingPathComponent("test.xcloc")
        try encoder.encode(xclocFile, to: outputURL)
        
        // 3. 读取并比较 contents.json
        let sourceContentsURL = sourceURL.appendingPathComponent("contents.json")
        let outputContentsURL = outputURL.appendingPathComponent("contents.json")
        
        let sourceContents = try String(contentsOf: sourceContentsURL, encoding: .utf8)
        let outputContents = try String(contentsOf: outputContentsURL, encoding: .utf8)
        
        // 将 JSON 字符串转换为字典进行比较，避免格式化差异
        let sourceJSON = try JSONSerialization.jsonObject(with: sourceContents.data(using: .utf8)!) as! [String: Any]
        let outputJSON = try JSONSerialization.jsonObject(with: outputContents.data(using: .utf8)!) as! [String: Any]
        
        XCTAssertEqual(
            NSDictionary(dictionary: sourceJSON),
            NSDictionary(dictionary: outputJSON),
            "contents.json 的内容应该完全相同"
        )
    }
    
    /// 测试修改翻译后的文件结构完整性
    func testModifyTranslationAndVerifyStructure() throws {
        // 1. 读取原始文件并记录原始结构
        let sourceURL = testResourcesURL.appendingPathComponent("zh-Hant.xcloc")
        var xclocFile = try decoder.decode(from: sourceURL)
        
        let originalContentsURL = sourceURL.appendingPathComponent("contents.json")
        let originalContents = try String(contentsOf: originalContentsURL, encoding: .utf8)
        let originalStructure = try FileManager.default.subpaths(atPath: sourceURL.path)?
            .filter { !$0.contains(".DS_Store") }
            .sorted() ?? []
        
        // 2. 修改翻译内容
        let targetUnit = xclocFile.translationUnits.first { $0.id == "导出本地化" }
        XCTAssertNotNil(targetUnit, "应该能找到测试用的翻译单元")
        
        let modifiedUnit = TranslationUnit(
            id: targetUnit!.id,
            source: targetUnit!.source,
            target: "测试修改后的翻译",
            note: targetUnit!.note
        )
        xclocFile.updateTranslation(modifiedUnit)
        
        // 3. 保存修改后的文件
        let outputURL = tempDirectoryURL.appendingPathComponent("modified.xcloc")
        try encoder.encode(xclocFile, to: outputURL)
        
        // 4. 验证文件结构保持不变
        let modifiedStructure = try FileManager.default.subpaths(atPath: outputURL.path)?
            .filter { !$0.contains(".DS_Store") }
            .sorted() ?? []
        
        XCTAssertEqual(originalStructure, modifiedStructure, "文件结构应保持不变")
        
        // 5. 验证 contents.json 内容保持不变
        let modifiedContentsURL = outputURL.appendingPathComponent("contents.json")
        let modifiedContents = try String(contentsOf: modifiedContentsURL, encoding: .utf8)
        
        let originalJSON = try JSONSerialization.jsonObject(with: originalContents.data(using: .utf8)!) as! [String: Any]
        let modifiedJSON = try JSONSerialization.jsonObject(with: modifiedContents.data(using: .utf8)!) as! [String: Any]
        
        XCTAssertEqual(
            NSDictionary(dictionary: originalJSON),
            NSDictionary(dictionary: modifiedJSON),
            "contents.json 的内容应该保持不变"
        )
        
        // 6. 验证翻译确实被修改
        let reloadedFile = try decoder.decode(from: outputURL)
        let modifiedTranslation = reloadedFile.translationUnits.first { $0.id == "导出本地化" }
        
        XCTAssertEqual(
            modifiedTranslation?.target,
            "测试修改后的翻译",
            "翻译内容应该已更新"
        )
    }
}

// MARK: - FileManager Extension
extension FileManager {
    /// 计算目录的哈希值
    func hashOfDirectory(at url: URL) throws -> Int {
        guard let contents = subpaths(atPath: url.path) else {
            throw NSError(domain: "FileManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "无法读取目录内容"
            ])
        }
        
        // 打印目录内容，帮助调试
        print("Directory contents at \(url.lastPathComponent):")
        for path in contents.sorted() {
            let fileURL = url.appendingPathComponent(path)
            if !fileURL.hasDirectoryPath {
                print("- \(path)")
            }
        }
        
        var hasher = Hasher()
        for path in contents.sorted() {
            let fileURL = url.appendingPathComponent(path)
            if !fileURL.hasDirectoryPath {
                let data = try Data(contentsOf: fileURL)
                // 打印每个文件的哈希值，帮助调试
                print("File hash for \(path): \(data.hashValue)")
                hasher.combine(path)
                hasher.combine(data)
            }
        }
        
        let finalHash = hasher.finalize()
        print("Final hash for \(url.lastPathComponent): \(finalHash)")
        return finalHash
    }
}