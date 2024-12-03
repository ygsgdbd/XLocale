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
                    
                    // 添加一键翻译按钮和进度
                    HStack {
                        Button {
                            if viewModel.isTranslatingAll {
                                cancelTranslation()
                            } else {
                                Task {
                                    await translateAll()
                                }
                            }
                        } label: {
                            if viewModel.isTranslatingAll {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("翻译中...")
                                    Text("点击停止")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Label("一键翻译", systemImage: "wand.and.stars")
                            }
                        }
                        
                        if viewModel.isTranslatingAll {
                            ProgressView(value: translationProgress)
                                .progressViewStyle(.linear)
                                .frame(width: 100)
                            Text(String(format: "%.0f%%", translationProgress * 100))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        
                        Spacer()
                        
                        // 原有的筛选器
                        Picker("筛选", selection: $viewModel.currentFilter) {
                            Text("全部").tag(XclocViewModel.TranslationFilter.all)
                            Text("未翻译").tag(XclocViewModel.TranslationFilter.untranslated)
                            Text("已翻译").tag(XclocViewModel.TranslationFilter.translated)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                    }
                    .padding(.horizontal)
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
                        translations: viewModel.filteredTranslationUnits
                    )
                }
                .padding(.top)
            }
        } else {
            EmptyStateView(
                "选文件",
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

// MARK: - 翻译表格
private struct TranslationTable: View {
    let translations: [TranslationUnit]
    @State private var selectedID: TranslationUnit.ID?
    @EnvironmentObject private var viewModel: XclocViewModel
    
    private let maxTextLength = 1000
    
    private func statusEmoji(for item: TranslationUnit) -> String {
        if item.source.count > maxTextLength {
            return "⚠️"  // 文本过长
        }
        if item.target.isEmpty {
            return ""  // 待翻译
        }
        return ""
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            Table(translations, selection: $selectedID) {
                // 源文本列
                TableColumn("源文本") { item in
                    Text(item.source)
                }
                .width(min: 150, ideal: 200)
                
                // 翻译列
                TableColumn("翻译") { item in
                    HStack(spacing: 4) {
                        if item.id == viewModel.currentTranslatingUnit?.id {
                            ProgressView()
                                .controlSize(.small)
                        }
                        if item.target.isEmpty {
                            Text(statusEmoji(for: item))
                        } else {
                            Text(verbatim: item.target)
                        }
                        Spacer()  // 确保内容左对齐
                    }
                }
                .width(min: 150, ideal: 200)
                
                // 字符长度列
                TableColumn("字符数") { item in
                    HStack {
                        Text("\(item.source.count)")
                            .monospacedDigit()
                        if item.source.count > maxTextLength {
                            Text("⚠️")
                        }
                    }
                }
                .width(80)
                
                // 备注列
                TableColumn("备注") { item in
                    if let note = item.note {
                        Text(note)
                            .foregroundColor(.secondary)
                    }
                }
                .width(min: 100, ideal: 150)
            }
            .onChange(of: selectedID) { id in
                if !viewModel.isTranslatingAll {
                    let translation = translations.first { $0.id == id }
                    Task { @MainActor in
                        viewModel.selectTranslation(translation)
                    }
                }
            }
            .onChange(of: viewModel.currentTranslatingUnit) { unit in
                if let unit = unit {
                    withAnimation {
                        selectedID = unit.id
                        proxy.scrollTo(unit.id, anchor: .center)
                    }
                }
            }
            .scrollDisabled(viewModel.isTranslatingAll)
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
