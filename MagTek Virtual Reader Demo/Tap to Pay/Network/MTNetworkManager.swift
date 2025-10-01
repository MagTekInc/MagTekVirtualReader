//
//  Created by MagTek on 8/18/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import Foundation

protocol MTNetworkProtocol {
    func request<T: Decodable>(from endpoint: MTEndpoint) async throws -> T
}

final class MTNetworkManager: MTNetworkProtocol {
    static let shared = MTNetworkManager()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }
    
    func request<T: Decodable>(from endpoint: MTEndpoint) async throws -> T {
        guard let url = URL(string: endpoint.baseURL + endpoint.path) else {
            throw MTNetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        if let headers = endpoint.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let body = endpoint.body {
            do {
                request.httpBody = try JSONEncoder().encode(MTAnyEncodable(body))
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } catch {
                throw MTNetworkError.decodingError(error)
            }
        }
        
        #if DEBUG
            print("Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
            if let headers = request.allHTTPHeaderFields { print("Headers: \(headers)") }
            if let body = request.httpBody, let json = String(data: body, encoding: .utf8) { print("Body: \(json)") }
        #endif
        
        do {
            let (data, response) = try await session.data(for: request)
            
            #if DEBUG
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Response: \(jsonString)")
                }
            #endif
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MTNetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                break // Success, pass
            case 400...499:
                throw MTNetworkError.serverError(httpResponse.statusCode, message: dataToString(data))
            case 500...599:
                throw MTNetworkError.serverError(httpResponse.statusCode, message: dataToString(data))
            default:
                throw MTNetworkError.serverError(httpResponse.statusCode, message: dataToString(data))
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(T.self, from: data)
            
        } catch let decodingError as PPGDecodingError {
            throw MTNetworkError.decodingError(decodingError)
        } catch let urlError as URLError {
            throw MTNetworkError.urlError(urlError)
        } catch {
            throw MTNetworkError.unknown(error)
        }
    }
    
    private func dataToString(_ data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
}

struct MTAnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init(_ wrapped: Encodable) {
        self._encode = wrapped.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
