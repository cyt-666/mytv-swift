import SwiftUI

struct WatchlistView: View {
    @State private var viewModel = WatchlistViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView("暂无观看清单", systemImage: "bookmark", description: Text("收藏的电影和剧集会显示在这里"))
                        .padding(.top, 36)
                } else {
                    MediaGridView(items: viewModel.items) { _ in }
                        .padding(.horizontal, 20)
                }
            }
            .padding(.top, 24)
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.mediaType) { _, _ in Task { await viewModel.load() } }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("类型", selection: $viewModel.mediaType) {
                    Text("电影").tag("movies")
                    Text("剧集").tag("shows")
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
                .frame(width: 180)
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
