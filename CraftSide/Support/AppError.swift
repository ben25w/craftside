import Foundation

enum AppError: LocalizedError {
    case missingConnection
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingConnection:
            "Add your Craft Daily Notes API URL in Settings."
        case .invalidURL:
            "The Craft API URL is not valid."
        case .invalidResponse:
            "Craft returned a response CraftSide could not read."
        case .httpStatus(let status, let body):
            body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Craft returned HTTP \(status)."
                : "Craft returned HTTP \(status). \(body)"
        case .keychain(let status):
            "Keychain failed with status \(status)."
        }
    }
}
