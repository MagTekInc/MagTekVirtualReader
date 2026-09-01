//
//  Created on 6/24/26.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//
//  Apple's Store and Forward API is iOS 18.4+, so the whole class is
//  @available(iOS 18.4, *)
//

import Foundation
import ProximityReader
import MagTekVirtualReader

enum MTSAFTesterError: Error, LocalizedError {
    case readerUnavailable
    case emptyDeleteToken
    case noActivePayment
    case batchEmpty
    case missingIntermediateCertificate
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .readerUnavailable:
            return "PaymentCardReader is unavailable. Run the online prepare flow on the main screen first."
        case .emptyDeleteToken:
            return "Delete-token response had empty storeAndForwardToken."
        case .noActivePayment:
            return "No active payment in the cached batch."
        case .batchEmpty:
            return "Fetched batch was empty."
        case .missingIntermediateCertificate:
            return "Batch is missing an intermediate certificate."
        case .networkUnavailable:
            return "Network unavailable. Connect to the internet and try again."
        }
    }
}

struct ForwardDeleteOutcome {
    let customerTransactionID: String
    let storeAndForwardToken: String
    let remainingAfterResolve: Int
    let countAfter: Int
    let countAfterMatchesRemaining: Bool
}

@MainActor
final class MTStoreAndForwardTester: ObservableObject {

    // MARK: - Dependencies

    private let mtReader: MagTekVirtualCardReader
    private var baseConfig: MagTekVRConfig
    private let baseURL: String

    // MARK: - Active capture session

    private var pendingCaptureSession: StoreAndForwardPaymentCardReaderSession?

    // MARK: - Lazy store

    private var cachedStore: PaymentCardReaderStore?

    // MARK: - Cached batch for retry-safe partial-failure handling
    /// When non-nil, the next forwardAndDeleteNext()
    /// skips the fetch and resumes against this batch.

    private var currentBatch: StoreAndForwardBatch?
    private var currentPayment: StoreAndForwardBatch.StoredPaymentCardReadResult?
    private var currentCustomerTransactionID: String?

    // MARK: - Published state for the view

    @Published var storedCount = 0
    @Published var lastLog = ""
    @Published var isCapturing = false
    @Published var isProcessingNext = false

    /// Read-only from the view (the Reset Batch State disabled-state reads it
    /// as `tester.lastSuccessfulForward`).
    ///
    /// Lifecycle (the disabled-state guard idepends on these three transitions
    /// being honored):
    ///   • set true immediately after transactionOutput.isTransactionApproved == true
    ///   • set false after resolveBatch returns successfully (along with clearing the
    ///     cached batch state)
    ///   • set false at the end of resetBatchStateExplicit() so the button does not
    ///     remain permanently disabled after a successful reset
    @Published private(set) var lastSuccessfulForward = false

    // MARK: - Init

    init(mtReader: MagTekVirtualCardReader, config: MagTekVRConfig, baseURL: String) {
        self.mtReader = mtReader
        self.baseConfig = config
        self.baseURL = baseURL
    }

    // MARK: - Reader/store helpers

    /// Resolves the active reader. Apple does not document multi-instance safety for
    /// PaymentCardReader and the SDK already owns one — prefer the existing instance.
    private func activeReader() throws -> PaymentCardReader {
        guard let reader = mtReader.paymentCardReader else {
            throw MTSAFTesterError.readerUnavailable
        }
        return reader
    }

    /// Fresh store accessor (Apple's API is sync-throwing, not async).
    private func store() throws -> PaymentCardReaderStore {
        /// Do NOT cache: Apple appears to snapshot state per instance, so re-fetch
        /// every time to ensure counts reflect newly captured transactions.
        return try activeReader().fetchPaymentCardReaderStore()
    }

    // MARK: - Public surface

    var magTekVirtualCardReader: MagTekVirtualCardReader {
        mtReader
    }

    func refreshCount() async throws {
        let count = try await mtReader.numberOfStoredTransaction()
        storedCount = count
        appendLog("storedCount = \(count)")
    }

    /// Variant that uses the SDK-provided Store & Forward helpers:
    ///  - fetchNextStoreAndForwardBatch()
    ///  - fetchStoreAndForwardDeletionToken(batchID:customerTransactionID:)
    ///  - completeStoreAndForwardBatch(deleteToken:)
    /// This is the closest SDK analog to `forwardAndDeleteNext`.
    func forwardAndDeleteNextViaSDK(
        amount: Decimal,
        processorName: String,
        transactionType: String,
        useEMVSAFToken: Bool = true
    ) async throws -> ForwardDeleteOutcome? {

        isProcessingNext = true
        defer { isProcessingNext = false }

        return try await forwardAndDeleteNextItem(
            amount: amount,
            processorName: processorName,
            transactionType: transactionType,
            useEMVSAFToken: useEMVSAFToken
        )
    }

    /// Single-item flow without the `isProcessingNext` bookkeeping, so the bulk loop can
    /// call it repeatedly while the UI stays disabled for the whole run.
    private func forwardAndDeleteNextItem(
        amount: Decimal,
        processorName: String,
        transactionType: String,
        useEMVSAFToken: Bool
    ) async throws -> ForwardDeleteOutcome? {

        appendLog("---- forwardAndDeleteNextViaSDK ----")

        /// Fetch the next batch via SDK helper.
        guard let batch = try await mtReader.fetchNextStoreAndForwardBatch() else {
            appendLog("no batch on Secure Element")
            try? await refreshCount()
            return nil
        }
        guard let payment = batch.payments.first else {
            appendLog("batch contained no payments")
            try? await mtReader.failStoreAndForwardBatch()
            try? await refreshCount()
            return nil
        }

        let batchID = batch.id
        let customerTxIDForRequest = normalizedCustomerTransactionID(payment.id)
        appendLog("customerTransactionID = \(customerTxIDForRequest); batchID=\(batchID)")

        /// Forward to Magensa.
        appendLog("forwarding to Magensa (SDK helper path)")
        let forwardResp: MTSAFForwardResponse
        do {
            forwardResp = try await forward(
                stored: payment,
                amount: amount,
                processorName: processorName,
                transactionType: transactionType,
                customerTransactionID: customerTxIDForRequest,
                batch: batch
            )
        } catch {
            appendLog("forward FAILED (SDK path) — \(error.localizedDescription)", isError: true)
            logRichError("forward.SDK", error)
            appendLog("batch retained; do NOT reset")
            throw error
        }
        /// Magensa answers HTTP 200 even when the processor declines or rejects the
        /// transaction, so `isTransactionApproved` is the only gate that keeps an
        /// unpaid record from being deleted off the Secure Element.
        guard forwardResp.isApproved else {
            let notApproved = MTSAFNetworkError.forwardNotApproved(
                customerTransactionID: customerTxIDForRequest,
                body: forwardResp.notApprovedSummary
            )
            appendLog("forward NOT APPROVED — \(forwardResp.notApprovedSummary)", isError: true)
            logRichError("forward.SDK.notApproved", notApproved)
            appendLog("batch retained; item NOT deleted from Secure Element", isError: true)
            throw notApproved
        }
        lastSuccessfulForward = true
        appendLog("approved (transactionID=\(forwardResp.transactionOutput?.transactionID ?? "<nil>"))")
        
        var deleteTokenstring: String?
        if useEMVSAFToken {
            // Store and forward token token used to delete stored data from secure enclave
            // will be obtained from Magense response for EMV transaction.
            appendLog("fetchStoreAndForwardDeletionToken")
            guard let deleteToken = forwardResp.appleTap2PaySafToken,
                  !deleteToken.isEmpty else {
                appendLog("deletion token FAILED — missing AppleTap2PaySaFToken", isError: true)
                logRichError("fetchStoreAndForwardDeletionToken.ForwardResponse", MTSAFNetworkError.emptyDeleteToken)
                appendLog("batch retained.")
                throw MTSAFNetworkError.emptyDeleteToken
            }
            appendLog("got deletion token (len=\(deleteToken.count))")
            deleteTokenstring = deleteToken
        } else {
            // Store and forward token token used to delete stored data from secure enclave
            // will be obtained additional API call from SDK.
            appendLog("fetchStoreAndForwardDeletionToken")
            let deleteToken: String
            do {
                deleteToken = try await mtReader.fetchStoreAndForwardDeletionToken(
                    batchID: batchID,
                    customerTransactionID: customerTxIDForRequest
                )
            } catch {
                appendLog("deletion token FAILED — \(error.localizedDescription)", isError: true)
                logRichError("fetchStoreAndForwardDeletionToken.SDK", error)
                appendLog("batch retained.")
                throw error
            }
            appendLog("got deletion token (len=\(deleteToken.count))")
            deleteTokenstring = deleteToken
        }

        guard let deleteToken = deleteTokenstring else {
            throw MTSAFTesterError.emptyDeleteToken
        }

        /// Complete (delete) the batch via SDK helper.
        appendLog("completeStoreAndForwardBatch")
        let remaining: Int
        do {
            remaining = try await mtReader.completeStoreAndForwardBatch(deleteToken: deleteToken)
        } catch {
            appendLog("complete FAILED — \(error.localizedDescription)", isError: true)
            logRichError("completeStoreAndForwardBatch.SDK", error)
            appendLog("batch retained; retry only (do NOT re-forward).")
            throw error
        }
        appendLog("remaining after complete = \(remaining)")

        /// Success — clear guard and refresh count.
        lastSuccessfulForward = false
        try? await refreshCount()
        let countAfter = storedCount
        let matches = (countAfter == remaining)
        if matches {
            appendLog("countAfter=\(countAfter) matches remaining=\(remaining)")
        } else {
            appendLog("MISMATCH countAfter=\(countAfter) remaining=\(remaining) — surface to back-end team",
                      isError: true)
        }

        return ForwardDeleteOutcome(
            customerTransactionID: customerTxIDForRequest,
            storeAndForwardToken: deleteToken,
            remainingAfterResolve: remaining,
            countAfter: countAfter,
            countAfterMatchesRemaining: matches
        )
    }
    
    /// Deletes the next stored item using SDK helpers only (no forward).
    /// Returns remaining count after deletion, or nil if nothing to delete.
    func deleteNextStoredItemViaSDK() async throws -> Int? {
        isProcessingNext = true
        defer { isProcessingNext = false }
        
        appendLog("---- DEL: deleteNextStoredItemViaSDK ----")
        
        /// Fetch next batch
        guard let batch = try await mtReader.fetchNextStoreAndForwardBatch() else {
            appendLog("DEL: no batch on Secure Element")
            try? await refreshCount()
            return nil
        }
        guard let payment = batch.payments.first else {
            appendLog("DEL: batch contained no payments")
            try? await mtReader.failStoreAndForwardBatch()
            try? await refreshCount()
            return nil
        }
        
        let batchID = batch.id
        let customerTxID = payment.id
        appendLog("DEL: batchID=\(batchID) payment.id=\(customerTxID)")
        
        /// Fetch deletion token
        let deleteToken: String
        do {
            deleteToken = try await mtReader.fetchStoreAndForwardDeletionToken(
                batchID: batchID,
                customerTransactionID: customerTxID
            )
        } catch {
            appendLog("DEL: fetch delete token failed — \(error.localizedDescription)", isError: true)
            logRichError("DEL.fetchStoreAndForwardDeletionToken.SDK", error)
            appendLog("DEL: batch retained")
            throw error
        }
        appendLog("DEL: got deletion token (len=\(deleteToken.count))")
        
        /// Complete (delete)
        let remaining: Int
        do {
            remaining = try await mtReader.completeStoreAndForwardBatch(deleteToken: deleteToken)
        } catch {
            appendLog("DEL: complete failed — \(error.localizedDescription)", isError: true)
            logRichError("DEL.completeStoreAndForwardBatch.SDK", error)
            appendLog("DEL: batch retained")
            throw error
        }
        appendLog("DEL: remaining after delete = \(remaining)")
        
        try? await refreshCount()
        return remaining
    }

    // MARK: - Bulk SDK helpers (fetch/delete all)

    private func normalizedCustomerTransactionID(_ storedID: String) -> String {
        let trimmed = storedID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let uuid = UUID(uuidString: trimmed) {
            return uuid.uuidString.uppercased()
        }
        return trimmed
    }

    // MARK: - Network helpers (MTAPIEndpoint)

    private func createPaymentRequest(
        stored: StoreAndForwardBatch.StoredPaymentCardReadResult,
        batch: StoreAndForwardBatch
    ) throws -> String {
        guard let firstIntermediateCertificate = batch.intermediateCertificate.first else {
            throw MTSAFTesterError.missingIntermediateCertificate
        }

        let request = PaymentRequest(
            id: batch.id,
            count: 1,
            intermediateCertificate: [firstIntermediateCertificate],
            leafCertificate: batch.leafCertificate,
            signature: batch.signature,
            payments: [
                PaymentRequest.Payment(
                    id: stored.id,
                    generalCardData: stored.generalCardData,
                    paymentCardData: stored.paymentCardData,
                    signature: stored.signature
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(request)
        return data.base64EncodedString()
    }

    private func forward(
        stored: StoreAndForwardBatch.StoredPaymentCardReadResult,
        amount: Decimal,
        processorName: String,
        transactionType: String,
        customerTransactionID: String,
        batch: StoreAndForwardBatch
    ) async throws -> MTSAFForwardResponse {
        let data = try createPaymentRequest(stored: stored, batch: batch)

        let body = MTSAFForwardRequest(
            transactionInput: .init(
                processorName: processorName,
                transactionInputDetails: [],
                transactionType: transactionType,
                amount: amount
            ),
            dataInput: .init(
                tlvList: "",
                encryptedData: .init(
                    keyVariant: "Embedded",
                    dataType: "AppleTapToPay",
                    data: data,
                    ksn: nil
                ),
                paymentMode: "EMV"
            ),
            customerTransactionID: customerTransactionID,
            additionalRequestData: []
        )

        let endpoint = MTAPIEndpoint.postProcessApplePayment(
            baseURL: baseURL,
            body: body,
            username: baseConfig.userName,
            password: baseConfig.password
        )

        return try await MTNetworkManager.shared.request(from: endpoint)
    }

    func fetchAllStorePaymentCardReaderResultBatch() async throws {
        isProcessingNext = true
        defer { isProcessingNext = false }

        appendLog("---- ALL: fetchAllStorePaymentCardReaderResultBatch ----")
        do {
            let result = try await mtReader.fetchAllStorePaymentCardReaderResultBatch()
            appendLog("ALL: fetchAll returned \(String(describing: result))")
        } catch {
            appendLog("ALL: fetchAll failed — \(error.localizedDescription)", isError: true)
            logRichError("ALL.fetchAllStorePaymentCardReaderResultBatch", error)
            throw error
        }
        try? await refreshCount()
    }

    /// Forwards and deletes every stored item by repeating the single-transaction flow —
    /// Magensa has no batch endpoint, so items go up one at a time.
    ///
    /// Stops and rethrows on the first error. Apple only exposes the next stored item once
    /// the current one has been deleted, so the failing item must stay in the Secure Element
    /// for a later retry rather than be skipped.
    ///
    /// Returns the number of items forwarded and deleted.
    func forwardAndDeleteAllViaSDK(
        amount: Decimal,
        processorName: String,
        transactionType: String,
        useEMVSAFToken: Bool = true
    ) async throws -> Int {
        isProcessingNext = true
        defer { isProcessingNext = false }

        appendLog("---- ALL: forwardAndDeleteAllViaSDK ----")

        var processed = 0
        while true {
            do {
                guard try await forwardAndDeleteNextItem(
                    amount: amount,
                    processorName: processorName,
                    transactionType: transactionType,
                    useEMVSAFToken: useEMVSAFToken
                ) != nil else { break }
            } catch where Self.isStoreAndForwardResultsNotFound(error) {
                /// Apple reports "no stored results" rather than returning nil once the
                /// Secure Element has been drained — that is the normal end of the run.
                appendLog("ALL: Secure Element is empty — done")
                break
            } catch {
                appendLog("ALL: stopped after \(processed) item(s) — \(error.localizedDescription)",
                          isError: true)
                throw error
            }
            processed += 1
        }

        appendLog("ALL: processed \(processed) item(s)")
        return processed
    }

    func deleteAllStorePaymentCardReaderResultBatch() async throws {
        isProcessingNext = true
        defer { isProcessingNext = false }

        appendLog("---- ALL: deleteAllStorePaymentCardReaderResultBatch ----")
        do {
            let fetchResult = try await mtReader.fetchAllStorePaymentCardReaderResultBatch()
            appendLog("ALL: fetchAll returned \(String(describing: fetchResult))")

            if let fetchResult {
                let deleteResult = try await mtReader.deleteAllStorePaymentCardReaderResultBatch(fetchResult)
                appendLog("ALL: deleteAll returned \(String(describing: deleteResult))")
            } else {
                appendLog("ALL: deleteAll returned nil (no fetchResult)")
            }
        } catch {
            try? await mtReader.failStoreAndForwardBatch()
            appendLog("ALL: deleteAll failed — \(error.localizedDescription)", isError: true)
            logRichError("ALL.deleteAllStorePaymentCardReaderResultBatch", error)
            throw error
        }
        try? await refreshCount()
    }

    /// Debug-only escape hatch — the only path to `resetBatchState()`.
    /// Caller MUST present the duplicate-charge-risk dialog and
    /// require explicit user confirmation before invoking this method.
    ///
    /// Idempotent semantics: if Apple reports "no batch to reset" (a separate
    /// StoreError case from `storeAndForwardBatchAlreadyExists`), we treat that
    /// as a successful no-op rather than throwing. The local cached batch state
    /// is cleared regardless of whether Apple had anything to reset, since
    /// observing "no batch on the SE side" means our local cache is stale.
    func resetBatchStateExplicit() async throws {
        appendLog("RESET: resetBatchStateExplicit invoked")

        do {
            try await store().resetBatchState()
            appendLog("RESET: Apple's resetBatchState() returned success")
        } catch {
            let caseName = Self.storeErrorCaseName(from: error)
            /// "Nothing to reset" cases — Apple's API throws even when the
            /// operation is logically a no-op. Don't propagate these as errors.
            let benignNoOpCases: Set<String> = [
                "storeAndForwardBatchNotFound",
                "storeAndForwardResultsNotFound"
            ]
            if benignNoOpCases.contains(caseName) {
                appendLog("RESET: nothing to reset (Apple reported \(caseName)) — treating as no-op success")
            } else {
                logRichError("RESET.resetBatchState", error)
                /// Still clear local cache before re-throwing; the local state
                /// is no longer trustworthy after a reset attempt either way.
                currentBatch = nil
                currentPayment = nil
                currentCustomerTransactionID = nil
                lastSuccessfulForward = false
                throw error
            }
        }

        /// Clear local cache regardless of whether Apple had a batch.
        currentBatch = nil
        currentPayment = nil
        currentCustomerTransactionID = nil
        lastSuccessfulForward = false
        try? await refreshCount()
        appendLog("RESET: complete")
    }

    // MARK: - Logging

    /// Records a network-unavailable failure for a Process Stored Items action.
    func reportNetworkUnavailable(for action: String) {
        appendLog("---- \(action) ----", isError: true)
        appendLog("network unavailable — \(action) requires network connectivity", isError: true)
        logRichError(action, MTSAFTesterError.networkUnavailable)
    }

    private func appendLog(_ line: String, isError: Bool = false) {
        let stamped = "[\(Self.shortStamp())] \(line)"
        lastLog.append(stamped + "\n")
        let prefixed = "[SAF] " + line
        /// Print to stdout so the line shows up in Xcode's debug console — easy to copy/paste.
        print(prefixed)
//        if isError {
//            MTLogManager.shared.error(prefixed)
//        } else {
//            MTLogManager.shared.info(prefixed)
//        }
    }

    /// Dumps every piece of information we can extract from an error: Swift type,
    /// localized description, NSError bridge fields, underlying error chain, and
    /// `PaymentCardReaderError.errorName` if applicable. All lines are tagged with
    /// `label` so multiple calls in one run stay distinguishable.
    private func logRichError(_ label: String, _ error: Error) {
        appendLog("---- \(label) ERROR DUMP ----", isError: true)
        appendLog("\(label): swift type = \(type(of: error))", isError: true)
        appendLog("\(label): localizedDescription = \(error.localizedDescription)", isError: true)

        let ns = error as NSError
        appendLog("\(label): nsError.domain = \(ns.domain)", isError: true)
        appendLog("\(label): nsError.code = \(ns.code)", isError: true)
        if let reason = ns.localizedFailureReason {
            appendLog("\(label): nsError.localizedFailureReason = \(reason)", isError: true)
        }
        if let recovery = ns.localizedRecoverySuggestion {
            appendLog("\(label): nsError.localizedRecoverySuggestion = \(recovery)", isError: true)
        }
        for (key, value) in ns.userInfo {
            /// Skip the underlying-error key here; we expand it below.
            if key == NSUnderlyingErrorKey { continue }
            appendLog("\(label): nsError.userInfo[\(key)] = \(value)", isError: true)
        }

        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            appendLog("\(label): underlying.swift type = \(type(of: underlying))", isError: true)
            appendLog("\(label): underlying.domain = \(underlying.domain)", isError: true)
            appendLog("\(label): underlying.code = \(underlying.code)", isError: true)
            appendLog("\(label): underlying.localizedDescription = \(underlying.localizedDescription)", isError: true)
            if let reason = underlying.localizedFailureReason {
                appendLog("\(label): underlying.localizedFailureReason = \(reason)", isError: true)
            }
            for (key, value) in underlying.userInfo {
                appendLog("\(label): underlying.userInfo[\(key)] = \(value)", isError: true)
            }
        }

        if let readerError = error as? PaymentCardReaderError {
            appendLog("\(label): PaymentCardReaderError.errorName = \(readerError.errorName)", isError: true)

            /// Cases that carry an associated value — extract it explicitly. The
            /// bridged NSError above hides these, but Apple's docs say the inner
            /// String/Date is the actual diagnostic detail.
            switch readerError {
            case .prepareFailed(let reason):
                appendLog("\(label): prepareFailed reason = \(reason ?? "<nil>")", isError: true)
            case .invalidReaderToken(let reason):
                appendLog("\(label): invalidReaderToken reason = \(reason ?? "<nil>")", isError: true)
            case .deviceBanned(let date):
                let dateStr = date.map { "\($0)" } ?? "<nil>"
                appendLog("\(label): deviceBanned untilDate = \(dateStr)", isError: true)
            default:
                break
            }
        }

        if let readError = error as? PaymentCardReaderSession.ReadError {
            appendLog("\(label): PaymentCardReaderSession.ReadError.errorName = \(readError.errorName)", isError: true)
        }

        /// PaymentCardReaderStore.StoreError isn't necessarily castable as a known
        /// type at compile time on lower SDK versions, but its case name is still
        /// recoverable via reflection.
        let storeCaseName = Self.storeErrorCaseName(from: error)
        if !storeCaseName.isEmpty
            && (error as NSError).domain.contains("StoreError") {
            appendLog("\(label): StoreError case (via reflection) = \(storeCaseName)", isError: true)
        }

        appendLog("---- end \(label) ERROR DUMP ----", isError: true)
    }

    private static func shortStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    private static func iosVersionString() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// Extracts the textual case name from any Swift enum error using reflection.
    /// Returns "" if the input isn't enum-shaped. We use this to match against
    /// `PaymentCardReaderStore.StoreError` cases (e.g. `storeAndForwardBatchAlreadyExists`)
    /// without binding to specific enum case identifiers — those can shift across
    /// iOS SDK versions and we want to compile against the lowest supported SDK.
    static func storeErrorCaseName(from error: Error) -> String {
        // NSError-bridged Swift errors have `_domain` ending in the type name, but
        // that's harder to parse. The case name is the most useful here.
        let mirror = Mirror(reflecting: error)
        if let label = mirror.children.first?.label {
            // Enum case with associated value: Mirror gives "caseName" as the label.
            return label
        }
        // Enum case without associated value: String(describing:) gives the bare case name.
        let desc = String(describing: error)
        // Strip parameter list if present, e.g. "storeError(reason: \"...\")" -> "storeError"
        if let paren = desc.firstIndex(of: "(") {
            return String(desc[..<paren])
        }
        return desc
    }

    static func isStoreAndForwardBatchAlreadyExists(_ error: Error) -> Bool {
        storeErrorCaseName(from: error) == "storeAndForwardBatchAlreadyExists"
    }

    static func isStoreAndForwardResultsNotFound(_ error: Error) -> Bool {
        storeErrorCaseName(from: error) == "storeAndForwardResultsNotFound"
    }

    static func isForwardNotApproved(_ error: Error) -> Bool {
        guard let networkError = error as? MTSAFNetworkError else { return false }
        if case .forwardNotApproved = networkError { return true }
        return false
    }
}
