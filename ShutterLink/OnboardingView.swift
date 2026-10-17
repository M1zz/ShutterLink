import SwiftUI

/// First-launch guide that explains the camera + App Clip remote flow.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page: Int

    init(startPage: Int = 0, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _page = State(initialValue: startPage)
    }

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let text: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(id: 0, symbol: "camera.on.rectangle.fill",
             title: "Set up the camera",
             text: "Place this iPhone on a tripod or lean it somewhere steady. Use the level and the people counter to frame everyone."),
        Page(id: 1, symbol: "qrcode.viewfinder",
             title: "Anyone can be the remote",
             text: "Tap the QR button. Another iPhone scans it with the Camera app and becomes a remote in seconds, without installing anything."),
        Page(id: 2, symbol: "hand.raised.fill",
             title: "Or go hands-free",
             text: "Raise your palm, clap, or let ShutterLink shoot when everyone smiles. A voice and light countdown tells the group when to pose."),
        Page(id: 3, symbol: "star.square.on.square.fill",
             title: "Nobody blinks",
             text: "Group shot takes several photos and picks the one where everyone's eyes are open. The remote gets a copy to keep.")
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                ForEach(pages) { item in
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: item.symbol)
                            .font(.system(size: 84))
                            .foregroundStyle(.yellow)
                            .frame(height: 120)
                        Text(item.title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(item.text)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Start shooting")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundStyle(.black)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
