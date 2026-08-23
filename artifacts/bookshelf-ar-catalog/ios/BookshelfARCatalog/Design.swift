import SwiftUI

enum Brand {
    static let primary = Color(red: 47 / 255, green: 149 / 255, blue: 220 / 255)
    static let background = Color(.systemBackground)
    static let card = Color(.secondarySystemBackground)
    static let secondary = Color(.systemGray6)
    static let muted = Color(.systemGray5)
    static let mutedForeground = Color(.secondaryLabel)
    static let border = Color(.separator)
    static let accent = Color(.systemGray6)
}

struct BookCoverView: View {
    let url: String?
    let title: String
    var size: CGFloat = 70

    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size * 0.68, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var fallback: some View {
        ZStack {
            Brand.accent
            Text(String(title.prefix(1)).uppercased())
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.primary)
        }
    }
}

struct Screen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18, content: content)
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 28)
        }
        .background(Brand.background)
        .scrollDismissesKeyboard(.interactively)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Brand.primary.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct StatusPill: View {
    let text: String
    let emphasized: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(emphasized ? Brand.primary : Brand.mutedForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(emphasized ? Brand.accent : Brand.muted, in: RoundedRectangle(cornerRadius: 7))
    }
}
