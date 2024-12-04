import SwiftUI

/// 视图样式常量
enum ViewStyle {
    /// 间距
    enum Spacing {
        /// 小间距 (4)
        static let small: CGFloat = 4
        /// 默认间距 (8)
        static let normal: CGFloat = 8
        /// 大间距 (16)
        static let large: CGFloat = 16
    }
    
    /// 圆角
    enum CornerRadius {
        /// 默认圆角 (6)
        static let normal: CGFloat = 6
    }
    
    /// 边框
    enum Border {
        /// 默认边框 (1)
        static let normal: CGFloat = 1
    }
} 