import SwiftUI

struct FileDiffView: View {
    let diff: FileDiff
    let diffLines: [DiffLine]
    @State private var isExpanded = false

    private var statusIcon: (name: String, color: Color) {
        if diff.additions > 0 && diff.deletions == 0 {
            return ("plus.circle.fill", Theme.success)
        } else if diff.deletions > 0 && diff.additions == 0 {
            return ("minus.circle.fill", Theme.errorCritical)
        } else if diff.before != diff.after {
            return ("arrow.right.circle.fill", Color.yellow)
        }
        return ("pencil.circle.fill", Theme.interactiveBlue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: statusIcon.name)
                        .foregroundStyle(statusIcon.color)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(diff.file)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.textStrong)
                            .lineLimit(1)

                        if diff.before != diff.after {
                            HStack(spacing: 4) {
                                Text(diff.before)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                Text(diff.after)
                            }
                            .font(.caption2)
                            .foregroundStyle(Theme.textWeak)
                            .lineLimit(1)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text("+\(diff.additions)")
                            .foregroundStyle(Theme.success)
                        Text("-\(diff.deletions)")
                            .foregroundStyle(Theme.errorCritical)
                    }
                    .font(.caption)
                    .monospacedDigit()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Theme.textWeak)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded && !diffLines.isEmpty {
                Divider().overlay(Theme.borderWeak)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(diffLines) { line in
                            DiffLineView(line: line)
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
        .overlay { Theme.borderOverlay(radius: 8) }
    }
}
