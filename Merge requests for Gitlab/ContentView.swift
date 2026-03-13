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
                        Text("Allez dans les réglages (⌘,)").font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isLoading && viewModel.createdMRs.isEmpty && viewModel.assignedMRs.isEmpty {
                    ProgressView("Chargement...").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let mrs = selectedTab == 0 ? viewModel.createdMRs : viewModel.assignedMRs
                    
                    if mrs.isEmpty {
                        VStack {
                            Image(systemName: "checkmark.circle").font(.largeTitle).padding(.bottom, 5)
                            Text("Tout est à jour !").fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(mrs) { mr in
                            MRRow(mr: mr)
                        }
                        .listStyle(.inset)
                    }
                }
            }
            .frame(minHeight: 300, maxHeight: 600)

            Divider()
            
            footer
        }
        .onAppear {
            if !apiToken.isEmpty {
                Task { await viewModel.fetchAll(token: apiToken) }
            }
        }
    }
    
    var footer: some View {
        HStack(spacing: 15) {
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            
            Button {
                Task { await viewModel.fetchAll(token: apiToken) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    if viewModel.isLoading { Text("...").font(.caption) }
                }
            }
            .buttonStyle(.plain)

            Spacer()
            
            Button("Quitter") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct MRRow: View {
    let mr: MergeRequest
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if mr.draft {
                    Text("DRAFT")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(3)
                }
                Text(mr.title)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .font(.system(size: 13))
            }
            Text(mr.references.full)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: mr.webUrl) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage("gitlabToken") private var apiToken: String = ""
    var body: some View {
        Form {
            Section(header: Text("Configuration GitLab").fontWeight(.bold)) {
                SecureField("Personal Access Token :", text: $apiToken)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(30)
        .frame(width: 450)
    }
}
