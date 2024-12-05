import SwiftUI

/// 命令执行进度视图模型
class CommandProgressViewModel: ObservableObject {
    /// 标题
    @Published var title: String
    /// 命令
    @Published var command: String
    /// 进度 (0.0-1.0)
    @Published var progress: Double?
    /// 日志输出
    @Published var logs: String = ""
    /// 是否可以取消
    @Published var canCancel: Bool = true
    /// 是否已完成
    @Published var isFinished: Bool = false
    
    private var isCancelled = false
    
    /// 初始化
    /// - Parameters:
    ///   - title: 标题
    ///   - command: 命令
    init(title: String, command: String) {
        self.title = title
        self.command = command
    }
    
    /// 添加日志
    /// - Parameter message: 日志行
    func appendLog(_ message: String) {
        Task { @MainActor in
            logs += message + "\n"
        }
    }
    
    /// 更新进度
    /// - Parameter progress: 进度值 (0.0-1.0)
    func updateProgress(_ progress: Double?) {
        Task { @MainActor in
            self.progress = progress
        }
    }
    
    /// 完成
    func finish() {
        Task { @MainActor in
            self.isFinished = true
            self.canCancel = false
        }
    }
    
    /// 取消操作
    func cancel() {
        isCancelled = true
        canCancel = false
    }
    
    /// 是否应该取消
    var shouldCancel: Bool {
        isCancelled
    }
} 