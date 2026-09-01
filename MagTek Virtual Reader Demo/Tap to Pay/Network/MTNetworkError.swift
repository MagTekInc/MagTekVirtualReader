//
//  Created by Bayram Mete on 8/18/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import Foundation

enum MTNetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case serverError(Int, message: String? = nil)
    case urlError(URLError)
    case unknown(Error)
}
