import SwiftUI
import Combine

// --- MODÈLES ---

struct MergeRequest: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String
    let webUrl: String
    let references: Reference
    let draft: Bool
    let labels: [String]
    let author: Author
    let createdAt: Date
    let userNotesCount: Int
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: MergeRequest, rhs: MergeRequest) -> Bool { lhs.id == rhs.id }
    
    enum CodingKeys: String, CodingKey {
        case id, title, references, draft, labels, author
        case webUrl = "web_url"
        case createdAt = "created_at"
        case userNotesCount = "user_notes_count"
    }
}

struct Author: Decodable, Hashable {
    let name: String
    let avatarUrl: String?
    enum CodingKeys: String, CodingKey { case name, avatarUrl = "avatar_url" }
}

struct Reference: Decodable, Hashable { let full: String }
struct GitLabUser: Decodable { let id: Int }

// --- VIEWMODEL ---

@MainActor
class GitLabViewModel: ObservableObject {
    @Published var createdMRs: [MergeRequest] = []
    @Published var assignedMRs: [MergeRequest] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
    
    init() {
        setupTimer()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.setupTimer() }
            }
            .store(in: &cancellables)
    }
    
    func setupTimer() {
        timerCancellable?.cancel()
        let interval = UserDefaults.standard.double(forKey: "refreshInterval")
        let finalInterval = interval > 0 ? interval : 30.0
        
        timerCancellable = Timer.publish(every: finalInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let token = UserDefaults.standard.string(forKey: "gitlabToken") ?? ""
                Task { await self.fetchAll(token: token) }
            }
    }
    
    func fetchAll(token: String) async {
        guard !token.isEmpty else { return }
        if createdMRs.isEmpty && assignedMRs.isEmpty { isLoading = true }
        
        do {
            let currentUser = try await fetchCurrentUser(token: token)
            let userId = currentUser.id
            
            async let authored = fetchMRs(token: token, endpoint: "state=opened&scope=all&author_id=\(userId)")
            async let assigned = fetchMRs(token: token, endpoint: "state=opened&scope=all&assignee_id=\(userId)")
            async let reviews = fetchMRs(token: token, endpoint: "state=opened&scope=all&reviewer_id=\(userId)")
            
            let authoredList = try await authored
            let assignedList = try await assigned
            let reviewsList = try await reviews
            
            let combined = Array(Set(authoredList + assignedList)).sorted(by: { $0.createdAt > $1.createdAt })
            
            self.createdMRs = combined
            self.assignedMRs = reviewsList.sorted(by: { $0.createdAt > $1.createdAt })
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
        return try decoder.decode(GitLabUser.self, from: data)
    }
    
    private func fetchMRs(token: String, endpoint: String) async throws -> [MergeRequest] {
        let urlString = "https://gitlab.com/api/v4/merge_requests?\(endpoint)&per_page=100"
        guard let url = URL(string: urlString) else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([MergeRequest].self, from: data)
    }
}
