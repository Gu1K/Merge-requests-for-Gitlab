import Foundation

enum L10n {
    static var language: String {
        Locale.preferredLanguages.first ?? "en"
    }
    
    static var isFrench: Bool { language.hasPrefix("fr") }
    
    static var tabMine: String { isFrench ? "Mes MRs" : "My MRs" }
    static var tabReview: String { isFrench ? "À réviser" : "To Review" }
    static var tokenMissing: String { isFrench ? "Token manquant" : "Missing Token" }
    static var settingsInstruction: String { isFrench ? "Ouvrez les réglages (⌘,) pour configurer l'accès." : "Open settings (⌘,) to configure access." }
    static var syncGitLab: String { isFrench ? "Synchronisation GitLab..." : "Syncing GitLab..." }
    static var nothingToReport: String { isFrench ? "Rien à signaler" : "Nothing to report" }
    static var updateInProgress: String { isFrench ? "Mise à jour..." : "Updating..." }
    static var quit: String { isFrench ? "Quitter" : "Quit" }
    static var createdBy: String { isFrench ? "par" : "by" }
    static var configTitle: String { isFrench ? "Configuration" : "Settings" }
    static var tokenScopeNote: String { isFrench ? "Nécessite le scope 'read_api'." : "Requires 'read_api' scope." }
    static var refreshDelay: String { isFrench ? "Délai de rafraîchissement" : "Refresh Delay" }
    static var seconds: String { isFrench ? "secondes" : "seconds" }
    static var minute: String { isFrench ? "minute" : "minute" }
    static var helpSettings: String { isFrench ? "Paramètres" : "Settings" }
    static var helpRefresh: String { isFrench ? "Rafraîchir maintenant" : "Refresh now" }
    static var helpMarkRead: String { isFrench ? "Marquer tout comme lu" : "Mark all as read" }
}
