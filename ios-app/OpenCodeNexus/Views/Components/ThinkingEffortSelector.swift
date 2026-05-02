import SwiftUI

enum ThinkingEffort: String, CaseIterable, Identifiable, Equatable {
    var id: String { rawValue }
    
    case low
    case medium
    case high
    case veryHigh
    
    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .veryHigh: "Very High"
        }
    }
    
    var icon: String {
        switch self {
        case .low: "lightbulb"
        case .medium: "lightbulb.fill"
        case .high: "lightbulb.fill.badge.plus"
        case .veryHigh: "brain.head.profile"
        }
    }
}

struct ThinkingEffortSelector: View {
    @Binding var selection: ThinkingEffort
    
    var body: some View {
        Menu {
            ForEach(ThinkingEffort.allCases) { effort in
                Button {
                    selection = effort
                } label: {
                    HStack {
                        Image(systemName: effort.icon)
                        Text(effort.displayName)
                        if selection == effort {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selection.icon)
                    .font(.caption2)
                Text(selection.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .rect(cornerRadius: 6))
            .overlay { Theme.borderOverlay(radius: 6) }
        }
    }
}
