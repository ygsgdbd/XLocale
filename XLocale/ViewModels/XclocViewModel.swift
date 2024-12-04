import SwiftUI
import AppKit

@MainActor
class XclocViewModel: ObservableObject {
    @Published var xclocFiles: [URL] = []
    @Published var selectedFile: XclocFile?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var fileBookmark: Data?
    @Published private(set) var selectedTranslation: TranslationUnit?
    @Published var selectedFileURL: URL?
    
    @AppStorage("folderBookmark") private var folderBookmarkData: Data?
    
    enum TranslationFilter {
        case all
        case untranslated
        case translated
    }
    
    @Published var currentFilter: TranslationFilter = .all
    
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
    
    // 添加统计信息计算属性
    var translationStats: (total: Int, translated: Int, remaining: Int)? {
        guard let file = selectedFile else { return nil }
        let total = file.translationUnits.count
        let translated = file.translationUnits.filter { !$0.target.isEmpty }.count
        return (total, translated, total - translated)
    }
    
    private var translator: AITranslator?
    
    private func initTranslator() {
        do {
            translator = try AITranslator(settings: .shared)
        } catch {
            errorMessage = "初始化翻译服务失败：\(error.localizedDescription)"
        }
    }
    
    @Published var isTranslating = false
    @Published var isTranslatingAll = false
    @Published var currentTranslatingUnit: TranslationUnit?
    
    private var currentTask: Task<Void, Never>?  // 只保留当前任务追踪
    
    func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = false
        openPanel.prompt = "选择文件夹"
        openPanel.message = "请选择包含 .xcloc 文件的文件夹"
        
        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            
            if response == .OK, let url = openPanel.url {
                self.loadXclocFile(url: url)
            }
        }
    }
    
    func loadXclocFile(url: URL) {
        isLoading = true
        
        do {
            folderBookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            )
            
            xclocFiles = contents.filter { $0.pathExtension == "xcloc" }
            print("找到 \(xclocFiles.count) 个 .xcloc 文件")
            
        } catch {
            errorMessage = "读取文件夹失败：\(error.localizedDescription)"
        }
        
        isLoading = false
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
    
    private func parseXclocFile(_ url: URL) {
        isLoading = true
        
        do {
            guard url.isFileURL else {
                throw NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "无效的文件 URL"])
            }
            
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: url.path) else {
                throw NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "文件不存在：\(url.path)"])
            }
            
            let securitySuccess = url.startAccessingSecurityScopedResource()
            defer {
                if securitySuccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            guard fileManager.isReadableFile(atPath: url.path) else {
                throw NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "文件不可读取：\(url.path)"])
            }
            
            selectedFile = try XclocParser.parse(xclocURL: url)
            selectedTranslation = nil
            
        } catch {
            errorMessage = "解析文件失败：\(error.localizedDescription)"
        }
        
        isLoading = false
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
    
    func selectTranslation(_ translation: TranslationUnit?) {
        Task { @MainActor in
            self.selectedTranslation = translation
        }
    }
    
    /// 清空当前文件的所有翻译
    @MainActor
    func clearAllTranslations() {
        guard var selectedFile = selectedFile else { return }
        
        // 显示进度提示
        isTranslatingAll = true
        errorMessage = "正在清空翻译..."
        
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
                // 一次性保存所有更改
                try await Task.yield() // 允许其他任务执行
                try XclocParser.saveAll(file: selectedFile)
                
                // 回到主线程更新 UI
                await MainActor.run {
                    // 更新选中的文件
                    self.selectedFile = selectedFile
                    self.selectedTranslation = nil
                    self.isTranslatingAll = false
                    self.errorMessage = "已清空所有翻译"
                }
                
            } catch {
                // 回到主线程显示错误
                await MainActor.run {
                    self.isTranslatingAll = false
                    self.errorMessage = "清空翻译失败：\(error.localizedDescription)"
                }
            }
        }
    }
}
