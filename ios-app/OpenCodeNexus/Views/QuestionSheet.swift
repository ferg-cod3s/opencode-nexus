import SwiftUI

struct QuestionSheet: View {
    let questions: [Question]
    let onAnswer: (Question, [[String]]) -> Void
    let onReject: (Question) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var responses: [String: String] = [:]
    @State private var selections: [String: Set<String>] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if questions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.success)
                        Text("All questions answered")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textBase)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(questions) { question in
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(question.questions) { item in
                        questionContent(request: question, item: item)
                    }

                    Button {
                        let answers = answers(for: question)
                        guard answers.contains(where: { !$0.isEmpty }) else { return }
                        onAnswer(question, answers)
                        clear(question)
                    } label: {
                        Label("Submit", systemImage: "arrow.up.circle.fill")
                    }
                    .disabled(!canSubmit(question))

                    Button(role: .destructive) {
                        onReject(question)
                        clear(question)
                    } label: {
                        Label("Reject", systemImage: "xmark.circle")
                    }
                }
                .padding(.vertical, 4)
            }
                }
            }
            .navigationTitle("Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: questions.isEmpty) {
                if questions.isEmpty { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func questionContent(request: Question, item: QuestionInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(Theme.interactiveBlue)
                Text(item.header)
                    .font(.body.weight(.medium))
            }

            Text(item.question)
                .font(.caption)
                .foregroundStyle(Theme.textBase)

            if !item.options.isEmpty {
                ForEach(item.options) { option in
                    Button {
                        toggle(option.label, for: key(request, item), multiple: item.multiple)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: isSelected(option.label, for: key(request, item)) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(Theme.interactiveBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                if !option.description.isEmpty {
                                    Text(option.description)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textBase)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if item.custom {
                TextField("Custom answer...", text: Binding(
                    get: { responses[key(request, item)] ?? "" },
                    set: { responses[key(request, item)] = $0 }
                ))
                .font(.body)
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func key(_ request: Question, _ item: QuestionInfo) -> String {
        "\(request.id):\(item.id)"
    }

    private func isSelected(_ label: String, for key: String) -> Bool {
        selections[key]?.contains(label) == true
    }

    private func toggle(_ label: String, for key: String, multiple: Bool) {
        var values = selections[key] ?? []
        if values.contains(label) {
            values.remove(label)
        } else if multiple {
            values.insert(label)
        } else {
            values = [label]
        }
        selections[key] = values
    }

    private func answers(for question: Question) -> [[String]] {
        question.questions.map { item in
            let itemKey = key(question, item)
            var values = Array(selections[itemKey] ?? []).sorted()
            let custom = (responses[itemKey] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !custom.isEmpty {
                values.append(custom)
            }
            return values
        }
    }

    private func canSubmit(_ question: Question) -> Bool {
        answers(for: question).contains { !$0.isEmpty }
    }

    private func clear(_ question: Question) {
        for item in question.questions {
            let itemKey = key(question, item)
            responses.removeValue(forKey: itemKey)
            selections.removeValue(forKey: itemKey)
        }
    }
}
