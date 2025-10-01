//
//  Created by MagTek on 8/19/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import Foundation

struct MTNewTransactionResponse: Codable {
    let dataOutput: MTNewDataOutput?
    let traceID: String?
    let magTranID: String?
    let customerTransactionID: String?
    let transactionUTCTimeStamp: String?
    let transactionOutput: MTNewTransactionOutput?
    let additionalResponseData: String?
}

struct MTNewDataOutput: Codable {
    let cardID: String?
    let panLast4: String?
    let isReplay: Bool?
    let additionalOutputData: [MTKeyValue]?
}

struct MTKeyValue: Codable {
    let key: String?
    let value: String?
}

struct MTNewTransactionOutput: Codable {
    let transactionID: String?
    let isTransactionApproved: Bool?
    let transactionStatus: String?
    let transactionMessage: String?
    let authCode: String?
    let authorizedAmount: Decimal?
    let processorConvertedResponse: MTNewProcessorConvertedResponse?
    let processorNormalizedResponse: MTNewProcessorNormalizedResponse?
    let avsResult: String?
    let cvvResult: String?
    let issuerAuthenticationData: String?
    let issuerScriptTemplate1: String?
    let issuerScriptTemplate2: String?
    let token: String?
    let transactionOutputDetails: [MTKeyValue]?
}

struct MTNewProcessorConvertedResponse: Codable {
    let saleResponse: MTSaleResponse?
}

struct MTNewProcessorNormalizedResponse: Codable {
    let processorStatus: String?
    let processorStatusCode: String?
    let processorTransactionTimestamp: String?
    let processorTransactionID: String?
    let processorTransactionAmount: String?
    let processorMaskedCard: String?
    let processorReference: String?
    let processorCardBrand: String?
    let panLast4: String?
    let CardType: String?
    let processorName: String?
    let responseMessage: String?
    let authCode: String?
    let hostResponseCode: String?
    let taskID: String?
    let transactionAmount: String?
    let processedAmount: String?
    let totalAmount: String?
    let addressVerificationCode: String?
    let commercialCard: String?
    let aci: String?
    let cardTransactionIdentifier: String?
    let customerReceipt: String?
    let merchantReceipt: String?
    let emvIssuerScripts: String?
    let emvIssuerAuthenticationData: String?
}

struct MTSaleResponse: Codable {
    let status: String?
    let responseCode: String?
    let responseMessage: String?
    let authCode: String?
    let hostReferenceNumber: String?
    let hostResponseCode: String?
    let taskID: String?
    let transactionID: String?
    let transactionTimestamp: String?
    let transactionAmount: String?
    let processedAmount: String?
    let totalAmount: String?
    let addressVerificationCode: String?
    let cardType: String?
    let maskedCardNumber: String?
    let commercialCard: String?
    let aci: String?
    let cardTransactionIdentifier: String?
    let customerReceipt: String?
    let merchantReceipt: String?
    let emvIssuerScripts: String?
    let emvIssuerAuthenticationData: String?
}
