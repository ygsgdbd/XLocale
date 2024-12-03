import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AISettings.shared
    @Environment(\.dismiss) private var dismiss
    
    enum SettingsTab: String, CaseIterable {
        case general = "通用"
        case services = "服务商"
        case about = "关于"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .services: return "network"
            case .about: return "info.circle"
            }
        }
    }
    
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        NavigationSplitView {
            // 左侧导航栏
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .navigationTitle("设置")
        } detail: {
            // 右侧内容区
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .services:
                    AIServiceSettingsView()
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.controlBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 700, height: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - 通用设置视图
private struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                Toggle("自动检查更新", isOn: .constant(true))
                Toggle("显示开发者选项", isOn: .constant(false))
            } header: {
                Text("基本设置")
            }
            
            Section {
                Button("导出设置") {}
                Button("导入设置") {}
                Button("重置所有设置") {}
                    .foregroundColor(.red)
            } header: {
                Text("配置管理")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - AI 服务商设置视图
private struct AIServiceSettingsView: View {
    @StateObject private var settings = AISettings.shared
    @State private var isValidating = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧服务商列表
            List(AISettings.AIProvider.allCases, id: \.self, selection: $settings.provider) { provider in
                Text(provider.rawValue)
                    .font(.body)
                    .padding(.vertical, 8)
            }
            .listStyle(.sidebar)
            .frame(width: 150)
            
            // 右侧配置区域
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 基础配置
                    VStack(alignment: .leading, spacing: 16) {
                        Text("基础配置")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledTextField(label: "API Key", text: $settings.apiKey, isSecure: true)
                            LabeledTextField(label: "服务器地址", text: $settings.baseURL)
                            LabeledTextField(label: "模型", text: $settings.model)
                        }
                    }
                    
                    Divider()
                    
                    // 翻译参数
                    VStack(alignment: .leading, spacing: 16) {
                        Text("翻译参数")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledTextField(label: "目标语言", text: $settings.targetLanguage)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("系统提示词")
                                    .foregroundStyle(.secondary)
                                TextEditor(text: $settings.systemPrompt)
                                    .font(.body)
                                    .frame(height: 80)
                                    .padding(4)
                                    .background(Color(.textBackgroundColor))
                                    .cornerRadius(6)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("温度: \(String(format: "%.1f", settings.temperature))")
                                    .foregroundStyle(.secondary)
                                Slider(value: $settings.temperature, in: 0...1)
                                    .frame(width: 200)
                            }
                            
                            HStack {
                                Text("最大 Token")
                                    .foregroundStyle(.secondary)
                                Stepper(String(settings.maxTokens), value: $settings.maxTokens, in: 100...4000, step: 100)
                                    .frame(width: 200)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 操作按钮
                    HStack {
                        Button {
                            validateConnection()
                        } label: {
                            if isValidating {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("验证中...")
                                }
                            } else {
                                Text("验证连接")
                            }
                        }
                        .disabled(isValidating)
                        
                        Spacer()
                        
                        Button("保存设置") {
                            settings.updateDefaultsForProvider()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.controlBackgroundColor))
        }
    }
    
    private func validateConnection() {
        isValidating = true
        
        Task {
            do {
                let translator = try AITranslator(settings: settings)
                if let result = try await translator.translate("Hello", targetLocale: "en") {
                    print("验证成功：\(result)")
                }
            } catch {
                print("验证失败：\(error.localizedDescription)")
            }
            
            isValidating = false
        }
    }
}

// MARK: - 辅助视图
private struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            if isSecure {
                SecureField("", text: $text)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - 关于页面
private struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("XLocale")
                .font(.title)
            Text("版本 1.0.0")
                .foregroundStyle(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Link("项目主页", destination: URL(string: "https://github.com/linhey/XLocale")!)
                Link("问题反馈", destination: URL(string: "https://github.com/linhey/XLocale/issues")!)
                Link("开发者主页", destination: URL(string: "https://github.com/linhey")!)
            }
            
            Spacer()
            
            Text("© 2024 linhey. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
} 
