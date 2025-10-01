//
//  Created by MagTek on 5/29/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import SwiftUI

struct MTAmountInputView: View {
    @State private var amount = "2.00"
    @FocusState private var isAmountFieldFocused: Bool
    @ObservedObject var model: MTReaderViewModel
    
    var body: some View {
        VStack {
            HStack {
                Label("Amount:", systemImage: "cart")
                    .font(.headline)
                
                Spacer()
                Text("$")
                TextField("2.00", text: $model.amountString)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFieldFocused)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 150)
                    .onChange(of: model.amountString) {
                        let filtered = model.amountString.filter { "0123456789.".contains($0) }
                        let parts = filtered.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
                        
                        if parts.count == 2 {
                            let integerPart = parts[0]
                            let fractionalPart = parts[1].prefix(2) // limit to 2 digits
                            model.amountString = "\(integerPart).\(fractionalPart)"
                        } else {
                            model.amountString = filtered
                        }
                    }
                    .frame(height: 40) // Prevents HStack from collapsing vertically
            }
            .onTapGesture { // Added to dismiss keyboard when tapping outside
                if isAmountFieldFocused {
                    isAmountFieldFocused = false
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isAmountFieldFocused = false
                    }
                }
            }
        }
    }
}
