//
//  Created by MagTek on 4/20/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import Foundation

// Define a custom error enum (from swift_jsondecoder_error_handling)
enum PPGDecodingError: Error, LocalizedError {
    case invalidData(Data) // Store the data that failed to decode
    case decodingFailed(error: Error) // Wrap the underlying DecodingError
    case missingData
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let data):
            let dataString = String(data: data, encoding: .utf8) ?? "Invalid Data"
            return "Invalid data for decoding: \(dataString)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .missingData:
            return "Data was nil during decoding"
        }
    }
}

// MARK: - Custom Error Definitions
/// Custom errors for Magensa Payment Protecton Gateway API interactions, providing more specific failure reasons.
enum PPGAPIError: Error, LocalizedError {
    case invalidURL
    case authenticationFailed
    case networkError(Error)
    case invalidResponse
    case apiError(statusCode: Int, message: String?)
    case encodingError(Error)
    case decodingError(Error)
    case unknown

    /// Provides a user-friendly description for each error case.
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The API URL provided is invalid. Please check the endpoint."
        case .authenticationFailed: return "Authentication failed. Please verify your username and password."
        case .networkError(let error): return "A network error occurred: \(error.localizedDescription)"
        case .invalidResponse: return "Received an invalid response from the server. Expected HTTP response."
        case .apiError(let statusCode, let message):
            return "Magensa API returned an error (Status Code \(statusCode)): \(message ?? "No specific error message provided.")"
        case .encodingError(let error): return "Failed to encode the request body into JSON: \(error.localizedDescription)"
        case .decodingError(let error): return "Failed to decode the API response: \(error.localizedDescription)"
        case .unknown: return "An unknown error occurred during the API call."
        }
    }
}

// MARK: - Root Model
///=================================
/// Start  of New UnitiGate Input Data Structure
///=================================

struct PPGTransactionRequest: Codable {
    let dataInput: PPGDataInput
    let transactionInput: PPGTransactionInput
    let customerTransactionID: String
}

struct PPGDataInput: Codable {
    let encryptedData: PPGEncryptedData
    let tlvList: String
    let paymentMode: String
}

struct PPGEncryptedData: Codable {
    let dataType: String
    let data: String
    let keyVariant: String
    let ksn: String?
}

struct PPGTransactionInputDetail: Codable{
    let key: String
    let value: String
}

struct PPGTransactionInput: Codable {
    let transactionType: String
    let amount: Decimal
    let processorName: String
    let transactionInputDetails: [PPGTransactionInputDetail]?
}

///=================================
/// End of New UnitiGate Input Data Structure
///=================================

// MARK: - DataOutput

struct PPGDataOutput: Codable {
    let cardID, panLast4: String
    let isReplay: Bool
    let additionalOutputData: [PPGAdditionalOutputDatum]
}

// MARK: - AdditionalOutputDatum

struct PPGAdditionalOutputDatum: Codable {
    let key, value: String
}

// MARK: - TransactionOutput

struct PPGTransactionOutput: Codable {
    let transactionID: String
    let isTransactionApproved: Bool
    let transactionStatus, transactionMessage: String
    let authCode, authorizedAmount: String?
    let processorConvertedResponse: PPGProcessorConvertedResponse
    let processorNormalizedResponse: PPGProcessorNormalizedResponse
    let avsResult, cvvResult, issuerAuthenticationData, issuerScriptTemplate1, issuerScriptTemplate2: String?
    let token: String
    let transactionOutputDetails: [PPGTransactionOutputDetail]
}

// MARK: - ProcessorConvertedResponse

struct PPGProcessorConvertedResponse: Codable {
    let creditCardSaleResponse: PPGCreditCardSaleResponse
}

// MARK: - CreditCardSaleResponse

struct PPGCreditCardSaleResponse: Codable {
    let response: PPGResponse
}

// MARK: - Response

struct PPGResponse: Codable {
    let expressResponseCode, expressResponseMessage, expressTransactionDate, expressTransactionTime: String
    let expressTransactionTimezone: String
    let batch: PPGBatch
    let card: PPGCard
    let transaction: PPGTransaction
}

// MARK: - Batch

struct PPGBatch: Codable {
    let hostBatchID: String
}

// MARK: - Card

struct PPGCard: Codable {
    let expirationMonth, expirationYear, cardLogo, cardNumberMasked, bIN: String

    enum CodingKeys: String, CodingKey {
        case expirationMonth, expirationYear, cardLogo, cardNumberMasked
        case bIN = "bIN"
    }
}

// MARK: - Transaction (within CreditCardSaleResponse)

struct PPGTransaction: Codable {
    let transactionID, referenceNumber, processorName, transactionStatusCode: String
}

// MARK: - ProcessorNormalizedResponse

struct PPGProcessorNormalizedResponse: Codable {
    let processorStatus, processorStatusCode, processorTransactionTimestamp, processorTransactionID: String
    let processorTransactionAmount, processorMaskedCard, processorCardBrand, panLast4: String
    let cardType: String?
    let expressResponseCode, expressResponseMessage, expressTransactionTime: String
    let expressTransactionTimezone, hostBatchID, expirationMonth, expirationYear: String
    let bIN, referenceNumber, processorName: String

    enum CodingKeys: String, CodingKey {
        case processorStatus, processorStatusCode, processorTransactionTimestamp, processorTransactionID, processorTransactionAmount, processorMaskedCard, processorCardBrand, panLast4, cardType, expressResponseCode, expressResponseMessage, expressTransactionTime, expressTransactionTimezone, hostBatchID, expirationMonth, expirationYear
        case bIN = "bIN"
        case referenceNumber, processorName
    }
}

// MARK: - TransactionOutputDetail

struct PPGTransactionOutputDetail: Codable {
    let key, value: String
}
//======================
// JET PAY RESPONSE
//======================

// MARK: - New Models for Payment Response JSON

enum JetPayResponse {
    struct PaymentResponse: Decodable {
        let dataOutput: DataOutput
        let traceID: String
        let magTranID: String
        let customerTransactionID: String?
        let transactionUTCTimeStamp: String
        let transactionOutput: TransactionOutput
        let additionalResponseData: String?
    }
    
    struct DataOutput: Decodable {
        let cardID: String
        let panLast4: String
        let isReplay: Bool
        let additionalOutputData: [AdditionalOutputData]
        
        enum CodingKeys: String, CodingKey {
            case cardID = "cardID"
            case panLast4
            case isReplay
            case additionalOutputData
        }
    }
    
    struct AdditionalOutputData: Decodable {
        let key: String
        let value: String
    }
    
    struct TransactionOutput: Decodable {
        let transactionID: String?
        let isTransactionApproved: Bool
        let transactionStatus: String
        let transactionMessage: String
        let authCode: String
        let authorizedAmount: Double?
        let processorConvertedResponse: ProcessorConvertedResponse?
        let processorNormalizedResponse: ProcessorNormalizedResponse?
        let avsResult: String?
        let cvvResult: String?
        let issuerAuthenticationData: String?
        let issuerScriptTemplate1: String?
        let issuerScriptTemplate2: String?
        let token: String?
        let transactionOutputDetails: [TransactionOutputDetails]
        
        enum CodingKeys: String, CodingKey {
            case transactionID = "transactionID"
            case isTransactionApproved
            case transactionStatus
            case transactionMessage
            case authCode
            case authorizedAmount
            case processorConvertedResponse
            case processorNormalizedResponse
            case avsResult
            case cvvResult
            case issuerAuthenticationData
            case issuerScriptTemplate1
            case issuerScriptTemplate2
            case token
            case transactionOutputDetails
        }
    }
    
    struct ProcessorConvertedResponse: Decodable {
        let jetPayResponse: JetPayResponse
    }
    
    struct JetPayResponse: Decodable {
        let transactionID: String?
        let actionCode: String?
        let approval: String?
        let responseText: String?
        let uniqueID: String?
        let rRN: String?
        let rawResponseCode: String?
        let verificationResult: String?
        
        enum CodingKeys: String, CodingKey {
            case transactionID = "TransactionID"
            case actionCode = "ActionCode"
            case approval = "Approval"
            case responseText = "ResponseText"
            case uniqueID = "UniqueID"
            case rRN = "RRN"
            case rawResponseCode = "RawResponseCode"
            case verificationResult = "VerificationResult"
        }
    }
    
    struct ProcessorNormalizedResponse: Decodable {
        let transactionID: String
        let actionCode: String
        let approval: String
        let responseText: String
        let uniqueID: String
        let rRN: String
        let rawResponseCode: String
        let verificationResult: String
        
        enum CodingKeys: String, CodingKey {
            case transactionID = "transactionID"
            case actionCode
            case approval
            case responseText
            case uniqueID
            case rRN
            case rawResponseCode
            case verificationResult
        }
    }
    
    struct TransactionOutputDetails: Decodable {
        let key: String
        let value: String
    }
}

@MainActor
final class PaymentGatewayServiceAPI {
    private var username: String
    private var password: String

    @Published private var transactionState = "Ready"
    @Published private var lastTransactionApproved: Bool? = nil
    
    init(userName: String, password: String) {
        self.username = userName
        self.password = password
    }
    
    func newPaymentRequest(model: MTPaymentRequest) async throws -> MTNewTransactionResponse? {
        transactionState = "Preparing request..."
        let transactionRequest = buildTransactionRequest(from: model)
        
        do {
            let endpoint = MTAPIEndpoint.postProcessApplePayment(
                body: transactionRequest,
                username: username,
                password: password
            )
            
            debugPrint("Making network call...")
            transactionState = "Connecting to API..."
            
            let response: MTNewTransactionResponse = try await MTNetworkManager.shared.request(from: endpoint)
            
            guard
                let transactionOutput = response.transactionOutput,
                let dataOutput = response.dataOutput,
                let transactionID = transactionOutput.transactionID,
                let isApproved = transactionOutput.isTransactionApproved,
                let panLast4 = dataOutput.panLast4
            else {
                debugPrint("Missing required fields in response")
                return nil
            }
            
            debugPrint("✅ panLast4: \(panLast4)")
            debugPrint("✅ isTransactionApproved: \(isApproved)")
            debugPrint("✅ transactionID (from API): \(transactionID)")
            
            lastTransactionApproved = isApproved
            transactionState = isApproved ? "Approved" : "Declined"
            
            return response
        } catch let netError as MTNetworkError {
            debugPrint("Network error: \(netError)")
            transactionState = "Network error occurred: \(netError)"
            throw netError
        } catch {
            debugPrint("Unexpected error: \(error.localizedDescription)")
            transactionState = "Unexpected error"
            throw error
        }
    }
    
    // TransactionRequest prepare
    func buildTransactionRequest(from model: MTPaymentRequest) -> PPGTransactionRequest {
        // Prepare encrypted data
        let encryptedData = PPGEncryptedData(
            dataType: "AppleTapToPay",
            data: model.paymentCardData,
            keyVariant: "Embedded",
            ksn: nil
        )
        
        // Prepare DataInput
        let dataInput = PPGDataInput(
            encryptedData: encryptedData,
            tlvList: model.generalCardData,
            paymentMode: "EMV"
        )
        
        if let transactionDetails = model.transactionDetails {
            debugPrint("-- transactionDetails: ")
            for detail in transactionDetails {
                debugPrint("Key: \(detail.key), Value: \(detail.value)")
            }
        }
        
        // Prepare TransactionInput
        let transactionInput = PPGTransactionInput(
            transactionType: model.transactionType,
            amount: model.amount,
            processorName: model.processorName,
            transactionInputDetails: model.transactionDetails
        )
        
        // Determine transaction ID
        let customerTransactionID = model.transactionID.isEmpty ? UUID().uuidString : model.transactionID
        
        return PPGTransactionRequest(
            dataInput: dataInput,
            transactionInput: transactionInput,
            customerTransactionID: customerTransactionID
        )
    }
}
