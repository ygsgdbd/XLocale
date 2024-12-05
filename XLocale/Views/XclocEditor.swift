import SwiftUI

struct XclocEditor: View {
    @StateObject private var viewModel = XclocViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 200, idealWidth: 220, maxWidth: .infinity)
                .navigationTitle("文件")
        } content: {
            TranslationContentView()
                .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity)
                .layoutPriority(1)
        } detail: {
            DetailView()
                .frame(minWidth: 300, idealWidth: 350)
                .layoutPriority(0.5)
        }
        .environmentObject(viewModel)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.saveFile()
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
                .help("保存当前文件")
                .disabled(viewModel.currentFile == nil || viewModel.isTranslating)
                
                if viewModel.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                }
                
                Button {
                    showingSettings = true
                } label: {
                    Label("设置", systemImage: "gear")
                }
                .help("打开设置")
            }
        }
        .overlay {
            if let message = viewModel.loadingMessage {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $viewModel.showingExportProgress) {
            if let progressModel = viewModel.exportProgress {
                CommandProgressView(
                    viewModel: progressModel,
                    isPresented: $viewModel.showingExportProgress
                )
            }
        }
        .sheet(isPresented: $viewModel.showingImportProgress) {
            if let progressModel = viewModel.importProgress {
                CommandProgressView(
                    viewModel: progressModel,
                    isPresented: $viewModel.showingImportProgress
                )
            }
        }
        .alert("错误", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

// MARK: - 侧边栏视图
private struct SidebarView: View {
    var body: some View {
        FileListView()
    }
}


// MARK: - 中间内容视图
private struct TranslationContentView: View {
    @EnvironmentObject private var viewModel: XclocViewModel
    @State private var translationProgress: Double = 0
    @State private var translationTask: Task<Void, Never>?
    
    var body: some View {
        if let selectedFile = viewModel.selectedFile {
            VStack(spacing: 0) {
                // 顶部信息区域
                VStack(alignment: .leading, spacing: 12) {
                    // 文件信息区域
                    HStack(spacing: 16) {
                        Label(selectedFile.url.lastPathComponent, systemImage: "doc.text")
                            .font(.headline)
                        
                        Divider()
                            .frame(height: 16)
                        
                        // 语言信息
                        HStack(spacing: 8) {
                            Text(selectedFile.contents.developmentRegion)
                                .foregroundStyle(.primary)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                                .imageScale(.small)
                            Text(selectedFile.contents.targetLocale)
                                .foregroundStyle(.primary)
                        }
                        .font(.subheadline)
                    }
                    
                    // 翻译进度
                    if let stats = viewModel.translationStats {
                        HStack(spacing: 16) {
                            ProgressView(
                                value: Double(stats.translated),
                                total: Double(stats.total)
                            )
                            .frame(width: 100)
                            .tint(.green)
                            
                            HStack(spacing: 12) {
                                Label("\(stats.total)", systemImage: "doc.text")
                                Label("\(stats.translated)", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Label("\(stats.untranslated)", systemImage: "circle")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                            .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                .padding()
                .background(Material.bar)
                
                Divider()
                
                // 工具栏
                HStack {
                    // 一键翻译按钮
                    Button {
                        if viewModel.isTranslatingAll {
                            viewModel.cancelTranslation()
                        } else {
                            Task { await translateAll() }
                        }
                    } label: {
                        if viewModel.isTranslatingAll {
                            Label("停止翻译", systemImage: "stop.circle")
                        } else {
                            Label("一键翻译", systemImage: "wand.and.stars")
                        }
                    }
                    .help(viewModel.isTranslatingAll ? "停止翻译" : "自动翻译所有未翻译的文本")
                    
                    if viewModel.isTranslatingAll {
                        ProgressView(value: translationProgress)
                            .frame(width: 100)
                        Text(String(format: "%.0f%%", translationProgress * 100))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    
                    // 导入到 Xcode 按钮
                    Button {
                        viewModel.importToXcode()
                    } label: {
                        Label("导入到 Xcode", systemImage: "arrow.right.square")
                    }
                    .help("将翻译导入到 Xcode 项目")
                    .disabled(viewModel.currentFile == nil || viewModel.isImporting)
                    
                    if viewModel.isImporting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    
                    Spacer()
                    
                    // 筛选器
                    Picker("显示", selection: $viewModel.currentFilter) {
                        Label("全部", systemImage: "list.bullet")
                            .tag(XclocViewModel.TranslationFilter.all)
                        Label("未翻译", systemImage: "circle")
                            .tag(XclocViewModel.TranslationFilter.untranslated)
                        Label("已翻译", systemImage: "checkmark.circle")
                            .tag(XclocViewModel.TranslationFilter.translated)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                    .help("筛选显示的翻译条目")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
                
                // 翻译表格
                TranslationTableView(translations: viewModel.filteredUnits)
                    .background(Color(nsColor: .controlBackgroundColor))
            }
        } else {
            EmptyStateView(
                "选择文件",
                systemImage: "doc.text",
                description: Text("从左侧选择要编辑的文件")
            )
        }
    }
    
    private func translateAll() async {
        guard viewModel.selectedFile != nil else { return }
        
        // 创建并存储任务
        translationTask = Task {
            await viewModel.translateAll { progress in
                translationProgress = progress
            }
        }
        
        // 等待任务完成
        await translationTask?.value
        translationTask = nil
        translationProgress = 0
    }
    
    private func cancelTranslation() {
        translationTask?.cancel()
        translationTask = nil
        translationProgress = 0
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
            EmptyStateView(
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

// MARK: - 表单字组件
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
