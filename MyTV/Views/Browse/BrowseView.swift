import SwiftUI

struct BrowseView: View {
    @State private var viewModel = BrowseViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "暂无结果",
                        systemImage: "square.grid.2x2",
                        description: Text("换一个类型或国家试试")
                    )
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    MediaGridView(items: viewModel.items.map { .movie($0) }) { _ in }
                        .padding(.horizontal, 20)
                }
            }
            .padding(.top, 24)
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.selectedGenre) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.selectedCountry) { _, _ in Task { await viewModel.load() } }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Picker("类型", selection: $viewModel.selectedGenre) {
                        Text("全部类型").tag("")
                        ForEach(viewModel.genres) { genre in
                            Text(genre.title).tag(genre.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.regular)

                    Picker("国家", selection: $viewModel.selectedCountry) {
                        Text("全部国家").tag("")
                        ForEach(viewModel.countries) { country in
                            Text(country.title).tag(country.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.regular)
                }
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
