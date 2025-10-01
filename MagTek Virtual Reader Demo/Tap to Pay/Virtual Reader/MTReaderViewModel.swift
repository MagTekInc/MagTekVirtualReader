//
//  Created by MagTekon 4/20/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import SwiftUI

/// Values that describe types of transactions.
enum MTTransactionType: Int, CaseIterable, Identifiable {
    case sale, refund, authorize

    /// A computed property you can use to get text representations of the names of the enumeration cases.
    var name: String {
        switch self {
        case .sale:
            return "SALE"
        case .refund:
            return "REFUND"
        case .authorize:
            return "AUTHORIZE"
        }
    }

    /// An identifier that enables this enumeration to conform to the identifiable protocol.
    var id: Int { self.rawValue }
}

enum MTPaymentProcessor: Int, CaseIterable, Identifiable {
    case TSYSPilot, RapidConnectV3
    
    /// A computed property you can use to get text representations of the names of the enumeration cases.
    var name: String {
        switch self {
        case .TSYSPilot: return "TSYS - Pilot"
        case .RapidConnectV3: return "Rapid Connect v3"
        }
    }
    
    /// An identifier that enables this enumeration to conform to the identifiable protocol.
    var id: Int { self.rawValue }
}

/// Generic reader interface model that doesn't support Tap to Pay on iPhone.
///
/// This implementation demonstrates how to support both existing solutions and
/// custom SDKs that support iOS 15.4 and earlier, and iOS 16 and later by
/// abstracting out specific Tap to Pay implementation elements and then extending
/// this class, adding those elements in order to create a class you can instantiate
/// at run time once you've determined iOS version and hardware is available on
/// the user's device.
///
/// See `ProximityReaderViewModel.swift` for the implementation that supports Tap to Pay.
class MTReaderViewModel: ObservableObject, Identifiable {
    private static let kDefaultAmountString = "2.00"
    private static let kDefaultAmount = Decimal(string: kDefaultAmountString) ?? 0.00
    @Published var status = "Not Ready"
    @Published var info = ""
    @Published var transactionTypePicker = MTTransactionType.sale
    @Published var paymentProcessorPicker = MTPaymentProcessor.TSYSPilot
    @Published var readerID = ""
    @Published var statusOK = false
    @Published var trxShow = false
    @Published var paymentShow = false
    @Published var trxStatus = ""
    @Published var trxResult = ""
    @Published var apiTestStatus = ""
    @Published var formattedVasResultString = ""
    @Published var amountDecimal: Decimal = kDefaultAmount
    @Published var readerIdentifier = ""    {
        didSet {
            if readerIdentifier != oldValue { // oldValue is implicitly available in didSet
                readerID = String(readerIdentifier.prefix(32) + "...")
            }
        }
    }
    @Published var amountString = kDefaultAmountString {
        didSet {
            self.amountDecimal = Decimal(string: amountString) ?? 0.0
        }
    }

    /// A Boolean value that represent that background status of the app.
    var isBackground = false

    /// A set of values that represent the current authorization status.
    var currentAuthResult: (status: String, amount: Decimal, transactionId: String)?

    /// A Boolean value that indicates whether Tap to Pay is available on the current device.
    ///
    /// This implementation returns `false` since this base class demonstrates
    /// support for iOS 15.4 and earlier (or iOS devices that don't have Tap to Pay hardware).
    var isTapToPayAvailable: Bool {
        return false
    }

    /// An placeholder function that subclasses implement for account linking.
    func linkAccount() {}
    
    /// An placeholder function that subclasses implement for account linking.
    func isAccountLinked() async -> Bool {
        return false
    }

    /// An placeholder function that subclasses implement to ready the SKD for use after the app returns from the background state.
    func preparePaymentCardReaderSession() {}
    
    func prepare() {}

    /// An placeholder function that subclasses implement to reset the SDK to its initial state.
    ///
    func cleanup() {}

    /// An placeholder function that subclasses implement to implement the payment process specific to your Payment Service Processor (PSP).
    ///
    /// - Parameter:
    ///      - amount: A decimal amount that represents a payment the network should process.
    func pay(_ amount: Decimal) {}

    /// An placeholder function that subclasses implement to implement that clears the results of a previous transaction.
    func clearTransactionResult() {}
}
