import SwiftUI

struct PasswordPromptView: View {
    let message: String
    let onSubmit: (String) -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var password = ""
    @FocusState private var focused: Bool

    private var palette: AppPalette { AppPalette.current(scheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "lock.fill")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(palette.text)
            SecureField("Password", text: $password)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(9)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(palette.background.opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.border, lineWidth: 1))
                )
                .focused($focused)
                .onSubmit(submit)
            HStack {
                Spacer()
                Button("Cancel") {
                    onSubmit("")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(palette.secondary)
                Button("Unlock") {
                    submit()
                }
                .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
                .disabled(password.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 320)
        .background(AppPalette.current(scheme).card)
        .onAppear {
            focused = true
        }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        onSubmit(password)
        password = ""
    }
}