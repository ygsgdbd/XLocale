import Foundation

/// 用于处理 Xcode 项目本地化文件导出的服务类
class XcodeExporter {
    /// 导出进度更新
    struct ExportProgress {
        let progress: Double
        let message: String
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
    
    /// 导出 Xcode 项目的本地化文件
    /// - Parameters:
    ///   - projectURL: Xcode 项目文件路径
    ///   - progressHandler: 进度更新回调
    /// - Returns: 导出的 xcloc 文件所在目录
    func exportLocalizations(
        from projectURL: URL,
        progressHandler: @escaping (ExportProgress) -> Void
    ) async throws -> URL {
        // 确保缓存目录存在
        try FileManager.default.createDirectory(at: cacheDirectory, 
                                             withIntermediateDirectories: true)
        
        // 清理旧的导出文件
        try? FileManager.default.removeItem(at: cacheDirectory)
        
        let projectPath = projectURL.path
        let exportPath = cacheDirectory.path
        
        // 构建导出命令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [
            "-exportLocalizations",
            "-project", projectPath,
            "-localizationPath", exportPath
        ]
        
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
                // 解析进度
                if line.contains("Copying") {
                    progressHandler(.init(progress: 0.3, message: line))
                } else if line.contains("Writing") {
                    progressHandler(.init(progress: 0.6, message: line))
                } else if line.contains("Done") {
                    progressHandler(.init(progress: 1.0, message: "导出完成"))
                } else {
                    progressHandler(.init(progress: 0.1, message: line))
                }
            }
        }
        
        // 执行导出
        try process.run()
        process.waitUntilExit()
        
        // 检查执行结果
        if process.terminationStatus != 0 {
            let errorData = errorHandle.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"
            throw ExportError.exportFailed(errorMessage)
        }
        
        return cacheDirectory
    }
    
    /// 导入本地化文件到 Xcode 项目
    /// - Parameters:
    ///   - xclocURL: 本地化文件目录
    ///   - projectURL: Xcode 项目文件路径
    ///   - progressHandler: 进度更新回调
    func importLocalizations(
        from xclocURL: URL,
        to projectURL: URL,
        progressHandler: @escaping (ExportProgress) -> Void
    ) async throws {
        // 1. 先导出一次当前的本地化文件（强制 Xcode 刷新缓存）
        let tempExportPath = FileManager.default.temporaryDirectory.appendingPathComponent("XLocaleTemp")
        try? FileManager.default.removeItem(at: tempExportPath)
        try FileManager.default.createDirectory(at: tempExportPath, withIntermediateDirectories: true)
        
        let exportProcess = Process()
        exportProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        exportProcess.arguments = [
            "-exportLocalizations",
            "-project", projectURL.path,
            "-localizationPath", tempExportPath.path
        ]
        try exportProcess.run()
        exportProcess.waitUntilExit()
        
        // 2. 清理派生数据
        let derivedDataPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Developer/Xcode/DerivedData")
        
        if let projectName = projectURL.deletingPathExtension().lastPathComponent
            .components(separatedBy: ".").first {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: derivedDataPath,
                    includingPropertiesForKeys: nil
                )
                for item in contents where item.lastPathComponent.contains(projectName) {
                    try? FileManager.default.removeItem(at: item)
                }
            } catch {
                print("清理派生数据失败：\(error.localizedDescription)")
            }
        }
        
        // 3. 执行导入
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [
            "-importLocalizations",
            "-project", projectURL.path,
            "-localizationPath", xclocURL.path
        ]
        
        // 设置环境变量
        var environment = ProcessInfo.processInfo.environment
        environment["DERIVED_DATA_CACHE_ROOT"] = NSTemporaryDirectory()
        process.environment = environment
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        Task {
            for try await line in outputHandle.bytes.lines {
                if line.contains("Importing") {
                    progressHandler(.init(progress: 0.3, message: line))
                } else if line.contains("Writing") {
                    progressHandler(.init(progress: 0.6, message: line))
                } else if line.contains("Done") {
                    progressHandler(.init(progress: 1.0, message: "导入完成"))
                } else {
                    progressHandler(.init(progress: 0.1, message: line))
                }
            }
        }
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorHandle.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"
            throw ExportError.exportFailed(errorMessage)
        }
        
        // 4. 清理临时文件
        try? FileManager.default.removeItem(at: tempExportPath)
        
        // 5. 等待文件系统同步
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
} 