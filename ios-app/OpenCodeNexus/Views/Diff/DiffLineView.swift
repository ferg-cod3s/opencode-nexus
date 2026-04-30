import SwiftUI

struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            lineNumbers
            lineContent
        }
        .font(.system(size: 11, design: .monospaced))
    }

    @ViewBuilder
    private var lineNumbers: some View {
        HStack(spacing: 4) {
            Text(line.oldLineNumber.map { "\($0)" } ?? "")
                .frame(width: 36, alignment: .trailing)
            Text(line.newLineNumber.map { "\($0)" } ?? "")
                .frame(width: 36, alignment: .trailing)
        }
        .foregroundStyle(Theme.textWeak)
        .padding(.leading, 4)
    }

    @ViewBuilder
    private var lineContent: some View {
        switch line.type {
        case .addition:
            Text("+\(line.content)")
                .foregroundStyle(Theme.success)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .padding(.trailing, 8)
                .background(Theme.success.opacity(0.15))
        case .deletion:
            Text("-\(line.content)")
                .foregroundStyle(Theme.errorCritical)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .padding(.trailing, 8)
                .background(Theme.errorCritical.opacity(0.15))
        case .header:
            Text(" \(line.content)")
                .foregroundStyle(Theme.interactiveBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .padding(.trailing, 8)
                .background(Theme.interactiveBlue.opacity(0.1))
        case .noNewline:
            Text(" \(line.content)")
                .foregroundStyle(Theme.textWeak)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .padding(.trailing, 8)
        case .context:
            Text(" \(line.content)")
                .foregroundStyle(Theme.textBase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .padding(.trailing, 8)
        }
    }
}
