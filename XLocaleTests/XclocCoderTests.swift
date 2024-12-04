import XCTest
@testable import XLocale

final class XclocCoderTests: XCTestCase {
    
    var tempDirectoryURL: URL!
    var testResourcesURL: URL!
    var decoder: XclocDecoder!
    var encoder: XclocEncoder!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 创建临时目录
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        
        // 设置测试资源目录
        testResourcesURL = Bundle(for: type(of: self))
            .url(forResource: "TestResources", withExtension: nil)!
        
        // 初始化编解码器
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
    
    /// 测试读取并保存不做修改的情况 - 验证文件完整性
    func testReadAndSaveWithoutModification() throws {
        // 1. 读取原始文件
        let sourceURL = testResourcesURL.appendingPathComponent("zh-Hant.xcloc")
        let xclocFile = try decoder.decode(from: sourceURL)
        
        // 2. 保存到新位置
        let outputURL = tempDirectoryURL.appendingPathComponent("test.xcloc")
        try encoder.encode(xclocFile, to: outputURL)
        
        // 3. 验证文件结构
        guard let sourcePaths = FileManager.default.subpaths(atPath: sourceURL.path),
              let outputPaths = FileManager.default.subpaths(atPath: outputURL.path) else {
            XCTFail("无法读取文件路径")
            return
        }
        
        // 打印文件列表，帮助调试
        print("\nSource files:")
        sourcePaths.sorted().forEach { print("- \($0)") }
        print("\nOutput files:")
        outputPaths.sorted().forEach { print("- \($0)") }
        
        // 验证文件列表相同
        XCTAssertEqual(
            Set(sourcePaths.filter { !$0.contains(".DS_Store") }),
            Set(outputPaths.filter { !$0.contains(".DS_Store") }),
            "文件列表应该相同"
        )
        
        // 4. 验证文件内容
        for path in sourcePaths where !path.contains(".DS_Store") {
            let sourceFileURL = sourceURL.appendingPathComponent(path)
            let outputFileURL = outputURL.appendingPathComponent(path)
            
            if !sourceFileURL.hasDirectoryPath {
                let sourceData = try Data(contentsOf: sourceFileURL)
                let outputData = try Data(contentsOf: outputFileURL)
                
                // 打印每个文件的内容哈希，帮助调试
                print("\nComparing file: \(path)")
                print("Source hash: \(sourceData.hashValue)")
                print("Output hash: \(outputData.hashValue)")
                
                XCTAssertEqual(
                    sourceData, outputData,
                    "文件内容应该相同: \(path)"
                )
            }
        }
    }
    
    /// 测试读取、修改并保存的情况 - 验证翻译内容的变化
    func testReadModifyAndSave() throws {
        // 1. 读取原始文件
        let sourceURL = testResourcesURL.appendingPathComponent("zh-Hant.xcloc")
        let originalFile = try decoder.decode(from: sourceURL)
        
        // 2. 修改一个翻译
        var modifiedFile = originalFile
        let targetUnit = modifiedFile.translationUnits.first { $0.id == "导出本地化" }
        XCTAssertNotNil(targetUnit, "应该能找到测试用的翻译单元")
        
        let modifiedUnit = TranslationUnit(
            id: targetUnit!.id,
            source: targetUnit!.source,
            target: "测试修改后的翻译",
            note: targetUnit!.note
        )
        modifiedFile.updateTranslation(modifiedUnit)
        
        // 3. 保存修改后的文件
        let outputURL = tempDirectoryURL.appendingPathComponent("modified.xcloc")
        try encoder.encode(modifiedFile, to: outputURL)
        
        // 4. 验证必要的文件存在
        let requiredPaths = [
            "contents.json",
            "Localized Contents/zh-Hant.xliff",
            "Source Contents/XLocale/Resources/Localizations/en.lproj/Localizable.strings"
        ]
        
        for path in requiredPaths {
            let fileURL = outputURL.appendingPathComponent(path)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: fileURL.path),
                "必要的文件应该存在: \(path)"
            )
        }
        
        // 5. 验证翻译内容被正确修改
        let decodedFile = try decoder.decode(from: outputURL)
        let modifiedTranslation = decodedFile.translationUnits.first { $0.id == "导出本地化" }
        XCTAssertNotNil(modifiedTranslation, "应该能找到修改后的翻译")
        XCTAssertEqual(modifiedTranslation?.target, "测试修改后的翻译", "翻���内容应该已更新")
        
        // 6. 验证基本信息保持不变
        XCTAssertEqual(decodedFile.contents.developmentRegion, originalFile.contents.developmentRegion)
        XCTAssertEqual(decodedFile.contents.targetLocale, originalFile.contents.targetLocale)
        XCTAssertEqual(decodedFile.contents.toolInfo.toolName, originalFile.contents.toolInfo.toolName)
        XCTAssertEqual(decodedFile.sourceContentPath, originalFile.sourceContentPath)
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