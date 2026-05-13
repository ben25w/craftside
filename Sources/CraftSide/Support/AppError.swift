import Foundation

enum AppError: LocalizedError {
    case missingConnection
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingConnection:
            "Add your Craft API URL before loading notes."
        case .invalidURL:
            "The Craft API URL is not valid."
        case .invalidResponse:
            "Craft returned a response the app could not read."
        case .httpStatus(let status, let body):
            "Craft returned HTTP \(status). \(body)"
        }
    }
}
