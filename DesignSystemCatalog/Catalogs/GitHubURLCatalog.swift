/*
 Abstract:
 makeGitHubURL ヘルパーの動作確認カタログ。
 fullName に特殊文字が含まれた場合の percent-encode 挙動を確認できる。
 */

import SwiftUI
import GitHubFinderDesignSystem

struct GitHubURLCatalog: View {
    @State private var input = "apple/swift"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Input").font(.caption).foregroundStyle(.secondary)
                TextField("owner/repo", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Output").font(.caption).foregroundStyle(.secondary)
                Text(makeGitHubURL(fullName: input)?.absoluteString ?? "(invalid)")
                    .font(.subheadline.monospaced())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Common Cases").font(.caption).foregroundStyle(.secondary)
                exampleRow(input: "apple/swift")
                exampleRow(input: "user/repo with space")
                exampleRow(input: "owner/日本語")
                exampleRow(input: "")
            }

            Spacer()
        }
        .padding()
        .navigationTitle("GitHubURL")
    }

    private func exampleRow(input: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(input.isEmpty ? "(empty)" : input)
                .font(.caption.monospaced())
                .frame(width: 120, alignment: .leading)
            Text(makeGitHubURL(fullName: input)?.absoluteString ?? "nil")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

#Preview {
    NavigationStack { GitHubURLCatalog() }
}
