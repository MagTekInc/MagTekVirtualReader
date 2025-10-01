//
//  Created by MagTek on 4/20/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import SwiftUI
import MagTekVirtualReader

struct MTVirtualReaderDemoView: View {
    @Environment(\.scenePhase) var scenePhase
    @ObservedObject var mtViewModel: MTViewModel
    @State private var setupExpanded = false
    @State private var showLogView = false
    @State private var isPerformingTasks = false
    @State var startTime = DispatchTime.now()
    @State var bMeasureRelinkAccountTime = false
    @State var apiTestResult = ""
    
    init(model: MTViewModel) {
        mtViewModel = model
    }
    
    var body: some View {
        Color.black.ignoresSafeArea()
            .overlay {
                VStack {
                    Text("MagTek Virtual Reader Demo")
                    
                    if showLogView {
                        Divider()
                        MTLogView(showLogView: $showLogView)
                    } else {
                        Form {
                            Section {
                                DisclosureGroup("CONFIGURATION", isExpanded: $setupExpanded) {
                                    HStack {
                                        Button(action: {
                                            Task {
                                                await mtViewModel.fetchToken()
                                            }
                                        }, label: {
                                            Label("Fetch JWT Token", systemImage: "link.icloud")
                                                .font(.headline)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        })
                                    }
                                    
                                    HStack {
                                        Button(action: {
                                            startTime = DispatchTime.now()
                                            bMeasureRelinkAccountTime = true
                                            mtViewModel.linkAccount()
                                        }, label: {
                                            Label("Link Merchant Account", systemImage: "link.icloud")
                                                .font(.headline)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        })
                                    }
                                    
                                    HStack {
                                        Button(action: {
                                            mtViewModel.CheckIfAccountLinked()
                                        }, label: {
                                            Label("Is Account Linked?", systemImage: "person.text.rectangle")
                                                .font(.headline)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        })
                                    }
                                    
                                    HStack {
                                        Button(action: {
                                            Task {
                                                mtViewModel.preparePaymentCardReaderSession()
                                            }
                                        }, label: {
                                            Label("Prepare Reader Session", systemImage: "wave.3.right.circle")
                                                .font(.headline)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        })
                                    }
                                    
                                    HStack {
                                        Button(action: {
                                            mtViewModel.cleanup()
                                        }, label: {
                                            Label("Release Reader & Session", systemImage: "trash")
                                                .font(.headline)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        })
                                    }
                                    
                                    HStack {
                                        Button(action: {
                                            showLogView = true
                                        }, label: {
                                            Label("View Log", systemImage: "person.circle.fill")
                                                .font(.headline)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        })
                                    }
                                    .fullScreenCover(isPresented: $showLogView) {
                                        MTLogView(showLogView: $showLogView)
                                    }
                                }
                            }
                            
                            Section {
                                HStack(alignment: .firstTextBaseline) {
                                    Label("Processor: ", systemImage: "dollarsign.circle")
                                        .font(.headline)
                                    Spacer()
                                    Picker("", selection: $mtViewModel.paymentProcessorPicker) {
                                        ForEach(MTPaymentProcessor.allCases) { processor in
                                            Text(processor.name).tag(processor)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .foregroundColor(.blue)
                                }
                                
                                HStack(alignment: .firstTextBaseline) {
                                    Label("Transaction: ", systemImage: "creditcard")
                                        .font(.headline)
                                    Spacer()
                                    Picker("", selection: $mtViewModel.transactionTypePicker) {
                                        ForEach(MTTransactionType.allCases) { type in
                                            Text(type.name).tag(type)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .foregroundColor(.blue)
                                }
                                HStack(alignment: .firstTextBaseline) {
                                    MTAmountInputView(model: mtViewModel)
                                        .onTapGesture { }
                                }
                            } footer: {
                                // Hide Pay button if Tap To Pay isn't supported.
                                if mtViewModel.isTapToPayAvailable  {
                                    ZStack {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(mtViewModel.status)
                                                .foregroundColor(mtViewModel.statusOK ? .green : .gray)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .font(.body)
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                mtViewModel.preparePaymentCardReaderSession()
                                            }, label: {
                                                Image(systemName: "arrow.clockwise.circle")
                                                    .font(.body)
                                                    .foregroundColor(.blue)
                                            })
                                            .frame(alignment: .trailing)
                                        }
                                        .padding(.top, 2)
                                        
                                        if mtViewModel.isProcessingPayment {
                                            Color.black.opacity(0.9)
                                                .edgesIgnoringSafeArea(.all)
                                            VStack(spacing: 16) {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(1.5)
                                                Text("Authorizing Transaction")
                                                    .foregroundColor(.orange)
                                                    .font(.headline)
                                            }
                                            .padding(24)
                                            .background(Color.gray.opacity(0.8))
                                            .cornerRadius(16)
                                            .shadow(radius: 10)
                                        }
                                    }
                                    .animation(.easeInOut, value: mtViewModel.isProcessingPayment)
                                } else {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text("This device or iOS does not support Tap to Pay on iPhone.")
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .font(.body)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .disabled(mtViewModel.isProcessingPayment)
                        
                        Spacer()
                        
                        if mtViewModel.trxShow {
                            Group {
                                Text(mtViewModel.trxStatus)
                                    .font(.title)
                                Text(mtViewModel.trxResult)
                                    .font(Font.system(size: 13, design: .monospaced))
                                Text(mtViewModel.formattedVasResultString)
                                    .font(Font.system(size: 13, design: .monospaced))
                            }
                            .padding(.top, 10)
                            .padding(.horizontal, 24)
                            .colorScheme(.dark)
                            
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    mtViewModel.clearTransactionResult()
                                },
                                       label: { Text("OK")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: 120, minHeight: 50, alignment: .center)
                                })
                                .background(Color.blue)
                                .cornerRadius(15)
                                .colorScheme(.dark)
                                
                                Spacer()
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                            .padding(.horizontal, 24)
                            .colorScheme(.dark)
                        } else {
                            HStack {
                                Spacer()
                                if !setupExpanded {
                                    Button(action: {
                                        debugPrint("model.amountDecimal \(mtViewModel.amountDecimal)")
                                        if mtViewModel.isCardReaderSessionActive {
                                            debugPrint("ACTIVE SESSION pay model.amountDecimal \(mtViewModel.amountDecimal)")
                                            mtViewModel.pay(mtViewModel.amountDecimal)
                                        } else {
                                            Task {
                                                debugPrint("INACTIVE SESSION pay model.amountDecimal \(mtViewModel.amountDecimal)")
                                                await mtViewModel.processTapToPayTransaction(mtViewModel.amountDecimal)
                                            }
                                        }
                                    }, label: {
                                        if mtViewModel.isTapToPayAvailable {
                                            if mtViewModel.statusOK && !mtViewModel.isProcessingPayment {
                                                Label("Pay", systemImage: "wave.3.right.circle")
                                                    .font(.largeTitle)
                                                    .foregroundColor(.white)
                                                    .frame(width: 180, height: 80, alignment: .center)
                                            } else {
                                                // Don't display anything.
                                            }
                                        } else {
                                            Label("Use Other Payment Interface", systemImage: "exclamationmark.triangle")
                                                .font(.body)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
                                        }
                                    })
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(15)
                                    .shadow(radius: 5)
                                    .disabled(isPerformingTasks)
                                    
                                    Spacer()
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                            .padding(.horizontal, 24)
                            .colorScheme(.dark)
                            .background(.black)
                            .onAppear() {
                                if setupExpanded {
                                    setupExpanded.toggle()
                                }
                                
                                if mtViewModel.isTapToPayAvailable  {
                                    Task {
                                        await mtViewModel.setupReaderID()
                                        
                                        if mtViewModel.reconfigureSession || !mtViewModel.isCardReaderSessionActive {
                                            await mtViewModel.reconfigureCardReaderSession()
                                        }
                                    }
                                }
                            }
                            .onChange(of: scenePhase) { _ , newPhase in
                                switch newPhase {
                                case .active:
                                    debugPrint("App Scene Phase: ACTIVE (App is in foreground and interactive)")
                                    // Perform actions when the app becomes active, e.g., resume tasks, refresh data
                                    if !apiTestResult.isEmpty {
                                        mtViewModel.apiTestStatus = apiTestResult
                                        apiTestResult = ""
                                    }
                                case .inactive:
                                    debugPrint("App Scene Phase: INACTIVE (App is in foreground but non-interactive, e.g., system alert, Control Center)")
                                    // This is when you typically see "UIApplication: inactive" in the console.
                                    // Perform actions for temporary interruptions, e.g., pause ongoing animations, save transient state
                                    if bMeasureRelinkAccountTime {
                                        bMeasureRelinkAccountTime = false
                                        debugPrint("- RelinkAccount: \(mtViewModel.getCurrentFormattedDateTimeUTC())")
                                        let end = DispatchTime.now()
                                        let elapsedTimeNanoSeconds = end.uptimeNanoseconds - mtViewModel.startTime.uptimeNanoseconds
                                        let elapsedTimeMiliSeconds = elapsedTimeNanoSeconds / 1_000_000
                                        
                                        let executionTime = "relinkAccount-T&C = \(elapsedTimeMiliSeconds) ms"
                                        debugPrint(executionTime)
                                        apiTestResult = executionTime
                                        mtViewModel.logInfo(executionTime)
                                    }
                                case .background:
                                    debugPrint("App Scene Phase: BACKGROUND (App is minimized or suspended)")
                                    // Perform actions when the app goes to the background, e.g., save critical data, stop location updates
                                @unknown default:
                                    // Handle future cases if new scene phases are introduced
                                    debugPrint("App Scene Phase: Unknown new phase")
                                }
                            }
                        }
                    }
                }
            }
    }
}
