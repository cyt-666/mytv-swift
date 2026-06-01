import SwiftUI

struct BackdropImageView: View {
    let urlString: String?

    var body: some View {
        ZStack {
            if let urlString {
                AsyncPosterImage(urlString: urlString)
                    .blur(radius: 60)
                    .scaleEffect(1.2)
                    .opacity(0.4)

                // Dark overlay for contrast
                Color.black.opacity(0.3)
            } else {
                Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.8), value: urlString)
    }
}
