import SwiftUI

struct SessionRow: View {
    let session: Session
    let status: SessionStatus?
    let hasPermission: Bool
    let hasQuestion: Bool

    init(session: Session, status: SessionStatus? = nil, hasPermission: Bool = false, hasQuestion: Bool = false) {
        self.session = session
        self.status = status
        self.hasPermission = hasPermission
        self.hasQuestion = hasQuestion
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(session.displayTitle)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    if let status {
                        statusBadge(status)
                    }

                    if hasPermission || hasQuestion {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 8, height: 8)
                            Text("Input needed")
                                .font(.caption2)
                                .foregroundStyle(Color.yellow)
                        }
                    }

                    if session.share != nil {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundStyle(Theme.interactiveBlue)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text((session.time.updatedDate ?? session.time.createdDate).relativeString)

                    if let summary = session.summary {
                        Text("+\(summary.additions)/-\(summary.deletions)")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(Theme.textBase)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textBase)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textWeak)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func statusBadge(_ status: SessionStatus) -> some View {
        switch status.status {
        case "busy":
            HStack(spacing: 3) {
                ProgressView()
                    .controlSize(.mini)
                Text("Running")
                    .font(.caption2)
                    .foregroundStyle(Theme.interactiveBlue)
            }
        case "retry":
            HStack(spacing: 3) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundStyle(Theme.brandYuzu)
                Text("Retry")
                    .font(.caption2)
                    .foregroundStyle(Theme.brandYuzu)
            }
        case "error", "failed":
            HStack(spacing: 3) {
                Circle()
                    .fill(Theme.errorCritical)
                    .frame(width: 8, height: 8)
                Text("Error")
                    .font(.caption2)
                    .foregroundStyle(Theme.errorCritical)
            }
        default:
            EmptyView()
        }
    }
}
