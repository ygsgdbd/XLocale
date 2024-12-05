import SwiftUI

/// 命令执行进度视图模型
class CommandProgressViewModel: ObservableObject, Identifiable {
    /// 标题
    let title: String
    
    /// 日志输出
    @Published var logs: String = ""
    /// 是否已完成
    @Published var isFinished = false
    
    let id = UUID()
    
    /// 初始化
    /// - Parameters:
    ///   - title: 标题
    init(title: String) {
        self.title = title
    }
    
    /// 添加日志
    /// - Parameter message: 日志行
    func appendLog(_ message: String) {
        logs += message + "\n"
    }
} 