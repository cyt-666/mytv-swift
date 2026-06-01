import SwiftUI

struct ShowsView: View {
    @State private var viewModel = ShowsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                } else {
                    MediaGridView(items: viewModel.items.map { .show($0) }) { _ in }
                        .padding(.horizontal, 20)
                }
            }
            .padding(.top, 24)
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.selectedTab) { _, _ in
            Task { await viewModel.load() }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("分类", selection: $viewModel.selectedTab) {
                    Text("热门").tag(ShowsViewModel.Tab.trending)
                    Text("流行").tag(ShowsViewModel.Tab.popular)
                    Text("即将上映").tag(ShowsViewModel.Tab.anticipated)
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
                .frame(width: 300)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { CacheService.clearAllAPIResponses(); await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: viewModel.isLoading)
                }
                .disabled(viewModel.isLoading)
                .help("刷新")
            }
        }
    }
}
