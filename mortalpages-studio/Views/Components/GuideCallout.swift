import SwiftUI

public struct GuideCallout: View {
    public let title: String
    public let whatItDoes: String
    public let howItWorks: String?
    public var proTip: String? = nil
    public var icon: String = "info.circle.fill"
    public var tintColor: Color = .accentColor
    
    @State private var isExpanded: Bool = true
    
    public init(
        title: String,
        whatItDoes: String,
        howItWorks: String? = nil,
        proTip: String? = nil,
        icon: String = "info.circle.fill",
        tintColor: Color = .accentColor,
        isExpanded: Bool = true
    ) {
        self.title = title
        self.whatItDoes = whatItDoes
        self.howItWorks = howItWorks
        self.proTip = proTip
        self.icon = icon
        self.tintColor = tintColor
        self._isExpanded = State(initialValue: isExpanded)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(tintColor)
                    .font(.system(size: 13, weight: .bold))
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(tintColor)
                
                Spacer()
                
                if howItWorks != nil || proTip != nil {
                    Button(action: { withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() } }) {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Hide Details" : "Show Details")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // "What it does" section
            HStack(alignment: .top, spacing: 8) {
                Text("WHAT IT DOES")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(tintColor.opacity(0.85))
                    .frame(width: 88, alignment: .leading)
                    .padding(.top, 1)
                
                Text(whatItDoes)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // "How it works" section
            if isExpanded, let how = howItWorks {
                Divider().opacity(0.4)
                HStack(alignment: .top, spacing: 8) {
                    Text("HOW IT WORKS")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(tintColor.opacity(0.85))
                        .frame(width: 88, alignment: .leading)
                        .padding(.top, 1)
                    
                    Text(how)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Pro Tip section
            if isExpanded, let tip = proTip {
                HStack(alignment: .top, spacing: 8) {
                    Text("PRO TIP")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.orange)
                        .frame(width: 88, alignment: .leading)
                        .padding(.top, 1)
                    
                    Text(tip)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tintColor.opacity(0.22), lineWidth: 1)
        )
    }
}
