import Foundation
import Defaults

/// AI 服务提供商类型
enum AIProviderType: String, Codable, CaseIterable {
    case openAI = "OpenAI"
    case deepseek = "DeepSeek"
    case moonshot = "Moonshot"
    case groq = "Groq"
    
    var defaultConfig: AIConfig {
        switch self {
        case .openAI:
            return AIConfig(
                provider: self,
                baseURL: "https://api.openai.com/v1",
                model: "gpt-3.5-turbo"
            )
        case .deepseek:
            return AIConfig(
                provider: self,
                baseURL: "https://api.deepseek.com/v1",
                model: "deepseek-chat"
            )
        case .moonshot:
            return AIConfig(
                provider: self,
                baseURL: "https://api.moonshot.cn/v1",
                model: "moonshot-v1-8k"
            )
        case .groq:
            return AIConfig(
                provider: self,
                baseURL: "https://api.groq.com/v1",
                model: "mixtral-8x7b-32768"
            )
        }
    }
}

/// AI 配置模型
struct AIConfig: Codable, Defaults.Serializable {
    /// 服务提供商
    var provider: AIProviderType
    /// 服务器地址
    var baseURL: String
    /// API 密钥
    var apiKey: String = ""
    /// 使用的模型
    var model: String
    /// 温度参数 (0.0-1.0)
    var temperature: Double = 0.7
    /// 最大 token 数
    var maxTokens: Int = 2000
    /// 系统提示词
    var systemPrompt: String = "你是一个专业的翻译"
} 