import SwiftUI

struct ModelGroup: Identifiable {
    let providerID: String
    let providerName: String
    let models: [(providerID: String, modelID: String, name: String)]
    var id: String { providerID }
}

func groupedModels(_ models: [(providerID: String, modelID: String, name: String)], providers: [ProviderInfo]) -> [ModelGroup] {
    let providerNames = Dictionary(uniqueKeysWithValues: providers.compactMap { p in
        p.name.map { (p.id, $0) }
    })

    let grouped = Dictionary(grouping: models) { $0.providerID }
    return grouped
        .map { (pid, models) in
            ModelGroup(
                providerID: pid,
                providerName: providerNames[pid] ?? pid,
                models: models.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            )
        }
        .sorted { $0.providerName.localizedCaseInsensitiveCompare($1.providerName) == .orderedAscending }
}

struct InlineModelPicker: View {
    let models: [(providerID: String, modelID: String, name: String)]
    let providers: [ProviderInfo]
    let defaults: [String: String]
    @Binding var selection: ModelRefBody?

    private var displayText: String {
        guard let sel = selection else {
            if let first = defaults.sorted(by: { $0.key < $1.key }).first {
                return first.value
            }
            return "Default"
        }
        return sel.modelID ?? "Default"
    }

    var body: some View {
        Menu {
            ForEach(groupedModels(models, providers: providers)) { group in
                Menu {
                    ForEach(group.models, id: \.modelID) { model in
                        Button {
                            selection = ModelRefBody(providerID: model.providerID, modelID: model.modelID)
                        } label: {
                            HStack {
                                if selection?.modelID == model.modelID && selection?.providerID == model.providerID {
                                    Image(systemName: "checkmark")
                                }
                                Text(model.name)
                                Spacer()
                                                if let m = providers.first(where: { $0.id == model.providerID })?.models?[model.modelID], model.providerID == "opencode", m.isFree {
                                    Text("Free")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                } label: {
                    Label(group.providerName, systemImage: "server.rack")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.caption2)
                Text(displayText)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .rect(cornerRadius: 6))
            .overlay { Theme.borderOverlay(radius: 6) }
        }
    }
}

struct InlineAgentPicker: View {
    let agents: [AgentInfo]
    @Binding var selection: String?

    var body: some View {
        Menu {
            ForEach(agents) { agent in
                Button {
                    selection = agent.name
                } label: {
                    HStack {
                        if selection == agent.name { Image(systemName: "checkmark") }
                        Text(agent.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.caption2)
                Text(selection ?? "Default")
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .rect(cornerRadius: 6))
            .overlay { Theme.borderOverlay(radius: 6) }
        }
    }
}

struct ModelPicker: View {
    let models: [(providerID: String, modelID: String, name: String)]
    let providers: [ProviderInfo]
    let defaults: [String: String]
    @Binding var selection: ModelRefBody?
    @State private var searchText = ""
    @State private var isExpanded = false

    private var filteredGroups: [ModelGroup] {
        let groups = groupedModels(models, providers: providers)
        if searchText.isEmpty { return groups }
        return groups.compactMap { group in
            let filtered = group.models.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.modelID.localizedCaseInsensitiveContains(searchText) ||
                group.providerName.localizedCaseInsensitiveContains(searchText)
            }
            if filtered.isEmpty { return nil }
            return ModelGroup(providerID: group.providerID, providerName: group.providerName, models: filtered)
        }
    }

    private var defaultDisplayText: String {
        if let sel = selection { return sel.modelID ?? "Default" }
        if let first = defaults.first { return first.value }
        return "Default"
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(defaultDisplayText)
                        .font(.body)
                        .foregroundStyle(selection == nil ? Theme.textBase : Theme.textStrong)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.textWeak)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                .overlay { Theme.borderOverlay(radius: 8) }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(Theme.textBase)
                        TextField("Search models...", text: $searchText)
                            .font(.body)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .rect(cornerRadius: 6))
                    .overlay { Theme.borderOverlay(radius: 6) }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(filteredGroups) { group in
                                Section {
                                    ForEach(group.models, id: \.modelID) { model in
                                        Button {
                                            selection = ModelRefBody(providerID: model.providerID, modelID: model.modelID)
                                            withAnimation { isExpanded = false }
                                            searchText = ""
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(model.name)
                                                        .font(.subheadline)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                                if selection?.modelID == model.modelID && selection?.providerID == model.providerID {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption)
                                                        .foregroundStyle(Theme.interactiveBlue)
                                                }
                                if let m = providers.first(where: { $0.id == model.providerID })?.models?[model.modelID], model.providerID == "opencode", m.isFree {
                                                    Text("Free")
                                                        .font(.caption2)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 2)
                                                        .background(Theme.success.opacity(0.15))
                                                        .foregroundStyle(Theme.success)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } header: {
                                    Text(group.providerName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.textBase)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(.bar)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }
            }
        }
    }
}

struct AgentPicker: View {
    let agents: [AgentInfo]
    @Binding var selection: String?
    @State private var isExpanded = false

    private var filteredAgents: [AgentInfo] {
        agents
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(selection ?? "Default")
                        .font(.body)
                        .foregroundStyle(selection == nil ? Theme.textBase : Theme.textStrong)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.textWeak)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                .overlay { Theme.borderOverlay(radius: 8) }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredAgents) { agent in
                            Button {
                                selection = agent.name
                                withAnimation { isExpanded = false }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(agent.name)
                                            .font(.body)
                                        if let desc = agent.description {
                                            Text(desc)
                                                .font(.caption)
                                                .foregroundStyle(Theme.textBase)
                                                .lineLimit(1)
                                        }
                                    }
                                    if selection == agent.name {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Theme.interactiveBlue)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
    }
}
