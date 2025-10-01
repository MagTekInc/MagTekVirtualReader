//
//  Created by MagTekn on 8/12/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import SwiftUI
import ProximityReader

@main
struct MagTekTapToPayDemoApp: App {
    @StateObject private var mtViewModel = MTViewModel()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MTVirtualReaderDemoView(model: mtViewModel)
            // In SwiftUI, a scenePhase occurs slightly earlier than the events below which can cause `ProximityReader`
            // to reject API calls such as `prepare()`  causing the app to throw a `.backgroundRequestNotAllowed` error.
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    if mtViewModel.isBackground {
                        mtViewModel.preparePaymentCardReaderSession()
                    }
                    mtViewModel.isBackground = false
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    mtViewModel.isBackground = true
                }
        }
    }
}
