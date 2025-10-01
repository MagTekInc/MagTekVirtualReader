//
//  Created by MagTek on 8/20/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import SwiftUI

struct MTLogEntryRow: View {
    let logMessage: MTLogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(MTLogManager.shared.logDateFormatter.string(from: logMessage.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(logMessage.level.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(logMessage.level.color)
            }
            
            Text(logMessage.message)
                .font(.caption)
                .foregroundColor(logMessage.level.color)
        }.padding(4)
    }
}
