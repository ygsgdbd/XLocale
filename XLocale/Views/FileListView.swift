import SwiftUI
import SwiftUIX

struct FileListView: View {
    @EnvironmentObject private var viewModel: XclocViewModel
    @State private var selectedURL: URL?
    @State private var showingAlert = false
    
    var body: some View {
        List(viewModel.xclocFiles, id: \.self, selection: $selectedURL) { url in
            FileItemView(url: url)
        }
        .onChange(of: selectedURL) { url in
            if viewModel.isTranslatingAll {
                showingAlert = true
            } else {
                viewModel.selectFile(url)
            }
        }
        .alert("正在翻译中", isPresented: $showingAlert) {
            Button("取消翻译并切换", role: .destructive) {
                viewModel.selectFile(selectedURL)
            }
            Button("继续翻译", role: .cancel) {
                // 恢复之前的选择
                selectedURL = viewModel.selectedFileURL
            }
        } message: {
            Text("切换文件将中断当前的翻译任务")
        }
    }
}

// MARK: - 文件项视图
private struct FileItemView: View {
    let url: URL
    @State private var stats: (total: Int, translated: Int, remaining: Int)?
    @EnvironmentObject private var viewModel: XclocViewModel
    
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
        // 监听当前文件的变化
        .onChange(of: viewModel.selectedFile) { file in
            if file?.url == url {
                // 如果是当前文件，重新加载统计信息
                Task {
                    await loadStats()
                }
            }
        }
    }
    
    @MainActor
    private func loadStats() async {
        do {
            let stats = try await Task.detached(priority: .background) {
                let file = try XclocParser.parse(xclocURL: url)
                let total = file.translationUnits.count
                let translated = file.translationUnits.filter { !$0.target.isEmpty }.count
                return (total, translated, total - translated)
            }.value
            
            self.stats = stats
        } catch {
            print("加载文件条数失败：\(error.localizedDescription)")
        }
    }
}

#Preview {
    FileListView()
        .environmentObject(XclocViewModel())
} 
