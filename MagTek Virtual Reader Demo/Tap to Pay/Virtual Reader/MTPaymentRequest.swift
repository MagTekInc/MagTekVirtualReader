//
//  Created by MagTek on 8/19/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import Foundation

struct MTPaymentInputDetail: Encodable {
    let key: String
    let value: String
}

// MARK: - Transaction Request Model
struct MTPaymentRequest: Encodable {
    let transactionID: String
    let transactionType: String
    let transactionDetails: [PPGTransactionInputDetail]?
    let amount: Decimal
    let processorName: String
    let paymentCardData: String
    let generalCardData: String
}
