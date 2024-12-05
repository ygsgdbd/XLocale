import Foundation

/// 用于处理 Xcode 项目本地化文件导出的服务类
class XcodeExporter {
    /// 导出状态更新
    struct ExportStatus {
        let message: String
        let isFinished: Bool
    }
    
    /// 导出错误类型
    enum ExportError: LocalizedError {
        case invalidProjectPath
        case exportFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidProjectPath:
                return "无效的项目路径"
            case .exportFailed(let message):
                return "导出失败: \(message)"
            }
        }
    }
    
    /// 获取缓存目录路径
    private var cacheDirectory: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("XLocale/Exports")
    }
        
    /// 从 project.pbxproj 文件中获取支持的语言列表
    private func getKnownRegions(from projectURL: URL) throws -> [String] {
        // 查找 project.pbxproj 文件
        let pbxprojURL = projectURL.appendingPathComponent("project.pbxproj")
        let content = try String(contentsOf: pbxprojURL, encoding: .utf8)
        
        // 匹配 knownRegions 部分
        let pattern = #"knownRegions\s*=\s*\(\s*([^)]+)\s*\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) else {
            return []
        }
        
        // 提取语言列表
        if let range = Range(match.range(at: 1), in: content) {
            return content[range]
                .components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",\"")) }
                .filter { !$0.isEmpty && $0 != "Base" }  // 过滤掉空字符串和 Base
        }
        
        return []
    }
    
    /// 导出 Xcode 项目的本地化文件
    func exportLocalizations(
        from projectURL: URL,
        statusHandler: @escaping (ExportStatus) -> Void
    ) async throws -> URL {
        // 确保缓存目录存在
        try FileManager.default.createDirectory(at: cacheDirectory, 
                                             withIntermediateDirectories: true)
        
        // 清理旧的导出文件
        try? FileManager.default.removeItem(at: cacheDirectory)
        
        let projectPath = projectURL.path
        let exportPath = cacheDirectory.path
        
        statusHandler(.init(message: "开始导出本地化文件...", isFinished: false))
        
        // 获取支持的语言列表
        let languages = try getKnownRegions(from: projectURL)
        statusHandler(.init(message: "检测到支持的语言: \(languages.joined(separator: ", "))", isFinished: false))
        
        // 构建导出命令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        
        var arguments = [
            "-exportLocalizations",
            "-project", projectPath,
            "-localizationPath", exportPath
        ]
        
        // 添加每个语言的导出参数
        for language in languages {
            arguments.append(contentsOf: ["-exportLanguage", language])
        }
        
        process.arguments = arguments
        
        // 捕获输出
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // 创建文件句柄用于读取输出
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        // 异步读取输出
        Task {
            for try await line in outputHandle.bytes.lines {
                statusHandler(.init(message: line, isFinished: false))
            }
        }
        
        // 执行导出
        try process.run()
        process.waitUntilExit()
        
        // 检查执行结果
        if process.terminationStatus != 0 {
            let errorData = errorHandle.readDataToEndOfFile()
            if let errorMessage = String(data: errorData, encoding: .utf8) {
                statusHandler(.init(message: "错误: \(errorMessage)", isFinished: true))
                throw ExportError.exportFailed(errorMessage)
            } else {
                let message = "未知错误 (退出码: \(process.terminationStatus))"
                statusHandler(.init(message: message, isFinished: true))
                throw ExportError.exportFailed(message)
            }
        }
        
        statusHandler(.init(message: "导出完成，文件保存在: \(cacheDirectory.path)", isFinished: true))
        return cacheDirectory
    }
    
    /// 导入本地化文件到 Xcode 项目
    func importLocalizations(
        from xclocURL: URL,
        to projectURL: URL,
        statusHandler: @escaping (ExportStatus) -> Void
    ) async throws {
        statusHandler(.init(message: "开始导入...", isFinished: false))
        
        // 1. 读取并验证 contents.json
        let contentsURL = xclocURL.appendingPathComponent("contents.json")
        guard let contentsData = try? Data(contentsOf: contentsURL),
              let contents = try? JSONDecoder().decode(XclocContents.self, from: contentsData) else {
            throw ExportError.exportFailed("无法读取 contents.json")
        }
        
        // 2. 验证 XLIFF 文件
        let xliffURL = xclocURL.appendingPathComponent("Localized Contents")
            .appendingPathComponent("\(contents.targetLocale).xliff")
        guard FileManager.default.fileExists(atPath: xliffURL.path) else {
            throw ExportError.exportFailed("找不到对应的 XLIFF 文件：\(contents.targetLocale).xliff")
        }
        
        // 3. 验证 XLIFF 中的语言代码
        let xliffData = try Data(contentsOf: xliffURL)
        let xmlDoc = try XMLDocument(data: xliffData)
        guard let rootElement = xmlDoc.rootElement(),
              let fileElement = rootElement.elements(forName: "file").first,
              let targetLanguage = fileElement.attribute(forName: "target-language")?.stringValue else {
            throw ExportError.exportFailed("无法读取 XLIFF 文件的语言设置")
        }
        
        // 4. 检查语言代码是否一致
        if targetLanguage != contents.targetLocale {
            throw ExportError.exportFailed("""
                语言代码不一致：
                contents.json 中的目标语言为：\(contents.targetLocale)
                XLIFF 文件中的目标语言为：\(targetLanguage)
                请确保语言代码一致
                """)
        }
        
        statusHandler(.init(message: "验证文件结构完成", isFinished: false))
        
        // 5. 执行导入命令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [
            "-importLocalizations",
            "-project", projectURL.path,
            "-localizationPath", xclocURL.path
        ]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        Task {
            for try await line in outputHandle.bytes.lines {
                statusHandler(.init(message: line, isFinished: false))
            }
        }
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorHandle.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"
            throw ExportError.exportFailed(errorMessage)
        }
        
        // 等待文件系统同步
        try await Task.sleep(nanoseconds: 1_000_000_000)
        statusHandler(.init(message: "导入完成", isFinished: true))
    }
} 
