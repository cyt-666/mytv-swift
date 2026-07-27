import SwiftUI

struct LanguageSelectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let isRequired: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("选择语言")
                    .font(.system(size: 28, weight: .bold))
                Text("选择 MyTV 使用的界面语言。你之后也可以在设置中修改。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        appState.setAppLanguage(language)
                        if !isRequired {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(language.nativeName)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(language.localizedNameKey)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if appState.appLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !isRequired {
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(24)
        .frame(minWidth: 320, idealWidth: 420, maxWidth: 520)
    }
}
