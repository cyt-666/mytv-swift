import SwiftUI

enum AdaptiveLayout {
    static var runsOnIOS: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    static func isCompact(_ horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    static func pageHorizontalPadding(compact: Bool) -> CGFloat {
        compact ? 16 : 20
    }
}

struct AdaptiveDetailColumns<Main: View, Sidebar: View>: View {
    let main: Main
    let sidebar: Sidebar
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        @ViewBuilder main: () -> Main,
        @ViewBuilder sidebar: () -> Sidebar
    ) {
        self.main = main()
        self.sidebar = sidebar()
    }

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 18) {
                    sidebar
                        .frame(maxWidth: .infinity, alignment: .leading)
                    main
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 32)
            } else {
                HStack(alignment: .top, spacing: 22) {
                    main
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    sidebar
                        .frame(width: 220)
                }
                .frame(maxWidth: 1080)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
