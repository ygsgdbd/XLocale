import Foundation
import OpenAI
import SwifterSwift

enum AITranslatorError: LocalizedError {
    case invalidURL
    case invalidHost
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API URL"
        case .invalidHost:
            return "无效的服务器地址"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}

class AITranslator {
    private let openAI: OpenAI
    private let settings: AISettings
    
    init(settings: AISettings = .shared) throws {
        self.settings = settings
        
        // 验证 URL 格式
        guard let url = URL(string: settings.baseURL) else {
            throw AITranslatorError.invalidURL
        }
        
        // 验证 host
        guard let host = url.host else {
            throw AITranslatorError.invalidHost
        }
        
        print("正在初始化 OpenAI 客户端:")
        print("- Host: \(host)")
        print("- Port: \(url.port ?? 443)")
        print("- API Key: \(settings.apiKey.prefix(8))...")
        
        // 创建配置
        let config = OpenAI.Configuration(
            token: settings.apiKey,
            host: host,
            port: url.port ?? 443,
            timeoutInterval: 60.0  // 增加超时时间
        )
        
        self.openAI = OpenAI(configuration: config)
    }
    
    func translate(_ text: String) async throws -> String? {
        do {
            print("准备翻译文本:")
            print("- 模型: \(settings.model)")
            print("- 温度: \(settings.temperature)")
            print("- 文本长度: \(text.count)")
            
            let messages = [
                ChatQuery.ChatCompletionMessageParam(role: .system, content: settings.systemPrompt),
                ChatQuery.ChatCompletionMessageParam(role: .user, content: text)
            ]
            
            let query = ChatQuery(
                messages: messages.compactMap { $0 },
                model: .init(settings.model),
                temperature: settings.temperature
            )
            
            let result = try await openAI.chats(query: query)
            return result.choices.first?.message.content?.string
            
        } catch {
            print("翻译失败: \(error)")
            throw AITranslatorError.networkError(error)
        }
    }
    
    // 批量翻译
    func translateBatch(_ units: [TranslationUnit]) async throws -> [TranslationUnit] {
        var updatedUnits = units
        for i in updatedUnits.indices {
            if let translatedText = try await translate(units[i].source) {
                updatedUnits[i].target = translatedText
            }
        }
        return updatedUnits
    }
} 
