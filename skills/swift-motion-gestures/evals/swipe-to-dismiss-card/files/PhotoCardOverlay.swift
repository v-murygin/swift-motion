import SwiftUI

struct PhotoCardOverlay: View {
    let photo: Image
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                photo
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                Button("Close") { isPresented = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
    }
}
