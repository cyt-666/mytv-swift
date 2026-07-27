import SwiftUI
import AuthenticationServices

struct LoginWebView: View {
    @Environment(AppState.self) private var appState
    @State private var authService = AuthService.shared
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("MyTV")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Trakt.tv 观影助手")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()
                .frame(height: 20)

            Text("登录后可同步观看记录、收藏和观看清单")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                Task { await performLogin() }
            }) {
                HStack {
                    if isLoggingIn {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isLoggingIn ? L10n.string("登录中...") : L10n.string("使用 Trakt 账号登录"))
                }
                .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoggingIn)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .background {
            WindowAccessor { window in
                authService.updatePresentationAnchor(window)
            }
            .frame(width: 0, height: 0)
        }
    }

    private func performLogin() async {
        isLoggingIn = true
        errorMessage = nil
        do {
            try await authService.login()
        } catch is CancellationError {
            // User cancelled, ignore
        } catch {
            if let authError = error as? AuthError,
               case .sessionFailed(let inner) = authError,
               (inner as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                // User cancelled login window, ignore
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoggingIn = false
    }
}
