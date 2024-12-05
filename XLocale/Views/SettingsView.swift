import SwiftUI
import SwiftUIX

struct SettingsView: View {
    @ObservedObject var settings = AISettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isTestingConnection = false
    @State private var testResult: (success: Bool, message: String)?
    
    var body: some View {
        Form {
            // MARK: - AI 服务商设置
            Section("AI 服务商") {
                Picker("服务商", selection: $settings.config.provider) {
                    ForEach(AIProviderType.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .onChange(of: settings.config.provider) { newProvider in
                    settings.switchProvider(newProvider)
                }
                
                TextField("服务器地址", text: $settings.config.baseURL)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("API Key", text: $settings.config.apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            // MARK: - 模型设置
            Section("模型设置") {
                TextField("模型", text: $settings.config.model)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Text("温度")
                    Slider(value: $settings.config.temperature, in: 0...1)
                    Text(String(format: "%.1f", settings.config.temperature))
                        .monospacedDigit()
                }
                
                Stepper("最大 Token: \(settings.config.maxTokens)", 
                        value: $settings.config.maxTokens,
                        in: 100...4000,
                        step: 100)
            }
            
            // MARK: - 提示词设置
            Section("提示词设置") {
                TextEditor(text: $settings.config.systemPrompt)
                    .frame(height: 100)
            }
            
            // MARK: - 操作按钮
            Section("操作") {
                VStack(spacing: 12) {
                    HStack {
                        Button("重置为默认") {
                            settings.resetToDefault()
                        }
                        
                        Spacer()
                        
                        Button("测试连接") {
                            testConnection()
                        }
                        .disabled(isTestingConnection)
                        
                        Button("应用设置") {
                            // 保存设置
                            dismiss()
                        }
                        .keyboardShortcut(.return)
                    }
                    
                    // 显示测试结果
                    if isTestingConnection {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在测试连接...")
                                .foregroundColor(.secondary)
                        }
                    } else if let result = testResult {
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                            Text(result.message)
                                .foregroundColor(result.success ? .secondary : .red)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 500)
        .overlay(alignment: .topTrailing) {
            // 关闭按钮
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape)
            .padding(8)
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        Task {
            do {
                let translator = try AITranslator(settings: settings)
                // 尝试翻译一个简单的文本来测试连接
                let result = try await translator.translate("Hello", targetLocale: "zh-Hans")
                
                await MainActor.run {
                    isTestingConnection = false
                    if result != nil {
                        testResult = (true, "连接成功")
                    } else {
                        testResult = (false, "连接失败：未收到响应")
                    }
                }
            } catch {
                await MainActor.run {
                    isTestingConnection = false
                    testResult = (false, "连接失败：\(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    SettingsView()
} 
