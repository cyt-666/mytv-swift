import SwiftUI

struct SidebarSearchField: View {
    @Binding var query: String
    @Environment(\.colorScheme) private var colorScheme
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            TextField("搜索", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.10), lineWidth: 1)
        )
    }
}
