import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GitLabViewModel()
    @AppStorage("gitlabToken") private var apiToken: String = ""
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Mes MRs (\(viewModel.createdMRs.count))").tag(0)
                Text("À réviser (\(viewModel.assignedMRs.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                if apiToken.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "key.fill").font(.largeTitle)
                        Text("Token manquant").fontWeight(.bold)
                        Text("Ouvrez les réglages pour configurer l'accès.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isLoading && viewModel.createdMRs.isEmpty && viewModel.assignedMRs.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let mrs = selectedTab == 0 ? viewModel.createdMRs : viewModel.assignedMRs
                    if mrs.isEmpty {
                        VStack {
                            Image(systemName: "tray").font(.largeTitle)
                            Text("Aucune MR en cours").foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(mrs) { mr in
                            MRRow(mr: mr)
                        }
                        .listStyle(.inset)
                    }
                }
            }
            .frame(minHeight: 350)

            Divider()
            footer
        }
        .onAppear { if !apiToken.isEmpty { Task { await viewModel.fetchAll(token: apiToken) } } }
    }
    
    var footer: some View {
        HStack {
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            
            Button {
                Task { await viewModel.fetchAll(token: apiToken) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button("Quitter") { NSApplication.shared.terminate(nil) }
                .controlSize(.small)
        }
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// --- SOUS-VUE POUR CHAQUE LIGNE DE MR ---
struct MRRow: View {
    let mr: MergeRequest
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: mr.author.avatarUrl ?? "")) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    if mr.draft {
                        Text("DRAFT").font(.system(size: 8, weight: .bold)).padding(2).background(Color.gray.opacity(0.2)).cornerRadius(3)
                    }
                    Text(mr.title).fontWeight(.medium).font(.system(size: 13)).lineLimit(2)
                }
                
                Text("\(mr.references.full) • \(mr.createdAt.relativeTime())")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                if !mr.labels.isEmpty {
                    HStack {
                        ForEach(mr.labels, id: \.self) { label in
                            Text(label)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(labelColor(label).opacity(0.15))
                                .foregroundColor(labelColor(label))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { if let url = URL(string: mr.webUrl) { NSWorkspace.shared.open(url) } }
    }
    
    func labelColor(_ label: String) -> Color {
        let l = label.lowercased()
        if l.contains("feature") || l.contains("🚀") { return .blue }
        if l.contains("bug") || l.contains("🐛") { return .red }
        return .secondary
    }
}

// --- VUE DES RÉGLAGES ---
struct SettingsView: View {
    @AppStorage("gitlabToken") private var apiToken: String = ""
    
    var body: some View {
        Form {
            Section {
                SecureField("GitLab Personal Access Token :", text: $apiToken)
                    .textFieldStyle(.roundedBorder)
                Text("Nécessite le scope 'read_api'.")
                    .font(.caption).foregroundColor(.secondary)
            } header: {
                Text("Configuration").fontWeight(.bold)
            }
        }
        .padding(30)
        .frame(width: 400, height: 120)
    }
}

// Extension pour le temps relatif
extension Date {
    func relativeTime() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
