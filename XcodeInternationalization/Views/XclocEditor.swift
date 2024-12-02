import SwiftUI

struct XclocEditor: View {
    @StateObject private var viewModel = XclocViewModel()
    @State private var selectedTranslation: TranslationUnit?
    @State private var selectedFileURL: URL?

    var body: some View {
        NavigationSplitView {
            // 左侧文件列表
            VStack {
                Button(action: viewModel.selectFolder) {
                    HStack {
                        Image(systemName: "folder")
                        Text("选择文件夹")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding()

                if viewModel.xclocFiles.isEmpty {
                    ContentUnavailableView(
                        "没有文件",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("选择包含 .xcloc 文件的文件夹")
                    )
                } else {
                    List(viewModel.xclocFiles, id: \.lastPathComponent, selection: $selectedFileURL) { url in
                        Text(url.lastPathComponent)
                            .tag(url)
                    }
                    .onChange(of: selectedFileURL) { newValue in
                        if let url = newValue {
                            viewModel.parseXclocFile(url)
                        }
                    }
                }
            }
            .frame(minWidth: 200, maxWidth: 300)
        } content: {
            // 中间翻译表格
            if let selectedFile = viewModel.selectedFile {
                FileDetailTable(file: selectedFile, selectedTranslation: $selectedTranslation)
            } else {
                ContentUnavailableView(
                    "选择文件",
                    systemImage: "doc.text",
                    description: Text("从左侧选择要编辑的文件")
                )
            }
        } detail: {
            TranslationDetailWrapper(
                translation: $selectedTranslation,
                onSave: { updatedTranslation in
                    viewModel.saveTranslation(updatedTranslation)
                }
            )
        }
    }
}

struct FileDetailTable: View {
    // MARK: - Properties

    let file: XclocFile?
    @Binding var selectedTranslation: TranslationUnit?
    @State private var selectedID: TranslationUnit.ID?

    // MARK: - Body

    var body: some View {
        VStack {
            Table(file?.translationUnits ?? [], selection: $selectedID) {
                TableColumn("源文本") { unit in
                    Text(unit.source)
                        
                }
                .width(min: 150, ideal: 200)

                TableColumn("翻译") { unit in
                    Text(verbatim: unit.target)
                        
                }
                .width(min: 150, ideal: 200)

                TableColumn("备注") { unit in
                    if let note = unit.note {
                        Text(note)
                            
                            .foregroundColor(.secondary)
                    }
                }
                .width(min: 100, ideal: 150)
            }
            .onChange(of: selectedID) { id in
                selectedTranslation = file?.translationUnits.first { $0.id == id }
            }
        }
    }
}

struct TranslationDetailWrapper: View {
    @Binding var translation: TranslationUnit?
    var onSave: ((TranslationUnit) -> Void)?
    
    var body: some View {
        if let translationBinding = Binding($translation) {
            TranslationDetailView(translation: translationBinding, onSave: onSave)
        } else {
            ContentUnavailableView(
                "选择翻译",
                systemImage: "text.bubble",
                description: Text("从中间选择要编辑的翻译")
            )
        }
    }
}

struct TranslationDetailView: View {
    @Binding var translation: TranslationUnit
    var onSave: ((TranslationUnit) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("翻译")
                .font(.headline)
            
            TextEditor(text: $translation.target)
                .font(.body)
                .frame(height: 100)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            Button("保存") {
                print("保存按钮被点击")
                onSave?(translation)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

#Preview {
    XclocEditor()
}
