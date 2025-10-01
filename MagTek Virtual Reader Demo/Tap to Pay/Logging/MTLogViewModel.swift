//
//  Created by MagTek on 8/20/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import SwiftUI
import Combine

@MainActor
final class MTLogViewModel: ObservableObject {
    @Published var selectedLogLevel: MTLogLevel? = nil
    @Published private(set) var filteredLogEntries: [MTLogEntry] = []
    
    private let logger = MTLogManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        logger.$logEntries
            .combineLatest($selectedLogLevel)
            .map { logs, selectedLevel in
                guard let level = selectedLevel else { return logs }
                return logs.filter { $0.level == level }
            }
            .assign(to: &$filteredLogEntries)
    }
    
    func copyLogs() {
        logger.copyLogsToClipboard()
    }
}
