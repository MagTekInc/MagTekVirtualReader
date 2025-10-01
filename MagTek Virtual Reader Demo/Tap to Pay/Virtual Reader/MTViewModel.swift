//
//  Created by MagTek on 4/20/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import os
import UIKit
import ProximityReader
import MagTekVirtualReader

final class MTViewModel: MTReaderViewModel, @unchecked Sendable {
    @Published var logData = ""
    @Published var isProcessingPayment = false
    @Published var isCardReaderSessionActive = false
    @Published var reconfigureSession = false
    private var paymentData: PaymentCardReadResult?
    private var readError: PaymentCardReaderSession.ReadError?
    private var jwtTokenString = ""
    private var mtVRConfig = MagTekVRConfig(userName: "", password: "", url: "", readerID: "")
    private var mtVRCardReader: MagTekVirtualCardReader?
    static let msgTTPIsReady = "Tap to Pay Ready"
    let logger = MTLogManager.shared
    public var startTime = DispatchTime.now()
    
    /// Creates a new proximity reader model object.
    override init() {
        // ❌❌❌ IMPORTANT ❌❌❌ DO NOT HARD CODE CREDENTIALS IN PRODUCTION APP
         mtVRConfig = MagTekVRConfig(userName: MTConstants.userName,
                                           password: MTConstants.password,
                                           url: MTConstants.magensaURL,
                                           readerID: "")
        mtVRCardReader = MagTekVirtualCardReader(config: mtVRConfig)

        
        logger.logDeviceInfo()

        super.init()
    }
    
    @MainActor
    func setupReaderID() async {
        guard isTapToPayAvailable else { return }
        
        if let rid = mtVRConfig.readerID, rid.isEmpty {
            if let newReaderID = try? await mtVRCardReader?.getPaymentCardReaderIdentifier() {
                logInfo("readerID: '\(newReaderID)'")
                readerIdentifier = newReaderID
                mtVRConfig.readerID = newReaderID
                statusOK = true
            } else {
                logInfo("❌ readerID: failed getPaymentCardReaderIdentifier()")
            }
        } else {
            logInfo("❌ readerID: empty")
        }
    }
    
    @MainActor
    func updateConfig(_ cfg: MagTekVRConfig) {
        Task {
            if let rid = mtVRConfig.readerID, !rid.isEmpty {
                logInfo("readerID: '\(rid)'")
                mtVRConfig = MagTekVRConfig(userName: "\(cfg.userName)", password: cfg.password, url: cfg.url, readerID: rid)
            } else {
                await setupReaderID()
                logInfo("readerID: setupReaderID()")
                mtVRConfig = MagTekVRConfig(userName: "\(cfg.userName)", password: cfg.password, url: cfg.url, readerID: readerIdentifier)
            }
            
            try? mtVRCardReader?.setConfiguration(mtVRConfig)
            reconfigureSession = true
        }
    }
    
    func reconfigureCardReaderSession() async {
        await fetchToken()
        await preparePaymentCardReaderSessionWithToken()
        
        DispatchQueue.main.async {
            self.reconfigureSession = false
        }
    }
    
    private func updateLogData(_ log: String) {
        debugPrint(log)
        DispatchQueue.main.async {
            self.logData = log
            self.logInfo(log)
        }
    }
    
    private func logError(_ errMessage: String) {
        debugPrint(errMessage)
        logger.error(errMessage)
    }
    
    public func logInfo(_ info: String) {
        debugPrint(info)
        logger.info(info)
    }
    
    private func updateStatusInfo(status: String?, statusOK: Bool?) {
        DispatchQueue.main.async {
            if let statusOK = statusOK {
                self.statusOK = statusOK
            }
            
            if let status {
                self.status = status
            }
        }
    }
    
    public func processTapToPayTransaction(_ amount: Decimal) async {
        logger.info(#function)
        guard let magTekVirtualCardReader = mtVRCardReader else {
            logError("magTekVirtualCardReader is nil.")
            return
        }
        
        guard magTekVirtualCardReader.isTapToPaySupported()else {
            logError("Tap To Pay is not available.")
            return
        }
        
        var logString = ""
        
        do {
            let isMerchantAccountLinked = try await magTekVirtualCardReader.isMerchantAccountLinked()
            
            if isMerchantAccountLinked {
                logString += "Merchant account already linked."
                updateLogData(logString)
                updateStatusInfo(status: "Account Linked", statusOK: true)
            } else {
                logString = "Merchant account not linked."
                updateLogData(logString)
                
                try await magTekVirtualCardReader.linkMerchantAccount()
                updateStatusInfo(status: "Merchant account Linked.", statusOK: true)
            }
            
            // Prepare Payment Card Reader Session
            let myevents = magTekVirtualCardReader.getPaymentCardReaderEvents()
            debugPrint("<----- Listening PaymentCardReader events ---------->")
            
            Task {
                for await event in myevents {
                    debugPrint("-----> Received event: \(event)")
                    DispatchQueue.main.async {
                        self.status = "Configuring - \(event)"
                    }
                }
            }
            
            try await magTekVirtualCardReader.configurePaymentCardReaderSession { progress in
                DispatchQueue.main.async {
                    self.status = "Configuring - \(progress)%."
                }
            }
            
            DispatchQueue.main.async {
                self.isCardReaderSessionActive = true
                self.status = MTViewModel.msgTTPIsReady
                self.statusOK = true
            }
            
            pay(amount)
            
        } catch let error as MagTekVirtualReaderError {
            await handlePaymentCardReaderError(error, callingFunc: #function)
        }
        
        catch { // catch any other errors.
            logString = "Unexpected error: \(error.localizedDescription)"
            logError(logString)
        }
    }
    
    /// A Boolean value that indicates whether the Tap to Pay API is available.
    override var isTapToPayAvailable: Bool {
        guard let magTekVirtualCardReader = mtVRCardReader else {
            logError("\(#function): magTekVirtualCardReader is nil.")
            return false
        }
        
        return magTekVirtualCardReader.isTapToPaySupported()
    }
    
    /// Fetch JWT Token
    ///
    public func fetchToken() async {
        logger.info(#function)
        guard let magTekVirtualCardReader = mtVRCardReader else {
            logError("magTekVirtualCardReader is nil.")
            return
        }
        
        guard magTekVirtualCardReader.isTapToPaySupported() else {
            logger.info("Device doesn't support Tap To Pay")
            
            DispatchQueue.main.async {
                self.status = "Device doesn't support Tap To Pay"
                self.statusOK = false
            }
            
            return
        }
        
        Task {
            let start = getCurrentDispatchTimeAndFormattedUTCString()
            logInfo("Token Fetch Started...")
            
            do {
                let token = try await magTekVirtualCardReader.fetchPaymentCardReaderTokenFromMagensaPSP(mtVRConfig)
                jwtTokenString = token
                
                let end = getCurrentDispatchTimeAndFormattedUTCString()
                let nanoTime = end.dispatchTime.uptimeNanoseconds - start.dispatchTime.uptimeNanoseconds
                let timeInterval = Double(nanoTime) / 1_000_000 // convert to milliseconds
                let successString = "Token Fetch Success (\(timeInterval) ms)"
                logInfo(successString)
                
                DispatchQueue.main.async {
                    self.apiTestStatus = successString
                    self.statusOK = true
                }
            } catch {
                let end = getCurrentDispatchTimeAndFormattedUTCString()
                let nanoTime = end.dispatchTime.uptimeNanoseconds - start.dispatchTime.uptimeNanoseconds
                let timeInterval = Double(nanoTime) / 1_000_000 // convert to milliseconds
                logInfo("❌ Token Fetch Fail (\(timeInterval) ms)")
                
                DispatchQueue.main.async {
                    self.apiTestStatus = "Failed to fetch token!"
                    self.statusOK = false
                }
                
                await handlePaymentCardReaderError(error, callingFunc: #function)
            }
        }
    }
    
    /// Links to a merchant's account.
    ///
    /// This demonstrates how to link a merchant's account. In a production
    /// implementation you would perform this step only once per merchant.
    override func linkAccount() {
        logger.info(#function)
        
        Task {
            do {
                guard (mtVRCardReader?.isTapToPaySupported()) != nil else {
                    logger.info("Device doesn't support Tap To Pay")
                    
                    DispatchQueue.main.async {
                        self.status = "Device doesn't support Tap To Pay"
                        self.statusOK = false
                    }
                    return
                }

                if self.jwtTokenString.isEmpty {
                    if let tokenString = try await mtVRCardReader?.fetchPaymentCardReaderTokenFromMagensaPSP(mtVRConfig) {
                        self.jwtTokenString = tokenString
                    }
                }
                
                let start = getCurrentDispatchTimeAndFormattedUTCString()
                logInfo("+ Link Account: \(start.dateString)")
                
                try await mtVRCardReader?.linkMerchantAccountWithToken(self.jwtTokenString)
                
                let end = getCurrentDispatchTimeAndFormattedUTCString()
                let nanoElapsedTime = (end.dispatchTime.uptimeNanoseconds - start.dispatchTime.uptimeNanoseconds)
                let timeInterval = Double(nanoElapsedTime) / 1_000_000 // Convert to milliseconds
                let executionTime = "Link Account: \(timeInterval) ms"
                logInfo("+ Link Account: \(end.dateString)")
                logInfo(executionTime)
                
                DispatchQueue.main.async {
                    self.apiTestStatus = executionTime
                    self.statusOK = true
                }
            } catch {
                await handlePaymentCardReaderError(error, callingFunc: #function)
            }
        }
    }
    
    func getCurrentFormattedDateTimeUTC() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Explicitly set to UTC
        return formatter.string(from: now)
    }
    
    /// Returns the current DispatchTime and its corresponding formatted string representation in UTC.
    ///
    /// - Returns: A tuple containing:
    ///   - `dispatchTime`: The DispatchTime captured at the moment the function is called.
    ///   - `dateString`: The formatted string of the current wall-clock time in "yyyy-MM-dd HH:mm:ss.SSS" format (UTC).
    func getCurrentDispatchTimeAndFormattedUTCString() -> (dispatchTime: DispatchTime, dateString: String) {
        let currentDispatchTime = DispatchTime.now()
        let now = Date()
        
        // Configure a DateFormatter to output the string in UTC format.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX") // Ensures consistent format
        formatter.timeZone = TimeZone(secondsFromGMT: 0)     // Explicitly set formatter to UTC
        
        // Format the wall-clock Date into a string.
        let dateString = formatter.string(from: now)
        
        // Return both the DispatchTime and the formatted UTC string as a tuple.
        return (dispatchTime: currentDispatchTime, dateString: dateString)
    }
    
    func calculateElapsedTimeInMS(start: DispatchTime, end: DispatchTime) -> Double {
        let timeIntervalInMilliseconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000 //ms
        return timeIntervalInMilliseconds
    }
    
    func formatDoubleTo3DecDigits(_ value: Double) -> String {
        // "%.3f" means format as a floating-point number with exactly 3 digits after the decimal point.
        return String(format: "%.3f", value)
    }
    
    func setConfiguration(_ config: MagTekVRConfig) {
        mtVRCardReader = MagTekVirtualCardReader(config: config)
        try? mtVRCardReader?.setConfiguration(mtVRConfig)
    }
    
    ///
    /// Test if  to a merchant's account is already linked
    ///
    override func isAccountLinked() async -> Bool {
        logger.info(#function)
        var isMerchantAccountLinked = false
        
        guard (mtVRCardReader?.isTapToPaySupported()) != nil else {
            logger.info("Device doesn't support Tap To Pay")
            
            DispatchQueue.main.async {
                self.status = "Device doesn't support Tap To Pay"
                self.statusOK = false
            }
            
            return false
        }
        
        do {
            let start = getCurrentDispatchTimeAndFormattedUTCString()
            logInfo("+ isAccountLinked = \(start.dateString)")
            
            isMerchantAccountLinked = try await mtVRCardReader?.isMerchantAccountLinked() ?? false
            
            let end = getCurrentDispatchTimeAndFormattedUTCString()
            let elapsedTime = calculateElapsedTimeInMS(start: start.dispatchTime, end: end.dispatchTime)
            logInfo("- isAccountLinked = \(start.dateString)")
            logInfo("isAccountLinked Time = \(formatDoubleTo3DecDigits(elapsedTime)) ms")
            
            DispatchQueue.main.async {
                self.statusOK = true
            }
            
            return isMerchantAccountLinked
            
        } catch {
            await handlePaymentCardReaderError(error, callingFunc: #function)
            return false
        }
    }
    
    func CheckIfAccountLinked() {
        Task {
            let bResult = await isAccountLinked()
            logInfo("isAccountLinked: \(bResult ? "YES": "NO")")
        }
    }
    
    /// Prepares the model to execute transactions.
    ///
    /// You need to call this function in order to ensure you obtain a valid and active session.
    /// `ProximityReader` validates if the current reader is ready for a transaction. Typically,
    /// when the reader is already ready, `prepare()` returns immediately with success.
    /// A best practice is to have only one active reader and one active session.
    ///
    /// Call this function when the app becomes `.active` from the `.background` state.
    /// Typically, you call this function while observing the app's lifecycle events
    ///(see `SampleReaderApp.swift`).
    override func preparePaymentCardReaderSession() {
        logger.info(#function)
        
        DispatchQueue.main.async {
            self.status = "Preparing"
            self.statusOK = false
        }
        
        let myevents = mtVRCardReader?.getPaymentCardReaderEvents()
        
        Task {
            if let events = myevents {
                debugPrint("<----- Listening PaymentCardReader events ---------->")
                
                for await event in events {
                    debugPrint("-----> Received event: \(event)")
                    // Handle event in the app
                    DispatchQueue.main.async {
                        self.status = "\(event) (Apple)"
                    }
                }
            }
        }
        
        Task {
            guard let reader = self.mtVRCardReader else {
                throw NSError(domain: "ReaderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Reader not available"])
            }
            
            do {
                let fetchTokenTimeStart = getCurrentDispatchTimeAndFormattedUTCString()
                logInfo("+ Fetch Token = \(fetchTokenTimeStart.dateString)")
                
                let token = try await mtVRCardReader?.fetchPaymentCardReaderTokenFromMagensaPSP(self.mtVRConfig)
                
                let fetchTokenTimeEnd = getCurrentDispatchTimeAndFormattedUTCString()
                logInfo("- Fetch Token = \(fetchTokenTimeEnd.dateString)")
                let fetchTokenElapsedTime = calculateElapsedTimeInMS(start: fetchTokenTimeStart.dispatchTime, end: fetchTokenTimeEnd.dispatchTime)
                logInfo("<<<---- FetchToken Time = \(formatDoubleTo3DecDigits(fetchTokenElapsedTime)) ms")
                
                logInfo("+ Prepare = \(fetchTokenTimeEnd.dateString)")
//                _ = try await reader.prepareCardReaderSessionWithToken(token!)
                _ = try await reader.preparePaymentCardReaderSessionWithToken(token!)

                
                let prepareTimeEnd = getCurrentDispatchTimeAndFormattedUTCString()
                logInfo("- Prepare = \(prepareTimeEnd.dateString)")
                
                let prepareElapsedTime = calculateElapsedTimeInMS(start: fetchTokenTimeEnd.dispatchTime, end: prepareTimeEnd.dispatchTime)
                logInfo("<<<---- prepare Time = \(formatDoubleTo3DecDigits(prepareElapsedTime)) ms")
                
                DispatchQueue.main.async {
                    self.isCardReaderSessionActive = true
                    self.status = MTViewModel.msgTTPIsReady
                    self.statusOK = true
                }
            } catch {
                logger.info("catch \(error)")
                await handlePaymentCardReaderError(error, callingFunc: #function)
            }
        }
    }
    
    func preparePaymentCardReaderSessionWithToken() async {
        logger.info(#function)
        
        DispatchQueue.main.async {
            self.status = "Preparing"
            self.statusOK = false
        }
        
        let myevents = mtVRCardReader?.getPaymentCardReaderEvents()
        
        Task {
            if let events = myevents {
                debugPrint("<----- Listening PaymentCardReader events ---------->")
                
                for await event in events {
                    debugPrint("-----> Received event: \(event)")
                    // Handle event in the app
                    DispatchQueue.main.async {
                        self.status = "\(event) (Apple)"
                    }
                }
            }
        }
        
        Task {
            guard let reader = self.mtVRCardReader else {
                throw NSError(domain: "ReaderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Reader not available"])
            }
            
            do {
                debugPrint("self.JWTTokenString = '\(self.jwtTokenString)'")
                
                if self.jwtTokenString.isEmpty {
                    if let tokenString = try await mtVRCardReader?.fetchPaymentCardReaderTokenFromMagensaPSP(mtVRConfig) {
                        self.jwtTokenString = tokenString
                    }
                }
                
                let start = DispatchTime.now()
                
                let isMerchantAccountLinked = try await reader.isMerchantAccountLinked()
                if !isMerchantAccountLinked {
                    logInfo("Token fetch success. Account needs linking.")
                    try await mtVRCardReader?.linkMerchantAccountWithToken(self.jwtTokenString)
                }

                try await reader.preparePaymentCardReaderSessionWithToken(self.jwtTokenString)
                
                let end = DispatchTime.now()
                let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
                let timeInterval = Double(nanoTime) / 1_000_000  // Convert to milliseconds
                
                let executionTime = "Session Prepared: \(timeInterval) ms"
                logInfo(executionTime)
                debugPrint("preparePaymentCardReaderSessionWithToken Time = \(timeInterval) ms")
                
                DispatchQueue.main.async {
                    self.isCardReaderSessionActive = true
                    self.status = MTViewModel.msgTTPIsReady
                    self.statusOK = true
                    self.apiTestStatus = executionTime
                }
            } catch {
                logger.info("catch \(error)")
                await handlePaymentCardReaderError(error, callingFunc: #function)
            }
        }
    }
    
    /// Resets the model and reestablishes the payment reader session.
    /// - Parameter: None
    ///
    override func cleanup() {
        logger.info(#function)
        self.status = "Not Ready"
        self.statusOK = false
        mtVRCardReader = MagTekVirtualCardReader(config: mtVRConfig)
    }
    
    /// Pays the amount you specify.
    ///
    /// An example implementation that demonstrates processing a typical payment transaction.
    ///
    /// - Parameter:
    ///      - amount: A decimal amount that represents a payment the network should process.
    override func pay(_ requestAmount: Decimal) {
        logger.info("Pay Initiated: '\(requestAmount)'")
        
        Task {
            if !self.isCardReaderSessionActive {
                self.readError = .noReaderSession
                await showTransactionResult(requestAmount: requestAmount)
                return
            }
            
            let myevents = mtVRCardReader?.getPaymentCardReaderEvents()
            let readCardStart = getCurrentDispatchTimeAndFormattedUTCString()
            
            Task {
                if let events = myevents {
                    debugPrint("<----- pay::Listening PaymentCardReader events ---------->")
                    
                    for await event in events {
                        debugPrint("---> pay::Received event: \(event)")
                        
                        if event.name == "cardDetected" {
                            let timeInfo = getCurrentDispatchTimeAndFormattedUTCString()
                            let cardDetectedElapsedTime = calculateElapsedTimeInMS(start: readCardStart.dispatchTime, end: timeInfo.dispatchTime)
                            
                            logInfo("--pay::cardDetected: \(timeInfo.dateString)")
                            logInfo("--pay::cardDetected Time: \(cardDetectedElapsedTime) ms")
                        }

                        DispatchQueue.main.async {
                            self.status = "\(event) (Apple)"
                        }
                    }
                }
            }
            
            do {
                var readData: Any?
                let paymentType: PaymentTransactionType = transactionTypePicker == .refund ? PaymentTransactionType.refund : PaymentTransactionType.purchase
                
                logInfo("+ pay.ReadCard:\(readCardStart.dateString)")
                debugPrint("amount = \(requestAmount)")
                readData = try await mtVRCardReader?.readContactlessPaymentCard(for: requestAmount, currencyCode: "USD", transactionType: paymentType)
                
                let readCardEnd = getCurrentDispatchTimeAndFormattedUTCString()
                
                let elapsedTimeSeconds = calculateElapsedTimeInMS(start: readCardStart.dispatchTime, end: readCardEnd.dispatchTime) / 1000
                
                logInfo("- pay.ReadCard:\(readCardEnd.dateString)")
                logInfo ("ReadCard Time = \(elapsedTimeSeconds) seconds")
                
                // Handling of read results for each type of read.
                var transactionId = "<none>"
                
                // Payment Card results
                if let payment = readData as? PaymentCardReadResult {
                    DispatchQueue.main.async {
                        transactionId = payment.id
                    }
                    
                    paymentData = payment
                    logger.info("payment.paymentCardData = \(String(describing: self.paymentData?.paymentCardData))")
                    logger.info("payment.generalCardData = \(String(describing: self.paymentData?.generalCardData))")
                    logger.info("payment.outcome = \(payment.outcome)")
                    
                    if payment.outcome == .success {
                        if let paymentCardDataString = self.paymentData?.paymentCardData,  let generalCardDataString = self.paymentData?.generalCardData {
                            print("paymentCardDataString: '\(paymentCardDataString)'")
                            print("generalCardDataString: '\(generalCardDataString)'")
                            
                            DispatchQueue.main.async {
                                self.isProcessingPayment = true // 3. Start loading spinner
                            }
                            
                            //============================================================
                            // Call Magensa UnigatePSP to process the payment transaction
                            //============================================================
                            let trxStart = getCurrentDispatchTimeAndFormattedUTCString()
                            logInfo("+ pay.ProcessPaymentTransaction: \(trxStart.dateString)")
                            
                            let newTransactionResponse = await ProcessPaymentTransaction(transactionId: transactionId,
                                                                                         transactionType: transactionTypePicker.name,
                                                                                         transactionInputDetails: [],
                                                                                         amount: requestAmount,
                                                                                         paymentCardData: paymentCardDataString,
                                                                                         generalCardData: generalCardDataString)
                            
                            let trxEnd = getCurrentDispatchTimeAndFormattedUTCString()
                            logInfo("+ pay.ProcessPaymentTransaction: \(trxEnd.dateString)")
                            
                            let elapsedTimeSeconds = calculateElapsedTimeInMS(start: trxStart.dispatchTime, end: trxEnd.dispatchTime) / 1000
                            logInfo("pay.ProcessPaymentTransaction Time: \(formatDoubleTo3DecDigits(elapsedTimeSeconds)) seconds")
                            
                            //Calculate total time: DetectCard/ReadCard/ProcessPaymentTransaction
                            let totalElapsedTime = calculateElapsedTimeInMS(start: readCardStart.dispatchTime, end: trxEnd.dispatchTime) / 1000
                            logInfo ("<<<--- pay::T(Read + Trans) Total  Time = \(formatDoubleTo3DecDigits(totalElapsedTime)) seconds --->>")
                            
                            DispatchQueue.main.async {
                                self.isProcessingPayment = false // 3. Start loading spinner
                                
                                guard
                                    let response = newTransactionResponse,
                                    let transactionOutput = response.transactionOutput,
                                    let isTrxApproved = transactionOutput.isTransactionApproved,
                                    let authorizedAmount = transactionOutput.authorizedAmount
                                else {
                                    debugPrint("Missing required fields in response")
                                    return
                                }
                                
                                if isTrxApproved {
                                    if authorizedAmount < requestAmount {
                                        self.currentAuthResult = ("PARTIALLY APPROVED", authorizedAmount, transactionId)
                                        self.status = MTViewModel.msgTTPIsReady
                                        self.statusOK = true
                                    } else {
                                        self.currentAuthResult = ("APPROVED", authorizedAmount, transactionId)
                                        self.status = MTViewModel.msgTTPIsReady
                                        self.statusOK = true
                                    }
                                } else {
                                    self.currentAuthResult = ("DECLINED", 0, transactionId)
                                    self.statusOK = false
                                }
                            }
                        } else {
                            self.currentAuthResult = ("DECLINED", 0, transactionId)
                        }
                    } else {
                        self.currentAuthResult = ("DECLINED (Apple)", 0, transactionId)
                    }
                }
                
                // Update the display.
                await showTransactionResult(requestAmount: requestAmount)
            } catch {
                if let err = error as? PaymentCardReaderSession.ReadError {
                    readError = err
                    handleReadError(err)
                } else {
                    // unexpected error type
                    let error = String(describing: error)
                    logger.info("Unknown and unexpected error returned from PaymentProcessorApi.shared.transaction. Error: \(error).")
                }
                
                // Update the display.
                await showTransactionResult(requestAmount: requestAmount)
            }
        }
    }
    
    override func clearTransactionResult() {
        statusOK = true
        paymentData = nil
        currentAuthResult = nil
        readError = nil
        trxShow = false
        paymentShow = false
        trxResult = ""
        formattedVasResultString = ""
        apiTestStatus = ""
        
        debugPrint("clearTransactionResult:statusOK = \(self.statusOK)")
    }
    
    func reportSessionEvent(_ eventName: String) {
        logger.info("Event: \(eventName)")
    }
    
    func reportURLError(_ error: URLError) -> String {
        let code = error.code
        let description = error.localizedDescription
        let userInfo = error.userInfo
        
        let errorMessage = """
        URLError occurred:
        Code: \(code)
        Description: \(description)
        UserInfo: \(userInfo)
        """
        
        return errorMessage
    }
    
    // MARK: - Error handler functions
    @MainActor
    private func handlePaymentCardReaderError(_ error: Error, callingFunc: String = "") {
        let errorMessage: String
        // 1. Handle specific error types first.  This order is important.
        if let MagTekTTPCardReaderError = error as? MagTekVirtualReaderError {
            errorMessage = MagTekTTPCardReaderError.errorMessage
        } else if let magTekError = error as? MagTekTokenRequestError {
            errorMessage = magTekError.description ?? magTekError.errorMessage
            logError(errorMessage)
        } else if let readerError = error as? PaymentCardReaderError {
            // 2. Handle PaymentCardReaderError cases.
            switch readerError {
            case .accountNotLinked:
                errorMessage = "Your account is not linked. Call linkAccount() or ask user to initiate account setup."
            case .prepareFailed(let reason):
                errorMessage = "Unable to prepare. Reason: \(reason ?? "Unknown.")"
            case .invalidReaderToken(let reason):
                errorMessage = "Invalid reader token. Reason: \(reason ?? "Unknown.")"
            case .osVersionNotSupported:
                errorMessage = "This iOS version is no longer supported. Update your device."
            case .deviceBanned(let date):
                errorMessage = date.map { "Your device is temporarily banned. Try again at \($0.formatted())." }
                ?? "Your device is temporarily banned. Try again later and if this error persists contact support."
            case .notReady:
                errorMessage = "Reader not ready."
            case .readerBusy:
                errorMessage = "Your reader is busy. Try again in a few minutes."
            case .prepareExpired:
                errorMessage = "The session expired, call prepare again. (This is deprecated in iOS 16 and later)."
            case .accountAlreadyLinked:
                errorMessage = "Account is already linked, proceed with preparing the reader."
            case .accountLinkingFailed, .accountLinkingCancelled:
                errorMessage = "Account linking not completed."
            case .tokenExpired:
                errorMessage = "Your reader token expired. Fetch a new token from your PSP."
            case .unsupported:
                errorMessage = "There's a problem with your device, most likely permanent. Contact support."
            case .notAllowed:
                errorMessage = "Your app is not allowed to use this API. Check your entitlement."
            case .backgroundRequestNotAllowed:
                errorMessage = "Calling API from background isn't allowed."
            default:
                errorMessage = "\(readerError.errorName)"
            }
        } else {
            // 3. Handle unexpected errors.  This should be last.
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
        
        // 4.  Consolidate logging and state updates. Do this *once*.
        logger.error(errorMessage)
        status = errorMessage
        info = status
        statusOK = false
        clearTransactionResult()
    }
    
    /// Handle read errors.
    ///
    /// This function demonstrates handing of possible read errors and describes typical causes and solutions.
    ///
    /// Parameter:
    ///  - err: A `PaymentCardReaderSession.ReadError` value.
    ///
    func handleReadError(_ err: PaymentCardReaderSession.ReadError) {
        logger.error(err.errorName)
        
        switch err {
        case .readerTokenExpired:
            // You should fetch a new token from PSP and perform `readPaymentCard`
            // with current transaction request to seamlessly allow current transaction to go through.
            logger.info("\(err.errorName)")
            logger.error("The payment card reader token has expired.")
        case .noReaderSession:
            // There's no active session. Most likely the app hasn't called
            // `prepare()` upon returning from background; call `prepare()` to fix this issue.
            logger.info("\(err.errorName)")
            logger.error("There's no active session.")
        case .readNotAllowed:
            /// Your app isn't allowed to call `read()` API. Check the app's entitlements.
            logger.info("\(err.errorName)")
            logger.error("The app isn't allowed to call read payment card.")
        case .readNotAllowedDuringCall:
            /// The framework doesn't allow the read operations while voice calls are in progress.
            logger.info("\(err.errorName)")
            logger.error("The framework doesn't allow the read operations while voice calls are in progress.")
        default:
            logger.info("\(err.errorName)")
        }
    }
    
    // MARK: - Update display functions
    
    @MainActor private func showTransactionResult(requestAmount: Decimal) {
        var authStatus = ""
        var paymentShow = false
        var trxStatus = ""
        var trxResult = "Unexpected result"
        var errorThrown = false
        
        if let err = readError {
            trxStatus = "❌: \(err.errorName)"
            trxResult = "Transaction not completed\n\n\(err.errorDescription)"
            errorThrown = true
            
            let logInfo = "Transaction Status: \(trxStatus), \nTransaction Result: \(trxResult)"
            logger.error(logInfo)
        } else {
            if let authResult = currentAuthResult {
                if authResult.status == "APPROVED" {
                    authStatus = "APPROVED ✅"
                } else if authResult.status == "PARTIALLY APPROVED" {
                    authStatus = "PARTIALLY APPROVED ℹ️"
                } else {
                    authStatus = "DECLINED 🛑"
                }
                
                let athorizedAmount = self.formatTo9DigitsMax2Decimals(authResult.amount)
                let requestAmount = self.formatTo9DigitsMax2Decimals(requestAmount)

                trxResult =
                    """
                    Requested Amount: $\(requestAmount)
                    Authorized Amount: $\(athorizedAmount)
                    Trans #: \(authResult.transactionId)
                    """
                
                paymentShow = true
                
                let logInfo = "Authorization Status: \(authStatus), \nTransaction Result: \(trxResult)"
                logger.info(logInfo)
            }
        }
        
        if errorThrown {
            self.trxStatus = trxStatus
        } else {
            if authStatus.isEmpty {
                self.trxStatus = "❌ Unknown Error."
            } else {
                self.trxStatus = "\(authStatus)"
            }
        }
        
        self.paymentShow = paymentShow
        self.trxResult = trxResult
        self.trxShow = true
        
        debugPrint("self.statusOK = \(self.statusOK)")
    }
    
    private func reset() {
        cleanup()
        statusOK = false
        status = "Not Ready"
        logger.info("reset")
    }
    
    private func formattedAmount(_ amount: Decimal) -> String? {
        let formatter = NumberFormatter()
        formatter.generatesDecimalNumbers = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber)
    }
    
    func formatTo9DigitsMax2Decimals(_ number: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.maximumIntegerDigits = 9
        
        return formatter.string(for: number) ?? "Invalid"
    }
    
    //
    // Call UniGate Payment Gateway
    //
    func ProcessPaymentTransaction(transactionId: String,
                                   transactionType: String,
                                   transactionInputDetails: [PPGTransactionInputDetail]?,
                                   amount: Decimal,
                                   paymentCardData: String,
                                   generalCardData: String) async -> MTNewTransactionResponse? {
        
        let UnigateClient = await PaymentGatewayServiceAPI(userName: mtVRConfig.userName, password:mtVRConfig.password)
        
        do {
            logger.info("Initiating Magensa API call...")
            
            let selectedPaymentProcessor = paymentProcessorPicker.name
            logger.info("selectedPaymentProcessor = \(selectedPaymentProcessor)")
            
            let paymentRequest = MTPaymentRequest(transactionID: UUID().uuidString,
                                                 transactionType: transactionType,
                                                 transactionDetails: transactionInputDetails,
                                                 amount: amount,
                                                 processorName: selectedPaymentProcessor,
                                                 paymentCardData: paymentCardData,
                                                 generalCardData: generalCardData)
            let response = try await UnigateClient.newPaymentRequest(model: paymentRequest)
            
            logger.info("Magensa API call finished successfully!")
            
            return response
        } catch {
            // Catch any other unexpected errors that are not `MagensaAPIError`.
            let errorMessage = "An unexpected system error occurred: \(error.localizedDescription)"
            
            DispatchQueue.main.async {
                self.logger.info("\(errorMessage)")
                self.status = "❌ Authorization Failed!"
                self.statusOK = false
            }
            logger.info(errorMessage)
            return nil
        }
    }
}
