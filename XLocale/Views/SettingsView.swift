import SwiftUI

struct SettingsView: View {
    @AppStorage(AISettings.defaultsKey) private var settingsData: Data = try! JSONEncoder().encode(AISettings())
    @State private var settings: AISettings = .shared
    @State private var selectedProvider: AISettings.AIProvider = .openAI
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?
    @Environment(\.dismiss) private var dismiss
    
    enum ValidationResult {
        case success
        case failure(String)
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return .green
            case .failure: return .red
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // 左侧服务商列表
            List(AISettings.AIProvider.allCases, id: \.self, selection: $selectedProvider) { provider in
                HStack {
                    Image(systemName: providerIcon(for: provider))
                        .foregroundStyle(providerColor(for: provider))
                    Text(provider.rawValue)
                }
            }
            .navigationTitle("AI 服务")
            .onChange(of: selectedProvider) { _, newProvider in
                settings.provider = newProvider
                settings.updateDefaultsForProvider()
            }
        } detail: {
            // 右侧设置详情
            Form {
                Section {
                    TextField("API Key", text: $settings.apiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        TextField("Base URL", text: $settings.baseURL)
                            .textFieldStyle(.roundedBorder)
                        
                        // 验证按钮
                        Button {
                            Task {
                                await validateSettings()
                            }
                        } label: {
                            if isValidating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("验证")
                            }
                        }
                        .disabled(isValidating || settings.apiKey.isEmpty)
                    }
                    
                    // 验证结果提示
                    if let result = validationResult {
                        HStack {
                            Image(systemName: result.icon)
                            switch result {
                            case .success:
                                Text("验证成功")
                            case .failure(let error):
                                Text(error)
                            }
                        }
                        .foregroundColor(result.color)
                        .font(.caption)
                    }
                }
                
                Section("模型设置") {
                    TextField("模型", text: $settings.model)
                        .textFieldStyle(.roundedBorder)
                    VStack(alignment: .leading) {
                        Text("温度: \(settings.temperature, specifier: "%.1f")")
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.temperature, in: 0...2)
                    }
                }
                
                Section("系统提示词") {
                    TextEditor(text: $settings.systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                }
                
                HStack {
                    Button("取消") {
                        dismiss()
                    }
                    
                    Spacer()
                    
                    Button("保存") {
                        settings.provider = selectedProvider
                        if let data = try? JSONEncoder().encode(settings) {
                            settingsData = data
                        }
                        dismiss()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(isValidating)
                }
                .padding(.top)
            }
            .formStyle(.grouped)
            .padding()
            .navigationTitle(selectedProvider.rawValue)
        }
        .frame(width: 700, height: 500)
    }
    
    // 为不同服务商提供不同图标
    private func providerIcon(for provider: AISettings.AIProvider) -> String {
        switch provider {
        case .deepseek:
            return "sparkles.square.filled.on.square"  // 或其他合适的图标
        case .openAI:
            return "brain"
        case .azure:
            return "cloud"
        case .anthropic:
            return "sparkles"
        }
    }
    
    // 为不同服务商提供不同颜色
    private func providerColor(for provider: AISettings.AIProvider) -> Color {
        switch provider {
        case .deepseek:
            return .purple  // DeepSeek 的品牌色
        case .openAI:
            return .green
        case .azure:
            return .blue
        case .anthropic:
            return .purple
        }
    }
    
    private func validateSettings() async {
        isValidating = true
        validationResult = nil
        
        do {
            let translator = try AITranslator(settings: settings)
            // 使用一个简单的测试文本进行验证
            let testText = "Hello, this is a test message."
            if let _ = try await translator.translate(testText) {
                validationResult = .success
            } else {
                validationResult = .failure("翻译失败")
            }
        } catch AITranslatorError.invalidURL {
            validationResult = .failure("无效的 API URL")
        } catch AITranslatorError.invalidHost {
            validationResult = .failure("无效的服务器地址")
        } catch {
            validationResult = .failure(error.localizedDescription)
        }
        
        isValidating = false
    }
}

#Preview {
    SettingsView()
} 
