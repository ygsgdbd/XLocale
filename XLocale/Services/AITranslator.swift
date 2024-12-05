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
    private let retryCount = 3
    private let retryDelay: TimeInterval = 2
    
    init(settings: AISettings = .shared) throws {
        self.settings = settings
        
        guard let url = URL(string: settings.config.baseURL) else {
            throw AITranslatorError.invalidURL
        }
        
        guard let host = url.host else {
            throw AITranslatorError.invalidHost
        }
        
        let config = OpenAI.Configuration(
            token: settings.config.apiKey,
            host: host,
            port: url.port ?? 443,
            timeoutInterval: 30
        )
        
        self.openAI = OpenAI(configuration: config)
    }
    
    func translate(_ text: String, targetLocale: String) async throws -> String? {
        var lastError: Error?
        
        // 添加重试逻辑
        for attempt in 0..<retryCount {
            do {
                let messages: [ChatQuery.ChatCompletionMessageParam?] = [
                    .init(role: .system, content: "\(settings.config.systemPrompt)，请将下面的文本翻译成\(targetLocale)语"),
                    .init(role: .user, content: text)
                ]
                
                let query = ChatQuery(
                    messages: messages.compactMap { $0 },
                    model: .init(settings.config.model),
                    maxTokens: settings.config.maxTokens,
                    temperature: settings.config.temperature
                )
                
                // 添加请求间隔
                if attempt > 0 {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
                
                let response = try await openAI.chats(query: query)
                
                return await MainActor.run {
                    response.choices.first?.message.content?.string
                }
            } catch {
                lastError = error
                print("翻译失败，尝试次数：\(attempt + 1)，错误：\(error)")
                
                // 如果不是超时错误，直接抛出
                if let urlError = error as? URLError, 
                   urlError.code != .timedOut {
                    throw error
                }
                
                // 最后一次尝试失败，抛出错误
                if attempt == retryCount - 1 {
                    throw error
                }
            }
        }
        
        throw lastError ?? AITranslatorError.networkError(NSError(domain: "", code: -1))
    }
    
    func translateBatch(_ units: [TranslationUnit], targetLocale: String) async throws -> [TranslationUnit] {
        var updatedUnits = units
        for i in updatedUnits.indices {
            if let translatedText = try await translate(units[i].source, targetLocale: targetLocale) {
                updatedUnits[i].target = translatedText
            }
        }
        return updatedUnits
    }
    
    deinit {
        // 确保资源被释放
        URLSession.shared.invalidateAndCancel()
    }
}
