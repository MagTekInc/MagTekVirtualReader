//
//  Copyright © 2026 MagTek, Inc. All rights reserved.
//

import SwiftUI

/// Modal sheet that collects the Username, Password, and URL used to configure
/// the `MTViewModel`. Presented at launch and reused for "Update Credentials".
struct MTCredentialsView: View {
    @ObservedObject var mtViewModel: MTViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var userName: String
    @State private var password: String
    @State private var url: String
    @State private var isPasswordVisible = false
    @State private var configurationError: String?
    @State private var isSaving = false

    init(mtViewModel: MTViewModel) {
        self.mtViewModel = mtViewModel
        _userName = State(initialValue: mtViewModel.userName)
        _password = State(initialValue: mtViewModel.password)
        _url = State(initialValue: mtViewModel.configURL.isEmpty ? MTViewModel.defaultURLString : mtViewModel.configURL)
    }

    private var isValid: Bool {
        !userName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        !url.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Credentials") {
                    TextField("Username", text: $userName)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    HStack {
                        Group {
                            if isPasswordVisible {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                        Button(action: { isPasswordVisible.toggle() }) {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                    }
                }

                Section("BASE URL") {
                    TextField("URL", text: $url)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("Update Credentials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            do {
                                try await mtViewModel.applyCredentials(
                                    userName: userName,
                                    password: password,
                                    baseURL: url
                                )
                                dismiss()
                            } catch {
                                configurationError = error.localizedDescription
                            }
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .alert(
                "Unable to Save Credentials",
                isPresented: Binding(
                    get: { configurationError != nil },
                    set: { if !$0 { configurationError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(configurationError ?? "The base URL is invalid.")
            }
        }
    }
}
