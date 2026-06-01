import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var authService = AuthService.shared

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            // Traffic lights spacer
            Spacer()
                .frame(height: 52)

            // Search field
            SidebarSearchField(query: $state.searchQuery) {
                if !state.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    appState.navigate(to: .search(query: state.searchQuery.trimmingCharacters(in: .whitespaces)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Navigation groups
            List(selection: $state.selectedSection) {
                Section("发现") {
                    ForEach(SidebarSection.allCases.filter(\.isDiscovery)) { section in
                        SidebarNavItem(section: section)
                            .tag(section)
                    }
                }

                Section("我的") {
                    ForEach(SidebarSection.allCases.filter { !$0.isDiscovery }) { section in
                        SidebarNavItem(section: section)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            // User card at bottom
            UserCardView()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(
            minWidth: AppConstants.sidebarMinWidth,
            idealWidth: AppConstants.sidebarIdealWidth,
            maxWidth: AppConstants.sidebarMaxWidth
        )
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                if colorScheme == .dark {
                    Color.black.opacity(0.10)
                } else {
                    Color.white.opacity(0.10)
                }
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(colorScheme == .dark ? .white.opacity(0.04) : .black.opacity(0.035))
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }
}
