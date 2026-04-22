import Foundation

struct CloudinaryUploadResult {
    let secureURL: String
    let publicID: String
}

enum CloudinaryUploadError: LocalizedError {
    case missingConfig
    case invalidResponse
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .missingConfig:
            return "Cloudinary is not configured. Add cloud name and upload preset in Constants."
        case .invalidResponse:
            return "Cloudinary upload returned an invalid response."
        case .uploadFailed:
            return "Cloudinary upload failed. Please try again."
        }
    }
}

final class CloudinaryUploadService {
    static let shared = CloudinaryUploadService()
    private init() {}

    func uploadImage(
        _ data: Data,
        folder: String = "campusconnect/events",
        uploadPreset: String = Constants.cloudinaryEventsUploadPreset
    ) async throws -> CloudinaryUploadResult {
        guard Constants.isCloudinaryConfigured else {
            throw CloudinaryUploadError.missingConfig
        }

        let cloudName = Constants.cloudinaryCloudName
        let uploadPreset = uploadPreset
        guard let url = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload") else {
            throw CloudinaryUploadError.uploadFailed
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendFormField(named: "upload_preset", value: uploadPreset, using: boundary)
        body.appendFormField(named: "folder", value: folder, using: boundary)
        body.appendFileField(named: "file", filename: "event.jpg", mimeType: "image/jpeg", fileData: data, using: boundary)
        body.appendString("--\(boundary)--\r\n")

        let (responseData, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CloudinaryUploadError.uploadFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let secureURL = json["secure_url"] as? String,
              let publicID = json["public_id"] as? String else {
            throw CloudinaryUploadError.invalidResponse
        }

        return CloudinaryUploadResult(secureURL: secureURL, publicID: publicID)
    }
}

private extension Data {
    mutating func appendString(_ value: String) {
        if let data = value.data(using: .utf8) {
            append(data)
        }
    }

    mutating func appendFormField(named name: String, value: String, using boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendFileField(named name: String, filename: String, mimeType: String, fileData: Data, using boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(fileData)
        appendString("\r\n")
    }
}
