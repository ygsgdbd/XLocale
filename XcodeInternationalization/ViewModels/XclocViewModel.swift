import SwiftUI
import AppKit

class XclocViewModel: ObservableObject {
    @Published var xclocFiles: [URL] = []
    @Published var selectedFile: XclocFile?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var fileBookmark: Data?
    
    @AppStorage("folderBookmark") private var folderBookmarkData: Data?
    @AppStorage("xclocBookmarks") private var xclocBookmarksString: String = "{}"
    
    private var xclocBookmarks: [String: Data] {
        get {
            if let data = xclocBookmarksString.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                return dict.compactMapValues { Data(base64Encoded: $0) }
            }
            return [:]
        }
        set {
            let dict = newValue.mapValues { $0.base64EncodedString() }
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let string = String(data: data, encoding: .utf8) {
                xclocBookmarksString = string
            }
        }
    }
    
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
            
            var newBookmarks: [String: Data] = [:]
            for xclocURL in xclocFiles {
                let bookmarkData = try xclocURL.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                newBookmarks[xclocURL.lastPathComponent] = bookmarkData
            }
            xclocBookmarks = newBookmarks
            
            print("找到 \(xclocFiles.count) 个 .xcloc 文件")
        } catch {
            errorMessage = "读取文件夹失败：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func parseXclocFile(_ url: URL) {
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
    
    func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.folder]
        
        if panel.runModal() == .OK {
            guard let url = panel.urls.first else { 
                print("未选择文件")
                return 
            }
            
            // 保存文件访问权限的书签
            do {
                print("开始创建书签")
                let bookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                self.fileBookmark = bookmark
                print("书签创建成功")
                
                // 立即开始访问
                let startAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if startAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                print("安全访问状态: \(startAccessing)")
                
                // 解析文件
                print("开始解析文件：\(url.path)")
                let file = try XclocParser.parse(xclocURL: url)
                selectedFile = file
                print("解析成功")
                
            } catch {
                print("创建书签失败: \(error)")
            }
        }
    }
} 