import SwiftUI
import Combine

// --- MODÈLES DE DONNÉES ---

struct MergeRequest: Identifiable, Decodable, Hashable {
    let id: Int
    let iid: Int
    let title: String
    let webUrl: String
    let references: Reference
    let draft: Bool
    
    // Pour éviter les doublons lors de la fusion des listes
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: MergeRequest, rhs: MergeRequest) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id, iid, title, references, draft
        case webUrl = "web_url"
    }
}

struct Reference: Decodable, Hashable {
    let full: String
}

struct GitLabUser: Decodable {
    let id: Int
}

// --- VIEWMODEL ---

@MainActor
class GitLabViewModel: ObservableObject {
    @Published var createdMRs: [MergeRequest] = []
    @Published var assignedMRs: [MergeRequest] = []
    @Published var isLoading = false
    
    func fetchAll(token: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        
        do {
            let currentUser = try await fetchCurrentUser(token: token)
            let userId = currentUser.id
            
            // 1. On récupère les MRs créées par toi
            async let authored = fetchMRs(token: token, endpoint: "state=opened&scope=all&author_id=\(userId)")
            
            // 2. On récupère les MRs assignées à toi (ton cas sur la capture)
            async let assigned = fetchMRs(token: token, endpoint: "state=opened&scope=all&assignee_id=\(userId)")
            
            // 3. On récupère les MRs où tu es Reviewer (onglet 2)
            async let reviews = fetchMRs(token: token, endpoint: "state=opened&scope=all&reviewer_id=\(userId)")
            
            // Fusion des MRs créées et assignées pour l'onglet 1 (sans doublons)
            let combinedCreated = Array(Set(try await authored + (try await assigned)))
                .sorted(by: { $0.id > $1.id })
            
            self.createdMRs = combinedCreated
            self.assignedMRs = try await reviews
            
        } catch {
            print("Erreur GitLab : \(error)")
        }
        
        isLoading = false
    }
    
    private func fetchCurrentUser(token: String) async throws -> GitLabUser {
        let url = URL(string: "https://gitlab.com/api/v4/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(GitLabUser.self, from: data)
    }
    
    private func fetchMRs(token: String, endpoint: String) async throws -> [MergeRequest] {
        let urlString = "https://gitlab.com/api/v4/merge_requests?\(endpoint)&per_page=100"
        guard let url = URL(string: urlString) else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([MergeRequest].self, from: data)
    }
}
