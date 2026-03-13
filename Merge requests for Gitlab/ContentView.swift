import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GitLabViewModel()
    @AppStorage("gitlabToken") private var apiToken: String = ""
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("\(L10n.tabMine) (\(viewModel.createdMRs.count))").tag(0)
                Text("\(L10n.tabReview) (\(viewModel.assignedMRs.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                if apiToken.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "key.fill").font(.system(size: 40))
                        Text(L10n.tokenMissing).font(.headline)
                        Text(L10n.settingsInstruction).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isLoading && viewModel.createdMRs.isEmpty && viewModel.assignedMRs.isEmpty {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(L10n.syncGitLab).font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let mrs = selectedTab == 0 ? viewModel.createdMRs : viewModel.assignedMRs
                    if mrs.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "sun.max").font(.system(size: 30))
                            Text(L10n.nothingToReport).font(.headline)
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(mrs) { mr in
                            MRRow(mr: mr)
                        }
                        .id(viewModel.refreshID) // Force le re-render pour les badges
                        .listStyle(.inset)
                    }
                }
            }
            .frame(minHeight: 500)

            Divider()
            footer
        }
        .onAppear { if !apiToken.isEmpty { Task { await viewModel.fetchAll(token: apiToken) } } }
    }
    
    var footer: some View {
        HStack(spacing: 15) {
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help(L10n.helpSettings)
            
            Button { Task { await viewModel.fetchAll(token: apiToken) } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help(L10n.helpRefresh)
            
            Button { withAnimation { viewModel.markAllAsRead() } } label: {
                Image(systemName: "checkmark.circle")
            }
            .buttonStyle(.plain)
            .help(L10n.helpMarkRead)
            
            Spacer()
            if viewModel.isLoading { ProgressView().controlSize(.small) }
            Spacer()
            
            Button(L10n.quit) { NSApplication.shared.terminate(nil) }.controlSize(.small)
        }
        .padding(12).background(Color(NSColor.windowBackgroundColor))
    }
}

struct MRRow: View {
    let mr: MergeRequest
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: mr.author.avatarUrl ?? "")) { image in
                        image.resizable()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(statusColor, lineWidth: mr.approvalStatus != .none ? 3 : 0))

                    if mr.approvalStatus == .approved {
                        Image(systemName: "checkmark.seal.fill")
                            .resizable().frame(width: 14, height: 14)
                            .foregroundColor(.green).background(Color.white.clipShape(Circle()))
                            .offset(x: 4, y: 4)
                    }
                }
                
                if mr.userNotesCount > 0 {
                    let hasNew = mr.hasNewComments()
                    Text("\(mr.userNotesCount)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(hasNew ? Color.red : Color.primary.opacity(0.1))
                        .foregroundColor(hasNew ? .white : .primary.opacity(0.8))
                        .clipShape(Capsule())
                }
            }
            .frame(width: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    if mr.draft {
                        Text("DRAFT").font(.system(size: 9, weight: .bold)).padding(.horizontal, 4).padding(.vertical, 2).background(Color.gray.opacity(0.2)).cornerRadius(4)
                    }
                    Text(mr.title).fontWeight(.semibold).font(.system(size: 14)).lineLimit(2)
                        .foregroundColor(mr.approvalStatus == .approved ? .secondary : .primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mr.references.full).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).lineLimit(1)
                    Text("\(L10n.createdBy) \(mr.author.name) • \(mr.createdAt.relativeTime())").font(.system(size: 11)).foregroundColor(.secondary)
                }

                if !mr.labels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(mr.labels, id: \.self) { label in
                                Text(label).font(.system(size: 10, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 3).background(labelColor(label).opacity(0.15)).foregroundColor(labelColor(label)).cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8).contentShape(Rectangle())
        .onTapGesture { if let url = URL(string: mr.webUrl) { NSWorkspace.shared.open(url) } }
    }
    
    var statusColor: Color {
        switch mr.approvalStatus {
        case .approved: return .green
        case .requestChanges: return .red
        default: return .clear
        }
    }
    
    func labelColor(_ label: String) -> Color {
        let l = label.lowercased()
        if l.contains("feature") || l.contains("🚀") { return .blue }
        if l.contains("bug") || l.contains("🐛") { return .red }
        return .secondary
    }
}

// --- VUE DES RÉGLAGES (DÉPLACÉE EN DEHORS POUR LE SCOPE) ---
struct SettingsView: View {
    @AppStorage("gitlabToken") private var apiToken: String = ""
    @AppStorage("refreshInterval") private var refreshInterval: Double = 30.0
    
    var body: some View {
        Form {
            Section(header: Text(L10n.configTitle).fontWeight(.bold)) {
                SecureField("Token", text: $apiToken).textFieldStyle(.roundedBorder)
            }
            Section(header: Text(L10n.refreshDelay).fontWeight(.bold)) {
                Picker(L10n.seconds, selection: $refreshInterval) {
                    Text("15 \(L10n.seconds)").tag(15.0)
                    Text("30 \(L10n.seconds)").tag(30.0)
                    Text("1 \(L10n.minute)").tag(60.0)
                    Text("5 \(L10n.minute)s").tag(300.0)
                }
            }
        }
        .padding(30).frame(width: 450, height: 200)
    }
}

extension Date {
    func relativeTime() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: L10n.isFrench ? "fr" : "en")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
