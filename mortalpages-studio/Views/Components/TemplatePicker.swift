import SwiftUI

public struct TemplatePicker: View {
    public let label: String
    @Binding public var selection: String
    @ObservedObject private var registry = TemplateRegistry.shared
    
    public init(_ label: String, selection: Binding<String>) {
        self.label = label
        self._selection = selection
    }
    
    public var body: some View {
        HStack {
            if !label.isEmpty {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Picker("", selection: $selection) {
                let grouped = Dictionary(grouping: registry.templates, by: { $0.category })
                let categories = grouped.keys.sorted()
                
                ForEach(categories, id: \.self) { cat in
                    Section(header: Text(cat)) {
                        ForEach(grouped[cat] ?? []) { item in
                            HStack {
                                Image(systemName: item.icon)
                                Text(item.name)
                            }
                            .tag(item.relativePath)
                        }
                    }
                }
            }
            .labelsHidden()
            .frame(minWidth: 180, maxWidth: 260)
        }
    }
}
