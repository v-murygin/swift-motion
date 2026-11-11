import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @State private var isFavorite = false
    @State private var showToast = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(recipe.title).font(.title.bold())
                        Spacer()
                        Button {
                            isFavorite.toggle()
                            showToast = isFavorite
                            if isFavorite {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showToast = false }
                            }
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(isFavorite ? .red : .secondary)
                        }
                    }
                    Text(recipe.summary)
                }
                .padding()
            }

            if showToast {
                Text("Added to favorites")
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
        }
    }
}

struct Recipe { let title: String; let summary: String }
