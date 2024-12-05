import Foundation
import SwiftUI
import Defaults

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
    
    // MARK: - Private Properties
    
    private let encoderConfiguration = XclocEncoder.Configuration(includeNotes: true)
    private lazy var encoder = XclocEncoder(configuration: encoderConfiguration)
    private let decoder = XclocDecoder()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentFile: XclocFile?
    @Published private(set) var translationUnits: [TranslationUnit] = []
    @Published private(set) var xclocFiles: [XclocFile] = []
    @Published var searchText: String = ""
    @Published var currentFilter: TranslationFilter = .all
    @Published var selectedTranslation: TranslationUnit?
    @Published var currentTranslatingUnit: TranslationUnit?
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
    @Published var showingExportProgress = false
    @Published private(set) var exportProgress: CommandProgressViewModel?
    @Published var showingImportProgress = false
    @Published private(set) var importProgress: CommandProgressViewModel?
    
    init() {
        // 从 Defaults 恢复上次的项目路径
        if let path = Defaults[.lastXcodeProjectPath] {
            xcodeProjectURL = URL(fileURLWithPath: path)
        }
    }
    
    // MARK: - Computed Properties
    
    var selectedFile: XclocFile? { currentFile }
    
    var filteredUnits: [TranslationUnit] {
        let filtered = currentFilter.apply(to: translationUnits)
        
        guard !searchText.isEmpty else { return filtered }
        return filtered.filter { unit in
            unit.source.localizedCaseInsensitiveContains(searchText) ||
            unit.target.localizedCaseInsensitiveContains(searchText) ||
            (unit.note?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var filteredTranslationUnits: [TranslationUnit] { filteredUnits }
    
    // MARK: - File Operations
    
    func openFile(at url: URL) {
        loadingMessage = "正在打开文件..."
        
        do {
            let file = try decoder.decode(from: url)
            currentFile = file
            translationUnits = file.translationUnits
            updateTranslationStats()
        } catch {
            errorMessage = "打开文件失败: \(error.localizedDescription)"
        }
        
        loadingMessage = nil
    }
    
    func saveFile() {
        guard let file = currentFile else {
            print("错误：没有打开的文件")
            return
        }
        
        loadingMessage = "正在保存文件..."
        print("\n准备保存整个文件：")
        print("- 文件路径：\(file.url.path)")
        print("- 翻译单元数量：\(translationUnits.count)")
        
        // 打印所有翻译单元
        print("\n当前所有翻译单元：")
        for unit in translationUnits {
            print("- ID: \(unit.id), Target: \(unit.target)")
        }
        
        do {
            var updatedFile = file
            updatedFile.translationUnits = translationUnits
            
            try encoder.encode(updatedFile, to: file.url)
            print("文件保存成功")
            
            // 验证保存结果
            if let savedFile = try? decoder.decode(from: file.url) {
                print("\n验证保存结果：")
                print("- 翻译单元数量：\(savedFile.translationUnits.count)")
                
                // 验证所有翻译
                print("\n保存后的翻译内容：")
                for unit in savedFile.translationUnits {
                    print("- ID: \(unit.id), Target: \(unit.target)")
                }
            }
            
            currentFile = updatedFile
            updateTranslationStats()
        } catch {
            print("保存文件失败：\(error.localizedDescription)")
            errorMessage = "保存文件失败: \(error.localizedDescription)"
        }
        
        loadingMessage = nil
    }
    
    func saveTranslation(_ translation: TranslationUnit) {
        print("\n准备保存单个翻译：")
        print("- ID: \(translation.id)")
        print("- Source: \(translation.source)")
        print("- Target: \(translation.target)")
        
        // 1. 更新内存中的翻译单元
        guard let index = translationUnits.firstIndex(where: { $0.id == translation.id }) else {
            print("错误：找不到要更新的翻译单元")
            return
        }
        
        // 打印更新前的状态
        print("\n更新前的状态：")
        print("- 内存中的翻译：\(translationUnits[index].target)")
        print("- 新的翻译：\(translation.target)")
        
        // 创建新的翻译单元
        let updatedUnit = TranslationUnit(
            id: translation.id,
            source: translation.source,
            target: translation.target,
            note: translation.note
        )
        
        // 更新内存中的翻译单元
        translationUnits[index] = updatedUnit
        print("\n内存更新后的状态：")
        print("- 更新后的翻译：\(translationUnits[index].target)")
        
        // 2. 更新文件
        if var file = currentFile {
            print("\n准备更新文件：")
            print("- 文件路径：\(file.url.path)")
            print("- 翻译单元总数：\(translationUnits.count)")
            
            // 创建新的文件对象
            let updatedFile = XclocFile(
                url: file.url,
                contents: file.contents,
                translationUnits: translationUnits
            )
            
            // 保存到磁盘
            do {
                try encoder.encode(updatedFile, to: file.url)
                print("文件保存成功")
                
                // 立即重新加载文件验证
                if let reloadedFile = try? decoder.decode(from: file.url),
                   let savedUnit = reloadedFile.translationUnits.first(where: { $0.id == translation.id }) {
                    print("\n重新加载验证：")
                    print("- ID: \(savedUnit.id)")
                    print("- Target: \(savedUnit.target)")
                    
                    // 更新当前文件
                    currentFile = reloadedFile
                    translationUnits = reloadedFile.translationUnits
                    updateTranslationStats()
                } else {
                    print("错误：无法重新加载文件进行验证")
                }
            } catch {
                print("保存文件失败：\(error.localizedDescription)")
                errorMessage = "保存文件失败: \(error.localizedDescription)"
            }
        } else {
            print("错误：没有打开的文件")
        }
    }
    
    /// 开始导出
    func startExport() {
        guard let projectURL = xcodeProjectURL else {
            errorMessage = "请先选择 Xcode 项目"
            return
        }
        
        let command = """
        xcodebuild -exportLocalizations \\
            -project \(projectURL.path) \\
            -localizationPath ~/Library/Caches/XLocale/Exports
        """
        
        // 创建进度视图模型
        let progressModel = CommandProgressViewModel(
            title: "导出本地化文件",
            command: command
        )
        
        // 开始导出
        Task { [weak self] in
            do {
                let exporter = XcodeExporter()
                let exportURL = try await exporter.exportLocalizations(
                    from: projectURL
                ) { progress in
                    Task { @MainActor in
                        progressModel.appendLog(progress.message)
                        progressModel.updateProgress(progress.progress)
                    }
                }
                
                // 扫描导出目录中的所有 xcloc 文件
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(
                    at: exportURL,
                    includingPropertiesForKeys: nil
                )
                
                let xclocFiles = contents.filter { $0.pathExtension == "xcloc" }
                
                await MainActor.run {
                    // 加载所有 xcloc 文件
                    for url in xclocFiles {
                        if let xclocFile = try? self?.decoder.decode(from: url) {
                            if !(self?.xclocFiles.contains(where: { $0.url == xclocFile.url }) ?? false) {
                                self?.xclocFiles.append(xclocFile)
                            }
                        }
                    }
                    
                    // 如果文件，选择第一个
                    if let firstFile = self?.xclocFiles.first {
                        self?.currentFile = firstFile
                        self?.translationUnits = firstFile.translationUnits
                        self?.updateTranslationStats()
                    }
                    
                    // 完成后自动关闭窗口
                    progressModel.finish()
                    self?.showingExportProgress = false
                }
            } catch {
                await MainActor.run {
                    progressModel.appendLog("错误: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
        
        // 设置视图模型
        exportProgress = progressModel
        showingExportProgress = true
    }
    
    /// 选择文件
    func selectFile(_ url: URL) {
        loadingMessage = "正在打开文件..."
        
        do {
            let file = try decoder.decode(from: url)
            currentFile = file
            
            if !xclocFiles.contains(where: { $0.url == url }) {
                xclocFiles.append(file)
            }
            
            translationUnits = file.translationUnits
            updateTranslationStats()
        } catch {
            errorMessage = "打开文件失败: \(error.localizedDescription)"
        }
        
        loadingMessage = nil
    }
    
    // MARK: - Translation Operations
    
    /// 翻译当前选中的单元
    @MainActor
    func translateCurrent() async {
        guard let translation = selectedTranslation else { return }
        isTranslating = true
        
        do {
            // TODO: 实翻译逻辑
            // let translatedText = try await translator.translate(translation.source)
            // saveTranslation(translation.with(target: translatedText))
        } catch {
            errorMessage = "翻译失败: \(error.localizedDescription)"
        }
        
        isTranslating = false
    }
    
    /// 翻译所有未翻译的单元
    /// - Parameter progress: 进度回调
    @MainActor
    func translateAll(progress: @escaping (Double) -> Void) async {
        guard !isTranslatingAll else { return }
        isTranslatingAll = true
        
        let untranslated = translationUnits.filter { $0.target.isEmpty }
        let total = Double(untranslated.count)
        var completed = 0.0
        
        do {
            for unit in untranslated {
                guard isTranslatingAll else { break }  // 检查是否被取消
                
                // TODO: 实现翻译逻辑
                // let translatedText = try await translator.translate(unit.source)
                // saveTranslation(unit.with(target: translatedText))
                
                completed += 1
                progress(completed / total)
            }
        } catch {
            errorMessage = "批量翻译失败: \(error.localizedDescription)"
        }
        
        isTranslatingAll = false
        progress(1.0)
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
        translationUnits = translationUnits.map { unit in
            TranslationUnit(
                id: unit.id,
                source: unit.source,
                target: "",  // 清空翻译
                note: unit.note
            )
        }
        
        if var file = currentFile {
            file.translationUnits = translationUnits
            currentFile = file
            saveFile()
            updateTranslationStats()
        }
    }
    
    // MARK: - Xcode Integration
    
    /// 导入到 Xcode
    func importToXcode() {
        guard let file = currentFile else {
            errorMessage = "没有打开的文件"
            return
        }
        
        guard let projectURL = xcodeProjectURL else {
            errorMessage = "请先选择 Xcode 项目"
            return
        }
        
        let command = """
        xcodebuild -importLocalizations \\
            -project \(projectURL.path) \\
            -localizationPath \(file.url.path)
        """
        
        // 创建进度视图模型
        let progressModel = CommandProgressViewModel(
            title: "导入本地化文件",
            command: command
        )
        
        // 开始导入
        Task { [weak self] in
            do {
                let importer = XcodeExporter()
                try await importer.importLocalizations(
                    from: file.url,
                    to: projectURL
                ) { progress in
                    Task { @MainActor in
                        progressModel.appendLog(progress.message)
                        progressModel.updateProgress(progress.progress)
                    }
                }
                
                await MainActor.run {
                    // 完成后自动关闭窗口
                    progressModel.finish()
                    self?.showingImportProgress = false
                }
            } catch {
                await MainActor.run {
                    progressModel.appendLog("错误: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
        
        // 设置视图模型���显示窗口
        importProgress = progressModel
        showingImportProgress = true
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
    
}
