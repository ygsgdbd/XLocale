import SwiftUI
import SwiftUIX

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: Text?
    
    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title2)
                .foregroundStyle(.primary)
            
            if let description = description {
                description
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    EmptyStateView(
        "没有文件",
        systemImage: "doc.text.magnifyingglass",
        description: Text("从左侧选择要编辑的文件")
    )
} 