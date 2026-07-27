import SwiftUI

struct SidebarNavItem: View {
    let section: SidebarSection

    var body: some View {
        Label {
            Text(section.titleKey)
                .font(.system(size: 13))
        } icon: {
            Image(systemName: section.icon)
                .font(.system(size: 14))
                .frame(width: 20)
        }
    }
}
