import Foundation
import FirebaseFirestore
import GoogleSignIn
import UIKit

enum CampusGmailError: LocalizedError {
    case missingOAuthConfiguration
    case missingPresenter
    case invalidCampusEmail
    case googleAccountMismatch(expected: String, actual: String)
    case notConnected
    case badResponse
    case fireStoreUnavailable

    var errorDescription: String? {
        switch self {
        case .missingOAuthConfiguration:
            return "Google Sign-In is not configured yet. Add the iOS OAuth client ID and reversed client ID in Xcode."
        case .missingPresenter:
            return "Could not open Google Sign-In from the current screen."
        case .invalidCampusEmail:
            return "Use your @\(Constants.campusEmailDomain) account to enable KUET mail."
        case .googleAccountMismatch(let expected, let actual):
            return "Choose \(expected) in Google Sign-In. You selected \(actual)."
        case .notConnected:
            return "KUET mail is not connected on this device."
        case .badResponse:
            return "Gmail returned an unexpected response."
        case .fireStoreUnavailable:
            return "CampusConnect could not save the mail setting right now. Check App Check/network setup and try again."
        }
    }
}

struct CampusGmailSyncResult {
    let storedCount: Int
}

@MainActor
final class CampusGmailService {
    static let shared = CampusGmailService()

    private let db = Firestore.firestore()
    private let gmailMetadataScope = "https://www.googleapis.com/auth/gmail.metadata"

    private init() {}

    func connectAndSync(uid: String, campusEmail: String) async throws -> CampusGmailSyncResult {
        let normalizedEmail = normalizedCampusEmail(campusEmail)
        guard ValidationService.isValidCampusEmail(normalizedEmail) else {
            throw CampusGmailError.invalidCampusEmail
        }

        try configureGoogleSignIn()
        let presenter = try presentingViewController()
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presenter,
            hint: normalizedEmail,
            additionalScopes: [gmailMetadataScope]
        )
        let user = result.user
        try validateGoogleAccount(user, expectedEmail: normalizedEmail)
        return try await sync(user: user, uid: uid, campusEmail: normalizedEmail)
    }

    func syncIfPossible(uid: String, campusEmail: String) async throws -> CampusGmailSyncResult {
        let normalizedEmail = normalizedCampusEmail(campusEmail)
        guard ValidationService.isValidCampusEmail(normalizedEmail) else {
            throw CampusGmailError.invalidCampusEmail
        }

        try configureGoogleSignIn()
        let user: GIDGoogleUser
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            user = currentUser
        } else if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
        } else {
            throw CampusGmailError.notConnected
        }

        try validateGoogleAccount(user, expectedEmail: normalizedEmail)
        if user.grantedScopes?.contains(gmailMetadataScope) != true {
            throw CampusGmailError.notConnected
        }
        return try await sync(user: user, uid: uid, campusEmail: normalizedEmail)
    }

    func disconnect(uid: String, campusEmail: String) async throws {
        let normalizedEmail = normalizedCampusEmail(campusEmail)
        GIDSignIn.sharedInstance.signOut()

        let now = Timestamp(date: Date())
        let batch = db.batch()
        let settingsRef = db.collection("gmail_connection_settings").document(uid)
        let userRef = db.collection("users").document(uid)
        batch.setData([
            "uid": uid,
            "email": normalizedEmail,
            "connected": false,
            "state": "Not Connected",
            "updatedAt": now
        ], forDocument: settingsRef, merge: true)
        batch.setData([
            "gmailConnected": false,
            "updatedAt": now
        ], forDocument: userRef, merge: true)
        do {
            try await batch.commit()
        } catch {
            throw mapFirestoreError(error)
        }
    }

    func restoreSignedInUser(campusEmail: String) async -> Bool {
        let normalizedEmail = normalizedCampusEmail(campusEmail)
        do {
            try configureGoogleSignIn()
            let user: GIDGoogleUser
            if let currentUser = GIDSignIn.sharedInstance.currentUser {
                user = currentUser
            } else if GIDSignIn.sharedInstance.hasPreviousSignIn() {
                user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            } else {
                return false
            }
            try validateGoogleAccount(user, expectedEmail: normalizedEmail)
            return user.grantedScopes?.contains(gmailMetadataScope) == true
        } catch {
            return false
        }
    }

    func signOutLocalGoogleSession() {
        GIDSignIn.sharedInstance.signOut()
    }

    private func sync(user: GIDGoogleUser, uid: String, campusEmail: String) async throws -> CampusGmailSyncResult {
        let refreshedUser = try await user.refreshTokensIfNeeded()
        let accessToken = refreshedUser.accessToken.tokenString
        let messageRefs = try await listInboxMessages(accessToken: accessToken)
        let messages = try await fetchMetadata(for: messageRefs, accessToken: accessToken)
        let storedCount = try await persist(messages: messages, uid: uid, email: campusEmail)
        return CampusGmailSyncResult(storedCount: storedCount)
    }

    private func configureGoogleSignIn() throws {
        let clientID = googleClientID()
        let reversedClientID = googleReversedClientID()
        guard !clientID.isEmpty,
              !reversedClientID.isEmpty,
              !clientID.contains("REPLACE_WITH"),
              !reversedClientID.contains("REPLACE_WITH") else {
            throw CampusGmailError.missingOAuthConfiguration
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    private func googleClientID() -> String {
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return googleServiceInfoValue(for: "CLIENT_ID")
    }

    private func googleReversedClientID() -> String {
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        for urlType in urlTypes {
            let schemes = urlType["CFBundleURLSchemes"] as? [String] ?? []
            if let scheme = schemes.first(where: { $0.contains("googleusercontent") }) {
                return scheme.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return googleServiceInfoValue(for: "REVERSED_CLIENT_ID")
    }

    private func googleServiceInfoValue(for key: String) -> String {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let values = NSDictionary(contentsOfFile: path),
              let value = values[key] as? String else {
            return ""
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validateGoogleAccount(_ user: GIDGoogleUser, expectedEmail: String) throws {
        let actualEmail = normalizedCampusEmail(user.profile?.email ?? "")
        guard ValidationService.isValidCampusEmail(actualEmail) else {
            throw CampusGmailError.invalidCampusEmail
        }
        guard actualEmail == expectedEmail else {
            throw CampusGmailError.googleAccountMismatch(expected: expectedEmail, actual: actualEmail)
        }
    }

    private func normalizedCampusEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func presentingViewController() throws -> UIViewController {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: \.isKeyWindow)
        guard let root = window?.rootViewController else {
            throw CampusGmailError.missingPresenter
        }
        return topViewController(from: root)
    }

    private func topViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = root as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = root as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return root
    }

    private func listInboxMessages(accessToken: String) async throws -> [GmailMessageReference] {
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")
        components?.queryItems = [
            URLQueryItem(name: "maxResults", value: "40"),
            URLQueryItem(name: "labelIds", value: "INBOX"),
            URLQueryItem(name: "includeSpamTrash", value: "false")
        ]
        guard let url = components?.url else { throw CampusGmailError.badResponse }

        let response: GmailListResponse = try await gmailRequest(url: url, accessToken: accessToken)
        return response.messages ?? []
    }

    private func fetchMetadata(
        for refs: [GmailMessageReference],
        accessToken: String
    ) async throws -> [CampusGmailMessageMetadata] {
        var results: [CampusGmailMessageMetadata] = []
        for ref in refs {
            guard let id = ref.id else { continue }
            var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)")
            components?.queryItems = [
                URLQueryItem(name: "format", value: "metadata"),
                URLQueryItem(name: "metadataHeaders", value: "Subject"),
                URLQueryItem(name: "metadataHeaders", value: "From"),
                URLQueryItem(name: "metadataHeaders", value: "Date")
            ]
            guard let url = components?.url else { continue }
            let response: GmailMessageResponse = try await gmailRequest(url: url, accessToken: accessToken)
            let headers = response.payload?.headers ?? []
            let title = headerValue("Subject", in: headers).ifBlank("(no subject)")
            let sender = headerValue("From", in: headers).ifBlank("Unknown sender")
            let date = dateFrom(internalDate: response.internalDate, fallbackHeader: headerValue("Date", in: headers))
            results.append(
                CampusGmailMessageMetadata(
                    id: response.id ?? id,
                    threadId: response.threadId,
                    title: title,
                    sender: sender,
                    receivedAt: date,
                    originalUrl: "https://mail.google.com/mail/u/0/#inbox/\(response.id ?? id)"
                )
            )
        }
        return results
    }

    private func gmailRequest<T: Decodable>(url: URL, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            if let body = String(data: data, encoding: .utf8), !body.isEmpty {
                throw NSError(
                    domain: "CampusGmailService",
                    code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: body]
                )
            }
            throw CampusGmailError.badResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func persist(messages: [CampusGmailMessageMetadata], uid: String, email: String) async throws -> Int {
        let now = Timestamp(date: Date())
        let batch = db.batch()
        let settingsRef = db.collection("gmail_connection_settings").document(uid)
        let userRef = db.collection("users").document(uid)

        batch.setData([
            "uid": uid,
            "email": email,
            "connected": true,
            "state": "Connected",
            "lastSyncAt": now,
            "lastSyncStatus": "SUCCESS",
            "lastSyncError": FieldValue.delete(),
            "lastSyncCount": messages.count,
            "updatedAt": now
        ], forDocument: settingsRef, merge: true)
        batch.setData([
            "gmailConnected": true,
            "updatedAt": now
        ], forDocument: userRef, merge: true)

        for message in messages {
            let itemRef = db.collection("synced_gmail_notice_items")
                .document(uid)
                .collection("items")
                .document(message.id)
            var payload: [String: Any] = [
                "title": message.title,
                "email": email,
                "sourceType": "GMAIL_METADATA",
                "sourceName": message.sender,
                "sender": message.sender,
                "originalUrl": message.originalUrl,
                "gmailMessageId": message.id,
                "publishedAt": Timestamp(date: message.receivedAt),
                "syncedAt": now
            ]
            if let threadId = message.threadId {
                payload["gmailThreadId"] = threadId
            }
            batch.setData(payload, forDocument: itemRef, merge: true)
        }

        do {
            try await batch.commit()
        } catch {
            throw mapFirestoreError(error)
        }
        return messages.count
    }

    private func mapFirestoreError(_ error: Error) -> Error {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain,
           nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
            return CampusGmailError.fireStoreUnavailable
        }
        return error
    }

    private func headerValue(_ name: String, in headers: [GmailHeader]) -> String {
        headers.first { $0.name.lowercased() == name.lowercased() }?.value ?? ""
    }

    private func dateFrom(internalDate: String?, fallbackHeader: String) -> Date {
        if let internalDate,
           let milliseconds = Double(internalDate) {
            return Date(timeIntervalSince1970: milliseconds / 1000.0)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        return formatter.date(from: fallbackHeader) ?? Date()
    }
}

private struct GmailListResponse: Decodable {
    let messages: [GmailMessageReference]?
}

private struct GmailMessageReference: Decodable {
    let id: String?
}

private struct GmailMessageResponse: Decodable {
    let id: String?
    let threadId: String?
    let internalDate: String?
    let payload: GmailPayload?
}

private struct GmailPayload: Decodable {
    let headers: [GmailHeader]?
}

private struct GmailHeader: Decodable {
    let name: String
    let value: String
}

private struct CampusGmailMessageMetadata {
    let id: String
    let threadId: String?
    let title: String
    let sender: String
    let receivedAt: Date
    let originalUrl: String
}

private extension String {
    func ifBlank(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
