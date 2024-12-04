import SwiftUI
import UniformTypeIdentifiers
import SwiftUIX

struct FileListView: View {
    @EnvironmentObject private var viewModel: XclocViewModel
    @State private var selectedURL: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 项目区域
            GroupBox {
                VStack(alignment: .leading, spacing: ViewStyle.Spacing.normal) {
                    // 项目信息或选择按钮
                    if let projectURL = viewModel.xcodeProjectURL {
                        projectInfoView(projectURL)
                    } else {
                        selectProjectButton
                    }
                    
                    // 导出按钮
                    exportButton
                }
                .padding(ViewStyle.Spacing.normal)
            }
            .padding(.horizontal, ViewStyle.Spacing.normal)
            
            Divider()
                .padding(.vertical, ViewStyle.Spacing.normal)
            
            // MARK: - 文件列表
            fileListView
        }
        .sheet(isPresented: $viewModel.showingExportProgress) {
            if let progressModel = viewModel.exportProgress {
                CommandProgressView(
                    viewModel: progressModel,
                    isPresented: $viewModel.showingExportProgress
                )
            }
        }
    }
    
    // MARK: - 项目信息视图
    private func projectInfoView(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: ViewStyle.Spacing.small) {
            HStack {
                VStack(alignment: .leading, spacing: ViewStyle.Spacing.small) {
                    Text(url.lastPathComponent)
                        .font(.body)
                        .lineLimit(1)
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    viewModel.xcodeProjectURL = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - 选择项目按钮
    private var selectProjectButton: some View {
        Button {
            selectXcodeProject()
        } label: {
            Label("选择项目", systemImage: "folder.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
    
    // MARK: - 导出按钮
    private var exportButton: some View {
        Button {
            viewModel.startExport()
        } label: {
            Label("导出本地化", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.xcodeProjectURL == nil)
    }
    
    // MARK: - 文件列表视图
    private var fileListView: some View {
        ScrollViewReader { proxy in
            List(selection: $selectedURL) {
                Section("已导出的文件") {
                    ForEach(viewModel.xclocFiles, id: \.url) { file in
                        FileListItem(file: file)
                            .tag(file.url)
                            .id(file.url)
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selectedURL) { url in
                if let url {
                    viewModel.selectFile(url)
                    withAnimation {
                        proxy.scrollTo(url, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - 选择项目方法
    private func selectXcodeProject() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["xcodeproj"]
        panel.message = "请选择 Xcode 项目文件 (.xcodeproj)"
        panel.prompt = "选择项目"
        
        if panel.runModal() == .OK {
            if let url = panel.url,
               url.pathExtension.lowercased() == "xcodeproj" {
                viewModel.xcodeProjectURL = url
            }
        }
    }
}

// MARK: - 文件列表项
private struct FileListItem: View {
    let file: XclocFile
    
    var body: some View {
        Label {
            Grid(alignment: .leading, horizontalSpacing: ViewStyle.Spacing.normal, verticalSpacing: ViewStyle.Spacing.small) {
                // 第一行：文件名
                GridRow {
                    Text(file.url.lastPathComponent)
                        .lineLimit(1)
                        .font(.body)
                        .gridCellColumns(2)
                }
                
                // 第二行：语言和进度
                GridRow {
                    // 进度条
                    ProgressView(value: file.translationProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(file.translationProgress >= 1.0 ? .green : .blue)
                    
                    // 进度文本
                    Text("\(file.translatedCount)/\(file.totalCount)")
                        .monospacedDigit()
                        .gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(file.translationProgress >= 1.0 ? .green : .blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, ViewStyle.Spacing.small)
    }
}

// MARK: - 环境值扩展
private struct SidebarWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 200
}

extension EnvironmentValues {
    var sidebarWidth: CGFloat {
        get { self[SidebarWidthKey.self] }
        set { self[SidebarWidthKey.self] = newValue }
    }
}

// MARK: - 视图修饰器
extension View {
    func sidebarWidth(_ width: CGFloat) -> some View {
        environment(\.sidebarWidth, width)
    }
}

// MARK: - 预览
#Preview {
    FileListView()
        .environmentObject(XclocViewModel())
        .frame(width: 300)
} 
