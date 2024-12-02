import SwiftUI

struct XclocEditor: View {
    @StateObject private var viewModel = XclocViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(width: 250)
        } content: {
            TranslationContentView()
                .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity)
                .layoutPriority(1)
        } detail: {
            DetailView()
                .frame(minWidth: 300)
                .layoutPriority(0.5)
        }
        .environmentObject(viewModel)
        .task {
            if viewModel.xclocFiles.isEmpty {
                viewModel.selectFolder()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Label("设置", systemImage: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - 侧边栏视图
private struct SidebarView: View {
    @EnvironmentObject private var viewModel: XclocViewModel
    
    var body: some View {
        FileListView()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.selectFolder()
                    } label: {
                        Label("选择文件夹", systemImage: "folder")
                    }
                }
            }
    }
}

// MARK: - 文件列表视图
private struct FileListView: View {
    @EnvironmentObject private var viewModel: XclocViewModel
    
    var body: some View {
        if viewModel.xclocFiles.isEmpty {
            VStack(spacing: 20) {
                ContentUnavailableView(
                    "没有文件",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("选择包含 .xcloc 文件的文件夹")
                )
                
                Button {
                    viewModel.selectFolder()
                } label: {
                    Label("选择目录", systemImage: "folder.badge.plus")
                        .padding()
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            List(Array(viewModel.xclocFiles.enumerated()), id: \.element, selection: $viewModel.selectedFileURL) { index, url in
                FileItemView(url: url, index: index)
            }
            .onChange(of: viewModel.selectedFileURL) { _, url in
                if let url = url {
                    viewModel.parseXclocFile(url)
                }
            }
        }
    }
}

// MARK: - 文件项视图
private struct FileItemView: View {
    let url: URL
    let index: Int
    @State private var stats: (total: Int, translated: Int, remaining: Int)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 文件名
            Text(url.lastPathComponent)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
            
            if let stats = stats {
                // 进度指示器
                HStack(spacing: 8) {
                    // 进度条
                    ProgressView(value: Double(stats.translated), total: Double(stats.total))
                        .progressViewStyle(.linear)
                        .tint(.green)
                    
                    // 统计数字
                    Text("\(stats.translated)/\(stats.total)")
                        .font(.monospacedCaption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 2)
        .tag(url)
        .task {
            await loadStats()
        }
    }
    
    @MainActor
    private func loadStats() async {
        do {
            // 在后台线程解析文件
            let stats = try await Task.detached(priority: .background) {
                let file = try XclocParser.parse(xclocURL: url)
                let total = file.translationUnits.count
                let translated = file.translationUnits.filter { !$0.target.isEmpty }.count
                return (total, translated, total - translated)
            }.value
            
            // 在主线程更新 UI
            self.stats = stats
        } catch {
            print("加载文件条数失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 中间内容视图
private struct TranslationContentView: View {
    @EnvironmentObject private var viewModel: XclocViewModel
    
    var body: some View {
        if let selectedFile = viewModel.selectedFile {
            VStack(spacing: 0) {
                // 顶部信息区域
                VStack(alignment: .leading, spacing: 16) {
                    // 文件基本信息
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.blue)
                        Text(selectedFile.url.lastPathComponent)
                            .font(.headline)
                    }
                    
                    // 语言信息
                    HStack(spacing: 24) {
                        Label {
                            Text(selectedFile.contents.developmentRegion)
                                .foregroundStyle(.primary)
                        } icon: {
                            Text("开发语言")
                                .foregroundStyle(.secondary)
                        }
                        
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        
                        Label {
                            Text(selectedFile.contents.targetLocale)
                                .foregroundStyle(.primary)
                        } icon: {
                            Text("目标语言")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                    
                    // 翻译进度
                    if let stats = viewModel.translationStats {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 16) {
                                Label("\(stats.total) 总条数", systemImage: "doc.text")
                                Label("\(stats.translated) 已翻译", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Label("\(stats.remaining) 未翻译", systemImage: "circle")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.callout)
                            
                            ProgressView(value: Double(stats.translated), total: Double(stats.total))
                                .progressViewStyle(.linear)
                                .tint(.green)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // 表格区域
                VStack(spacing: 12) {
                    // 筛选工具栏
                    HStack {
                        if let stats = viewModel.translationStats {
                            Text("\(viewModel.filteredTranslationUnits.count)/\(stats.total) 条")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("筛选", selection: $viewModel.currentFilter) {
                            Text("全部").tag(XclocViewModel.TranslationFilter.all)
                            Text("未翻译").tag(XclocViewModel.TranslationFilter.untranslated)
                            Text("已翻译").tag(XclocViewModel.TranslationFilter.translated)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                    }
                    .padding(.horizontal)
                    
                    // 翻译表格
                    TranslationTable(
                        translations: viewModel.filteredTranslationUnits,
                        selectedTranslation: $viewModel.selectedTranslation
                    )
                }
                .padding(.top)
            }
        } else {
            ContentUnavailableView(
                "选文件",
                systemImage: "doc.text",
                description: Text("从左侧选择要编辑的文件")
            )
        }
    }
}

// MARK: - 翻译表格
private struct TranslationTable: View {
    let translations: [TranslationUnit]
    @Binding var selectedTranslation: TranslationUnit?
    @State private var selectedID: TranslationUnit.ID?
    
    var body: some View {
        Table(translations, selection: $selectedID) {
            // 源文本列
            TableColumn("源文本") { item in
                Text(item.source)
            }
            .width(min: 150, ideal: 200)
            
            // 翻译列
            TableColumn("翻译") { item in
                Text(verbatim: item.target)
            }
            .width(min: 150, ideal: 200)
            
            // 备注列
            TableColumn("备注") { item in
                if let note = item.note {
                    Text(note)
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 100, ideal: 150)
        }
        .onChange(of: selectedID) { _, id in
            selectedTranslation = translations.first { $0.id == id }
        }
    }
}

// MARK: - 右侧详情视图
private struct DetailView: View {
    @EnvironmentObject private var viewModel: XclocViewModel
    
    var body: some View {
        if let translation = viewModel.selectedTranslation {
            TranslationDetailView(
                translation: translation,
                onSave: { updatedTranslation in
                    viewModel.saveTranslation(updatedTranslation)
                }
            )
        } else {
            ContentUnavailableView(
                "选择翻译",
                systemImage: "text.bubble",
                description: Text("从中间选择要编辑的翻译")
            )
        }
    }
}

// MARK: - 字体扩展
extension Font {
    static let monospacedBody = Font.system(.body, design: .monospaced)
    static let monospacedCaption = Font.system(.caption, design: .monospaced)
}

// MARK: - 表单字段组件
private struct FormField: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.monospacedCaption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(value)
                    .font(.monospacedBody)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制到剪贴板")
            }
        }
    }
}

// MARK: - 翻译详情视图
struct TranslationDetailView: View {
    @EnvironmentObject private var viewModel: XclocViewModel
    let translation: TranslationUnit
    let onSave: (TranslationUnit) -> Void
    @State private var editingTarget: String
    
    init(translation: TranslationUnit, onSave: @escaping (TranslationUnit) -> Void) {
        self.translation = translation
        self.onSave = onSave
        self._editingTarget = State(initialValue: translation.target)
    }
    
    private func saveTranslation() {
        var updatedTranslation = translation
        updatedTranslation.target = editingTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(updatedTranslation)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ID 显示
                FormField(label: "ID", value: translation.id)
                
                // 源文本显示
                FormField(label: "源文本", value: translation.source)
                
                // 翻译编辑区
                VStack(alignment: .leading, spacing: 4) {
                    Text("翻译")
                        .font(.monospacedCaption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $editingTarget)
                        .font(.monospacedBody)
                        .lineSpacing(4)
                        .frame(minHeight: 150)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: translation) {
                            editingTarget = $0.target
                        }
                }
                
                // 备注显示（如果有）
                if let note = translation.note {
                    FormField(label: "备注", value: note)
                }
                
                Spacer(minLength: 20)
                
                // 添加翻译按钮
                HStack {
                    Button {
                        Task {
                            await viewModel.translateCurrent()
                        }
                    } label: {
                        Label("AI 翻译", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isTranslating)
                    
                    Spacer()
                    
                    // 保存按钮
                    Button(action: saveTranslation) {
                        HStack {
                            Text("保存")
                            Text("⌘ + S")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut("s", modifiers: .command)
                    .help("保存翻译 (⌘S)")
                }
            }
            .padding(16)
            .overlay {
                if viewModel.isTranslating {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
}

#Preview {
    XclocEditor()
}
