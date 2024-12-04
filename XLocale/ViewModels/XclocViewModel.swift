import SwiftUI
import UniformTypeIdentifiers
import AppKit

@MainActor
class XclocViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var xclocFiles: [URL] = []
    @Published var selectedFile: XclocFile?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var fileBookmark: Data?
    @Published private(set) var selectedTranslation: TranslationUnit?
    @Published var selectedFileURL: URL?
    @Published var isTranslating = false
    @Published var isTranslatingAll = false
    @Published var currentTranslatingUnit: TranslationUnit?
    @Published var isExporting = false
    @Published var loadingMessage: String?
    @Published var exportProgress: Double = 0
    @Published var exportLog: String = ""
    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var importLog: String = ""
    @Published var projectURL: URL?
    
    // MARK: - Private Properties
    private var translator: AITranslator?
    private var currentTask: Task<Void, Never>?
    private let xcodeExporter = XcodeExporter()
    
    @AppStorage("folderBookmark") private var folderBookmarkData: Data?
    @AppStorage("lastProjectURL") private var lastProjectBookmark: Data?
    
    // MARK: - Enums
    enum TranslationFilter {
        case all
        case untranslated
        case translated
    }
    
    @Published var currentFilter: TranslationFilter = .all
    
    // MARK: - Computed Properties
    var filteredTranslationUnits: [TranslationUnit] {
        guard let file = selectedFile else { return [] }
        
        switch currentFilter {
        case .all:
            return file.translationUnits
        case .untranslated:
            return file.translationUnits.filter { $0.target.isEmpty }
        case .translated:
            return file.translationUnits.filter { !$0.target.isEmpty }
        }
    }
    
    var translationStats: (total: Int, translated: Int, remaining: Int)? {
        guard let file = selectedFile else { return nil }
        let total = file.translationUnits.count
        let translated = file.translationUnits.filter { !$0.target.isEmpty }.count
        return (total, translated, total - translated)
    }
    
    // MARK: - Initialization
    private func initTranslator() {
        do {
            translator = try AITranslator(settings: .shared)
        } catch {
            errorMessage = "初始化翻译服务失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: - Public Methods
    /// 开始导出流程
    func startExport() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["xcodeproj", "xcworkspace"]
        panel.message = "选择 Xcode 项目文件"
        panel.prompt = "导出"
        
        // 如果有上次使用的项目路径，设置为初始目录
        if let bookmark = lastProjectBookmark {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmark,
                                options: .withSecurityScope,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)
                if !isStale {
                    panel.directoryURL = url.deletingLastPathComponent()
                }
            } catch {
                print("恢复项目路径失败：\(error.localizedDescription)")
            }
        }
        
        guard panel.runModal() == .OK,
              let url = panel.url else { return }
        
        // 保存项目路径
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            lastProjectBookmark = bookmark
            projectURL = url
        } catch {
            print("保存项目路径失败：\(error.localizedDescription)")
        }
        
        Task {
            do {
                isExporting = true
                exportProgress = 0
                exportLog = "开始导出...\n"
                
                let exportedURL = try await xcodeExporter.exportLocalizations(from: url) { progress in
                    Task { @MainActor in
                        self.exportProgress = progress.progress
                        self.exportLog += progress.message + "\n"
                    }
                }
                
                loadingMessage = "正在加载本地化文件..."
                await MainActor.run {
                    loadXclocFiles(from: exportedURL)
                }
                
            } catch {
                errorMessage = "导出失败: \(error.localizedDescription)"
                exportLog += "错误: \(error.localizedDescription)\n"
            }
            
            isExporting = false
            loadingMessage = nil
        }
    }
    
    @MainActor
    func selectFile(_ url: URL?) {
        // 如果正在翻译，先取消翻译
        if isTranslatingAll {
            cancelTranslation()
        }
        
        if let url = url {
            selectedFileURL = url
            parseXclocFile(url)
        } else {
            selectedFileURL = nil
            selectedFile = nil
            selectedTranslation = nil
        }
    }
    
    // MARK: - Private Methods
    /// 加载 xcloc 文件
    private func loadXclocFiles(from url: URL) {
        do {
            // 获取目录内容
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            )
            
            // 过滤出 xcloc 文件
            xclocFiles = contents.filter { $0.pathExtension == "xcloc" }
            
            if xclocFiles.isEmpty {
                errorMessage = "未找到可用的本地化文件"
            } else {
                // 为每个文件创建安全访问书签
                for fileURL in xclocFiles {
                    do {
                        let bookmark = try fileURL.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        // 存储书签数据
                        UserDefaults.standard.set(bookmark, forKey: "bookmark_\(fileURL.lastPathComponent)")
                    } catch {
                        print("创建文件书签失败：\(error.localizedDescription)")
                    }
                }
                
                // 保存文件夹书签
                folderBookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                print("找到 \(xclocFiles.count) 个本地化文件")
            }
            
        } catch {
            errorMessage = "读取本地化文失败：\(error.localizedDescription)"
        }
    }
    
    private func parseXclocFile(_ url: URL) {
        isLoading = true
        
        do {
            guard url.isFileURL else {
                throw NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "无效的文件 URL"])
            }
            
            var fileToAccess = url
            
            // 尝试恢复文件访问权限
            if let bookmarkData = UserDefaults.standard.data(forKey: "bookmark_\(url.lastPathComponent)") {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    // 如果书签过期，重新创建
                    let newBookmark = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    UserDefaults.standard.set(newBookmark, forKey: "bookmark_\(url.lastPathComponent)")
                }
                
                fileToAccess = resolvedURL
            }
            
            let securitySuccess = fileToAccess.startAccessingSecurityScopedResource()
            defer {
                if securitySuccess {
                    fileToAccess.stopAccessingSecurityScopedResource()
                }
            }
            
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: fileToAccess.path) else {
                throw NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "文件不存在：\(fileToAccess.path)"])
            }
            
            guard fileManager.isReadableFile(atPath: fileToAccess.path) else {
                throw NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "文件不可读取：\(fileToAccess.path)"])
            }
            
            // 使用正确的 URL 解析文件
            selectedFile = try XclocParser.parse(xclocURL: fileToAccess)
            selectedTranslation = nil
            
            print("成功加载文件：\(fileToAccess.lastPathComponent)")
            print("找到 \(selectedFile?.translationUnits.count ?? 0) 个翻译条目")
            
        } catch {
            errorMessage = "解析文件失败：\(error.localizedDescription)"
            print("解析失败：\(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Translation Methods
    func selectTranslation(_ translation: TranslationUnit?) {
        Task { @MainActor in
            self.selectedTranslation = translation
        }
    }
    
    @MainActor
    func translateCurrent() async {
        guard let translation = selectedTranslation,
              let file = selectedFile else { return }
        
        if translator == nil {
            initTranslator()
        }
        
        guard let translator = translator else {
            errorMessage = "翻译服务初始化失败"
            return
        }
        
        do {
            isTranslating = true
            defer { isTranslating = false }
            
            var updatedTranslation = translation
            if let translatedText = try await translator.translate(
                translation.source,
                targetLocale: file.contents.targetLocale
            ) {
                updatedTranslation.target = translatedText
                saveTranslation(updatedTranslation)
            } else {
                errorMessage = "翻译失败：未获得翻译结果"
            }
            
        } catch {
            errorMessage = "翻译失败：\(error.localizedDescription)"
        }
    }
    
    func cancelTranslation() {
        currentTask?.cancel()
        currentTask = nil
        isTranslatingAll = false
        currentTranslatingUnit = nil
    }
    
    @MainActor
    func translateAll(progress: @escaping (Double) -> Void) async {
        guard let file = selectedFile else { return }
        
        isTranslatingAll = true
        defer { 
            isTranslatingAll = false 
            currentTranslatingUnit = nil
        }
        
        let untranslatedUnits = file.translationUnits.filter { 
            $0.target.isEmpty && $0.source.count <= 1000  // 只翻译长度合适的文本
        }
        let total = Double(untranslatedUnits.count)
        var completed = 0.0
        
        do {
            if translator == nil {
                initTranslator()
            }
            
            guard let translator = translator else {
                errorMessage = "翻译服务初始化失败"
                return
            }
            
            for unit in untranslatedUnits {
                try Task.checkCancellation()
                
                currentTranslatingUnit = unit
                
                if let translatedText = try await translator.translate(
                    unit.source,
                    targetLocale: file.contents.targetLocale
                ) {
                    var updatedUnit = unit
                    updatedUnit.target = translatedText
                    saveTranslation(updatedUnit)
                }
                
                completed += 1
                progress(completed / total)
            }
            
        } catch is CancellationError {
            print("翻译任务已取消")
        } catch {
            errorMessage = "批量翻译失败：\(error.localizedDescription)"
        }
    }
    
    @MainActor
    func saveTranslation(_ translation: TranslationUnit) {
        guard var file = selectedFile else {
            print("未选择文件")
            return
        }
        
        do {
            file.updateTranslation(translation)
            try XclocParser.save(file: file, translation: translation)
            selectedFile = file
            selectedTranslation = translation
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
    
    /// 清空当前文件的所有翻译
    @MainActor
    func clearAllTranslations() {
        guard var selectedFile = selectedFile else { return }
        
        // 显示进度提示
        isTranslatingAll = true
        errorMessage = "正在清空翻译..."
        
        // 确保文件可访问
        let fileURL = selectedFile.url
        if let bookmarkData = UserDefaults.standard.data(forKey: "bookmark_\(fileURL.lastPathComponent)") {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                let securitySuccess = resolvedURL.startAccessingSecurityScopedResource()
                defer {
                    if securitySuccess {
                        resolvedURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                // 创建新的翻译单元，清空目标文本
                let clearedUnits = selectedFile.translationUnits.map { unit in
                    var newUnit = unit
                    newUnit.target = ""
                    return newUnit
                }
                
                // 更新文件内容
                selectedFile.translationUnits = clearedUnits
                
                // 在后台线程保存文件
                Task.detached {
                    do {
                        try XclocParser.saveAll(file: selectedFile)
                        
                        // 回到主线程更新 UI
                        await MainActor.run {
                            self.selectedFile = selectedFile
                            self.selectedTranslation = nil
                            self.isTranslatingAll = false
                            self.errorMessage = "已清空所有翻译"
                        }
                        
                    } catch {
                        await MainActor.run {
                            self.isTranslatingAll = false
                            self.errorMessage = "清空翻译失败：\(error.localizedDescription)"
                        }
                    }
                }
            } catch {
                isTranslatingAll = false
                errorMessage = "访问文件失败：\(error.localizedDescription)"
            }
        } else {
            isTranslatingAll = false
            errorMessage = "无法访问文件，请重新导出"
        }
    }
    
    func importToXcode() {
        guard let selectedFile = selectedFile else {
            errorMessage = "请先选择要导入的翻译文件"
            return
        }
        
        // 如果有保存的项目路径，直接使用
        if let projectURL = projectURL {
            importToProject(selectedFile, projectURL: projectURL)
            return
        }
        
        // 否则让用户选择项目
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["xcodeproj", "xcworkspace"]
        panel.message = "请选择要导入到的 Xcode 项目文件"
        panel.prompt = "选择项目"
        
        guard panel.runModal() == .OK,
              let url = panel.url else { return }
        
        // 保存项目路径
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            lastProjectBookmark = bookmark
            projectURL = url
        } catch {
            print("保存项目路径失败：\(error.localizedDescription)")
        }
        
        importToProject(selectedFile, projectURL: url)
    }
    
    private func importToProject(_ file: XclocFile, projectURL: URL) {
        Task {
            do {
                isImporting = true
                importProgress = 0
                importLog = "正在导入翻译到 \(projectURL.lastPathComponent)...\n"
                
                let securitySuccess = file.url.startAccessingSecurityScopedResource()
                defer {
                    if securitySuccess {
                        file.url.stopAccessingSecurityScopedResource()
                    }
                }
                
                try await xcodeExporter.importLocalizations(
                    from: file.url,
                    to: projectURL,
                    progressHandler: { progress in
                        Task { @MainActor in
                            self.importProgress = progress.progress
                            self.importLog += progress.message + "\n"
                        }
                    }
                )
                
                await MainActor.run {
                    errorMessage = "已成功导入翻译到 \(projectURL.lastPathComponent)"
                }
                
            } catch {
                errorMessage = "导入失败: \(error.localizedDescription)"
                importLog += "错误: \(error.localizedDescription)\n"
            }
            
            isImporting = false
        }
    }
}
