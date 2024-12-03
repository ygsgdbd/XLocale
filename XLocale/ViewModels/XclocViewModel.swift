import SwiftUI
import AppKit

class XclocViewModel: ObservableObject {
    @Published var xclocFiles: [URL] = []
    @Published var selectedFile: XclocFile?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var fileBookmark: Data?
    @Published var selectedTranslation: TranslationUnit?
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
    
    func parseXclocFile(_ url: URL) {
        selectedFileURL = url
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
            print("安全访问状态: \(securitySuccess)")
            
            defer {
                if securitySuccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            guard fileManager.isReadableFile(atPath: url.path) else {
                throw NSError(domain: "", code: -1, 
                             userInfo: [NSLocalizedDescriptionKey: "文件不可读取：\(url.path)"])
            }
            
            print("开始解析文件：\(url.path)")
            selectedFile = try XclocParser.parse(xclocURL: url)
            selectedTranslation = nil
            print("解析成功")
            
        } catch {
            print("解析文件失败：\(error.localizedDescription)")
            errorMessage = "解析文件失败：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func saveTranslation(_ translation: TranslationUnit) {
        guard var file = selectedFile else {
            print("未选择文件")
            return
        }
        
        // 使用书签恢复文件访问权限
        if let bookmark = fileBookmark {
            do {
                print("开始恢复书签")
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmark,
                                options: .withSecurityScope,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)
                
                print("书签恢复成功，URL: \(url.path)")
                let startAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if startAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                print("安全访问状态: \(startAccessing)")
                
                // 更新和保存
                print("开始更新翻译")
                file.updateTranslation(translation)
                try XclocParser.save(file: file, translation: translation)
                selectedFile = file
                selectedTranslation = translation
                print("保存成功")
                
            } catch {
                print("恢复书签失败或保存失败: \(error)")
            }
        } else {
            print("书签不存在，重新创建书签")
            // 如果书签不存在，尝试重新创建
            if let url = selectedFile?.url {
                do {
                    fileBookmark = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    print("重新创建书签成功，重试保存")
                    // 递归调用，使用新创建的书签
                    saveTranslation(translation)
                } catch {
                    print("重新创建书签失败: \(error)")
                }
            }
        }
    }
    
    // 翻译单个条目
    func translateCurrent() async {
        guard let translation = selectedTranslation else { return }
        
        // 确保翻译器已初始化
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
            if let translatedText = try await translator.translate(translation.source) {
                updatedTranslation.target = translatedText
                saveTranslation(updatedTranslation)
            } else {
                errorMessage = "翻译失败：未获得翻译结果"
            }
            
        } catch {
            errorMessage = "翻译失败：\(error.localizedDescription)"
        }
    }
    
    // 翻译所有未翻译的条目
    func translateAll() async {
        guard let file = selectedFile else { return }
        
        // 确保翻译器已初始化
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
            
            // 获取所有未翻译的条目
            let untranslatedUnits = file.translationUnits.filter { $0.target.isEmpty }
            for unit in untranslatedUnits {
                if let translatedText = try await translator.translate(unit.source) {
                    var updatedUnit = unit
                    updatedUnit.target = translatedText
                    saveTranslation(updatedUnit)
                }
            }
            
        } catch {
            errorMessage = "批量翻译失败：\(error.localizedDescription)"
        }
    }
} 
