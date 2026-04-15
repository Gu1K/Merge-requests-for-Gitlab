import SwiftUI
import Combine
import UserNotifications

struct Author: Decodable, Hashable {
    let id: Int
    let name: String
    let avatarUrl: String?
    enum CodingKeys: String, CodingKey { case id, name, avatarUrl = "avatar_url" }
}

struct Reference: Decodable, Hashable { let full: String }
struct GitLabUser: Decodable { let id: Int }

struct MRApprovals: Decodable {
    let approved: Bool
    let approved_by: [ApprovalUser]?
    struct ApprovalUser: Decodable { let user: Author }
}

enum ApprovalStatus: Hashable { case none, approved, requestChanges }

struct MergeRequest: Identifiable, Decodable, Hashable {
    let id: Int
    let iid: Int
    let project_id: Int
    let title: String
    let webUrl: String
    let references: Reference
    let draft: Bool
    let labels: [String]
    let author: Author
    let createdAt: Date
    let userNotesCount: Int
    var approvalStatus: ApprovalStatus = .none

    func hasNewComments() -> Bool {
        let lastReadCount = UserDefaults.standard.integer(forKey: "lastReadCount_\(id)")
        return userNotesCount > lastReadCount
    }
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: MergeRequest, rhs: MergeRequest) -> Bool {
        lhs.id == rhs.id && lhs.userNotesCount == rhs.userNotesCount && lhs.approvalStatus == rhs.approvalStatus
    }
    
    enum CodingKeys: String, CodingKey {
        case id, iid, project_id, title, references, draft, labels, author
        case webUrl = "web_url"
        case createdAt = "created_at"
        case userNotesCount = "user_notes_count"
    }
}

@MainActor
class GitLabViewModel: ObservableObject {
    @Published var createdMRs: [MergeRequest] = []
    @Published var assignedMRs: [MergeRequest] = []
    @Published var isLoading = false
    @Published var refreshID = UUID()
    
    private var cancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        d.dateDecodingStrategy = .formatted(f)
        return d
    }()
    
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        setupTimer()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.setupTimer() } }
            .store(in: &cancellables)
    }
    
    func setupTimer() {
        timerCancellable?.cancel()
        let interval = UserDefaults.standard.double(forKey: "refreshInterval")
        let finalInterval = interval > 0 ? interval : 30.0
        timerCancellable = Timer.publish(every: finalInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                let token = UserDefaults.standard.string(forKey: "gitlabToken") ?? ""
                Task { await self?.fetchAll(token: token) }
            }
    }

    func markAllAsRead() {
        let allMRs = createdMRs + assignedMRs
        for mr in allMRs {
            UserDefaults.standard.set(mr.userNotesCount, forKey: "lastReadCount_\(mr.id)")
        }
        refreshID = UUID()
    }

    private func sendNotification(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func fetchAll(token: String) async {
        guard !token.isEmpty else { return }
        if createdMRs.isEmpty && assignedMRs.isEmpty { isLoading = true }
        
        do {
            let currentUser = try await fetchCurrentUser(token: token)
            async let auth = fetchMRs(token: token, endpoint: "state=opened&scope=all&author_id=\(currentUser.id)")
            async let ass = fetchMRs(token: token, endpoint: "state=opened&scope=all&assignee_id=\(currentUser.id)")
            async let rev = fetchMRs(token: token, endpoint: "state=opened&scope=all&reviewer_id=\(currentUser.id)")
            
            var fetchedMine = Array(Set(try await auth + (try await ass)))
            var fetchedToReview = try await rev
            
            fetchedMine = await fetchStatusForList(mrs: fetchedMine, token: token, userId: currentUser.id, isReviewTab: false)
            fetchedToReview = await fetchStatusForList(mrs: fetchedToReview, token: token, userId: currentUser.id, isReviewTab: true)
            
            self.createdMRs = fetchedMine.sorted(by: { $0.createdAt > $1.createdAt })
            self.assignedMRs = fetchedToReview.sorted(by: { $0.createdAt > $1.createdAt })
            self.refreshID = UUID()
        } catch {
            print("Erreur : \(error)")
        }
        isLoading = false
    }
    
    private func fetchStatusForList(mrs: [MergeRequest], token: String, userId: Int, isReviewTab: Bool) async -> [MergeRequest] {
        var enriched = mrs
        for i in 0..<enriched.count {
            let mr = enriched[i]
            
            if let approvals = try? await fetchApprovals(token: token, projectId: mr.project_id, mrIid: mr.iid) {
                let userHasApproved = approvals.approved_by?.contains(where: { $0.user.id == userId }) ?? false
                
                if isReviewTab {
                    if userHasApproved {
                        let discussions = try? await fetchDiscussions(token: token, projectId: mr.project_id, mrIid: mr.iid)
                        let hasRequestedChanges = discussions?.contains {
                            $0.notes.contains {
                                ($0.resolvable == true && $0.resolved == false)
                            }
                        } ?? false
                        if hasRequestedChanges {
                            enriched[i].approvalStatus = .requestChanges
                        } else {
                            enriched[i].approvalStatus = .approved
                        }
                    } else {
                        let discussions = try? await fetchDiscussions(token: token, projectId: mr.project_id, mrIid: mr.iid)
                        let hasUnresolved = discussions?.contains { $0.notes.contains { $0.resolvable == true && $0.resolved == false } } ?? false
                        enriched[i].approvalStatus = (hasUnresolved || !userHasApproved) ? .requestChanges : .none
                    }
                } else {
                    if approvals.approved {
                        let discussions = try? await fetchDiscussions(token: token, projectId: mr.project_id, mrIid: mr.iid)
                        let hasOthersUnresolved = discussions?.contains { $0.notes.contains { ($0.resolvable == true && $0.resolved == false) && $0.author.id != userId } } ?? false
                        if hasOthersUnresolved {
                            enriched[i].approvalStatus = .requestChanges
                        } else {
                            enriched[i].approvalStatus = .approved
                        }
                    } else {
                        enriched[i].approvalStatus = .none
                    }
                }
            }
        }
        return enriched
    }

    private func fetchApprovals(token: String, projectId: Int, mrIid: Int) async throws -> MRApprovals {
        let url = URL(string: "https://gitlab.com/api/v4/projects/\(projectId)/merge_requests/\(mrIid)/approvals")!
        var r = URLRequest(url: url); r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (d, _) = try await URLSession.shared.data(for: r); return try decoder.decode(MRApprovals.self, from: d)
    }

    struct Discussion: Decodable { let notes: [Note] }
    struct Note: Decodable {
        let author: AuthorID
        let resolvable: Bool?
        let resolved: Bool?
    }
    struct AuthorID: Decodable { let id: Int }

    private func fetchDiscussions(token: String, projectId: Int, mrIid: Int) async throws -> [Discussion] {
        let url = URL(string: "https://gitlab.com/api/v4/projects/\(projectId)/merge_requests/\(mrIid)/discussions")!
        var r = URLRequest(url: url); r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (d, _) = try await URLSession.shared.data(for: r); return try decoder.decode([Discussion].self, from: d)
    }

    private func fetchCurrentUser(token: String) async throws -> GitLabUser {
        let url = URL(string: "https://gitlab.com/api/v4/user")!
        var r = URLRequest(url: url); r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (d, _) = try await URLSession.shared.data(for: r); return try decoder.decode(GitLabUser.self, from: d)
    }
    
    private func fetchMRs(token: String, endpoint: String) async throws -> [MergeRequest] {
        let urlString = "https://gitlab.com/api/v4/merge_requests?\(endpoint)&per_page=100"
        guard let url = URL(string: urlString) else { return [] }
        var r = URLRequest(url: url); r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (d, _) = try await URLSession.shared.data(for: r); return try decoder.decode([MergeRequest].self, from: d)
    }
}
