//
//  Created on 6/24/26.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import SwiftUI
import UIKit
import ProximityReader

struct MTStoreAndForwardTestView: View {
    @ObservedObject var viewModel: MTViewModel
    @StateObject private var tester: MTStoreAndForwardTester
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false
    @State private var showResetSuggestion = false
    @State private var alertMessage: String?
    @State private var showDeleteNextMessage = false
    @State private var deleteNextMessage = ""
    @State private var resetSuggestionMessage = ""
    @State private var lastOutcome: ForwardDeleteOutcome?

    init(viewModel: MTViewModel, tester: MTStoreAndForwardTester) {
        self.viewModel = viewModel
        _tester = StateObject(wrappedValue: tester)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $viewModel.forceOfflineMode) {
                        Label("Enable Offline", systemImage: "wifi.slash")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .toggleStyle(.switch)
                    
                    HStack(alignment: .top) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Transaction Token")
                                    .font(.headline)
                                Text("After transaction completed, use token from response to delete processed card data.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } icon: {
                            Image(systemName: "key")
                        }
                        
                        Toggle("Use Transaction Token", isOn: $viewModel.useEMVSAFTOKEN)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    
                    HStack {
                        Label("Stored Items: \(tester.storedCount)", systemImage: "tray.full")
                            .font(.headline)
                        Spacer()
                        Button {
                            Task { await refreshCountSafely() }
                        } label: {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.title3)
                        }
                    }
                }
                
                Section("Token Expiration") {
                        HStack {
                            Label("\(tokenExpireTime())", systemImage: "clock")
                                .font(.headline)
                            Spacer()
                        }
                        
                        HStack {
                            Label("\(tokenRemainingTime()) (remaining)", systemImage: "clock")
                                .font(.headline)
                            Spacer()
                        }
                }

                Section("Process Stored Items") {
                    Button {
                        Task { await forwardTappedViaSDK() }
                    } label: {
                        Label("Fetch & Delete Next Item", systemImage: "paperplane.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(tester.isProcessingNext || tester.isCapturing)

                    Button(role: .destructive) {
                        Task { await deleteNextTapped() }
                    } label: {
                        Label("Delete Next Item", systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(tester.isProcessingNext || tester.isCapturing)
                    .alert("Delete Next Item", isPresented: $showDeleteNextMessage) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text(deleteNextMessage)
                    }
                    
                    Button {
                        Task { await fetchAndDeleteAllViaSDK() }
                    } label: {
                        Label("Fetch & Delete All Items", systemImage: "paperplane.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(tester.isProcessingNext || tester.isCapturing)
                    
                    
                    Button(role: .destructive) {
                        Task { await deleteAllViaSDK() }
                    } label: {
                        Label("Delete All Items", systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(tester.isProcessingNext || tester.isCapturing)

                    if let outcome = lastOutcome {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last outcome").font(.caption).foregroundStyle(.secondary)
                            Text("customerTxID: \(outcome.customerTransactionID)")
                                .font(.system(size: 11, design: .monospaced))
                                .lineLimit(1).truncationMode(.middle)
                            Text("storeAndForwardToken len: \(outcome.storeAndForwardToken.count)")
                                .font(.system(size: 11, design: .monospaced))
                            Text("remainingAfterResolve: \(outcome.remainingAfterResolve)")
                                .font(.system(size: 11, design: .monospaced))
                            Text("countAfter: \(outcome.countAfter) (matches: \(outcome.countAfterMatchesRemaining ? "✅" : "❌"))")
                                .font(.system(size: 11, design: .monospaced))
                        }
                    }
                }

                Section("Recovery") {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset Batch State", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(
                        tester.isProcessingNext
                        || tester.isCapturing
                        || tester.lastSuccessfulForward
                    )

                    if tester.lastSuccessfulForward {
                        Text("Reset is disabled because the current batch has been forwarded to Magensa but not yet resolved. Complete the resolve (Forward & Delete Next will retry) before resetting.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    ScrollView {
                        Text(tester.lastLog.isEmpty ? "(empty)" : tester.lastLog)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 180, maxHeight: 320)
                } header: {
                    HStack {
                        Text("Log")
                        Spacer()
                        Button("Clear") {
                            tester.lastLog = ""
                        }
                        .font(.caption)
                        .disabled(tester.lastLog.isEmpty)
                    }
                }
            }
            .navigationTitle("Offline Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await refreshCountSafely()
            }
            .confirmationDialog(
                "Reset Batch State",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    Task { await resetTapped() }
                }
            } message: {
                Text(
                    "DUPLICATE-CHARGE RISK. Reset Batch State unlocks current Secure Element batch so the next \"Forward & Delete Next\" will fetch the SAME record again. " +
                    "If you have ALREADY successfully forwarded this batch to Magensa earlier in this run, " +
                    "tapping Reset and then Forward will send the same payment a second time — the cardholder may be charged twice. " +
                    "Use this ONLY when a fetch is failing with storeAndForwardBatchAlreadyExists AND you have NOT yet successfully forwarded the current batch."
                )
            }
            .alert("Error", isPresented: .init(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
            .alert("Batch Already Exists", isPresented: $showResetSuggestion) {
                if tester.lastSuccessfulForward {
                    Button("OK", role: .cancel) { }
                } else {
                    Button("Reset", role: .destructive) {
                        Task { await resetTapped() }
                    }
                    Button("Cancel", role: .cancel) { }
                }
            } message: {
                Text(resetSuggestionMessage)
            }
        }
    }

    // MARK: - Actions

    /// Process Stored Items actions require Magensa/network access.
    /// Returns `false` after logging when the device is offline.
    private func ensureNetworkAvailable(for action: String) -> Bool {
        guard viewModel.isNetworkAvailable else {
            tester.reportNetworkUnavailable(for: action)
            alertMessage = MTSAFTesterError.networkUnavailable.localizedDescription
            return false
        }
        return true
    }

    private func refreshCountSafely() async {
        do {
            try await tester.refreshCount()
        } catch {
            alertMessage = "refreshCount failed: \(describe(error))\n\nSee the Log section below and Xcode console for full diagnostic dump."
        }
    }

    private func forwardTappedViaSDK() async {
        guard ensureNetworkAvailable(for: "forwardAndDeleteNextViaSDK") else { return }
        guard tester.storedCount > 0 else {
            alertMessage = "Secure Element is empty."
            return
        }
        
        do {
            let outcome = try await tester.forwardAndDeleteNextViaSDK(
                amount: viewModel.amountDecimal,
                processorName: viewModel.paymentProcessorPicker.name,
                transactionType: viewModel.transactionTypePicker.name,
                useEMVSAFToken: viewModel.useEMVSAFTOKEN
            )
            lastOutcome = outcome
            if outcome == nil {
                alertMessage = "Nothing to forward — Secure Element is empty."
            }
        } catch {
            if MTStoreAndForwardTester.isStoreAndForwardBatchAlreadyExists(error) {
                offerResetForBatchAlreadyExists()
                return
            }
            if MTStoreAndForwardTester.isForwardNotApproved(error) {
                alertMessage = "Transaction was NOT approved.\n\n\(error.localizedDescription)\n\nThe item was NOT deleted from the Secure Element."
                return
            }
            alertMessage = "forwardAndDeleteNextViaSDK failed: \(describe(error))\n\nSee the Log section below and Xcode console for full diagnostic dump."
        }
    }
    
    private func deleteNextTapped() async {
        guard ensureNetworkAvailable(for: "deleteNextStoredItemViaSDK") else { return }
        guard tester.storedCount > 0 else {
            presentDeleteNextMessage("Secure Element is empty.")
            return
        }
        
        do {
            let remaining = try await tester.deleteNextStoredItemViaSDK()
            if let remaining {
                presentDeleteNextMessage("Deleted next stored item. Remaining: \(remaining).")
            } else {
                presentDeleteNextMessage("Nothing to delete — Secure Element is empty.")
            }
        } catch {
            if MTStoreAndForwardTester.isStoreAndForwardBatchAlreadyExists(error) {
                offerResetForBatchAlreadyExists()
                return
            }
            alertMessage = "deleteNextStoredItemViaSDK failed: \(describe(error))\n\nSee the Log section below and Xcode console for full diagnostic dump."
        }
    }

    private func presentDeleteNextMessage(_ message: String) {
        deleteNextMessage = message
        showDeleteNextMessage = true
    }
    
    private func fetchAndDeleteAllViaSDK() async {
        guard ensureNetworkAvailable(for: "forwardAndDeleteAllViaSDK") else { return }
        guard tester.storedCount > 0 else {
            alertMessage = "Secure Element is empty."
            return
        }
        
        do {
            let processed = try await tester.forwardAndDeleteAllViaSDK(
                amount: viewModel.amountDecimal,
                processorName: viewModel.paymentProcessorPicker.name,
                transactionType: viewModel.transactionTypePicker.name,
                useEMVSAFToken: viewModel.useEMVSAFTOKEN
            )
            if processed == 0 {
                alertMessage = "Nothing to forward — Secure Element is empty."
            }
        } catch {
            if MTStoreAndForwardTester.isStoreAndForwardBatchAlreadyExists(error) {
                offerResetForBatchAlreadyExists()
                return
            }
            if MTStoreAndForwardTester.isForwardNotApproved(error) {
                alertMessage = "Transaction was NOT approved.\n\n\(error.localizedDescription)\n\nProcessing stopped. The item was NOT deleted and remaining items are still on the Secure Element."
                return
            }
            alertMessage = "forwardAndDeleteAllViaSDK failed: \(describe(error))\n\nSee the Log section below and Xcode console for full diagnostic dump.\n\nProcessing stopped; remaining items are still on the Secure Element."
        }
    }
    
    private func deleteAllViaSDK() async {
        guard ensureNetworkAvailable(for: "deleteAllStorePaymentCardReaderResultBatch") else { return }
        guard tester.storedCount > 0 else {
            alertMessage = "Secure Element is empty."
            return
        }
        
        do {
            try await tester.deleteAllStorePaymentCardReaderResultBatch()
        } catch {
            if MTStoreAndForwardTester.isStoreAndForwardBatchAlreadyExists(error) {
                offerResetForBatchAlreadyExists()
                return
            }
            alertMessage = "deleteAllStorePaymentCardReaderResultBatch failed: \(describe(error))\n\nSee the Log section below and Xcode console for full diagnostic dump."
        }
    }

    private func resetTapped() async {
        do {
            try await tester.resetBatchStateExplicit()
        } catch {
            alertMessage = "resetBatchState failed: \(describe(error))\n\nSee the Log section below and Xcode console for full diagnostic dump."
        }
    }

    private func offerResetForBatchAlreadyExists() {
        if tester.lastSuccessfulForward {
            resetSuggestionMessage = "An active offline batch is already active. This usually means the batch was forwarded to Magensa but not yet deleted. Please retry \"Fetch & Delete Next Item\" to complete the resolve before resetting."
        } else {
            resetSuggestionMessage = "An active offline batch is already active. If you have NOT forwarded it to Magensa yet, you can reset the batch state and retry. Warning: resetting after a successful forward can cause a duplicate charge."
        }
        showResetSuggestion = true
    }

    /// Decode a JWT header/payload base64url segment to a UTF-8 JSON string.
    /// Returns the original segment string if decoding fails.
    private func decodeJWTSegment(_ segment: String) -> String {
        var base64 = segment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Pad to multiple of 4
        let pad = base64.count % 4
        if pad > 0 { base64.append(String(repeating: "=", count: 4 - pad)) }
        guard let data = Data(base64Encoded: base64),
              let json = String(data: data, encoding: .utf8) else {
            return "<could not decode: \(segment.prefix(40))…>"
        }
        return json
    }

    /// Produce a one-line description that includes Apple's `errorName` when
    /// available — much more useful than the bridged "operation couldn't be
    /// completed" string.
    private func describe(_ error: Error) -> String {
        if let readerError = error as? PaymentCardReaderError {
            return "[\(readerError.errorName)] \(error.localizedDescription)"
        }
        if let readError = error as? PaymentCardReaderSession.ReadError {
            return "[\(readError.errorName)] \(error.localizedDescription)"
        }
        let ns = error as NSError
        return "\(ns.domain) code=\(ns.code): \(error.localizedDescription)"
    }

    private func tokenRemainingTime() -> String {
        guard let remaining = tester.magTekVirtualCardReader.paymentCardReaderTokenSecondsRemaining() else {
            return "--:--:--"
        }
        let totalSeconds = max(0, Int(remaining))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func tokenExpireTime() -> String {
        guard let expiration = tester.magTekVirtualCardReader.paymentCardReaderTokenExpirationDate() else {
            return "--"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: expiration)
    }
}
