import Foundation

struct AISettings: Codable {
    var provider: AIProvider = .deepseek
    var apiKey: String = ""
    var baseURL: String = "https://api.deepseek.com"
    var model: String = "deepseek-chat"
    var temperature: Double = 0.7
    var systemPrompt: String = """
        你是一个专业的本地化翻译专家。请将以下文本从英语翻译成简体中文，保持专业性和准确性。
        注意：
        1. 保持格式标记和占位符不变
        2. 确保术语的一致性
        3. 符合中文的语言习惯
        4. 保持技术术语的专业性
        """
    
    enum AIProvider: String, Codable, CaseIterable {
        case deepseek = "DeepSeek"
        case openAI = "OpenAI"
        case azure = "Azure OpenAI"
        case anthropic = "Anthropic"
    }
    
    mutating func updateDefaultsForProvider() {
        switch provider {
        case .deepseek:
            baseURL = "https://api.deepseek.com"
            model = "deepseek-chat"
        case .openAI:
            baseURL = "https://api.openai.com"
            model = "gpt-3.5-turbo"
        case .azure:
            baseURL = "https://your-resource-name.openai.azure.com"
            model = "gpt-35-turbo"
        case .anthropic:
            baseURL = "https://api.anthropic.com"
            model = "claude-2"
        }
    }
}

// 用于存储设置
extension AISettings {
    static let defaultsKey = "AISettings"
    
    static var shared: AISettings {
        get {
            if let data = UserDefaults.standard.data(forKey: defaultsKey),
               let settings = try? JSONDecoder().decode(AISettings.self, from: data) {
                return settings
            }
            return AISettings()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            }
        }
    }
}
