//
//  Created on 7/17/26.
//  Copyright © 2026 MagTek, Inc. All rights reserved.
//

import Foundation

// MARK: - Errors

enum MTSAFNetworkError: Error, LocalizedError {
    case invalidURL(String)
    case nonHTTPResponse
    case httpStatus(Int, body: String)
    case forwardNotApproved(customerTransactionID: String, body: String)
    case emptyDeleteToken
    case encodingFailed(Error)
    case decodingFailed(Error, body: String)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let s):
            return "Invalid URL: \(s)"
        case .nonHTTPResponse:
            return "Response was not an HTTPURLResponse."
        case .httpStatus(let code, let body):
            return "HTTP \(code). Body: \(body)"
        case .forwardNotApproved(let id, let body):
            return "Forward returned isTransactionApproved == false for customerTransactionID \(id). Body: \(body)"
        case .emptyDeleteToken:
            return "Delete-token response had empty storeAndForwardToken."
        case .encodingFailed(let err):
            return "Encoding failed: \(err.localizedDescription)"
        case .decodingFailed(let err, let body):
            return "Decoding failed: \(err.localizedDescription). Body: \(body)"
        case .transport(let err):
            return "Transport error: \(err.localizedDescription)"
        }
    }
}

// MARK: - Forward request / response

struct PaymentRequest: Codable {
    let id: String
    let count: Int
    let intermediateCertificate: [String]
    let leafCertificate: String
    let signature: String
    let payments: [Payment]
    struct Payment: Codable {
        let id: String
        let generalCardData: String
        let paymentCardData: String
        let signature: String
    }
}

struct MTSAFForwardRequest: Encodable {
    let transactionInput: TransactionInput
    let dataInput: DataInput
    let customerTransactionID: String
    let additionalRequestData: [String]

    struct TransactionInput: Encodable {
        let processorName: String
        let transactionInputDetails: [KeyValue]
        let transactionType: String
        let amount: Decimal
    }

    struct DataInput: Encodable {
        let tlvList: String
        let encryptedData: EncryptedData
        let paymentMode: String

        struct EncryptedData: Encodable {
            let keyVariant: String
            let dataType: String
            let data: String
            let ksn: String?

            enum CodingKeys: String, CodingKey {
                case keyVariant
                case dataType
                case data
                case ksn
            }

            /// We override default encode(encoder:) because ksn must be nil on all calls. Otherwise
            /// we'd use default encode(encoder:)
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(keyVariant, forKey: .keyVariant)
                try container.encode(dataType, forKey: .dataType)
                try container.encode(data, forKey: .data)

                // This writes `"ksn": null` when ksn == nil
                try container.encode(ksn, forKey: .ksn)
            }
        }
    }

    struct KeyValue: Encodable {
        let key: String
        let value: String
    }
}

struct MTSAFForwardResponse: Decodable {
    let customerTransactionID: String?
    let magTranID: String?
    let traceID: String?
    let transactionOutput: TransactionOutput?
    let additionalResponseData: [AdditionalResponseData]?
    let error: String?

    struct TransactionOutput: Decodable {
        let transactionID: String?
        let isTransactionApproved: Bool?
        let transactionStatus: String?
        let transactionMessage: String?
    }

    struct AdditionalResponseData: Decodable {
        let key: String
        let value: String
    }

    var appleTap2PaySafToken: String? {
        additionalResponseData?
            .first(where: { $0.key == "AppleTap2PaySaFToken" })?
            .value
    }

    var isApproved: Bool {
        transactionOutput?.isTransactionApproved == true
    }

    /// Human-readable reason for a non-approved forward. Magensa answers HTTP 200 for
    /// declines and processor-side rejects, so these fields are the only diagnostic we get.
    var notApprovedSummary: String {
        var parts: [String] = []
        if let status = transactionOutput?.transactionStatus, !status.isEmpty {
            parts.append("transactionStatus=\(status)")
        }
        if let message = transactionOutput?.transactionMessage, !message.isEmpty {
            parts.append("transactionMessage=\(message)")
        }
        if let error, !error.isEmpty {
            parts.append("error=\(error)")
        }
        if let transactionID = transactionOutput?.transactionID, !transactionID.isEmpty {
            parts.append("transactionID=\(transactionID)")
        }
        if let magTranID, !magTranID.isEmpty {
            parts.append("magTranID=\(magTranID)")
        }
        if let traceID, !traceID.isEmpty {
            parts.append("traceID=\(traceID)")
        }
        if parts.isEmpty {
            parts.append("no transactionStatus/transactionMessage returned")
        }
        return parts.joined(separator: "; ")
    }
}
