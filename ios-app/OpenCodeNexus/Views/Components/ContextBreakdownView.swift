import SwiftUI

struct ContextBreakdownView: View {
    let tokens: TokenInfo?
    let cost: Double?
    
    private var totalTokens: Int {
        guard let tokens else { return 0 }
        return (tokens.input ?? 0) + (tokens.output ?? 0) + (tokens.reasoning ?? 0) + (tokens.cache?.read ?? 0) + (tokens.cache?.write ?? 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Context Usage")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(formatTokenCount(totalTokens)) tokens")
                    .font(.caption)
                    .foregroundStyle(Theme.textWeak)
            }
            
            if let tokens {
                VStack(alignment: .leading, spacing: 4) {
                    if let input = tokens.input, input > 0 {
                        TokenRow(label: "Input", count: input, color: Theme.interactiveBlue)
                    }
                    if let output = tokens.output, output > 0 {
                        TokenRow(label: "Output", count: output, color: Theme.success)
                    }
                    if let reasoning = tokens.reasoning, reasoning > 0 {
                        TokenRow(label: "Reasoning", count: reasoning, color: Theme.brandYuzu)
                    }
                    if let cacheRead = tokens.cache?.read, cacheRead > 0 {
                        TokenRow(label: "Cache Read", count: cacheRead, color: Theme.textWeak)
                    }
                    if let cacheWrite = tokens.cache?.write, cacheWrite > 0 {
                        TokenRow(label: "Cache Write", count: cacheWrite, color: Theme.textWeak)
                    }
                }
            }
            
            if let cost = cost, cost > 0 {
                HStack {
                    Text("Cost")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "$%.4f", cost))
                        .font(.caption)
                        .foregroundStyle(Theme.textWeak)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
        .overlay { Theme.borderOverlay(radius: 8) }
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

struct TokenRow: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
            Spacer()
            Text(formatTokenCount(count))
                .font(.caption2)
                .foregroundStyle(Theme.textWeak)
        }
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}
