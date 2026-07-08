import AppKit
import SwiftUI

struct LogoView: View {
    var size: CGFloat = 96

    var body: some View {
        Group {
            if let image = loadBundledImage(named: "AppIcon") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                SwiftUILogoFallback(size: size)
            }
        }
    }

    private func loadBundledImage(named name: String) -> NSImage? {
        if let url = Bundle.module.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        if let image = NSImage(named: name) {
            return image
        }
        return nil
    }
}

struct SwiftUILogoFallback: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.49, green: 0.32, blue: 0.94),
                        Color(red: 0.18, green: 0.49, blue: 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: Color(red: 0.35, green: 0.20, blue: 0.85).opacity(0.35), radius: size * 0.08, x: 0, y: size * 0.04)

            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
