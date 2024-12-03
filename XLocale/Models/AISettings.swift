import SwiftUI

class AISettings: ObservableObject {
    static let shared = AISettings()
    static let defaultsKey = "AISettings"
    
    enum AIProvider: String, Codable, CaseIterable {
        case openAI = "OpenAI"
        case deepseek = "DeepSeek"
    }
    
    @AppStorage("provider") var provider: AIProvider = .openAI
    @AppStorage("baseURL") var baseURL: String = "https://api.openai.com/v1"
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("model") var model: String = "gpt-3.5-turbo"
    @AppStorage("temperature") var temperature: Double = 0.7
    @AppStorage("systemPrompt") var systemPrompt: String = "你是一个专业的翻译"
    @AppStorage("targetLanguage") var targetLanguage: String = "简体中文"
    @AppStorage("maxTokens") var maxTokens: Int = 2000
    
    func updateDefaultsForProvider() {
        switch provider {
        case .openAI:
            baseURL = "https://api.openai.com/v1"
            model = "gpt-3.5-turbo"
        case .deepseek:
            baseURL = "https://api.deepseek.com"
            model = "deepseek-chat"
        }
    }
    
    private init() {}
}
