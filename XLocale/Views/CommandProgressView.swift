import SwiftUI

/// 命令执行进度视图
struct CommandProgressView: View {
    @ObservedObject var viewModel: CommandProgressViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text(viewModel.title)
                .font(.headline)
            
            // 执行状态
            if !viewModel.isFinished {
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
                            .id("logs")
                    }
                    .onChange(of: viewModel.logs) { _ in
                        withAnimation {
                            proxy.scrollTo("logs", anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding()
        .frame(width: 500, height: 300)
    }
}
