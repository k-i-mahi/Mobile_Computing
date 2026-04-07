// ============================================================
// Bundle+Decode.swift
// Generic JSON bundle decoder with detailed error reporting
// ============================================================

import Foundation

extension Bundle {
    func decode<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        guard let url = self.url(
            forResource: filename.replacingOccurrences(of: ".json", with: ""),
            withExtension: "json"
        ) else {
            throw BundleError.fileNotFound(filename)
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch let DecodingError.keyNotFound(key, context) {
            throw BundleError.decodingFailed("Missing key '\(key.stringValue)': \(context.debugDescription)")
        } catch let DecodingError.typeMismatch(_, context) {
            throw BundleError.decodingFailed("Type mismatch: \(context.debugDescription)")
        } catch let DecodingError.valueNotFound(type, context) {
            throw BundleError.decodingFailed("Missing value for \(type): \(context.debugDescription)")
        } catch let DecodingError.dataCorrupted(context) {
            throw BundleError.decodingFailed("Corrupted data: \(context.debugDescription)")
        } catch {
            throw error
        }
    }
}

enum BundleError: LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let f):   return "Could not find '\(f)' in app bundle."
        case .decodingFailed(let m): return "JSON decode error: \(m)"
        }
    }
}
