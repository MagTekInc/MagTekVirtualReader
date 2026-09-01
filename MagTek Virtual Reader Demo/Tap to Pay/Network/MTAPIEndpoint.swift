//
//  Created by Bayram Mete on 8/18/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import Foundation

enum MTUnigateURLConfigurationError: LocalizedError {
    case emptyURL
    case invalidURL
    case unsupportedScheme
    case embeddedCredentials
    case queryOrFragment

    var errorDescription: String? {
        switch self {
        case .emptyURL:
            return "Enter the Unigate base URL."
        case .invalidURL:
            return "Enter a complete Unigate base URL, including its host."
        case .unsupportedScheme:
            return "The Unigate base URL must use https."
        case .embeddedCredentials:
            return "Do not include a username or password in the Unigate base URL."
        case .queryOrFragment:
            return "The Unigate base URL cannot contain a query or fragment."
        }
    }
}

enum MTUnigateURL {
    static let defaultBaseURL = ""

    private static let paymentCardReaderPath = "AppleTapToPayToken/PaymentCardReader"
    private static let storeAndForwardPath = "AppleTapToPayToken/StoreAndForward"

    static func normalizedBaseURL(_ rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MTUnigateURLConfigurationError.emptyURL
        }
        guard var components = URLComponents(string: trimmed),
              components.host?.isEmpty == false else {
            throw MTUnigateURLConfigurationError.invalidURL
        }
        guard components.scheme?.lowercased() == "https" else {
            throw MTUnigateURLConfigurationError.unsupportedScheme
        }
        guard components.user == nil, components.password == nil else {
            throw MTUnigateURLConfigurationError.embeddedCredentials
        }
        guard components.query == nil, components.fragment == nil else {
            throw MTUnigateURLConfigurationError.queryOrFragment
        }

        components.scheme = "https"
        components.host = components.host?.lowercased()

        var path = components.percentEncodedPath
        while path.hasSuffix("/") {
            path.removeLast()
        }
        components.percentEncodedPath = path + "/"

        guard let normalized = components.string else {
            throw MTUnigateURLConfigurationError.invalidURL
        }
        return normalized
    }

    static func paymentCardReaderURL(for baseURL: String) -> String {
        baseURL + paymentCardReaderPath
    }

    static func storeAndForwardURL(for baseURL: String) -> String {
        baseURL + storeAndForwardPath
    }
}

// HTTP Method
enum MTHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

//  Endpoint Protocol
protocol MTEndpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: MTHTTPMethod { get }
    var headers: [String: String]? { get }
    var body: Encodable? { get }
}

extension MTEndpoint {
    var body: Encodable? { nil } // default implementation
}

enum MTAPIEndpoint: MTEndpoint {
    case postProcessApplePayment(baseURL: String,
                                 body: Encodable? = nil,
                                 username: String? = nil,
                                 password: String? = nil,
                                 headers: [String: String]? = nil)

    var baseURL: String {
        switch self {
        case .postProcessApplePayment(let baseURL, _, _, _, _):
            return baseURL
        }
    }
    
    var path: String {
        switch self {
        case .postProcessApplePayment:
            return "transaction/EMV"
        }
    }
    
    var method: MTHTTPMethod {
        switch self {
        case .postProcessApplePayment:
            return .post
        }
    }
    
    var headers: [String: String]? {
        switch self {
        case .postProcessApplePayment(_, _, let username, let password, let customHeaders):
            var result = customHeaders ?? [:]
            result["Content-Type"] = "application/json"
            
            if let username, let password {
                let loginString = "\(username):\(password)"
                if let loginData = loginString.data(using: .utf8) {
                    let base64LoginString = loginData.base64EncodedString()
                    result["Authorization"] = "Basic \(base64LoginString)"
                }
            }
            return result
        }
    }

    var body: Encodable? {
        switch self {
        case .postProcessApplePayment(_, let body, _, _, _):
            return body
        }
    }
}
