import SwiftUI

/// 命令执行进度视图
struct CommandProgressView: View {
    @ObservedObject var viewModel: CommandProgressViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text(viewModel.title)
                .font(.headline)
            
            // 命令
            GroupBox {
                Text(viewModel.command)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            
            // 进度
            if let progress = viewModel.progress {
                ProgressView(value: progress) {
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.caption)
                        .monospacedDigit()
                }
                .progressViewStyle(.linear)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            
            // 日志输出
            GroupBox {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(viewModel.logs)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .id("logs")  // 用于自动滚动
                    }
                    .onChange(of: viewModel.logs) { _ in
                        // 自动滚动到底部
                        withAnimation {
                            proxy.scrollTo("logs", anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)  // 让日志区域占用剩余空间
            
            // 按钮
            HStack {
                if viewModel.canCancel {
                    Button(role: .cancel) {
                        viewModel.cancel()
                    } label: {
                        Text("取消")
                    }
                    .keyboardShortcut(.escape)
                }
                
                if viewModel.isFinished {
                    Button {
                        isPresented = false
                    } label: {
                        Text("完成")
                    }
                    .keyboardShortcut(.return)
                }
            }
        }
        .padding()
        .frame(width: 600, height: 400)  // 增加窗口大小
    }
}
