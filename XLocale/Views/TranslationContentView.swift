import SwiftUI
import SwiftUIX

struct TranslationContentView: View {
    @EnvironmentObject private var viewModel: XclocViewModel
    @ObservedObject private var settings = AISettings.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.currentFile != nil {
                // 工具栏
                toolbar
                // 翻译表格
                translationTable
            } else {
                EmptyStateView(
                    "选择文件",
                    systemImage: "doc.text",
                    description: Text("从左侧选择要编辑的文件")
                )
            }
        }
        .sheet(isPresented: $viewModel.isShowingProgress) {
            TranslationProgressView(
                title: "正在翻译...",
                progress: $viewModel.translationProgress,
                logs: $viewModel.translationLogs,
                onCancel: viewModel.cancelTranslateAll
            )
        }
    }
    
    // MARK: - Toolbar Components
    
    private var toolbar: some View {
        VStack(spacing: 0) {
            // 主工具栏
            HStack(spacing: 16) {
                // 左侧：当前文件信息
                if let currentFile = viewModel.currentFile {
                    currentFileInfo(currentFile)
                    
                    Divider()
                        .frame(height: 24)
                }
                
                // 筛选器
                filterSection
                
                Spacer()
                
                // AI 服务商选择
                Picker("", selection: $settings.config.provider) {
                    ForEach(AIProviderType.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .frame(width: 120)
                .help("选择 AI 服务商")
                
                // 右侧：操作按钮
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Material.bar)
            
            Divider()
        }
    }
    
    // 添加当前文件信视图
    private func currentFileInfo(_ file: XclocFile) -> some View {
        HStack(spacing: 12) {
            // 基本文件信息
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.url.deletingPathExtension().lastPathComponent)
                        .fontWeight(.medium)
                    
                    Text(file.url.deletingLastPathComponent().lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
                .frame(height: 24)
            
            // 详细信息
            VStack(alignment: .leading, spacing: 2) {
                // 开发语言和目标语言
                HStack(spacing: 16) {
                    Label {
                        Text("源语言: \(LocaleUtils.fullDisplayName(for: file.contents.developmentRegion ?? "en"))")
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "character.book.closed")
                    }
                    
                    Label {
                        Text("目标语言: \(LocaleUtils.fullDisplayName(for: file.contents.targetLocale ?? "unknown"))")
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "character.book.closed.fill")
                    }
                }
                .font(.caption)
                
                // 版本和工具信息
                HStack(spacing: 16) {
                    Label {
                        Text("版本: \(file.contents.version)")
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "number")
                    }
                    
                    Label {
                        Text("工具: \(file.contents.toolInfo.toolName)")
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "hammer")
                    }
                }
                .font(.caption)
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .help("文件路径: \(file.url.path)")
    }
    
    // 筛选区域
    private var filterSection: some View {
        HStack(spacing: 12) {
            Picker("显示", selection: $viewModel.currentFilter) {
                ForEach(viewModel.filterOptions, id: \.1) { option in
                    Label {
                        Text(option.0)
                    } icon: {
                        Image(systemName: viewModel.filterIcon(for: option.1))
                    }
                    .tag(option.1)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
        }
    }
    
    // 操作按钮区域
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // 一键翻译按钮
            Button {
                Task { await viewModel.startTranslateAll() }
            } label: {
                Label("一键翻译", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isTranslatingAll)
            .help("自动翻译所有未翻译的文本")
            
            Divider()
                .frame(height: 24)
            
            // 导入 Xcode 按钮
            Button {
                viewModel.importToXcode()
            } label: {
                Label("导入 Xcode", systemImage: "arrow.right.square")
            }
            .help("将翻译导入到 Xcode 项目")
            .disabled(viewModel.currentFile == nil || viewModel.isImporting)
            
            Divider()
                .frame(height: 24)
            
            // 清空翻译按钮
            Button(role: .destructive) {
                viewModel.showingClearConfirmation = true
            } label: {
                Label("清空翻译", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .controlSize(.regular)
            .help("清空所有翻译内容")
        }
    }
    
    // MARK: - Translation Table
    
    private var translationTable: some View {
        VStack(spacing: 0) {
            // 表格内容
            tableContent
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .confirmationDialog(
            "确定要清空所有翻译吗？",
            isPresented: $viewModel.showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空翻译", role: .destructive) {
                viewModel.clearAllTranslations()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将清所有翻译的内容，且无法恢复")
        }
    }
    
    private var tableContent: some View {
        ScrollViewReader { proxy in
            TranslationList(
                items: viewModel.filteredUnits,
                selectedID: $viewModel.selectedID,
                onSelectionChange: handleSelectionChange,
                proxy: proxy
            )
        }
    }
    
    // MARK: - Helper Views
    
    // MARK: - Methods
    
    private func handleSelectionChange(_ translation: TranslationUnit?) {
        if let translation = translation {
            viewModel.selectTranslation(translation)
        }
    }
}

// MARK: - Helper Components

private struct TranslationRow: View {
    let index: Int
    let item: TranslationUnit
    let isTranslating: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var viewModel: XclocViewModel
    
    private var needsTranslation: Bool {
        item.target.isEmpty
    }
    
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text(String(format: "#%d", index))
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
                    .gridColumnAlignment(.leading)
                
                Text(item.source)
                    .lineLimit(3)
                    .help(item.source)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gridColumnAlignment(.leading)
                
                HStack(spacing: 4) {
                    if isTranslating {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(item.target.isEmpty ? "待翻译" : item.target)
                        .foregroundStyle(item.target.isEmpty ? .secondary : .primary)
                        .lineLimit(3)
                        .help(item.target.isEmpty ? "点击开始翻译" : item.target)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .gridColumnAlignment(.leading)
                
                TranslationStatus(needsTranslation: needsTranslation)
                    .frame(width: 100)
                    .gridColumnAlignment(.center)
            }
            
            if let note = item.note {
                GridRow {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .gridCellColumns(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TranslationStatus: View {
    let needsTranslation: Bool
    
    var body: some View {
        HStack {
            Image(systemName: needsTranslation ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(needsTranslation ? .yellow : .green)
                .symbolRenderingMode(.hierarchical)
            Text(needsTranslation ? "未翻译" : "已翻译")
                .foregroundColor(needsTranslation ? .secondary : .primary)
        }
    }
}

private struct TranslationList: View {
    let items: [TranslationUnit]
    @Binding var selectedID: TranslationUnit.ID?
    let onSelectionChange: (TranslationUnit?) -> Void
    let proxy: ScrollViewProxy
    
    var body: some View {
        List(items.indices, id: \.self, selection: $selectedID) { index in
            let item = items[index]
            TranslationRow(
                index: index + 1,
                item: item,
                isTranslating: false
            )
            .tag(item.id)
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        }
        .listStyle(.automatic)
        .onChange(of: selectedID) { id in
            if let id = id,
               let selectedTranslation = items.first(where: { $0.id == id }) {
                onSelectionChange(selectedTranslation)
            }
        }
    }
}

#Preview {
    TranslationContentView()
        .environmentObject(XclocViewModel())
} 
