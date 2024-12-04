import SwiftUI
import SwiftUIX

struct FileListView: View {
    @EnvironmentObject private var viewModel: XclocViewModel
    @State private var selectedURL: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            // 添加工具栏
            HStack {
                Button {
                    viewModel.startExport()
                } label: {
                    Label("选择项目", systemImage: "folder.badge.plus")
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
                
                Spacer()
                
                // 显示文件数量
                if !viewModel.xclocFiles.isEmpty {
                    Text("\(viewModel.xclocFiles.count) 个文件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.bar)
            
            Divider()
            
            if viewModel.isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.exportProgress) {
                        Text("导出进度")
                    }
                    .progressViewStyle(.linear)
                    
                    ScrollView {
                        Text(viewModel.exportLog)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 100)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                }
                .padding()
            }
            
            // 文件列表
            if viewModel.xclocFiles.isEmpty {
                EmptyStateView(
                    "没有本地化文件",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("选择 Xcode 项目以导出本地化文件")
                )
            } else {
                List(viewModel.xclocFiles, id: \.self, selection: $selectedURL) { url in
                    FileItemView(url: url)
                        .tag(url)
                }
            }
        }
        .onChange(of: selectedURL) { url in
            viewModel.selectFile(url)
        }
        // 当 xclocFiles 更新时，自动选择第一个文件
        .onChange(of: viewModel.xclocFiles) { files in
            if let firstFile = files.first {
                selectedURL = firstFile
                viewModel.selectFile(firstFile)
            }
        }
    }
}

private struct FileItemView: View {
    let url: URL
    @State private var name: String = ""
    
    var body: some View {
        Label(name, systemImage: "doc.text")
            .onAppear {
                name = url.deletingPathExtension().lastPathComponent
            }
    }
}

#Preview {
    FileListView()
        .environmentObject(XclocViewModel())
} 
