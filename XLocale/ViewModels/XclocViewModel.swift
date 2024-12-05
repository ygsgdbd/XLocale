import Foundation
import SwiftUI
import Defaults

@MainActor
class XclocViewModel: ObservableObject {
    
    /// 翻译过滤器
    enum TranslationFilter: String {
        case all = "全部"
        case untranslated = "未翻译"
        case translated = "已翻译"
        
        func apply(to units: [TranslationUnit]) -> [TranslationUnit] {
            switch self {
            case .all: return units
            case .untranslated: return units.filter { $0.target.isEmpty }
            case .translated: return units.filter { !$0.target.isEmpty }
            }
        }
    }
    
    /// 翻译统计信息
    struct TranslationStats {
        let total: Int
        let translated: Int
        
        var untranslated: Int { total - translated }
        var progress: Double {
            guard total > 0 else { return 0 }
            return Double(translated) / Double(total)
        }
    }
    
    /// 翻译状态
    enum TranslationStatus {
        case started(String)
        case success(String)
        case failed(String, Error)
        case skipped(String)
    }
    
    // MARK: - Private Properties
    
    private let encoderConfiguration = XclocEncoder.Configuration(includeNotes: true)
    private lazy var encoder = XclocEncoder(configuration: encoderConfiguration)
    private let decoder = XclocDecoder()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentFile: XclocFile?
    @Published private(set) var xclocFiles: [XclocFile] = []
    @Published var searchText: String = ""
    @Published var currentFilter: TranslationFilter = .all
    @Published var selectedTranslation: TranslationUnit?
    @Published var errorMessage: String?
    @Published var isTranslating: Bool = false
    @Published var isTranslatingAll: Bool = false
    @Published var isImporting: Bool = false
    @Published var loadingMessage: String?
    @Published private(set) var translationStats: TranslationStats?
    @Published var xcodeProjectURL: URL? {
        didSet {
            // 保存到 Defaults
            Defaults[.lastXcodeProjectPath] = xcodeProjectURL?.path
        }
    }
    @Published var exportProgress: CommandProgressViewModel?
    @Published var importProgress: CommandProgressViewModel?
    
    // MARK: - Translation UI State
    @Published var translationProgress: Double = 0
    @Published var translationTask: Task<Void, Never>?
    @Published var selectedID: TranslationUnit.ID?
    @Published var showingClearConfirmation = false
    @Published var isShowingProgress = false
    @Published var translationLogs: [TranslationLog] = []
    
    init() {
        // 从 Defaults 恢复上次的项目路径
        if let path = Defaults[.lastXcodeProjectPath] {
            xcodeProjectURL = URL(fileURLWithPath: path)
        }
    }
    
    // MARK: - Computed Properties
    
    var filteredUnits: [TranslationUnit] {
        let filtered = currentFilter.apply(to: translationUnits)
        
        guard !searchText.isEmpty else { return filtered }
        return filtered.filter { unit in
            unit.source.localizedCaseInsensitiveContains(searchText) ||
            unit.target.localizedCaseInsensitiveContains(searchText) ||
            (unit.note?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var translationUnits: [TranslationUnit] {
        currentFile?.translationUnits ?? []
    }
    
    private func updateTranslationUnits(_ units: [TranslationUnit]) {
        guard var file = currentFile else { return }
        file.translationUnits = units
        currentFile = file
        updateTranslationStats()
    }
    
    func saveFile() {
        guard let file = currentFile else {
            return
        }
        
        loadingMessage = "正在保存文件..."
        
        Task {
            do {
                // 直接使用当前文件，不需要创建新的
                try await Task.detached(priority: .background) { [encoder, file] in
                    try encoder.encode(file, to: file.url)
                }.value
                
                if let reloadedFile = try? await Task.detached(priority: .background) { [decoder, file] in
                    try decoder.decode(from: file.url)
                }.value {
                    await MainActor.run {
                        self.currentFile = reloadedFile
                        self.updateTranslationStats()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "保存文件失败: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                self.loadingMessage = nil
            }
        }
    }
    
    func saveTranslation(_ translation: TranslationUnit) {
        var units = translationUnits
        guard let index = units.firstIndex(where: { $0.id == translation.id }) else {
            return
        }
        
        units[index] = translation
        
        if var file = currentFile {
            let updatedFile = XclocFile(
                url: file.url,
                contents: file.contents,
                translationUnits: units
            )
            
            do {
                try encoder.encode(updatedFile, to: file.url)
                
                if let reloadedFile = try? decoder.decode(from: file.url) {
                    currentFile = reloadedFile
                    updateTranslationStats()
                }
            } catch {
                errorMessage = "保存文件失败: \(error.localizedDescription)"
            }
        }
    }
    
    /// 开始导出
    @MainActor
    func startExport() {
        guard let projectURL = xcodeProjectURL else {
            errorMessage = "请先选择 Xcode 项目"
            return
        }
        
        // 检查是否有未保存的修改
        if !xclocFiles.isEmpty {
            let alert = NSAlert()
            alert.messageText = "导入新文件"
            alert.informativeText = "当前已有打开的文件，导入新文件将覆盖现有内容。请确保已保存所有修改。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "继续导入")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return }
        }
        
        exportProgress = CommandProgressViewModel(title: "导出本地化文件")
        
        Task.detached(priority: .userInitiated) { [weak self, decoder] in
            guard let self = self else { return }
            do {
                let exporter = XcodeExporter()
                
                // 执行导出操作
                let exportURL = try await exporter.exportLocalizations(from: projectURL) { status in
                    Task { @MainActor in
                        self.exportProgress?.appendLog(status.message)
                    }
                }
                
                // 在后台处理文件
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(
                    at: exportURL,
                    includingPropertiesForKeys: nil
                )
                
                // 在后解码文件
                let loadedFiles = try await withThrowingTaskGroup(of: XclocFile?.self) { group in
                    var files: [XclocFile] = []
                    
                    for url in contents where url.pathExtension == "xcloc" {
                        group.addTask { [decoder] in
                            try? await decoder.decode(from: url)
                        }
                    }
                    
                    for try await file in group {
                        if let file = file {
                            files.append(file)
                        }
                    }
                    
                    return files
                }
                
                // 更新 UI
                await MainActor.run {
                    // 直接替换文件列表
                    self.xclocFiles = loadedFiles
                    
                    // 选择第一个文件
                    if let firstFile = self.xclocFiles.first {
                        self.currentFile = firstFile
                        self.updateTranslationStats()
                    }
                    
                    // 添加延迟以确保日志显示完整
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        self.exportProgress?.isFinished = true
                        self.exportProgress = nil
                    }
                }
            } catch {
                await MainActor.run {
                    self.exportProgress?.appendLog("错误: \(error.localizedDescription)")
                    self.exportProgress?.isFinished = true
                    self.errorMessage = error.localizedDescription
                    self.exportProgress = nil
                }
            }
        }
    }
    
    /// 择文件
    func selectFile(_ url: URL) {
        loadingMessage = "正在打开文件..."
        
        do {
            let file = try decoder.decode(from: url)
            currentFile = file
            
            if !xclocFiles.contains(where: { $0.url == url }) {
                xclocFiles.append(file)
            }
            
            updateTranslationStats()
        } catch {
            errorMessage = "打开文件失败: \(error.localizedDescription)"
        }
        
        loadingMessage = nil
    }
    
    // MARK: - Translation Operations
    
    /// 译当前选中的单元
    @MainActor
    func translateCurrent() async {
        guard let translation = selectedTranslation else { return }
        isTranslating = true
        defer { isTranslating = false }
        
        // TODO: 实现翻译逻辑
        // let translatedText = try await translator.translate(translation.source)
        // saveTranslation(translation.with(target: translatedText))
    }
    
    /// 翻译所有未翻译的单元
    /// - Parameter progress: 进度回调
    @MainActor
    func translateAll(progress: @escaping (Double, TranslationStatus) -> Void) async {
        guard !isTranslatingAll else { return }
        isTranslatingAll = true
        defer { 
            isTranslatingAll = false
            progress(1.0, TranslationStatus.success("翻译完成"))
        }
        
        let untranslated = translationUnits.filter { $0.target.isEmpty }
        let total = Double(untranslated.count)
        var completed = 0.0
        
        guard let file = currentFile else { return }
        let targetLocale = file.contents.targetLocale
        
        do {
            let translator = try AITranslator()
            var updatedUnits = translationUnits // 创建一个可变副本
            
            for unit in untranslated {
                guard isTranslatingAll else { break }
                
                progress(completed / total, .started(unit.source))
                
                if unit.source.isEmpty {
                    progress(completed / total, .skipped(unit.source))
                    completed += 1
                    continue
                }
                
                do {
                    if let translatedText = try await translator.translate(unit.source, targetLocale: targetLocale) {
                        // 找到并更新对应的单元
                        if let index = updatedUnits.firstIndex(where: { $0.id == unit.id }) {
                            updatedUnits[index].target = translatedText
                            progress((completed + 1) / total, .success(unit.source))
                        }
                    }
                } catch {
                    progress((completed + 1) / total, .failed(unit.source, error))
                }
                
                completed += 1
            }
            
            // 批量更新所有翻译
            if var updatedFile = currentFile {
                updatedFile.translationUnits = updatedUnits
                try encoder.encode(updatedFile, to: updatedFile.url)
                
                if let reloadedFile = try? decoder.decode(from: updatedFile.url) {
                    currentFile = reloadedFile
                    updateTranslationStats()
                }
            }
            
        } catch {
            progress(completed / total, .failed("初始化翻译器失败", error))
        }
    }
    
    /// 取消批量翻译
    func cancelTranslation() {
        isTranslatingAll = false
    }
    
    /// 选择翻译单元
    func selectTranslation(_ translation: TranslationUnit) {
        selectedTranslation = translation
    }
    
    /// 清空所有翻译
    func clearAllTranslations() {
        let clearedUnits = translationUnits.map { unit in
            TranslationUnit(
                id: unit.id,
                source: unit.source,
                target: "",  // 清空翻译
                note: unit.note
            )
        }
        
        if var file = currentFile {
            file.translationUnits = clearedUnits
            currentFile = file
            saveFile()
        }
    }
    
    // MARK: - Xcode Integration
    
    /// 导入到 Xcode
    @MainActor
    func importToXcode() {
        guard let file = currentFile, let projectURL = xcodeProjectURL else {
            errorMessage = "请先选择文件和项目"
            return
        }
        
        isImporting = true
        let progressModel = CommandProgressViewModel(title: "导入本地化文件")
        importProgress = progressModel
        
        Task {
            defer {
                isImporting = false
            }
            
            do {
                let importer = XcodeExporter()
                try await importer.importLocalizations(from: file.url, to: projectURL) { status in
                    Task { @MainActor in
                        self.importProgress?.appendLog(status.message)
                        if status.isFinished {
                            self.importProgress?.isFinished = true
                            Task {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                self.importProgress = nil
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.importProgress?.appendLog("错误: \(error.localizedDescription)")
                    self.importProgress?.isFinished = true
                    self.errorMessage = error.localizedDescription
                    self.importProgress = nil
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateTranslationStats() {
        let total = translationUnits.count
        let translated = translationUnits.filter { !$0.target.isEmpty }.count
        
        translationStats = TranslationStats(
            total: total,
            translated: translated
        )
    }
    
    // MARK: - Translation UI Methods
    
    func startTranslateAll() async {
        guard currentFile != nil else { return }
        
        // 检查网络状态
        do {
            let translator = try AITranslator(settings: .shared)
            _ = try await translator.translate("test", targetLocale: "zh-Hans")
        } catch {
            await MainActor.run {
                NSAlert(error: error).runModal()
                return
            }
        }
        
        // 开始翻译
        isShowingProgress = true
        translationLogs = [TranslationLog(type: .info, message: "开始翻译...")]
        
        translationTask = Task {
            await translateAll { [weak self] progress, status in
                guard let self = self else { return }
                
                self.translationProgress = progress
                
                // 添加日志
                switch status {
                case .started(let text):
                    self.translationLogs.append(TranslationLog(type: .info, message: "正在翻译: \(text)"))
                case .success(let text):
                    self.translationLogs.append(TranslationLog(type: .success, message: "翻译成功: \(text)"))
                case .failed(let text, let error):
                    self.translationLogs.append(TranslationLog(type: .error, message: "翻译失败: \(text) - \(error.localizedDescription)"))
                case .skipped(let text):
                    self.translationLogs.append(TranslationLog(type: .warning, message: "跳过: \(text)"))
                }
            }
        }
        
        await translationTask?.value
        
        translationTask = nil
        translationProgress = 0
        isShowingProgress = false
        
        // 显示完成结果
        let alert = NSAlert()
        alert.messageText = "翻译完成"
        alert.informativeText = """
            总计: \(translationLogs.count)
            成功: \(translationLogs.filter { $0.type == .success }.count)
            失败: \(translationLogs.filter { $0.type == .error }.count)
            跳过: \(translationLogs.filter { $0.type == .warning }.count)
            """
        alert.runModal()
    }
    
    func cancelTranslateAll() {
        translationTask?.cancel()
        cancelTranslation()
        translationTask = nil
        translationProgress = 0
        isShowingProgress = false
        
        translationLogs.append(TranslationLog(type: .warning, message: "翻译已取消"))
    }
    
    // MARK: - UI Helper Methods
    
    func filterIcon(for filter: TranslationFilter) -> String {
        switch filter {
        case .all: return "list.bullet"
        case .translated: return "checkmark.circle.fill"
        case .untranslated: return "exclamationmark.circle.fill"
        }
    }
    
    var filterOptions: [(String, TranslationFilter)] {
        [
            ("全部 (\(translationStats?.total ?? 0))", .all),
            ("已翻译 (\(translationStats?.translated ?? 0))", .translated),
            ("未翻译 (\(translationStats?.untranslated ?? 0))", .untranslated)
        ]
    }
}
