import SwiftUI

/// 翻译表格视图
/// 用于显示和管理翻译条目列表
struct TranslationTableView: View {
    // MARK: - Properties
    
    let translations: [TranslationUnit]
    @State private var selectedID: TranslationUnit.ID?
    @EnvironmentObject private var viewModel: XclocViewModel
    @State private var showingClearConfirmation = false
    
    private var filterOptions: [(String, XclocViewModel.TranslationFilter)] {
        let stats = viewModel.translationStats
        return [
            ("全部(\(stats?.total ?? 0))", .all),
            ("已翻译(\(stats?.translated ?? 0))", .translated),
            ("未翻译(\(stats?.untranslated ?? 0))", .untranslated)
        ]
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 表头工具栏
            HStack {
                TableHeader()
                
                Spacer()
                
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("清空翻译", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("清空所有翻译内容")
                
                // 筛选按钮组
                Picker("显示", selection: $viewModel.currentFilter) {
                    ForEach(filterOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Material.bar)
            
            Divider()
            
            // 表格内容
            ScrollViewReader { proxy in
                List(translations.indices, id: \.self, selection: $selectedID) { index in
                    let item = translations[index]
                    TranslationRow(
                        index: index + 1,
                        item: item,
                        isTranslating: item.id == viewModel.currentTranslatingUnit?.id
                    )
                    .tag(item.id)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
                .listStyle(.plain) // 使用plain样式提升性能
                .onChange(of: selectedID) { id in
                    if let id = id {
                        if let selectedTranslation = translations.first(where: { $0.id == id }) {
                            viewModel.selectTranslation(selectedTranslation)
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
            }
        }
        .confirmationDialog(
            "确定要清空所有翻译吗？",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空翻译", role: .destructive) {
                viewModel.clearAllTranslations()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将清空所有已翻译的内容，且无法恢复")
        }
    }
}

// MARK: - 表头视图
private struct TableHeader: View {
    private let columns = [
        ("序号", CGFloat(40)),
        ("源文本", nil),
        ("翻译", nil),
        ("状态", CGFloat(100))
    ]
    
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                // 序号列
                Text(columns[0].0)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: columns[0].1)
                    .gridColumnAlignment(.leading)
                
                // 源文本列
                Text(columns[1].0)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gridColumnAlignment(.leading)
                
                // 翻译列
                Text(columns[2].0)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gridColumnAlignment(.leading)
                
                // 状态列
                Text(columns[3].0)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: columns[3].1)
                    .gridColumnAlignment(.center)
            }
        }
    }
}

// MARK: - 翻译行视图
private struct TranslationRow: View {
    // MARK: - Properties
    
    let index: Int
    let item: TranslationUnit
    let isTranslating: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var viewModel: XclocViewModel
    
    private var needsTranslation: Bool {
        item.target.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                // 序号列
                Text(String(format: "#%d", index))
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
                    .gridColumnAlignment(.leading)
                
                // 源文本列
                Text(item.source)
                    .lineLimit(3)
                    .help(item.source)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gridColumnAlignment(.leading)
                
                // 翻译列
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
                
                // 状态列
                TranslationStatus(needsTranslation: needsTranslation)
                    .frame(width: 100)
                    .gridColumnAlignment(.center)
            }
            .background(alignment: .leading) {
                if needsTranslation {
                    Rectangle()
                        .fill(Color.yellow.opacity(colorScheme == .dark ? 0.2 : 0.1))
                }
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

// MARK: - 翻译状态视图
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

// MARK: - Previews

#Preview("翻译表格") {
    TranslationTableView(translations: [
        TranslationUnit(id: "1", source: "Hello", target: "你好", note: "这是一个示例注释"),
        TranslationUnit(id: "2", source: "This is a very long text that needs to be translated into Chinese. It might contain multiple lines and complex content.", target: "", note: nil),
        TranslationUnit(id: "3", source: "Another example", target: "", note: "需要翻译")
    ])
    .frame(height: 300)
    .environmentObject(XclocViewModel())
} 
