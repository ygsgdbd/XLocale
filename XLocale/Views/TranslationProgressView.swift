import SwiftUI

struct TranslationProgressView: View {
    let title: String
    @Binding var progress: Double
    @Binding var logs: [TranslationLog]
    let onCancel: () -> Void
    
    @State private var scrollProxy: ScrollViewProxy?
    @State private var lastLogId: UUID?
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text(title)
                .font(.headline)
            
            // 进度条
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("翻译进度")
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .monospacedDigit()
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
            
            // 日志列表
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(logs.reversed()) { log in
                            HStack(spacing: 8) {
                                Image(systemName: log.type.iconName)
                                    .foregroundColor(log.type.color)
                                
                                Text(log.message)
                                    .foregroundColor(log.type.color)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(log.id)
                        }
                    }
                    .padding(.vertical, 8)
                    .onChange(of: logs) { newLogs in
                        if let lastLog = newLogs.last,
                           lastLog.id != lastLogId {
                            lastLogId = lastLog.id
                            withAnimation {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(height: 200)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // 取消按钮
            Button("取消翻译", role: .cancel, action: onCancel)
        }
        .padding()
        .frame(width: 400)
    }
}

// 翻译日志模型
struct TranslationLog: Identifiable, Equatable {
    let id = UUID()
    let type: LogType
    let message: String
    let timestamp = Date()
    
    static func == (lhs: TranslationLog, rhs: TranslationLog) -> Bool {
        lhs.id == rhs.id
    }
    
    enum LogType: Equatable {
        case info
        case success
        case error
        case warning
        
        var iconName: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .error: return "xmark.circle"
            case .warning: return "exclamationmark.triangle"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .secondary
            case .success: return .green
            case .error: return .red
            case .warning: return .yellow
            }
        }
    }
}

#Preview {
    TranslationProgressView(
        title: "正在翻译...",
        progress: .constant(0.45),
        logs: .constant([
            TranslationLog(type: .info, message: "开始翻译..."),
            TranslationLog(type: .success, message: "成功翻译: Hello World"),
            TranslationLog(type: .warning, message: "跳过空文本"),
            TranslationLog(type: .error, message: "翻译失败: 网络错误")
        ]),
        onCancel: {}
    )
} 