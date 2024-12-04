import Foundation

/// 命令执行进度视图模型
class CommandProgressViewModel: ObservableObject {
    /// 标题
    @Published private(set) var title: String
    /// 命令
    @Published private(set) var command: String
    /// 进度 (0.0-1.0)
    @Published private(set) var progress: Double?
    /// 日志输出
    @Published private(set) var logs: String = ""
    /// 是否可以取消
    @Published private(set) var canCancel: Bool = true
    /// 是否已完成
    @Published private(set) var isFinished: Bool = false
    
    /// 取消回调
    private var onCancel: (() -> Void)?
    
    /// 初始化
    /// - Parameters:
    ///   - title: 标题
    ///   - command: 命令
    init(title: String, command: String) {
        self.title = title
        self.command = command
    }
    
    /// 添加日志
    /// - Parameter line: 日志行
    func appendLog(_ line: String) {
        logs += line + "\n"
    }
    
    /// 更新进度
    /// - Parameter progress: 进度值 (0.0-1.0)
    func updateProgress(_ progress: Double?) {
        self.progress = progress
    }
    
    /// 设置取消回调
    /// - Parameter handler: 取消回调
    func setCancelHandler(_ handler: @escaping () -> Void) {
        onCancel = handler
    }
    
    /// 取消操作
    func cancel() {
        onCancel?()
        canCancel = false
    }
    
    /// 完成
    func finish() {
        isFinished = true
        canCancel = false
    }
} 