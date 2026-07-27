import SwiftUI

extension View {
    @ViewBuilder
    func macOSTopSafeAreaBleed() -> some View {
        #if os(macOS)
        self.ignoresSafeArea(.container, edges: .top)
        #else
        self
        #endif
    }

    @ViewBuilder
    func detailTopSafeAreaBleed(_ enabled: Bool) -> some View {
        #if os(iOS)
        if enabled {
            self.ignoresSafeArea(.container, edges: .top)
        } else {
            self
        }
        #else
        self.macOSTopSafeAreaBleed()
        #endif
    }

    @ViewBuilder
    func detailNavigationBarBackgroundHidden(_ enabled: Bool) -> some View {
        #if os(iOS)
        if enabled {
            self.toolbarBackground(.hidden, for: .navigationBar)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
