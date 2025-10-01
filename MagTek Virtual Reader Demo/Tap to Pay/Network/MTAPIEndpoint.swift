//
//  Created byMagTek on 8/18/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import Foundation

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
    case postProcessApplePayment(body: PPGTransactionRequest? = nil,
                                 username: String? = nil,
                                 password: String? = nil,
                                 headers: [String: String]? = nil)
    
    /*
     Check Magensa configuration for your
     environment & update baseURL as required.
     */
    var baseURL: String {
        MTConstants.unigateBaseURL
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
        case .postProcessApplePayment(_, let username, let password, let customHeaders):
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
        case .postProcessApplePayment(let body, _, _, _):
            guard let body = body else { return nil }
            return MTAnyEncodable(body)
        }
    }
}
