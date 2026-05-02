import SwiftUI

struct TodoListView: View {
    let todos: [Todo]
    let isLoading: Bool

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading todos...")
                } else if todos.isEmpty {
                    ContentUnavailableView("No tasks", systemImage: "list.bullet", description: Text("The agent hasn't created any tasks yet"))
                } else {
                    List {
                        ForEach(todos) { todo in
                            HStack(spacing: 12) {
                                statusIcon(for: todo.status)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(todo.content)
                                        .font(.body)
                                    if todo.priority != "normal" {
                                        Text(todo.priority.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func statusIcon(for status: String) -> some View {
        switch status {
        case "completed":
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case "in_progress":
            ProgressView()
                .scaleEffect(0.8)
        case "pending":
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        default:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }
}
