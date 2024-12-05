import SwiftUI
import Defaults

extension Defaults.Keys {
    static let aiConfig = Key<AIConfig>("aiConfig", default: AIProviderType.openAI.defaultConfig)
}

class AISettings: ObservableObject {
    static let shared = AISettings()
    
    @Published var config: AIConfig {
        didSet {
            // 保存到 UserDefaults
            Defaults[.aiConfig] = config
        }
    }
    
    private init() {
        // 从 UserDefaults 加载配置
        self.config = Defaults[.aiConfig]
    }
    
    /// 重置为服务商默认配置
    func resetToDefault() {
        config = config.provider.defaultConfig
    }
    
    /// 切换服务商
    func switchProvider(_ provider: AIProviderType) {
        var newConfig = provider.defaultConfig
        newConfig.apiKey = config.apiKey  // 保留原有的 API Key
        config = newConfig
    }
}
