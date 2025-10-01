//
//  Created by MagTek on 8/20/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import SwiftUI

struct MTLogView: View {
    @Binding var showLogView: Bool
    @StateObject private var viewModel = MTLogViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterBar
                Divider()
                logList
            }
            .navigationBarTitle("Logs", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Close") { showLogView = false },
                trailing:
                    HStack(spacing: 20) {
                        Button(action: { MTLogManager.shared.clearLogs() }) {
                            Image(systemName: "trash")}
                        
                        Button(action: { viewModel.copyLogs() }) {
                            Image(systemName: "doc.on.clipboard")}
                    }
            )
        }
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                filterButton(level: nil, title: "All")
                ForEach(MTLogLevel.allCases) { level in
                    filterButton(level: level, title: level.rawValue.capitalized)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(.thinMaterial)
    }
    
    private func filterButton(level: MTLogLevel?, title: String) -> some View {
        let isSelected = viewModel.selectedLogLevel == level
        return Button(action: {
            viewModel.selectedLogLevel = isSelected ? nil : level
        }) {
            Text(title)
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : (level?.color ?? .primary))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? (level?.color ?? .blue) : Color(.systemGray5))
                )
        }
    }
    
    private var logList: some View {
        ScrollViewReader { scrollView in
            List {
                ForEach(viewModel.filteredLogEntries) { logMessage in
                    MTLogEntryRow(logMessage: logMessage)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(rowBackground(for: logMessage))
                }
            }
            .listStyle(.plain)
            .onChange(of: viewModel.filteredLogEntries.count) {
                scrollToBottom(scrollView)
            }
            .onAppear {
                scrollToBottom(scrollView)
            }
        }
    }
    
    private func rowBackground(for log: MTLogEntry) -> Color {
        switch log.level {
        case .error: return Color.red.opacity(0.1)
        case .warning: return Color.orange.opacity(0.08)
        default: return Color.clear
        }
    }
    
    private func scrollToBottom(_ scrollView: ScrollViewProxy) {
        if let lastId = viewModel.filteredLogEntries.last?.id {
            withAnimation(.easeInOut) {
                scrollView.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}
