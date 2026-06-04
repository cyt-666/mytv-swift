import SwiftUI

struct CollectionView: View {
    @State private var viewModel = CollectionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView("暂无片库", systemImage: "folder", description: Text("收藏的电影和剧集会显示在这里"))
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
                Picker("片库类型", selection: $viewModel.mediaType) {
                    Text("电影").tag("movies")
                    Text("剧集").tag("shows")
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
                .labelsHidden()
                .frame(width: 140)
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
